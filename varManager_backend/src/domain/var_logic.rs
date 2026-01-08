use crate::infra::db::list_var_versions;
use sqlx::{Row, SqlitePool};
use std::collections::HashSet;

pub async fn resolve_var_exist_name(
    pool: &SqlitePool,
    var_name: &str,
) -> Result<String, String> {
    let parts: Vec<&str> = var_name.split('.').collect();
    if parts.len() != 3 {
        return Ok("missing".to_string());
    }
    let creator = parts[0];
    let package = parts[1];
    let version = parts[2];

    if version.eq_ignore_ascii_case("latest") {
        let latest = find_latest_version(pool, creator, package).await?;
        return Ok(latest.unwrap_or_else(|| "missing".to_string()));
    }

    if var_exists(pool, var_name).await? {
        return Ok(var_name.to_string());
    }

    if let Ok(requested) = version.parse::<i64>() {
        if let Some(closest) = find_closest_version(pool, creator, package, requested).await? {
            return Ok(format!("{}$", closest));
        }
    }

    Ok("missing".to_string())
}

pub async fn vars_dependencies(
    pool: &SqlitePool,
    mut var_names: Vec<String>,
) -> Result<Vec<String>, String> {
    loop {
        let mut varname_exist = Vec::new();
        let mut vars_processed = Vec::new();

        for var_name in var_names {
            if let Some(stripped) = var_name.strip_suffix('^') {
                vars_processed.push(stripped.to_string());
            } else {
                let mut exist = resolve_var_exist_name(pool, &var_name).await?;
                if let Some(stripped) = exist.strip_suffix('$') {
                    exist = stripped.to_string();
                }
                if exist != "missing" {
                    varname_exist.push(exist);
                }
            }
        }

        varname_exist = distinct_except(varname_exist, &vars_processed);
        let mut vardeps = Vec::new();
        for var_name in &varname_exist {
            vardeps.extend(list_dependencies_for_var(pool, var_name).await?);
        }

        vars_processed.extend(varname_exist);
        vars_processed = distinct(vars_processed);

        vardeps = distinct_except(vardeps, &vars_processed);
        if !vardeps.is_empty() {
            for var_name in &vars_processed {
                vardeps.push(format!("{}^", var_name));
            }
            var_names = vardeps;
            continue;
        }

        let cleaned = vars_processed
            .into_iter()
            .map(|name| name.trim_end_matches('^').to_string())
            .collect::<Vec<_>>();
        return Ok(distinct(cleaned));
    }
}

pub async fn implicated_vars(
    pool: &SqlitePool,
    mut var_names: Vec<String>,
) -> Result<Vec<String>, String> {
    loop {
        let mut varname_exist = Vec::new();
        let mut vars_processed = Vec::new();
        let mut implics = Vec::new();

        for var_name in var_names {
            if let Some(stripped) = var_name.strip_suffix('^') {
                vars_processed.push(stripped.to_string());
            } else {
                varname_exist.push(var_name);
            }
        }

        for var_name in &varname_exist {
            implics.extend(implicated_var(pool, var_name).await?);
        }

        vars_processed.extend(varname_exist);
        implics = distinct_except(implics, &vars_processed);

        if !implics.is_empty() {
            for var_name in &vars_processed {
                implics.push(format!("{}^", var_name));
            }
            var_names = implics;
            continue;
        }

        let cleaned = vars_processed
            .into_iter()
            .map(|name| name.trim_end_matches('^').to_string())
            .collect::<Vec<_>>();
        return Ok(distinct(cleaned));
    }
}

async fn implicated_var(pool: &SqlitePool, var_name: &str) -> Result<Vec<String>, String> {
    let mut varnames = Vec::new();
    let count = var_count_version(pool, var_name).await?;
    if count <= 1 {
        let is_latest = var_is_latest(pool, var_name).await?;
        if is_latest {
            let latest = format!("{}.latest", base_without_version(var_name));
            let deps = list_dependents(pool, &[var_name, &latest]).await?;
            varnames.extend(deps);
        } else {
            let deps = list_dependents(pool, &[var_name]).await?;
            varnames.extend(deps);
        }
    }
    Ok(distinct(varnames))
}

async fn var_count_version(pool: &SqlitePool, var_name: &str) -> Result<i64, String> {
    let parts: Vec<&str> = var_name.split('.').collect();
    if parts.len() != 3 {
        return Ok(0);
    }
    let count = sqlx::query_scalar::<_, i64>(
        "SELECT COUNT(1) FROM vars WHERE creatorName = ?1 AND packageName = ?2",
    )
    .bind(parts[0])
    .bind(parts[1])
    .fetch_one(pool)
    .await
    .map_err(|err| err.to_string())?;
    Ok(count)
}

async fn var_is_latest(pool: &SqlitePool, var_name: &str) -> Result<bool, String> {
    let parts: Vec<&str> = var_name.split('.').collect();
    if parts.len() != 3 {
        return Ok(true);
    }
    let version: i64 = match parts[2].parse() {
        Ok(ver) => ver,
        Err(_) => return Ok(true),
    };
    let rows = list_var_versions(pool, parts[0], parts[1]).await?;
    let mut max_ver: Option<i64> = None;
    for (_, ver) in rows {
        if let Ok(parsed) = ver.parse::<i64>() {
            if max_ver.map(|cur| parsed > cur).unwrap_or(true) {
                max_ver = Some(parsed);
            }
        }
    }
    Ok(max_ver.map(|max| version >= max).unwrap_or(true))
}

fn base_without_version(var_name: &str) -> String {
    match var_name.rsplit_once('.') {
        Some((base, _)) => base.to_string(),
        None => var_name.to_string(),
    }
}

async fn list_dependents(pool: &SqlitePool, deps: &[&str]) -> Result<Vec<String>, String> {
    if deps.is_empty() {
        return Ok(Vec::new());
    }
    let mut result = Vec::new();
    for dep in deps {
        let rows = sqlx::query("SELECT varName FROM dependencies WHERE dependency = ?1")
            .bind(dep)
            .fetch_all(pool)
            .await
            .map_err(|err| err.to_string())?;
        for row in rows {
            let name: Option<String> = row.try_get(0).map_err(|err| err.to_string())?;
            if let Some(name) = name {
                result.push(name);
            }
        }
    }
    Ok(result)
}

async fn list_dependencies_for_var(
    pool: &SqlitePool,
    var_name: &str,
) -> Result<Vec<String>, String> {
    let rows = sqlx::query("SELECT dependency FROM dependencies WHERE varName = ?1")
        .bind(var_name)
        .fetch_all(pool)
        .await
        .map_err(|err| err.to_string())?;
    let mut deps = Vec::new();
    for row in rows {
        let dep: Option<String> = row.try_get(0).map_err(|err| err.to_string())?;
        if let Some(dep) = dep {
            deps.push(dep);
        }
    }
    Ok(deps)
}

async fn var_exists(pool: &SqlitePool, var_name: &str) -> Result<bool, String> {
    let exists = sqlx::query_scalar::<_, i64>(
        "SELECT 1 FROM vars WHERE varName = ?1 LIMIT 1",
    )
    .bind(var_name)
    .fetch_optional(pool)
    .await
    .map_err(|err| err.to_string())?;
    Ok(exists.is_some())
}

async fn find_latest_version(
    pool: &SqlitePool,
    creator: &str,
    package: &str,
) -> Result<Option<String>, String> {
    let rows = list_var_versions(pool, creator, package).await?;
    let mut best: Option<(i64, String)> = None;
    for (name, version) in rows {
        if let Ok(ver) = version.parse::<i64>() {
            let should_replace = best.as_ref().map(|(cur, _)| ver > *cur).unwrap_or(true);
            if should_replace {
                best = Some((ver, name));
            }
        }
    }
    Ok(best.map(|(_, name)| name))
}

async fn find_closest_version(
    pool: &SqlitePool,
    creator: &str,
    package: &str,
    requested: i64,
) -> Result<Option<String>, String> {
    let rows = list_var_versions(pool, creator, package).await?;
    let mut versions: Vec<(i64, String)> = rows
        .into_iter()
        .filter_map(|(name, version)| version.parse::<i64>().ok().map(|ver| (ver, name)))
        .collect();
    if versions.is_empty() {
        return Ok(None);
    }
    versions.sort_by_key(|(ver, _)| *ver);
    for (ver, name) in versions.iter() {
        if *ver >= requested {
            return Ok(Some(name.clone()));
        }
    }
    Ok(versions.last().map(|(_, name)| name.clone()))
}

fn distinct(items: Vec<String>) -> Vec<String> {
    let mut seen = HashSet::new();
    let mut out = Vec::new();
    for item in items {
        if seen.insert(item.clone()) {
            out.push(item);
        }
    }
    out
}

fn distinct_except(items: Vec<String>, except: &[String]) -> Vec<String> {
    let except_set: HashSet<String> = except.iter().cloned().collect();
    let mut seen = HashSet::new();
    let mut out = Vec::new();
    for item in items {
        if except_set.contains(&item) {
            continue;
        }
        if seen.insert(item.clone()) {
            out.push(item);
        }
    }
    out
}
