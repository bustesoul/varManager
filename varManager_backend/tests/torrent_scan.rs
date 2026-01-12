use regex::Regex;
use std::path::Path;

#[test]
fn finds_anonymously_vamraider_captured_in_torrent_metadata() {
    let backend_root = Path::new(env!("CARGO_MANIFEST_DIR"));
    let repo_root = backend_root
        .parent()
        .unwrap_or(backend_root);
    let torrent_path = repo_root
        .join("data")
        .join("links")
        .join("torrents")
        .join("Virt-A-Mate_Patreon_Paywall_Pack.torrent");

    let data = std::fs::read(&torrent_path)
        .unwrap_or_else(|err| panic!("failed to read {}: {}", torrent_path.display(), err));
    let content = String::from_utf8_lossy(&data);

    let var_re = Regex::new(
        r"(?i)([A-Za-z0-9_\-]{1,60}\.[A-Za-z0-9_\-]{1,80}\.(?:\d+|latest))\.var",
    )
    .expect("failed to compile var regex");

    let target = "Anonymously.vamraider_captured.1";
    let found = var_re.captures_iter(&content).any(|caps| {
        caps.get(1)
            .map(|m| m.as_str().eq_ignore_ascii_case(target))
            .unwrap_or(false)
    });

    assert!(
        found,
        "expected to find {}.var in torrent metadata at {}",
        target,
        torrent_path.display()
    );
}
