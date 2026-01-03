use rusqlite::{params, Connection, OptionalExtension, Transaction};
use std::path::{Path, PathBuf};

pub struct Db {
    conn: Connection,
    path: PathBuf,
}

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

impl Db {
    pub fn open(path: &Path) -> Result<Self, String> {
        if let Some(parent) = path.parent() {
            std::fs::create_dir_all(parent).map_err(|err| err.to_string())?;
        }
        let conn = Connection::open(path).map_err(|err| err.to_string())?;
        Ok(Self {
            conn,
            path: path.to_path_buf(),
        })
    }

    pub fn ensure_schema(&self) -> Result<(), String> {
        self.conn
            .execute_batch(
                r#"
                CREATE TABLE IF NOT EXISTS dependencies (
                    ID INTEGER PRIMARY KEY AUTOINCREMENT,
                    varName TEXT,
                    dependency TEXT
                );
                CREATE TABLE IF NOT EXISTS HideFav (
                    varName TEXT PRIMARY KEY,
                    ID INTEGER NOT NULL,
                    hide INTEGER NOT NULL,
                    fav INTEGER NOT NULL
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
                    dependencyCnt INTEGER
                );
                "#,
            )
            .map_err(|err| err.to_string())
    }

    pub fn path(&self) -> &Path {
        &self.path
    }

    pub fn connection(&self) -> &Connection {
        &self.conn
    }

    pub fn transaction(&mut self) -> Result<Transaction<'_>, String> {
        self.conn.transaction().map_err(|err| err.to_string())
    }
}

pub fn var_exists(tx: &Transaction<'_>, var_name: &str) -> Result<bool, String> {
    let exists: Option<i64> = tx
        .query_row(
            "SELECT 1 FROM vars WHERE varName = ?1 LIMIT 1",
            params![var_name],
            |row| row.get(0),
        )
        .optional()
        .map_err(|err| err.to_string())?;
    Ok(exists.is_some())
}

pub fn upsert_var(tx: &Transaction<'_>, record: &VarRecord) -> Result<(), String> {
    tx.execute(
        r#"
        INSERT OR REPLACE INTO vars (
            varName, creatorName, packageName, metaDate, varDate, version, description,
            morph, cloth, hair, skin, pose, scene, script, plugin, asset, texture,
            look, subScene, appearance, dependencyCnt
        ) VALUES (
            ?1, ?2, ?3, ?4, ?5, ?6, ?7,
            ?8, ?9, ?10, ?11, ?12, ?13, ?14, ?15, ?16, ?17,
            ?18, ?19, ?20, ?21
        )
        "#,
        params![
            record.var_name,
            record.creator_name,
            record.package_name,
            record.meta_date,
            record.var_date,
            record.version,
            record.description,
            record.morph,
            record.cloth,
            record.hair,
            record.skin,
            record.pose,
            record.scene,
            record.script,
            record.plugin,
            record.asset,
            record.texture,
            record.look,
            record.sub_scene,
            record.appearance,
            record.dependency_cnt
        ],
    )
    .map_err(|err| err.to_string())?;
    Ok(())
}

pub fn replace_dependencies(
    tx: &Transaction<'_>,
    var_name: &str,
    deps: &[String],
) -> Result<(), String> {
    tx.execute("DELETE FROM dependencies WHERE varName = ?1", params![var_name])
        .map_err(|err| err.to_string())?;
    if deps.is_empty() {
        return Ok(());
    }
    let mut stmt = tx
        .prepare("INSERT INTO dependencies (varName, dependency) VALUES (?1, ?2)")
        .map_err(|err| err.to_string())?;
    for dep in deps {
        stmt.execute(params![var_name, dep])
            .map_err(|err| err.to_string())?;
    }
    Ok(())
}

pub fn replace_scenes(
    tx: &Transaction<'_>,
    var_name: &str,
    scenes: &[SceneRecord],
) -> Result<(), String> {
    tx.execute("DELETE FROM scenes WHERE varName = ?1", params![var_name])
        .map_err(|err| err.to_string())?;
    if scenes.is_empty() {
        return Ok(());
    }
    let mut stmt = tx
        .prepare(
            "INSERT INTO scenes (varName, atomType, previewPic, scenePath, isPreset, isLoadable)
             VALUES (?1, ?2, ?3, ?4, ?5, ?6)",
        )
        .map_err(|err| err.to_string())?;
    for scene in scenes {
        stmt.execute(params![
            scene.var_name,
            scene.atom_type,
            scene.preview_pic,
            scene.scene_path,
            scene.is_preset as i64,
            scene.is_loadable as i64
        ])
        .map_err(|err| err.to_string())?;
    }
    Ok(())
}

pub fn list_vars(tx: &Transaction<'_>) -> Result<Vec<String>, String> {
    let mut stmt = tx
        .prepare("SELECT varName FROM vars")
        .map_err(|err| err.to_string())?;
    let rows = stmt
        .query_map([], |row| row.get::<_, String>(0))
        .map_err(|err| err.to_string())?;
    let mut vars = Vec::new();
    for row in rows {
        vars.push(row.map_err(|err| err.to_string())?);
    }
    Ok(vars)
}

pub fn delete_var_related(tx: &Transaction<'_>, var_name: &str) -> Result<(), String> {
    tx.execute("DELETE FROM dependencies WHERE varName = ?1", params![var_name])
        .map_err(|err| err.to_string())?;
    tx.execute("DELETE FROM scenes WHERE varName = ?1", params![var_name])
        .map_err(|err| err.to_string())?;
    tx.execute("DELETE FROM vars WHERE varName = ?1", params![var_name])
        .map_err(|err| err.to_string())?;
    Ok(())
}
