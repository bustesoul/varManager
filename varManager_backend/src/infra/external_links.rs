use crate::app::data_dir;
use regex::Regex;
use std::collections::{HashMap, HashSet};
use std::fs;
use std::path::{Path, PathBuf};
use walkdir::WalkDir;

#[derive(Clone, Copy, Debug, Eq, PartialEq, Hash)]
pub enum ExternalSource {
    Pixeldrain,
    Mediafire,
}

impl ExternalSource {
    pub fn as_str(&self) -> &'static str {
        match self {
            ExternalSource::Pixeldrain => "pixeldrain",
            ExternalSource::Mediafire => "mediafire",
        }
    }

    fn rank(&self) -> u8 {
        match self {
            ExternalSource::Pixeldrain => 2,
            ExternalSource::Mediafire => 1,
        }
    }

    pub fn from_url(url: &str) -> Option<Self> {
        let lower = url.to_ascii_lowercase();
        if lower.contains("pixeldrain.com") || lower.contains("pixeldrain.sriflix.my") {
            return Some(ExternalSource::Pixeldrain);
        }
        if lower.contains("mediafire.com") {
            return Some(ExternalSource::Mediafire);
        }
        None
    }
}

#[derive(Default)]
pub struct ExternalLinksResult {
    pub download_urls: HashMap<String, String>,
    pub download_urls_no_version: HashMap<String, String>,
    pub download_sources: HashMap<String, String>,
    pub download_sources_no_version: HashMap<String, String>,
    pub torrent_hits: HashMap<String, Vec<String>>,
    pub torrent_hits_no_version: HashMap<String, Vec<String>>,
}

pub struct ExternalLinksOptions {
    pub sources: HashSet<ExternalSource>,
    pub pixeldrain_bypass: bool,
    pub include_torrents: bool,
}

pub fn scan_torrents_only(packages: &[String]) -> Result<ExternalLinksResult, String> {
    let matcher = PackageMatcher::new(packages);
    let mut result = ExternalLinksResult::default();
    if matcher.is_empty() {
        return Ok(result);
    }

    let links_root = links_root();
    if !links_root.exists() {
        return Ok(result);
    }

    let var_re =
        Regex::new(r"(?i)([A-Za-z0-9_\-]{1,60}\.[A-Za-z0-9_\-]{1,80}\.(?:\d+|latest))\.var")
            .map_err(|err| err.to_string())?;

    scan_torrents(&links_root, &var_re, &matcher, &mut result)?;
    Ok(result)
}

pub fn scan_external_links(
    packages: &[String],
    options: &ExternalLinksOptions,
) -> Result<ExternalLinksResult, String> {
    let matcher = PackageMatcher::new(packages);
    let mut result = ExternalLinksResult::default();
    if matcher.is_empty() {
        return Ok(result);
    }

    let links_root = links_root();
    if !links_root.exists() {
        return Ok(result);
    }

    let var_re =
        Regex::new(r"(?i)([A-Za-z0-9_\-]{1,60}\.[A-Za-z0-9_\-]{1,80}\.(?:\d+|latest))\.var")
            .map_err(|err| err.to_string())?;
    let url_re = Regex::new(r##"(?i)https?://[^\s\]\)>"']+"##).map_err(|err| err.to_string())?;

    let mut allowed = options.sources.clone();
    if allowed.is_empty() {
        allowed.insert(ExternalSource::Pixeldrain);
        allowed.insert(ExternalSource::Mediafire);
    }

    let mut rank_map: HashMap<String, u8> = HashMap::new();
    let mut base_rank_map: HashMap<String, (i64, u8)> = HashMap::new();

    let walker = WalkDir::new(&links_root).into_iter().filter_entry(|entry| {
        if entry.file_type().is_dir() {
            return !is_torrents_dir(entry.path());
        }
        true
    });

    for entry in walker {
        let entry = match entry {
            Ok(value) => value,
            Err(_) => continue,
        };
        if !entry.file_type().is_file() {
            continue;
        }
        if entry
            .path()
            .extension()
            .and_then(|ext| ext.to_str())
            .map(|ext| !ext.eq_ignore_ascii_case("txt"))
            .unwrap_or(true)
        {
            continue;
        }
        let data = match fs::read(entry.path()) {
            Ok(value) => value,
            Err(_) => continue,
        };
        let content = String::from_utf8_lossy(&data);
        for line in content.lines() {
            let var_name = match var_re.captures(line).and_then(|caps| caps.get(1)) {
                Some(m) => m.as_str(),
                None => continue,
            };
            let url_match = match url_re.find(line) {
                Some(m) => m.as_str(),
                None => continue,
            };
            let mut url = trim_url(url_match);
            let source = match ExternalSource::from_url(&url) {
                Some(value) => value,
                None => continue,
            };
            if !allowed.contains(&source) {
                continue;
            }
            if source == ExternalSource::Pixeldrain && options.pixeldrain_bypass {
                url = apply_pixeldrain_bypass(&url);
            }

            if let Some(exact_key) = matcher.exact_key(var_name) {
                insert_url(
                    &mut result.download_urls,
                    &mut result.download_sources,
                    &mut rank_map,
                    exact_key,
                    url.clone(),
                    source,
                );
            }

            if let Some((base, version)) = split_var_version(var_name) {
                if let Some(base_key) = matcher.base_key(base) {
                    if let Some(version_num) = parse_version(version) {
                        insert_base_url(
                            &mut result.download_urls_no_version,
                            &mut result.download_sources_no_version,
                            &mut base_rank_map,
                            base_key,
                            version_num,
                            url.clone(),
                            source,
                        );
                    }
                }
            }
        }
    }

    if options.include_torrents {
        scan_torrents(&links_root, &var_re, &matcher, &mut result)?;
    }

    Ok(result)
}

struct PackageMatcher {
    exact: HashMap<String, String>,
    base: HashMap<String, String>,
}

impl PackageMatcher {
    fn new(packages: &[String]) -> Self {
        let mut exact = HashMap::new();
        let mut base = HashMap::new();
        for package in packages {
            let trimmed = package.trim();
            if trimmed.is_empty() {
                continue;
            }
            let lower = trimmed.to_ascii_lowercase();
            exact.entry(lower).or_insert_with(|| trimmed.to_string());
            if let Some((base_name, _)) = split_var_version(trimmed) {
                let base_lower = base_name.to_ascii_lowercase();
                base.entry(base_lower)
                    .or_insert_with(|| base_name.to_string());
            }
        }
        Self { exact, base }
    }

    fn is_empty(&self) -> bool {
        self.exact.is_empty() && self.base.is_empty()
    }

    fn exact_key(&self, name: &str) -> Option<&str> {
        let key = name.to_ascii_lowercase();
        self.exact.get(&key).map(|value| value.as_str())
    }

    fn base_key(&self, base: &str) -> Option<&str> {
        let key = base.to_ascii_lowercase();
        self.base.get(&key).map(|value| value.as_str())
    }
}

fn links_root() -> PathBuf {
    data_dir().join("links")
}

fn split_var_version(name: &str) -> Option<(&str, &str)> {
    name.rsplit_once('.')
}

fn parse_version(value: &str) -> Option<i64> {
    value.parse::<i64>().ok()
}

fn is_torrents_dir(path: &Path) -> bool {
    path.file_name()
        .and_then(|name| name.to_str())
        .map(|name| name.eq_ignore_ascii_case("torrents"))
        .unwrap_or(false)
}

fn trim_url(value: &str) -> String {
    let mut trimmed = value.trim().to_string();
    loop {
        let last = trimmed.chars().last();
        if matches!(
            last,
            Some('.') | Some(',') | Some(')') | Some(']') | Some('>') | Some('"') | Some('\'')
        ) {
            trimmed.pop();
            continue;
        }
        break;
    }
    trimmed
}

fn apply_pixeldrain_bypass(url: &str) -> String {
    let replaced = url.replace("pixeldrain.com/u/", "pixeldrain.sriflix.my/");
    replaced.replace("pixeldrain.com/api/file/", "pixeldrain.sriflix.my/")
}

fn insert_url(
    urls: &mut HashMap<String, String>,
    sources: &mut HashMap<String, String>,
    ranks: &mut HashMap<String, u8>,
    key: &str,
    url: String,
    source: ExternalSource,
) {
    let rank = source.rank();
    if let Some(existing) = ranks.get(key) {
        if *existing >= rank {
            return;
        }
    }
    urls.insert(key.to_string(), url);
    sources.insert(key.to_string(), source.as_str().to_string());
    ranks.insert(key.to_string(), rank);
}

fn insert_base_url(
    urls: &mut HashMap<String, String>,
    sources: &mut HashMap<String, String>,
    ranks: &mut HashMap<String, (i64, u8)>,
    key: &str,
    version: i64,
    url: String,
    source: ExternalSource,
) {
    let rank = source.rank();
    if let Some((existing_version, existing_rank)) = ranks.get(key) {
        if *existing_version > version {
            return;
        }
        if *existing_version == version && *existing_rank >= rank {
            return;
        }
    }
    urls.insert(key.to_string(), url);
    sources.insert(key.to_string(), source.as_str().to_string());
    ranks.insert(key.to_string(), (version, rank));
}

fn scan_torrents(
    links_root: &Path,
    var_re: &Regex,
    matcher: &PackageMatcher,
    result: &mut ExternalLinksResult,
) -> Result<(), String> {
    let torrents_root = links_root.join("torrents");
    if !torrents_root.exists() {
        return Ok(());
    }
    for entry in WalkDir::new(&torrents_root).into_iter() {
        let entry = match entry {
            Ok(value) => value,
            Err(_) => continue,
        };
        if !entry.file_type().is_file() {
            continue;
        }
        if entry
            .path()
            .extension()
            .and_then(|ext| ext.to_str())
            .map(|ext| !ext.eq_ignore_ascii_case("torrent"))
            .unwrap_or(true)
        {
            continue;
        }
        let data = match fs::read(entry.path()) {
            Ok(value) => value,
            Err(_) => continue,
        };

        let content = String::from_utf8_lossy(&data);
        let torrent_name = entry
            .path()
            .file_name()
            .and_then(|name| name.to_str())
            .unwrap_or("unknown.torrent")
            .to_string();

        for captures in var_re.captures_iter(&content) {
            if let Some(var_match) = captures.get(1) {
                let var_name = var_match.as_str();

                if let Some(exact_key) = matcher.exact_key(var_name) {
                    result
                        .torrent_hits
                        .entry(exact_key.to_string())
                        .or_insert_with(Vec::new)
                        .push(torrent_name.clone());
                }

                if let Some((base, _)) = split_var_version(var_name) {
                    if let Some(base_key) = matcher.base_key(base) {
                        result
                            .torrent_hits_no_version
                            .entry(base_key.to_string())
                            .or_insert_with(Vec::new)
                            .push(torrent_name.clone());
                    }
                }
            }
        }
    }
    Ok(())
}
