use crate::db::list_var_versions;
use rusqlite::{Connection, OptionalExtension};
use std::collections::HashSet;

pub fn resolve_var_exist_name(conn: &Connection, var_name: &str) -> Result<String, String> {
    let parts: Vec<&str> = var_name.split('.').collect();
    if parts.len() != 3 {
        return Ok("missing".to_string());
    }
    let creator = parts[0];
    let package = parts[1];
    let version = parts[2];

    if version.eq_ignore_ascii_case("latest") {
        let latest = find_latest_version(conn, creator, package)?;
        return Ok(latest.unwrap_or_else(|| "missing".to_string()));
    }

    if var_exists(conn, var_name)? {
        return Ok(var_name.to_string());
    }

    if let Ok(requested) = version.parse::<i64>() {
        if let Some(closest) = find_closest_version(conn, creator, package, requested)? {
            return Ok(format!("{}$", closest));
        }
    }

    Ok("missing".to_string())
}

pub fn vars_dependencies(conn: &Connection, var_names: Vec<String>) -> Result<Vec<String>, String> {
    let mut varname_exist = Vec::new();
    let mut vars_processed = Vec::new();

    for var_name in var_names {
        if let Some(stripped) = var_name.strip_suffix('^') {
            vars_processed.push(stripped.to_string());
        } else {
            let mut exist = resolve_var_exist_name(conn, &var_name)?;
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
        vardeps.extend(list_dependencies_for_var(conn, var_name)?);
    }

    vars_processed.extend(varname_exist);
    vars_processed = distinct(vars_processed);

    vardeps = distinct_except(vardeps, &vars_processed);
    if !vardeps.is_empty() {
        for var_name in &vars_processed {
            vardeps.push(format!("{}^", var_name));
        }
        vars_dependencies(conn, vardeps)
    } else {
        let cleaned = vars_processed
            .into_iter()
            .map(|name| name.trim_end_matches('^').to_string())
            .collect::<Vec<_>>();
        Ok(distinct(cleaned))
    }
}

pub fn implicated_vars(conn: &Connection, var_names: Vec<String>) -> Result<Vec<String>, String> {
    tracing::debug!(
        requested_count = var_names.len(),
        "implicated_vars: start"
    );
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
        implics.extend(implicated_var(conn, var_name)?);
    }

    vars_processed.extend(varname_exist);
    implics = distinct_except(implics, &vars_processed);

    if !implics.is_empty() {
        for var_name in &vars_processed {
            implics.push(format!("{}^", var_name));
        }
        implicated_vars(conn, implics)
    } else {
        let cleaned = vars_processed
            .into_iter()
            .map(|name| name.trim_end_matches('^').to_string())
            .collect::<Vec<_>>();
        tracing::debug!(
            resolved_count = cleaned.len(),
            "implicated_vars: resolved"
        );
        Ok(distinct(cleaned))
    }
}

fn implicated_var(conn: &Connection, var_name: &str) -> Result<Vec<String>, String> {
    let mut varnames = Vec::new();
    let count = var_count_version(conn, var_name)?;
    if count <= 1 {
        let is_latest = var_is_latest(conn, var_name)?;
        if is_latest {
            let latest = format!("{}.latest", base_without_version(var_name));
            let deps = list_dependents(conn, &[var_name, &latest])?;
            tracing::debug!(
                var_name = %var_name,
                count,
                is_latest,
                latest = %latest,
                dependent_count = deps.len(),
                "implicated_var: dependents"
            );
            varnames.extend(deps);
        } else {
            let deps = list_dependents(conn, &[var_name])?;
            tracing::debug!(
                var_name = %var_name,
                count,
                is_latest,
                dependent_count = deps.len(),
                "implicated_var: dependents"
            );
            varnames.extend(deps);
        }
    } else {
        tracing::debug!(
            var_name = %var_name,
            count,
            "implicated_var: skip (multi-version)"
        );
    }
    Ok(distinct(varnames))
}

fn var_count_version(conn: &Connection, var_name: &str) -> Result<i64, String> {
    let parts: Vec<&str> = var_name.split('.').collect();
    if parts.len() != 3 {
        return Ok(0);
    }
    let mut stmt = conn
        .prepare("SELECT COUNT(1) FROM vars WHERE creatorName = ?1 AND packageName = ?2")
        .map_err(|err| err.to_string())?;
    let count: i64 = stmt
        .query_row([parts[0], parts[1]], |row| row.get(0))
        .map_err(|err| err.to_string())?;
    Ok(count)
}

fn var_is_latest(conn: &Connection, var_name: &str) -> Result<bool, String> {
    let parts: Vec<&str> = var_name.split('.').collect();
    if parts.len() != 3 {
        return Ok(true);
    }
    let version: i64 = match parts[2].parse() {
        Ok(ver) => ver,
        Err(_) => return Ok(true),
    };
    let rows = list_var_versions(conn, parts[0], parts[1])?;
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

fn list_dependents(conn: &Connection, deps: &[&str]) -> Result<Vec<String>, String> {
    if deps.is_empty() {
        return Ok(Vec::new());
    }
    let mut result = Vec::new();
    let mut stmt = conn
        .prepare("SELECT varName FROM dependencies WHERE dependency = ?1")
        .map_err(|err| err.to_string())?;
    for dep in deps {
        let rows = stmt
            .query_map([*dep], |row| row.get::<_, Option<String>>(0))
            .map_err(|err| err.to_string())?;
        for row in rows {
            if let Some(name) = row.map_err(|err| err.to_string())? {
                result.push(name);
            }
        }
    }
    Ok(result)
}

fn list_dependencies_for_var(conn: &Connection, var_name: &str) -> Result<Vec<String>, String> {
    let mut stmt = conn
        .prepare("SELECT dependency FROM dependencies WHERE varName = ?1")
        .map_err(|err| err.to_string())?;
    let rows = stmt
        .query_map([var_name], |row| row.get::<_, Option<String>>(0))
        .map_err(|err| err.to_string())?;
    let mut deps = Vec::new();
    for row in rows {
        if let Some(dep) = row.map_err(|err| err.to_string())? {
            deps.push(dep);
        }
    }
    Ok(deps)
}

fn var_exists(conn: &Connection, var_name: &str) -> Result<bool, String> {
    let mut stmt = conn
        .prepare("SELECT 1 FROM vars WHERE varName = ?1 LIMIT 1")
        .map_err(|err| err.to_string())?;
    let exists: Option<i64> = stmt
        .query_row([var_name], |row| row.get(0))
        .optional()
        .map_err(|err| err.to_string())?;
    Ok(exists.is_some())
}

fn find_latest_version(
    conn: &Connection,
    creator: &str,
    package: &str,
) -> Result<Option<String>, String> {
    let rows = list_var_versions(conn, creator, package)?;
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

fn find_closest_version(
    conn: &Connection,
    creator: &str,
    package: &str,
    requested: i64,
) -> Result<Option<String>, String> {
    let rows = list_var_versions(conn, creator, package)?;
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
