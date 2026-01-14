use crate::app::data_dir;
use sqlx::{
    sqlite::{SqliteConnectOptions, SqlitePoolOptions},
    Row, Sqlite, SqlitePool, Transaction,
};
use std::fs;
use std::path::PathBuf;

#[derive(Clone, Debug)]
pub struct VarRecord {
    pub var_name: String,
    pub creator_name: Option<String>,
    pub package_name: Option<String>,
    pub meta_date: Option<String>,
    pub var_date: Option<String>,
    pub version: Option<String>,
    pub description: Option<String>,
    pub morph: Option<i64>,
    pub cloth: Option<i64>,
    pub hair: Option<i64>,
    pub skin: Option<i64>,
    pub pose: Option<i64>,
    pub scene: Option<i64>,
    pub script: Option<i64>,
    pub plugin: Option<i64>,
    pub asset: Option<i64>,
    pub texture: Option<i64>,
    pub look: Option<i64>,
    pub sub_scene: Option<i64>,
    pub appearance: Option<i64>,
    pub dependency_cnt: Option<i64>,
    pub fsize: Option<f64>,
}

#[derive(Clone, Debug)]
pub struct VarScanInfo {
    pub var_name: String,
    pub var_date: Option<String>,
    pub fsize: Option<f64>,
}

#[derive(Clone, Debug)]
pub struct SceneRecord {
    pub var_name: String,
    pub atom_type: String,
    pub preview_pic: Option<String>,
    pub scene_path: String,
    pub is_preset: bool,
    pub is_loadable: bool,
}

#[derive(Clone, Debug)]
pub struct HideFavRecord {
    pub scene_path: String,
    pub hide: bool,
    pub fav: bool,
}

pub fn default_path() -> PathBuf {
    data_dir().join("varManager.db")
}

pub async fn open_default_pool() -> Result<SqlitePool, String> {
    let path = default_path();
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent).map_err(|err| err.to_string())?;
    }
    let options = SqliteConnectOptions::new()
        .filename(&path)
        .create_if_missing(true);
    let pool = SqlitePoolOptions::new()
        .max_connections(5)
        .connect_with(options)
        .await
        .map_err(|err| err.to_string())?;
    ensure_schema(&pool).await?;
    Ok(pool)
}

pub async fn ensure_schema(pool: &SqlitePool) -> Result<(), String> {
    let hide_fav_needs_migration = {
        let rows = sqlx::query("PRAGMA table_info(HideFav)")
            .fetch_all(pool)
            .await
            .map_err(|err| err.to_string())?;
        if rows.is_empty() {
            false
        } else {
            !rows.iter().any(|row| {
                let name: String = row.try_get("name").unwrap_or_default();
                name.eq_ignore_ascii_case("scenePath")
            })
        }
    };
    if hide_fav_needs_migration {
        sqlx::query("DROP TABLE IF EXISTS HideFav")
            .execute(pool)
            .await
            .map_err(|err| err.to_string())?;
    }

    sqlx::query(
        r#"
                CREATE TABLE IF NOT EXISTS dependencies (
                    ID INTEGER PRIMARY KEY AUTOINCREMENT,
                    varName TEXT,
                    dependency TEXT
                );
                CREATE TABLE IF NOT EXISTS HideFav (
                    varName TEXT NOT NULL,
                    scenePath TEXT NOT NULL,
                    hide INTEGER NOT NULL,
                    fav INTEGER NOT NULL,
                    PRIMARY KEY (varName, scenePath)
                );
                CREATE TABLE IF NOT EXISTS installStatus (
                    varName TEXT PRIMARY KEY,
                    installed INTEGER NOT NULL,
                    disabled INTEGER NOT NULL
                );
                CREATE TABLE IF NOT EXISTS savedepens (
                    ID INTEGER PRIMARY KEY AUTOINCREMENT,
                    varName TEXT,
                    dependency TEXT,
                    SavePath TEXT,
                    ModiDate TEXT
                );
                CREATE TABLE IF NOT EXISTS scenes (
                    ID INTEGER PRIMARY KEY AUTOINCREMENT,
                    varName TEXT,
                    atomType TEXT,
                    previewPic TEXT,
                    scenePath TEXT,
                    isPreset INTEGER NOT NULL,
                    isLoadable INTEGER NOT NULL
                );
                CREATE TABLE IF NOT EXISTS vars (
                    varName TEXT PRIMARY KEY,
                    creatorName TEXT,
                    packageName TEXT,
                    metaDate TEXT,
                    varDate TEXT,
                    version TEXT,
                    description TEXT,
                    morph INTEGER,
                    cloth INTEGER,
                    hair INTEGER,
                    skin INTEGER,
                    pose INTEGER,
                    scene INTEGER,
                    script INTEGER,
                    plugin INTEGER,
                    asset INTEGER,
                    texture INTEGER,
                    look INTEGER,
                    subScene INTEGER,
                    appearance INTEGER,
                    dependencyCnt INTEGER,
                    fsize REAL
                );
                CREATE TABLE IF NOT EXISTS image_cache_entries (
                    cache_key TEXT PRIMARY KEY,
                    file_name TEXT NOT NULL,
                    source_type TEXT NOT NULL,
                    source_url TEXT,
                    source_root TEXT,
                    source_path TEXT,
                    size_bytes INTEGER NOT NULL,
                    content_type TEXT NOT NULL,
                    created_at INTEGER NOT NULL,
                    last_accessed INTEGER NOT NULL,
                    access_count INTEGER NOT NULL
                );
                CREATE TABLE IF NOT EXISTS downloads (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    url TEXT NOT NULL,
                    name TEXT,
                    status TEXT NOT NULL,
                    downloaded_bytes INTEGER NOT NULL DEFAULT 0,
                    total_bytes INTEGER,
                    speed_bytes INTEGER NOT NULL DEFAULT 0,
                    error TEXT,
                    save_path TEXT,
                    temp_path TEXT,
                    created_at INTEGER NOT NULL,
                    updated_at INTEGER NOT NULL
                );

                CREATE INDEX IF NOT EXISTS idx_vars_creatorName ON vars(creatorName);
                CREATE INDEX IF NOT EXISTS idx_vars_packageName ON vars(packageName);
                CREATE INDEX IF NOT EXISTS idx_vars_metaDate ON vars(metaDate);
                CREATE INDEX IF NOT EXISTS idx_vars_varDate ON vars(varDate);
                CREATE INDEX IF NOT EXISTS idx_vars_fsize ON vars(fsize);
                CREATE INDEX IF NOT EXISTS idx_vars_dependencyCnt ON vars(dependencyCnt);
                CREATE INDEX IF NOT EXISTS idx_scenes_varName ON scenes(varName);
                CREATE INDEX IF NOT EXISTS idx_scenes_atomType ON scenes(atomType);
                CREATE INDEX IF NOT EXISTS idx_dependencies_varName ON dependencies(varName);
                CREATE INDEX IF NOT EXISTS idx_dependencies_dependency ON dependencies(dependency);
                CREATE INDEX IF NOT EXISTS idx_savedepens_dependency ON savedepens(dependency);
                CREATE INDEX IF NOT EXISTS idx_image_cache_last_accessed ON image_cache_entries(last_accessed);
                CREATE INDEX IF NOT EXISTS idx_downloads_status ON downloads(status);
                CREATE INDEX IF NOT EXISTS idx_downloads_created_at ON downloads(created_at);
                "#
    )
    .execute(pool)
    .await
    .map_err(|err| err.to_string())?;

    let _ = sqlx::query("ALTER TABLE vars ADD COLUMN fsize REAL")
        .execute(pool)
        .await;
    let _ = sqlx::query("ALTER TABLE downloads ADD COLUMN temp_path TEXT")
        .execute(pool)
        .await;

    Ok(())
}

pub async fn var_exists_conn(pool: &SqlitePool, var_name: &str) -> Result<bool, String> {
    let exists = sqlx::query_scalar::<_, i64>(
        "SELECT 1 FROM vars WHERE varName = ?1 LIMIT 1",
    )
    .bind(var_name)
    .fetch_optional(pool)
    .await
    .map_err(|err| err.to_string())?;
    Ok(exists.is_some())
}

pub async fn list_var_versions(
    pool: &SqlitePool,
    creator_name: &str,
    package_name: &str,
) -> Result<Vec<(String, String)>, String> {
    let rows = sqlx::query(
        "SELECT varName, version FROM vars WHERE creatorName = ?1 COLLATE NOCASE AND packageName = ?2 COLLATE NOCASE",
    )
    .bind(creator_name)
    .bind(package_name)
    .fetch_all(pool)
    .await
    .map_err(|err| err.to_string())?;
    let mut vars = Vec::new();
    for row in rows {
        let name: String = row.try_get(0).map_err(|err| err.to_string())?;
        let version: Option<String> = row.try_get(1).map_err(|err| err.to_string())?;
        vars.push((name, version.unwrap_or_default()));
    }
    Ok(vars)
}

pub async fn list_dependencies_all(pool: &SqlitePool) -> Result<Vec<String>, String> {
    let rows = sqlx::query("SELECT dependency FROM dependencies")
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

pub async fn list_dependencies_for_installed(
    pool: &SqlitePool,
) -> Result<Vec<String>, String> {
    let rows = sqlx::query(
        "SELECT d.dependency FROM dependencies d \
             JOIN installStatus i ON d.varName = i.varName \
             WHERE i.installed = 1",
    )
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

pub async fn list_dependencies_for_vars(
    pool: &SqlitePool,
    var_names: &[String],
) -> Result<Vec<String>, String> {
    if var_names.is_empty() {
        return Ok(Vec::new());
    }
    let mut builder = sqlx::QueryBuilder::new(
        "SELECT dependency FROM dependencies WHERE varName IN (",
    );
    let mut separated = builder.separated(", ");
    for name in var_names {
        separated.push_bind(name);
    }
    separated.push_unseparated(")");
    let rows = builder
        .build()
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

pub async fn upsert_install_status(
    pool: &SqlitePool,
    var_name: &str,
    installed: bool,
    disabled: bool,
) -> Result<(), String> {
    sqlx::query(
        "INSERT OR REPLACE INTO installStatus (varName, installed, disabled) VALUES (?1, ?2, ?3)",
    )
    .bind(var_name)
    .bind(installed as i64)
    .bind(disabled as i64)
    .execute(pool)
    .await
    .map_err(|err| err.to_string())?;
    Ok(())
}

pub async fn upsert_var(
    tx: &mut Transaction<'_, Sqlite>,
    record: &VarRecord,
) -> Result<(), String> {
    sqlx::query(
        r#"
        INSERT OR REPLACE INTO vars (
            varName, creatorName, packageName, metaDate, varDate, version, description,
            morph, cloth, hair, skin, pose, scene, script, plugin, asset, texture,
            look, subScene, appearance, dependencyCnt, fsize
        ) VALUES (
            ?1, ?2, ?3, ?4, ?5, ?6, ?7,
            ?8, ?9, ?10, ?11, ?12, ?13, ?14, ?15, ?16, ?17,
            ?18, ?19, ?20, ?21, ?22
        )
        "#,
    )
    .bind(&record.var_name)
    .bind(&record.creator_name)
    .bind(&record.package_name)
    .bind(&record.meta_date)
    .bind(&record.var_date)
    .bind(&record.version)
    .bind(&record.description)
    .bind(record.morph)
    .bind(record.cloth)
    .bind(record.hair)
    .bind(record.skin)
    .bind(record.pose)
    .bind(record.scene)
    .bind(record.script)
    .bind(record.plugin)
    .bind(record.asset)
    .bind(record.texture)
    .bind(record.look)
    .bind(record.sub_scene)
    .bind(record.appearance)
    .bind(record.dependency_cnt)
    .bind(record.fsize)
    .execute(tx.as_mut())
    .await
    .map_err(|err| err.to_string())?;
    Ok(())
}

pub async fn replace_dependencies(
    tx: &mut Transaction<'_, Sqlite>,
    var_name: &str,
    deps: &[String],
) -> Result<(), String> {
    sqlx::query("DELETE FROM dependencies WHERE varName = ?1")
        .bind(var_name)
        .execute(tx.as_mut())
        .await
        .map_err(|err| err.to_string())?;
    if deps.is_empty() {
        return Ok(());
    }
    for dep in deps {
        sqlx::query("INSERT INTO dependencies (varName, dependency) VALUES (?1, ?2)")
            .bind(var_name)
            .bind(dep)
            .execute(tx.as_mut())
            .await
            .map_err(|err| err.to_string())?;
    }
    Ok(())
}

pub async fn replace_scenes(
    tx: &mut Transaction<'_, Sqlite>,
    var_name: &str,
    scenes: &[SceneRecord],
) -> Result<(), String> {
    sqlx::query("DELETE FROM scenes WHERE varName = ?1")
        .bind(var_name)
        .execute(tx.as_mut())
        .await
        .map_err(|err| err.to_string())?;
    if scenes.is_empty() {
        return Ok(());
    }
    for scene in scenes {
        sqlx::query(
            "INSERT INTO scenes (varName, atomType, previewPic, scenePath, isPreset, isLoadable)\
             VALUES (?1, ?2, ?3, ?4, ?5, ?6)",
        )
        .bind(&scene.var_name)
        .bind(&scene.atom_type)
        .bind(&scene.preview_pic)
        .bind(&scene.scene_path)
        .bind(scene.is_preset as i64)
        .bind(scene.is_loadable as i64)
        .execute(tx.as_mut())
        .await
        .map_err(|err| err.to_string())?;
    }
    Ok(())
}

pub async fn replace_hide_fav(
    tx: &mut Transaction<'_, Sqlite>,
    var_name: &str,
    entries: &[HideFavRecord],
) -> Result<(), String> {
    sqlx::query("DELETE FROM HideFav WHERE varName = ?1")
        .bind(var_name)
        .execute(tx.as_mut())
        .await
        .map_err(|err| err.to_string())?;
    for entry in entries {
        if !entry.hide && !entry.fav {
            continue;
        }
        sqlx::query(
            "INSERT INTO HideFav (varName, scenePath, hide, fav) VALUES (?1, ?2, ?3, ?4)",
        )
        .bind(var_name)
        .bind(&entry.scene_path)
        .bind(if entry.hide { 1 } else { 0 })
        .bind(if entry.fav { 1 } else { 0 })
        .execute(tx.as_mut())
        .await
        .map_err(|err| err.to_string())?;
    }
    Ok(())
}

pub async fn list_vars(tx: &mut Transaction<'_, Sqlite>) -> Result<Vec<String>, String> {
    let rows = sqlx::query("SELECT varName FROM vars")
        .fetch_all(tx.as_mut())
        .await
        .map_err(|err| err.to_string())?;
    let mut vars = Vec::new();
    for row in rows {
        vars.push(row.try_get::<String, _>(0).map_err(|err| err.to_string())?);
    }
    Ok(vars)
}

pub async fn list_var_scan_info(
    tx: &mut Transaction<'_, Sqlite>,
) -> Result<Vec<VarScanInfo>, String> {
    let rows = sqlx::query("SELECT varName, varDate, fsize FROM vars")
        .fetch_all(tx.as_mut())
        .await
        .map_err(|err| err.to_string())?;
    let mut infos = Vec::new();
    for row in rows {
        infos.push(VarScanInfo {
            var_name: row.try_get(0).map_err(|err| err.to_string())?,
            var_date: row.try_get(1).map_err(|err| err.to_string())?,
            fsize: row.try_get(2).map_err(|err| err.to_string())?,
        });
    }
    Ok(infos)
}

pub async fn list_scenes_for_var(
    tx: &mut Transaction<'_, Sqlite>,
    var_name: &str,
) -> Result<Vec<SceneRecord>, String> {
    let rows = sqlx::query(
        "SELECT atomType, previewPic, scenePath, isPreset, isLoadable FROM scenes WHERE varName = ?1",
    )
    .bind(var_name)
    .fetch_all(tx.as_mut())
    .await
    .map_err(|err| err.to_string())?;
    let mut scenes = Vec::new();
    for row in rows {
        scenes.push(SceneRecord {
            var_name: var_name.to_string(),
            atom_type: row.try_get(0).map_err(|err| err.to_string())?,
            preview_pic: row.try_get(1).map_err(|err| err.to_string())?,
            scene_path: row.try_get(2).map_err(|err| err.to_string())?,
            is_preset: row.try_get::<i64, _>(3).map_err(|err| err.to_string())? != 0,
            is_loadable: row.try_get::<i64, _>(4).map_err(|err| err.to_string())? != 0,
        });
    }
    Ok(scenes)
}

pub async fn delete_var_related(
    tx: &mut Transaction<'_, Sqlite>,
    var_name: &str,
) -> Result<(), String> {
    sqlx::query("DELETE FROM dependencies WHERE varName = ?1")
        .bind(var_name)
        .execute(tx.as_mut())
        .await
        .map_err(|err| err.to_string())?;
    sqlx::query("DELETE FROM scenes WHERE varName = ?1")
        .bind(var_name)
        .execute(tx.as_mut())
        .await
        .map_err(|err| err.to_string())?;
    sqlx::query("DELETE FROM vars WHERE varName = ?1")
        .bind(var_name)
        .execute(tx.as_mut())
        .await
        .map_err(|err| err.to_string())?;
    Ok(())
}

pub async fn delete_var_related_conn(
    pool: &SqlitePool,
    var_name: &str,
) -> Result<(), String> {
    sqlx::query("DELETE FROM dependencies WHERE varName = ?1")
        .bind(var_name)
        .execute(pool)
        .await
        .map_err(|err| err.to_string())?;
    sqlx::query("DELETE FROM scenes WHERE varName = ?1")
        .bind(var_name)
        .execute(pool)
        .await
        .map_err(|err| err.to_string())?;
    sqlx::query("DELETE FROM vars WHERE varName = ?1")
        .bind(var_name)
        .execute(pool)
        .await
        .map_err(|err| err.to_string())?;
    Ok(())
}
