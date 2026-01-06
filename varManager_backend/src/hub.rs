use crate::job_channel::JobReporter;
use crate::var_logic::resolve_var_exist_name;
use crate::AppState;
use reqwest::blocking::Client;
use serde::{Deserialize, Serialize};
use serde_json::{json, Value};
use std::collections::HashMap;

const HUB_API: &str = "https://hub.virtamate.com/citizenx/api.php";
const HUB_PACKAGES: &str = "https://s3cdn.virtamate.com/data/packages.json";

#[derive(Deserialize)]
pub struct HubFindPackagesArgs {
    pub packages: Vec<String>,
}

#[derive(Deserialize)]
pub struct HubResourcesQuery {
    pub perpage: Option<u32>,
    pub location: Option<String>,
    pub paytype: Option<String>,
    pub category: Option<String>,
    pub username: Option<String>,
    pub tags: Option<String>,
    pub search: Option<String>,
    pub sort: Option<String>,
    pub page: Option<u32>,
}

#[derive(Deserialize)]
pub struct HubResourceDetailArgs {
    pub resource_id: String,
}

#[allow(dead_code)]
#[derive(Serialize)]
pub struct HubFindPackagesResult {
    pub packages: Vec<HubPackage>,
}

#[allow(dead_code)]
#[derive(Serialize)]
pub struct HubPackage {
    pub filename: String,
    pub download_url: Option<String>,
}

#[derive(Serialize)]
pub struct HubDownloadList {
    pub download_urls: HashMap<String, String>,
    pub download_urls_no_version: HashMap<String, String>,
}

#[derive(Deserialize)]
pub struct HubDownloadAllArgs {
    pub urls: Vec<String>,
}

pub async fn run_hub_missing_scan_job(
    _state: AppState,
    reporter: JobReporter,
    args: Option<Value>,
) -> Result<(), String> {
    tokio::task::spawn_blocking(move || {
        let args: HubFindPackagesArgs =
            args.map_or_else(|| Ok(HubFindPackagesArgs { packages: Vec::new() }), serde_json::from_value)
                .map_err(|err| err.to_string())?;
        missing_scan_blocking(&reporter, args)
    })
    .await
    .map_err(|err| err.to_string())?
}

pub async fn run_hub_updates_scan_job(
    _state: AppState,
    reporter: JobReporter,
    _args: Option<Value>,
) -> Result<(), String> {
    tokio::task::spawn_blocking(move || {
        updates_scan_blocking(&reporter)
    })
    .await
    .map_err(|err| err.to_string())?
}

pub async fn run_hub_download_all_job(
    state: AppState,
    reporter: JobReporter,
    args: Option<Value>,
) -> Result<(), String> {
    tokio::task::spawn_blocking(move || {
        let args = args.ok_or_else(|| "hub download args required".to_string())?;
        let args: HubDownloadAllArgs = serde_json::from_value(args).map_err(|err| err.to_string())?;
        download_all_blocking(&state, &reporter, args)
    })
    .await
    .map_err(|err| err.to_string())?
}

pub async fn run_hub_info_job(_state: AppState, reporter: JobReporter) -> Result<(), String> {
    tokio::task::spawn_blocking(move || {
        let info = get_info()?;
        reporter.set_result(info);
        Ok(())
    })
    .await
    .map_err(|err| err.to_string())?
}

pub async fn run_hub_resources_job(
    _state: AppState,
    reporter: JobReporter,
    args: Option<Value>,
) -> Result<(), String> {
    tokio::task::spawn_blocking(move || {
        let args = args.ok_or_else(|| "hub_resources args required".to_string())?;
        let query: HubResourcesQuery = serde_json::from_value(args).map_err(|err| err.to_string())?;
        let resources = get_resources(query)?;
        reporter.set_result(resources);
        Ok(())
    })
    .await
    .map_err(|err| err.to_string())?
}

pub async fn run_hub_resource_detail_job(
    _state: AppState,
    reporter: JobReporter,
    args: Option<Value>,
) -> Result<(), String> {
    tokio::task::spawn_blocking(move || {
        let args = args.ok_or_else(|| "hub_resource_detail args required".to_string())?;
        let args: HubResourceDetailArgs =
            serde_json::from_value(args).map_err(|err| err.to_string())?;
        let detail = get_resource_detail(&args.resource_id)?;
        let (download_urls, download_urls_no_version) = extract_resource_downloads(&detail);
        reporter.set_result(
            serde_json::to_value(HubDownloadList {
                download_urls,
                download_urls_no_version,
            })
            .map_err(|err| err.to_string())?,
        );
        Ok(())
    })
    .await
    .map_err(|err| err.to_string())?
}

pub async fn run_hub_find_packages_job(
    _state: AppState,
    reporter: JobReporter,
    args: Option<Value>,
) -> Result<(), String> {
    tokio::task::spawn_blocking(move || {
        let args = args.ok_or_else(|| "hub_find_packages args required".to_string())?;
        let args: HubFindPackagesArgs =
            serde_json::from_value(args).map_err(|err| err.to_string())?;
        let (download_urls, download_urls_no_version) = find_packages_maps(&args.packages)?;
        reporter.set_result(
            serde_json::to_value(HubDownloadList {
                download_urls,
                download_urls_no_version,
            })
            .map_err(|err| err.to_string())?,
        );
        Ok(())
    })
    .await
    .map_err(|err| err.to_string())?
}

fn missing_scan_blocking(reporter: &JobReporter, args: HubFindPackagesArgs) -> Result<(), String> {
    reporter.log("Hub missing scan start".to_string());
    reporter.progress(1);

    let db_path = crate::exe_dir().join("varManager.db");
    let db = crate::db::Db::open(&db_path)?;
    db.ensure_schema()?;

    let missing = if args.packages.is_empty() {
        collect_missing_dependencies(db.connection())?
    } else {
        args.packages
    };

    let (download_urls, download_urls_no_version) = find_packages_maps(&missing)?;
    reporter.set_result(
        serde_json::to_value(HubDownloadList {
            download_urls,
            download_urls_no_version,
        })
        .map_err(|err| err.to_string())?,
    );
    reporter.progress(100);
    reporter.log("Hub missing scan completed".to_string());
    Ok(())
}

fn updates_scan_blocking(reporter: &JobReporter) -> Result<(), String> {
    reporter.log("Hub updates scan start".to_string());
    reporter.progress(1);

    let db_path = crate::exe_dir().join("varManager.db");
    let db = crate::db::Db::open(&db_path)?;
    db.ensure_schema()?;

    let hub_packages = fetch_hub_packages()?;
    let mut newest_by_package: HashMap<String, (i64, String)> = HashMap::new();
    for (filename, download_id) in hub_packages {
        let name = filename.trim_end_matches(".var");
        if let Some((base, version)) = split_var_version(name) {
            if let Ok(ver) = version.parse::<i64>() {
                let entry = newest_by_package.entry(base.to_string()).or_insert((ver, download_id.clone()));
                if ver > entry.0 {
                    *entry = (ver, download_id.clone());
                }
            }
        }
    }

    let mut to_update = Vec::new();
    for (base, (hub_ver, _)) in newest_by_package.iter() {
        let latest_name = format!("{}.latest", base);
        let exist = resolve_var_exist_name(db.connection(), &latest_name)?;
        if exist != "missing" {
            if let Some((_, local_ver)) = split_var_version(&exist) {
                if let Ok(local_ver) = local_ver.parse::<i64>() {
                    if *hub_ver > local_ver {
                        to_update.push(latest_name);
                    }
                }
            }
        }
    }

    let (download_urls, download_urls_no_version) = find_packages_maps(&to_update)?;
    reporter.set_result(
        serde_json::to_value(HubDownloadList {
            download_urls,
            download_urls_no_version,
        })
        .map_err(|err| err.to_string())?,
    );
    reporter.progress(100);
    reporter.log("Hub updates scan completed".to_string());
    Ok(())
}

fn download_all_blocking(state: &AppState, reporter: &JobReporter, args: HubDownloadAllArgs) -> Result<(), String> {
    reporter.log(format!("Hub download all start ({} urls)", args.urls.len()));
    reporter.progress(1);
    crate::system_ops::run_downloader(state, &args.urls)?;
    reporter.progress(100);
    reporter.log("Hub download all completed".to_string());
    Ok(())
}

pub fn get_info() -> Result<Value, String> {
    let client = Client::new();
    let body = json!({ "source": "VaM", "action": "getInfo" });
    let resp = client
        .post(HUB_API)
        .json(&body)
        .send()
        .map_err(|err| err.to_string())?;
    resp.json::<Value>().map_err(|err| err.to_string())
}

fn is_filter_value(value: &str) -> bool {
    let trimmed = value.trim();
    !trimmed.is_empty() && !trimmed.eq_ignore_ascii_case("all")
}

pub fn get_resources(query: HubResourcesQuery) -> Result<Value, String> {
    let perpage = query.perpage.unwrap_or(48);
    let mut body = json!({
        "source": "VaM",
        "action": "getResources",
        "latest_image": "Y",
        "perpage": perpage.to_string(),
        "page": query.page.unwrap_or(1).to_string(),
    });
    if let Some(location) = query.location {
        let trimmed = location.trim();
        if is_filter_value(trimmed) {
            body["location"] = Value::String(trimmed.to_string());
        }
    }
    if let Some(paytype) = query.paytype {
        let trimmed = paytype.trim();
        if is_filter_value(trimmed) {
            body["category"] = Value::String(trimmed.to_string());
        }
    }
    if let Some(category) = query.category {
        let trimmed = category.trim();
        if is_filter_value(trimmed) {
            body["type"] = Value::String(trimmed.to_string());
        }
    }
    if let Some(username) = query.username {
        let trimmed = username.trim();
        if is_filter_value(trimmed) {
            body["username"] = Value::String(trimmed.to_string());
        }
    }
    if let Some(tags) = query.tags {
        let trimmed = tags.trim();
        if is_filter_value(trimmed) {
            body["tags"] = Value::String(trimmed.to_string());
        }
    }
    if let Some(search) = query.search {
        let trimmed = search.trim();
        if !trimmed.is_empty() {
            body["search"] = Value::String(trimmed.to_string());
            body["searchall"] = Value::String("true".to_string());
        }
    }
    if let Some(sort) = query.sort {
        body["sort"] = Value::String(sort);
    }
    let client = Client::new();
    let resp = client
        .post(HUB_API)
        .json(&body)
        .send()
        .map_err(|err| err.to_string())?;
    resp.json::<Value>().map_err(|err| err.to_string())
}

pub fn get_resource_detail(resource_id: &str) -> Result<Value, String> {
    let client = Client::new();
    let body = json!({
        "source": "VaM",
        "action": "getResourceDetail",
        "latest_image": "Y",
        "resource_id": resource_id
    });
    let resp = client
        .post(HUB_API)
        .json(&body)
        .send()
        .map_err(|err| err.to_string())?;
    resp.json::<Value>().map_err(|err| err.to_string())
}

pub fn find_packages_maps(
    packages: &[String],
) -> Result<(HashMap<String, String>, HashMap<String, String>), String> {
    if packages.is_empty() {
        return Ok((HashMap::new(), HashMap::new()));
    }
    let client = Client::new();
    let body = json!({
        "source": "VaM",
        "action": "findPackages",
        "packages": packages.join(",")
    });
    let resp = client
        .post(HUB_API)
        .json(&body)
        .send()
        .map_err(|err| err.to_string())?;
    let json: Value = resp.json().map_err(|err| err.to_string())?;
    let mut download_urls = HashMap::new();
    let mut download_urls_no_version = HashMap::new();
    if let Some(packages) = json.get("packages").and_then(|p| p.as_object()) {
        for package in packages.values() {
            let download_url = package.get("downloadUrl").and_then(|v| v.as_str());
            let filename = package.get("filename").and_then(|v| v.as_str());
            if let (Some(url), Some(name)) = (download_url, filename) {
                if !url.is_empty() && url != "null" && name.ends_with(".var") {
                    let basename = name.trim_end_matches(".var").to_string();
                    download_urls.insert(basename.clone(), url.to_string());
                    if let Some((base, _)) = split_var_version(&basename) {
                        download_urls_no_version.insert(base.to_string(), url.to_string());
                    }
                }
            }
        }
    }
    Ok((download_urls, download_urls_no_version))
}

fn collect_missing_dependencies(conn: &rusqlite::Connection) -> Result<Vec<String>, String> {
    let mut stmt = conn
        .prepare("SELECT dependency FROM dependencies")
        .map_err(|err| err.to_string())?;
    let rows = stmt
        .query_map([], |row| row.get::<_, Option<String>>(0))
        .map_err(|err| err.to_string())?;
    let mut dependencies = Vec::new();
    for row in rows {
        if let Some(dep) = row.map_err(|err| err.to_string())? {
            if !dep.is_empty() {
                dependencies.push(dep);
            }
        }
    }
    dependencies.sort();
    dependencies.dedup();

    let mut missing = Vec::new();
    for dep in dependencies {
        let exist = resolve_var_exist_name(conn, &dep)?;
        if let Some(stripped) = exist.strip_suffix('$') {
            missing.push(format!("{}$", dep));
            if stripped != "missing" {
                continue;
            }
        }
        if exist == "missing" {
            missing.push(dep);
        }
    }
    missing.sort();
    missing.dedup();
    Ok(missing)
}

fn fetch_hub_packages() -> Result<HashMap<String, String>, String> {
    let client = Client::new();
    let resp = client
        .get(HUB_PACKAGES)
        .send()
        .map_err(|err| err.to_string())?;
    resp.json::<HashMap<String, String>>()
        .map_err(|err| err.to_string())
}

fn split_var_version(name: &str) -> Option<(&str, &str)> {
    let mut parts = name.rsplitn(2, '.');
    let version = parts.next()?;
    let base = parts.next()?;
    Some((base, version))
}

fn extract_resource_downloads(detail: &Value) -> (HashMap<String, String>, HashMap<String, String>) {
    let mut download_urls = HashMap::new();
    let mut download_urls_no_version = HashMap::new();

    if let Some(hubfiles) = detail.get("hubFiles").and_then(|v| v.as_array()) {
        for hubfile in hubfiles {
            let filename = hubfile.get("filename").and_then(|v| v.as_str());
            let url = hubfile.get("urlHosted").and_then(|v| v.as_str());
            if let (Some(name), Some(url)) = (filename, url) {
                if !url.is_empty() && url != "null" && name.ends_with(".var") {
                    let basename = name.trim_end_matches(".var").to_string();
                    download_urls.insert(basename.clone(), url.to_string());
                    if let Some((base, _)) = split_var_version(&basename) {
                        download_urls_no_version.insert(base.to_string(), url.to_string());
                    }
                }
            }
        }
    }

    if let Some(deps) = detail.get("dependencies").and_then(|v| v.as_object()) {
        for dep_entries in deps.values() {
            if let Some(dep_array) = dep_entries.as_array() {
                for dep in dep_array {
                    let filename = dep.get("filename").and_then(|v| v.as_str());
                    let url = dep.get("downloadUrl").and_then(|v| v.as_str());
                    if let (Some(name), Some(url)) = (filename, url) {
                        if !url.is_empty() && url != "null" && name.ends_with(".var") {
                            let basename = name.trim_end_matches(".var").to_string();
                            download_urls.insert(basename.clone(), url.to_string());
                            if let Some((base, _)) = split_var_version(&basename) {
                                download_urls_no_version.insert(base.to_string(), url.to_string());
                            }
                        }
                    }
                }
            }
        }
    }

    (download_urls, download_urls_no_version)
}
