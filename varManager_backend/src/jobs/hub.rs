use crate::jobs::job_channel::JobReporter;
use crate::domain::var_logic::resolve_var_exist_name;
use crate::app::AppState;
use reqwest::blocking::Client;
use reqwest::header;
use serde::{Deserialize, Serialize};
use serde_json::{json, Value};
use std::cmp::Ordering;
use std::collections::{HashMap, HashSet};
use std::sync::{Mutex, OnceLock};
use std::time::{Duration, SystemTime};
use scraper::{Html, Selector};
use sqlx::{Row, SqlitePool};

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

#[derive(Clone)]
pub struct HubOptionsCache {
    pub locations: Vec<String>,
    pub pay_types: Vec<String>,
    pub categories: Vec<String>,
    pub tags: Vec<String>,
    pub creators: Vec<String>,
    pub sorts: Vec<String>,
}

static HUB_OPTIONS_CACHE: OnceLock<Mutex<Option<HubOptionsCache>>> = OnceLock::new();
static HUB_INFO_CACHE: OnceLock<Mutex<Option<HubInfoCacheEntry>>> = OnceLock::new();

#[derive(Serialize)]
pub struct HubDownloadList {
    pub download_urls: HashMap<String, String>,
    pub download_urls_no_version: HashMap<String, String>,
}

#[derive(Deserialize)]
pub struct HubDownloadAllArgs {
    pub urls: Vec<String>,
}

#[derive(Serialize)]
pub struct HubOverviewPanelData {
    pub description: String,
    pub images: Vec<String>,
}

#[derive(Clone)]
struct HubInfoCacheEntry {
    value: Value,
    fetched_at: SystemTime,
}

pub async fn run_hub_missing_scan_job(
    state: AppState,
    reporter: JobReporter,
    args: Option<Value>,
) -> Result<(), String> {
    tokio::task::spawn_blocking(move || {
        let args: HubFindPackagesArgs =
            args.map_or_else(|| Ok(HubFindPackagesArgs { packages: Vec::new() }), serde_json::from_value)
                .map_err(|err| err.to_string())?;
        missing_scan_blocking(&state, &reporter, args)
    })
    .await
    .map_err(|err| err.to_string())?
}

pub async fn run_hub_updates_scan_job(
    state: AppState,
    reporter: JobReporter,
    _args: Option<Value>,
) -> Result<(), String> {
    tokio::task::spawn_blocking(move || {
        updates_scan_blocking(&state, &reporter)
    })
    .await
    .map_err(|err| err.to_string())?
}

pub async fn run_hub_download_all_job(
    state: AppState,
    reporter: JobReporter,
    args: Option<Value>,
) -> Result<(), String> {
    let args = args.ok_or_else(|| "hub download args required".to_string())?;
    let args: HubDownloadAllArgs = serde_json::from_value(args).map_err(|err| err.to_string())?;
    download_all_async(&state, &reporter, args).await
}

pub async fn run_hub_info_job(_state: AppState, reporter: JobReporter) -> Result<(), String> {
    tokio::task::spawn_blocking(move || {
        let info = get_info_cached(false)?;
        let trimmed = match info {
            Value::Object(mut map) => {
                map.remove("users");
                map.remove("tags");
                Value::Object(map)
            }
            other => other,
        };
        reporter.set_result(trimmed);
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

pub async fn run_hub_overview_panel_job(
    _state: AppState,
    reporter: JobReporter,
    args: Option<Value>,
) -> Result<(), String> {
    tokio::task::spawn_blocking(move || {
        let args = args.ok_or_else(|| "hub_overview_panel args required".to_string())?;
        let args: HubResourceDetailArgs =
            serde_json::from_value(args).map_err(|err| err.to_string())?;
        let overview_data = get_overview_panel(&args.resource_id)?;
        reporter.set_result(
            serde_json::to_value(&overview_data)
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

fn missing_scan_blocking(
    state: &AppState,
    reporter: &JobReporter,
    args: HubFindPackagesArgs,
) -> Result<(), String> {
    reporter.log("Hub missing scan start".to_string());
    reporter.progress(1);

    let pool = &state.db_pool;
    let handle = tokio::runtime::Handle::current();

    let missing = if args.packages.is_empty() {
        handle.block_on(collect_missing_dependencies(pool))?
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

fn updates_scan_blocking(state: &AppState, reporter: &JobReporter) -> Result<(), String> {
    reporter.log("Hub updates scan start".to_string());
    reporter.progress(1);

    let pool = &state.db_pool;
    let handle = tokio::runtime::Handle::current();

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
        let exist = handle.block_on(resolve_var_exist_name(pool, &latest_name))?;
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

async fn download_all_async(
    state: &AppState,
    reporter: &JobReporter,
    args: HubDownloadAllArgs,
) -> Result<(), String> {
    let summary = crate::infra::downloader::download_urls(state, reporter, &args.urls).await?;
    reporter
        .set_result(serde_json::to_value(&summary).map_err(|err| err.to_string())?);
    if summary.failed > 0 {
        return Err(format!("{} download(s) failed.", summary.failed));
    }
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

fn hub_info_cache() -> &'static Mutex<Option<HubInfoCacheEntry>> {
    HUB_INFO_CACHE.get_or_init(|| Mutex::new(None))
}

fn get_info_cached(refresh: bool) -> Result<Value, String> {
    const TTL: Duration = Duration::from_secs(300);
    let cache = hub_info_cache();
    let mut guard = cache.lock().map_err(|_| "hub info cache locked")?;
    if !refresh {
        if let Some(entry) = guard.as_ref() {
            if entry
                .fetched_at
                .elapsed()
                .map(|age| age < TTL)
                .unwrap_or(false)
            {
                return Ok(entry.value.clone());
            }
        }
    }
    let info = get_info()?;
    *guard = Some(HubInfoCacheEntry {
        value: info.clone(),
        fetched_at: SystemTime::now(),
    });
    Ok(info)
}

fn list_from_array(value: Option<&Value>) -> Vec<String> {
    match value {
        Some(Value::Array(items)) => items
            .iter()
            .filter_map(|item| item.as_str().map(|s| s.to_string()))
            .filter(|s| !s.trim().is_empty())
            .collect(),
        _ => Vec::new(),
    }
}

fn list_from_keys(value: Option<&Value>) -> Vec<String> {
    match value {
        Some(Value::Object(map)) => map
            .keys()
            .filter(|s| !s.trim().is_empty())
            .map(|s| s.to_string())
            .collect(),
        _ => Vec::new(),
    }
}

fn load_hub_options(refresh: bool) -> Result<HubOptionsCache, String> {
    let info = get_info_cached(refresh)?;
    let locations = list_from_array(info.get("location"));
    let pay_types = list_from_array(info.get("category"));
    let categories = list_from_array(info.get("type"));
    let tags = list_from_keys(info.get("tags"));
    let creators = list_from_keys(info.get("users"));
    let sorts = list_from_array(info.get("sort"));

    Ok(HubOptionsCache {
        locations,
        pay_types,
        categories,
        tags,
        creators,
        sorts,
    })
}

fn hub_options_cache() -> &'static Mutex<Option<HubOptionsCache>> {
    HUB_OPTIONS_CACHE.get_or_init(|| Mutex::new(None))
}

pub fn search_hub_options(
    kind: &str,
    query: &str,
    offset: usize,
    limit: usize,
    refresh: bool,
) -> Result<(Vec<String>, usize), String> {
    let cache = hub_options_cache();
    let mut guard = cache.lock().map_err(|_| "hub options cache locked")?;
    if refresh || guard.is_none() {
        *guard = Some(load_hub_options(refresh)?);
    }
    let options = guard.clone().ok_or_else(|| "hub options empty".to_string())?;
    let mut items = match kind {
        "location" => options.locations,
        "paytype" => options.pay_types,
        "category" => options.categories,
        "tag" => options.tags,
        "creator" => options.creators,
        "sort" => options.sorts,
        _ => return Err("invalid hub option kind".to_string()),
    };
    let needle = query.trim().to_lowercase();
    if !needle.is_empty() {
        items.retain(|item| item.to_lowercase().contains(&needle));
    }
    items.sort_by(|a, b| {
        let a_lower = a.to_lowercase();
        let b_lower = b.to_lowercase();
        if !needle.is_empty() {
            let a_prefix = a_lower.starts_with(&needle);
            let b_prefix = b_lower.starts_with(&needle);
            if a_prefix != b_prefix {
                return if a_prefix {
                    Ordering::Less
                } else {
                    Ordering::Greater
                };
            }
        }
        a_lower.cmp(&b_lower)
    });
    items.dedup_by(|a, b| a.eq_ignore_ascii_case(b));
    let total = items.len();
    let start = offset.min(total);
    let end = (start + limit).min(total);
    Ok((items[start..end].to_vec(), total))
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

async fn collect_missing_dependencies(pool: &SqlitePool) -> Result<Vec<String>, String> {
    let rows = sqlx::query("SELECT dependency FROM dependencies")
        .fetch_all(pool)
        .await
        .map_err(|err| err.to_string())?;
    let mut dependencies = Vec::new();
    for row in rows {
        if let Some(dep) = row
            .try_get::<Option<String>, _>(0)
            .map_err(|err| err.to_string())?
        {
            if !dep.is_empty() {
                dependencies.push(dep);
            }
        }
    }
    dependencies.sort();
    dependencies.dedup();

    let mut missing = Vec::new();
    for dep in dependencies {
        let exist = resolve_var_exist_name(pool, &dep).await?;
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

fn hub_headers() -> header::HeaderMap {
    let mut headers = header::HeaderMap::new();
    headers.insert(
        header::ACCEPT,
        "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8"
            .parse()
            .unwrap(),
    );
    headers.insert(
        header::ACCEPT_LANGUAGE,
        "en-US,en;q=0.9".parse().unwrap(),
    );
    headers.insert(header::COOKIE, "vamhubconsent=yes".parse().unwrap());
    headers.insert(
        header::USER_AGENT,
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/127.0.0.0 Safari/537.36"
            .parse()
            .unwrap(),
    );
    headers
}

pub fn get_overview_panel(resource_id: &str) -> Result<HubOverviewPanelData, String> {
    let url = format!("https://hub.virtamate.com/resources/{}/overview-panel", resource_id);
    let client = Client::new();

    let response = client
        .get(&url)
        .headers(hub_headers())
        .send()
        .map_err(|err| err.to_string())?;

    if !response.status().is_success() {
        return Err(format!("Failed to fetch overview panel: {}", response.status()));
    }

    let html_content = response.text().map_err(|err| err.to_string())?;
    let document = Html::parse_document(&html_content);

    let normalize_text = |text: &str| text.split_whitespace().collect::<Vec<_>>().join(" ");
    let normalize_lines = |text: &str| {
        let cleaned = text.replace('\r', "\n");
        cleaned
            .lines()
            .map(|line| line.trim())
            .filter(|line| !line.is_empty())
            .collect::<Vec<_>>()
            .join("\n")
    };
    let normalize_url = |raw: &str| -> Option<String> {
        let trimmed = raw.trim();
        if trimmed.is_empty() {
            return None;
        }
        let lower = trimmed.to_ascii_lowercase();
        if lower.starts_with("data:") || lower.starts_with("javascript:") || lower.starts_with("blob:") {
            return None;
        }
        if trimmed.starts_with("http://") || trimmed.starts_with("https://") {
            return Some(trimmed.to_string());
        }
        if trimmed.starts_with("//") {
            return Some(format!("https:{}", trimmed));
        }
        if trimmed.starts_with("/") {
            return Some(format!("https://hub.virtamate.com{}", trimmed));
        }
        Some(format!("https://hub.virtamate.com/{}", trimmed))
    };
    let is_allowed_image = |url: &str| {
        let lower = url.to_ascii_lowercase();
        if lower.contains("/internal_data/") {
            return false;
        }
        if lower.starts_with("https://hub.virtamate.com/attachments/")
            || lower.starts_with("http://hub.virtamate.com/attachments/")
        {
            return true;
        }
        lower.contains("rsc.cdn77.org/data/resource_icons/")
    };
    let looks_like_image_attachment = |url: &str| {
        let lower = url.to_ascii_lowercase();
        if !lower.contains("/attachments/") {
            return false;
        }
        ["-jpg.", "-jpeg.", "-png.", "-gif.", "-webp."]
            .iter()
            .any(|ext| lower.contains(ext))
    };

    // 提取描述文本
    let description_selector = Selector::parse(".bbWrapper").unwrap();
    let mut description = String::new();

    // 读取 JSON-LD 描述与缩略图
    let mut ld_description: Option<String> = None;
    let mut ld_thumbnail: Option<String> = None;
    let ld_selector = Selector::parse("script[type=\"application/ld+json\"]").unwrap();
    for element in document.select(&ld_selector) {
        let json_text = element.text().collect::<Vec<_>>().join("").trim().to_string();
        if json_text.is_empty() {
            continue;
        }
        if let Ok(value) = serde_json::from_str::<Value>(&json_text) {
            let mut stack = vec![value];
            while let Some(node) = stack.pop() {
                match node {
                    Value::Object(map) => {
                        if ld_description.is_none() {
                            if let Some(Value::String(desc)) = map.get("description") {
                                ld_description = Some(desc.clone());
                            }
                        }
                        if ld_thumbnail.is_none() {
                            if let Some(Value::String(url)) = map.get("thumbnailUrl") {
                                ld_thumbnail = Some(url.clone());
                            }
                        }
                        if let Some(Value::Array(graph)) = map.get("@graph") {
                            for item in graph {
                                stack.push(item.clone());
                            }
                        }
                    }
                    Value::Array(items) => {
                        for item in items {
                            stack.push(item);
                        }
                    }
                    _ => {}
                }
                if ld_description.is_some() && ld_thumbnail.is_some() {
                    break;
                }
            }
        }
        if ld_description.is_some() && ld_thumbnail.is_some() {
            break;
        }
    }

    if let Some(desc) = ld_description {
        description = normalize_lines(&desc);
    }
    if description.is_empty() {
        if let Some(desc_element) = document.select(&description_selector).next() {
            let raw = desc_element.text().collect::<Vec<_>>().join(" ");
            description = normalize_text(&raw);
        }
    }

    // 提取图片URL
    let mut images: Vec<String> = Vec::new();
    let mut seen: HashSet<String> = HashSet::new();
    let mut push_image = |url: String| {
        if seen.insert(url.clone()) {
            images.push(url);
        }
    };

    let image_wrapper_selector = Selector::parse(".bbImageWrapper").unwrap();
    for element in document.select(&image_wrapper_selector) {
        if let Some(src) = element.value().attr("data-src") {
            if let Some(url) = normalize_url(src) {
                if is_allowed_image(&url) {
                    push_image(url);
                }
            }
        }
    }

    let attachment_selector = Selector::parse("ul.attachmentList a.file-preview").unwrap();
    for element in document.select(&attachment_selector) {
        for attr in ["href", "data-href"] {
            if let Some(href) = element.value().attr(attr) {
                if let Some(url) = normalize_url(href) {
                    if looks_like_image_attachment(&url) && is_allowed_image(&url) {
                        push_image(url);
                    }
                }
            }
        }
    }

    let img_selector = Selector::parse(".bbWrapper img").unwrap();
    for element in document.select(&img_selector) {
        for attr in ["data-src", "data-lazy-src", "data-original", "src"] {
            if let Some(src) = element.value().attr(attr) {
                if let Some(url) = normalize_url(src) {
                    if is_allowed_image(&url) {
                        push_image(url);
                    }
                }
            }
        }
    }

    if let Some(url) = ld_thumbnail {
        if let Some(normalized) = normalize_url(&url) {
            if is_allowed_image(&normalized) {
                push_image(normalized);
            }
        }
    }

    Ok(HubOverviewPanelData {
        description,
        images,
    })
}
