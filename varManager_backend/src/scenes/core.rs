use crate::infra::db::var_exists_conn;
use crate::infra::fs_util;
use crate::jobs::job_channel::JobReporter;
use crate::infra::paths::{config_paths, loadscene_path, resolve_var_file_path, temp_links_dir, CACHE_DIR};
use crate::domain::var_logic::vars_dependencies;
use crate::app::{exe_dir, AppState};
use crate::infra::winfs;
use crate::util;
use regex::Regex;
use serde::{Deserialize, Serialize};
use serde_json::{json, Value};
use std::collections::{HashMap, HashSet};
use std::fs;
use std::io::Read;
use std::path::{Path, PathBuf};
use std::thread;
use std::time::Duration;
use zip::ZipArchive;

#[derive(Clone, Serialize)]
pub struct AtomTreeNode {
    pub name: String,
    pub path: Option<String>,
    pub children: Vec<AtomTreeNode>,
}

const SCENE_BASE_ATOMS: [&str; 4] = ["CoreControl", "PlayerNavigationPanel", "VRController", "WindowCamera"];
const POSE_CONTROL_IDS: [&str; 26] = [
    "hipControl",
    "pelvisControl",
    "chestControl",
    "headControl",
    "rHandControl",
    "lHandControl",
    "rFootControl",
    "lFootControl",
    "neckControl",
    "eyeTargetControl",
    "rNippleControl",
    "lNippleControl",
    "rElbowControl",
    "lElbowControl",
    "rKneeControl",
    "lKneeControl",
    "rToeControl",
    "lToeControl",
    "abdomenControl",
    "abdomen2Control",
    "rThighControl",
    "lThighControl",
    "rArmControl",
    "lArmControl",
    "rShoulderControl",
    "lShoulderControl",
];
const POSE_OBJECT_IDS: [&str; 27] = [
    "hip",
    "pelvis",
    "rThigh",
    "rShin",
    "rFoot",
    "rToe",
    "lThigh",
    "lShin",
    "lFoot",
    "lToe",
    "LGlute",
    "RGlute",
    "abdomen",
    "abdomen2",
    "chest",
    "lPectoral",
    "rPectoral",
    "rCollar",
    "rShldr",
    "rForeArm",
    "rHand",
    "lCollar",
    "lShldr",
    "lForeArm",
    "lHand",
    "neck",
    "head",
];

const DEFAULT_EYE_COLOR: &str = "{ \"setUnlistedParamsToDefault\": \"false\", \"storables\": [{  \"id\": \"irises\",  \"hideMaterial\": \"false\",  \"renderQueue\": \"1999\",  \"Specular Texture Offset\": \"0\",  \"Specular Intensity\": \"1\",  \"Gloss\": \"2\",  \"Specular Fresnel\": \"0\",  \"Gloss Texture Offset\": \"0\",  \"Global Illumination Filter\": \"0\",  \"Diffuse Texture Offset\": \"0\",  \"Diffuse Bumpiness\": \"1\",  \"Specular Bumpiness\": \"1\",  \"customTexture1TileX\": \"1\",  \"customTexture1TileY\": \"1\",  \"customTexture1OffsetX\": \"0\",  \"customTexture1OffsetY\": \"0\",  \"customTexture2TileX\": \"1\",  \"customTexture2TileY\": \"1\",  \"customTexture2OffsetX\": \"0\",  \"customTexture2OffsetY\": \"0\",  \"customTexture3TileX\": \"1\",  \"customTexture3TileY\": \"1\",  \"customTexture3OffsetX\": \"0\",  \"customTexture3OffsetY\": \"0\",  \"customTexture4TileX\": \"1\",  \"customTexture4TileY\": \"1\",  \"customTexture4OffsetX\": \"0\",  \"customTexture4OffsetY\": \"0\",  \"Irises\": \"Color 1\",  \"customTexture_MainTex\": \"\",  \"customTexture_SpecTex\": \"\",  \"customTexture_GlossTex\": \"\",  \"customTexture_BumpMap\": \"\",  \"Diffuse Color\": {  \"h\": \"0\",  \"s\": \"0\",  \"v\": \"1\"  },  \"Specular Color\": {  \"h\": \"0\",  \"s\": \"0\",  \"v\": \"1\"  },  \"Subsurface Color\": {  \"h\": \"0\",  \"s\": \"0\",  \"v\": \"1\"  }  }, {  \"id\": \"sclera\",  \"hideMaterial\": \"false\",  \"renderQueue\": \"1999\",  \"Specular Texture Offset\": \"0\",  \"Specular Intensity\": \"0.5\",  \"Gloss\": \"5\",  \"Specular Fresnel\": \"0\",  \"Gloss Texture Offset\": \"0.2\",  \"Global Illumination Filter\": \"0\",  \"Diffuse Texture Offset\": \"0\",  \"Diffuse Bumpiness\": \"0.3\",  \"Specular Bumpiness\": \"0.05\",  \"customTexture1TileX\": \"1\",  \"customTexture1TileY\": \"1\",  \"customTexture1OffsetX\": \"0\",  \"customTexture1OffsetY\": \"0\",  \"customTexture2TileX\": \"1\",  \"customTexture2TileY\": \"1\",  \"customTexture2OffsetX\": \"0\",  \"customTexture2OffsetY\": \"0\",  \"customTexture3TileX\": \"1\",  \"customTexture3TileY\": \"1\",  \"customTexture3OffsetX\": \"0\",  \"customTexture3OffsetY\": \"0\",  \"customTexture4TileX\": \"1\",  \"customTexture4TileY\": \"1\",  \"customTexture4OffsetX\": \"0\",  \"customTexture4OffsetY\": \"0\",  \"Sclera\": \"Sclera 1\",  \"customTexture_MainTex\": \"\",  \"customTexture_SpecTex\": \"\",  \"customTexture_GlossTex\": \"\",  \"customTexture_BumpMap\": \"\",  \"Diffuse Color\": {  \"h\": \"0\",  \"s\": \"0\",  \"v\": \"1\"  },  \"Specular Color\": {  \"h\": \"0.5584416\",  \"s\": \"0.3019608\",  \"v\": \"1\"  },  \"Subsurface Color\": {  \"h\": \"0\",  \"s\": \"0\",  \"v\": \"1\"  }  }, {  \"id\": \"lacrimals\",  \"hideMaterial\": \"false\",  \"renderQueue\": \"1999\",  \"Specular Texture Offset\": \"0\",  \"Specular Intensity\": \"1\",  \"Gloss\": \"6.5\",  \"Specular Fresnel\": \"0.5\",  \"Global Illumination Filter\": \"0\",  \"Diffuse Texture Offset\": \"0\",  \"customTexture1TileX\": \"1\",  \"customTexture1TileY\": \"1\",  \"customTexture1OffsetX\": \"0\",  \"customTexture1OffsetY\": \"0\",  \"customTexture2TileX\": \"1\",  \"customTexture2TileY\": \"1\",  \"customTexture2OffsetX\": \"0\",  \"customTexture2OffsetY\": \"0\",  \"customTexture_MainTex\": \"\",  \"customTexture_SpecTex\": \"\",  \"Diffuse Color\": {  \"h\": \"0\",  \"s\": \"0\",  \"v\": \"1\"  },  \"Specular Color\": {  \"h\": \"0\",  \"s\": \"0\",  \"v\": \"1\"  },  \"Subsurface Color\": {  \"h\": \"0\",  \"s\": \"0\",  \"v\": \"1\"  }  }  ]  }  ";
const CLOTH_NAKED: &str = "{ \"setUnlistedParamsToDefault\" : \"true\", \"storables\" : [ { \"id\" : \"geometry\", \"clothing\" : [ ] } ] }";
const HAIR_BALD: &str = "{ \"setUnlistedParamsToDefault\" : \"true\", \"storables\" : [ { \"id\" : \"geometry\", \"hair\" : [ ] } ] }";

#[derive(Deserialize)]
pub(crate) struct SceneLoadArgs {
    json: Value,
    #[serde(default)]
    merge: bool,
    #[serde(default)]
    ignore_gender: bool,
    #[serde(default)]
    character_gender: Option<String>,
    #[serde(default)]
    person_order: Option<u32>,
}

#[derive(Deserialize)]
pub(crate) struct SceneAnalyzeArgs {
    save_name: String,
    #[serde(default)]
    character_gender: Option<String>,
}

#[derive(Serialize)]
struct SceneAnalyzeResult {
    var_name: String,
    entry_name: String,
    cache_dir: String,
    character_gender: String,
}

#[derive(Serialize)]
struct SceneLoadResult {
    rescan: bool,
    temp_installed: Vec<String>,
    loadscene_path: String,
}

#[derive(Deserialize)]
pub(crate) struct ScenePresetLookArgs {
    var_name: String,
    entry_name: String,
    atom_name: String,
    #[serde(default)]
    morphs: bool,
    #[serde(default)]
    hair: bool,
    #[serde(default)]
    clothing: bool,
    #[serde(default)]
    skin: bool,
    #[serde(default)]
    breast: bool,
    #[serde(default)]
    glute: bool,
    #[serde(default)]
    ignore_gender: bool,
    #[serde(default)]
    person_order: Option<u32>,
}

#[derive(Deserialize)]
pub(crate) struct ScenePresetArgs {
    var_name: String,
    entry_name: String,
    atom_name: String,
    #[serde(default)]
    ignore_gender: bool,
    #[serde(default)]
    person_order: Option<u32>,
}

#[derive(Deserialize)]
pub(crate) struct ScenePresetSceneArgs {
    var_name: String,
    entry_name: String,
    atom_paths: Vec<String>,
    #[serde(default)]
    ignore_gender: bool,
    #[serde(default)]
    person_order: Option<u32>,
}

#[derive(Deserialize)]
pub(crate) struct SceneAtomsArgs {
    var_name: String,
    entry_name: String,
    atom_paths: Vec<String>,
    #[serde(default)]
    ignore_gender: bool,
    #[serde(default)]
    person_order: Option<u32>,
    #[serde(default)]
    pub(crate) as_subscene: bool,
}

#[derive(Deserialize)]
pub(crate) struct SceneHideFavArgs {
    pub(crate) var_name: Option<String>,
    pub(crate) scene_path: String,
}

#[derive(Deserialize)]
pub(crate) struct CacheClearArgs {
    var_name: String,
    entry_name: String,
}

pub(crate) fn scene_load_blocking(state: &AppState, reporter: &JobReporter, args: SceneLoadArgs) -> Result<(), String> {
    let (_, vampath) = config_paths(state)?;
    let vampath = vampath.ok_or_else(|| "vampath is required in config.json".to_string())?;
    let mut json_ls = args.json;
    let resources = json_ls
        .get("resources")
        .and_then(|v| v.as_array())
        .cloned()
        .unwrap_or_default();
    if resources.is_empty() {
        return Err("scene_load requires resources".to_string());
    }

    let save_name = resources[0]
        .get("saveName")
        .and_then(|v| v.as_str())
        .unwrap_or("")
        .to_string();
    let (var_name, entry_name) = save_name_split(&save_name);
    let cache_dir = cache_dir(&var_name, &entry_name);
    let depend_path = cache_dir.join("depend.txt");
    let gender_path = cache_dir.join("gender.txt");

    if !depend_path.exists() {
        let gender = args
            .character_gender
            .as_deref()
            .unwrap_or("unknown")
            .to_string();
        read_save_name(state, &save_name, &gender, false)?;
    }

    let deps = read_lines(&depend_path)?;
    let gender = if gender_path.exists() {
        fs::read_to_string(&gender_path)
            .unwrap_or_else(|_| args.character_gender.clone().unwrap_or_else(|| "unknown".to_string()))
            .trim()
            .to_string()
    } else {
        args.character_gender.clone().unwrap_or_else(|| "unknown".to_string())
    };

    let result = build_loadscene(
        state,
        reporter,
        &vampath,
        &mut json_ls,
        args.merge,
        Some(deps),
        &gender,
        args.ignore_gender,
        args.person_order.unwrap_or(1),
    )?;
    reporter.set_result(serde_json::to_value(result).map_err(|e| e.to_string())?);
    Ok(())
}

pub(crate) fn scene_analyze_blocking(state: &AppState, reporter: &JobReporter, args: SceneAnalyzeArgs) -> Result<(), String> {
    let gender = args.character_gender.unwrap_or_else(|| "female".to_string());
    let result = read_save_name(state, &args.save_name, &gender, true)?;
    reporter.set_result(
        serde_json::to_value(SceneAnalyzeResult {
            var_name: result.var_name,
            entry_name: result.entry_name,
            cache_dir: result.cache_dir.to_string_lossy().to_string(),
            character_gender: result.character_gender,
        })
        .map_err(|e| e.to_string())?,
    );
    Ok(())
}

pub(crate) fn scene_preset_look_blocking(
    state: &AppState,
    reporter: &JobReporter,
    args: ScenePresetLookArgs,
) -> Result<(), String> {
    let (var_name, entry_name) = normalize_cache_key(&args.var_name, &args.entry_name);
    let cache_root = cache_dir(&var_name, &entry_name);
    ensure_analysis_cache(state, &var_name, &entry_name, &cache_root)?;

    let atom = load_person_atom(&cache_root, &args.atom_name)?;
    let mut save_names = Vec::new();
    let mut character_gender = "unknown".to_string();
    save_preset(
        state,
        &var_name,
        &atom,
        args.morphs,
        args.hair,
        args.clothing,
        args.skin,
        args.breast,
        args.glute,
        &mut save_names,
        &mut character_gender,
        args.ignore_gender,
        args.person_order.unwrap_or(0),
    )?;

    let deps = read_lines(&cache_root.join("depend.txt"))?;
    let vampath = config_paths(state)?
        .1
        .ok_or_else(|| "vampath is required in config.json".to_string())?;
    let result = build_loadscene(
        state,
        reporter,
        &vampath,
        &mut json!({ "resources": save_names }),
        false,
        Some(deps),
        &character_gender,
        args.ignore_gender,
        args.person_order.unwrap_or(0) + 1,
    )?;
    reporter.set_result(serde_json::to_value(result).map_err(|e| e.to_string())?);
    Ok(())
}

#[derive(Clone, Copy)]
pub(crate) enum PresetKind {
    Plugin,
    Pose,
    Animation,
}

pub(crate) fn scene_preset_blocking(
    state: &AppState,
    reporter: &JobReporter,
    args: ScenePresetArgs,
    kind: PresetKind,
) -> Result<(), String> {
    let (var_name, entry_name) = normalize_cache_key(&args.var_name, &args.entry_name);
    let cache_root = cache_dir(&var_name, &entry_name);
    ensure_analysis_cache(state, &var_name, &entry_name, &cache_root)?;

    let atom = load_person_atom(&cache_root, &args.atom_name)?;
    let mut save_names = Vec::new();
    let character_gender = "unknown".to_string();
    let person_order = args.person_order.unwrap_or(0);

    match kind {
        PresetKind::Plugin => save_plugin_preset(
            state,
            &var_name,
            &atom,
            &mut save_names,
            &character_gender,
            args.ignore_gender,
            person_order,
        )?,
        PresetKind::Pose => save_pose_preset(
            state,
            &var_name,
            &atom,
            &mut save_names,
            &character_gender,
            args.ignore_gender,
            person_order,
        )?,
        PresetKind::Animation => {
            let core = load_core_control(&cache_root)?;
            save_pose_preset(
                state,
                &var_name,
                &atom,
                &mut save_names,
                &character_gender,
                args.ignore_gender,
                person_order,
            )?;
            save_animation_preset(
                state,
                &var_name,
                &atom,
                &core,
                &mut save_names,
                &character_gender,
                args.ignore_gender,
                person_order,
            )?;
        }
    }

    let deps = read_lines(&cache_root.join("depend.txt"))?;
    let vampath = config_paths(state)?
        .1
        .ok_or_else(|| "vampath is required in config.json".to_string())?;
    let result = build_loadscene(
        state,
        reporter,
        &vampath,
        &mut json!({ "resources": save_names }),
        false,
        Some(deps),
        &character_gender,
        args.ignore_gender,
        person_order + 1,
    )?;
    reporter.set_result(serde_json::to_value(result).map_err(|e| e.to_string())?);
    Ok(())
}

pub(crate) fn scene_preset_scene_blocking(
    state: &AppState,
    reporter: &JobReporter,
    args: ScenePresetSceneArgs,
) -> Result<(), String> {
    let (var_name, entry_name) = normalize_cache_key(&args.var_name, &args.entry_name);
    let cache_root = cache_dir(&var_name, &entry_name);
    ensure_analysis_cache(state, &var_name, &entry_name, &cache_root)?;

    let mut save_names = Vec::new();
    add_preset_resource(
        &mut save_names,
        "emptyscene",
        "",
        "unknown",
        args.ignore_gender,
        args.person_order.unwrap_or(0) + 1,
    );
    let atom_resources = add_atom_resources(
        state,
        &cache_root,
        &args.atom_paths,
        args.ignore_gender,
        args.person_order.unwrap_or(0),
        false,
    )?;
    save_names.extend(atom_resources);

    let deps = read_lines(&cache_root.join("depend.txt"))?;
    let vampath = config_paths(state)?
        .1
        .ok_or_else(|| "vampath is required in config.json".to_string())?;
    let result = build_loadscene(
        state,
        reporter,
        &vampath,
        &mut json!({ "resources": save_names }),
        false,
        Some(deps),
        "unknown",
        args.ignore_gender,
        args.person_order.unwrap_or(0) + 1,
    )?;
    reporter.set_result(serde_json::to_value(result).map_err(|e| e.to_string())?);
    Ok(())
}

pub(crate) fn scene_add_atoms_blocking(
    state: &AppState,
    reporter: &JobReporter,
    args: SceneAtomsArgs,
) -> Result<(), String> {
    let (var_name, entry_name) = normalize_cache_key(&args.var_name, &args.entry_name);
    let cache_root = cache_dir(&var_name, &entry_name);
    ensure_analysis_cache(state, &var_name, &entry_name, &cache_root)?;

    let atom_resources = add_atom_resources(
        state,
        &cache_root,
        &args.atom_paths,
        args.ignore_gender,
        args.person_order.unwrap_or(0),
        args.as_subscene,
    )?;

    let deps = read_lines(&cache_root.join("depend.txt"))?;
    let vampath = config_paths(state)?
        .1
        .ok_or_else(|| "vampath is required in config.json".to_string())?;
    let result = build_loadscene(
        state,
        reporter,
        &vampath,
        &mut json!({ "resources": atom_resources }),
        false,
        Some(deps),
        "unknown",
        args.ignore_gender,
        args.person_order.unwrap_or(0) + 1,
    )?;
    reporter.set_result(serde_json::to_value(result).map_err(|e| e.to_string())?);
    Ok(())
}

pub(crate) fn cache_clear_blocking(
    _state: &AppState,
    reporter: &JobReporter,
    args: CacheClearArgs,
) -> Result<(), String> {
    let (var_name, entry_name) = normalize_cache_key(&args.var_name, &args.entry_name);
    let cache_root = cache_dir(&var_name, &entry_name);
    if cache_root.exists() {
        let _ = fs::remove_dir_all(&cache_root);
    }
    reporter.log(format!("cache cleared {}", cache_root.display()));
    Ok(())
}

struct ReadSaveResult {
    var_name: String,
    entry_name: String,
    cache_dir: PathBuf,
    character_gender: String,
}

fn read_save_name(
    state: &AppState,
    save_name: &str,
    character_gender: &str,
    analysis: bool,
) -> Result<ReadSaveResult, String> {
    let (varspath, vampath) = config_paths(state)?;
    let vampath = vampath.ok_or_else(|| "vampath is required in config.json".to_string())?;
    let (var_name, entry_name) = save_name_split(save_name);
    let cache_root = cache_dir(&var_name, &entry_name);
    fs::create_dir_all(&cache_root).map_err(|err| err.to_string())?;

    let mut jsonscene = String::new();
    let mut depends = Vec::new();
    if var_name != "save" {
        depends.push(var_name.clone());
        let destvarfile = resolve_var_file_path(&varspath, &var_name)?;
        let file = fs::File::open(destvarfile).map_err(|err| err.to_string())?;
        let mut zip = ZipArchive::new(file).map_err(|err| err.to_string())?;
        let mut entry = zip.by_name(&entry_name).map_err(|err| err.to_string())?;
        entry.read_to_string(&mut jsonscene).map_err(|err| err.to_string())?;
    } else {
        let jsonfile = vampath.join(save_name.replace('/', "\\"));
        jsonscene = fs::read_to_string(&jsonfile).map_err(|err| err.to_string())?;
    }

    let mut gender = character_gender.to_string();
    if gender.eq_ignore_ascii_case("unknown") {
        gender = "male".to_string();
        if jsonscene.contains("/Female/") || save_name.contains("/Female/") {
            gender = "female".to_string();
        }
    }

    let deps = extract_dependencies(&jsonscene)?;
    depends.extend(deps);
    depends = distinct(depends);

    let depend_filename = cache_root.join("depend.txt");
    fs::write(&depend_filename, depends.join("\n")).map_err(|err| err.to_string())?;
    let gender_filename = cache_root.join("gender.txt");
    fs::write(&gender_filename, &gender).map_err(|err| err.to_string())?;

    if analysis {
        let replaced = jsonscene.replace("\"SELF:/", &format!("\"{}:/", var_name));
        analysis_atoms(&replaced, &cache_root, true)?;
    }

    Ok(ReadSaveResult {
        var_name,
        entry_name,
        cache_dir: cache_root,
        character_gender: gender,
    })
}

fn analysis_atoms(jsonscene: &str, scene_folder: &Path, is_person: bool) -> Result<(), String> {
    let value: Value = serde_json::from_str(jsonscene).map_err(|err| err.to_string())?;
    if value.get("atoms").is_none() {
        let atom_id = get_atom_id(&value, is_person);
        if is_person {
            let folder = scene_folder.join("atoms").join("Person");
            fs::create_dir_all(&folder).map_err(|err| err.to_string())?;
            let filename = folder.join(format!("{}.bin", util::valid_file_name(&atom_id)));
            write_json_file(&filename, &value)?;
        } else {
            let filename = scene_folder.join(format!("{}.bin", util::valid_file_name(&atom_id)));
            write_json_file(&filename, &value)?;
        }
        return Ok(());
    }

    let mut posinfo = serde_json::Map::new();
    if let Some(obj) = value.as_object() {
        for (key, val) in obj.iter() {
            if key != "atoms" {
                posinfo.insert(key.clone(), val.clone());
            }
        }
    }
    write_json_file(&scene_folder.join("posinfo.bin"), &Value::Object(posinfo))?;

    let atoms = value.get("atoms").and_then(|v| v.as_array()).cloned().unwrap_or_default();
    let mut parent_atoms: HashMap<String, Vec<String>> = HashMap::new();
    for atom in atoms {
        let mut atom_type = atom.get("type").and_then(|v| v.as_str()).unwrap_or("").to_string();
        if atom_type.is_empty() {
            continue;
        }
        if SCENE_BASE_ATOMS.contains(&atom_type.as_str()) {
            atom_type = format!("(base){}", atom_type);
        }
        let atom_folder = scene_folder.join("atoms").join(&atom_type);
        fs::create_dir_all(&atom_folder).map_err(|err| err.to_string())?;
        if atom_type == "SubScene" {
            analysis_atoms(&atom.to_string(), &atom_folder, false)?;
            continue;
        }
        let atom_id = get_atom_id(&atom, atom_type == "Person");
        if let Some(parent_atom) = atom.get("parentAtom").and_then(|v| v.as_str()) {
            if !parent_atom.is_empty() {
                let parent_key = util::valid_file_name(parent_atom);
                parent_atoms
                    .entry(parent_key)
                    .or_default()
                    .push(util::valid_file_name(&atom_id));
            }
        }
        let filename = atom_folder.join(format!("{}.bin", util::valid_file_name(&atom_id)));
        write_json_file(&filename, &atom)?;
    }

    if !parent_atoms.is_empty() {
        let mut lines = Vec::new();
        for (parent, childs) in parent_atoms {
            lines.push(format!("{}\t{}", parent, childs.join(",")));
        }
        fs::write(scene_folder.join("parentAtom.txt"), lines.join("\n"))
            .map_err(|err| err.to_string())?;
    }

    Ok(())
}

fn get_atom_id(atom: &Value, is_person: bool) -> String {
    let atom_id = atom.get("id").and_then(|v| v.as_str()).unwrap_or("atom");
    if !is_person {
        return atom_id.to_string();
    }
    let mut gender = "unknown".to_string();
    if let Some(storables) = atom.get("storables").and_then(|v| v.as_array()) {
        for storable in storables {
            if storable.get("id").and_then(|v| v.as_str()) == Some("geometry") {
                if let Some(character) = storable.get("character").and_then(|v| v.as_str()) {
                    gender = get_character_gender(character);
                    break;
                }
            }
        }
    }
    format!("({}){}", gender, atom_id)
}

fn get_character_gender(character: &str) -> String {
    let lower = character.to_ascii_lowercase();
    if lower.starts_with("male")
        || lower.starts_with("lee")
        || lower.starts_with("jarlee")
        || lower.starts_with("julian")
        || lower.starts_with("jarjulian")
    {
        return "Male".to_string();
    }
    if lower.starts_with("futa") {
        return "Futa".to_string();
    }
    "Female".to_string()
}

fn ensure_analysis_cache(
    state: &AppState,
    var_name: &str,
    entry_name: &str,
    cache_root: &Path,
) -> Result<(), String> {
    let atoms_dir = cache_root.join("atoms");
    if atoms_dir.exists() {
        return Ok(());
    }
    let save_name = if var_name == "save" {
        entry_name.to_string()
    } else {
        format!("{}:/{}", var_name, entry_name)
    };
    let _ = read_save_name(state, &save_name, "female", true)?;
    Ok(())
}

pub fn list_analysis_atoms(
    state: &AppState,
    var_name: &str,
    entry_name: &str,
) -> Result<(Vec<AtomTreeNode>, Vec<String>), String> {
    let (var_name, entry_name) = normalize_cache_key(var_name, entry_name);
    let cache_root = cache_dir(&var_name, &entry_name);
    ensure_analysis_cache(state, &var_name, &entry_name, &cache_root)?;

    let atoms_root = cache_root.join("atoms");
    let atoms = if atoms_root.exists() {
        build_atom_tree(&atoms_root, &cache_root)?
    } else {
        Vec::new()
    };

    let mut person_atoms = Vec::new();
    let person_dir = atoms_root.join("Person");
    if person_dir.exists() {
        for entry in fs::read_dir(&person_dir).map_err(|err| err.to_string())? {
            let entry = entry.map_err(|err| err.to_string())?;
            let path = entry.path();
            if path.extension().and_then(|s| s.to_str()) != Some("bin") {
                continue;
            }
            if let Some(stem) = path.file_stem().and_then(|s| s.to_str()) {
                person_atoms.push(stem.to_string());
            }
        }
    }
    person_atoms.sort();
    person_atoms.dedup();

    Ok((atoms, person_atoms))
}

fn build_atom_tree(dir: &Path, cache_root: &Path) -> Result<Vec<AtomTreeNode>, String> {
    let mut entries = Vec::new();
    if dir.exists() {
        for entry in fs::read_dir(dir).map_err(|err| err.to_string())? {
            let entry = entry.map_err(|err| err.to_string())?;
            entries.push(entry.path());
        }
    }
    entries.sort_by(|a, b| {
        a.file_name()
            .and_then(|s| s.to_str())
            .unwrap_or("")
            .to_ascii_lowercase()
            .cmp(
                &b.file_name()
                    .and_then(|s| s.to_str())
                    .unwrap_or("")
                    .to_ascii_lowercase(),
            )
    });

    let mut nodes = Vec::new();
    for path in entries {
        let name = path
            .file_stem()
            .and_then(|s| s.to_str())
            .or_else(|| path.file_name().and_then(|s| s.to_str()))
            .unwrap_or("")
            .to_string();
        if path.is_dir() {
            let children = build_atom_tree(&path, cache_root)?;
            nodes.push(AtomTreeNode {
                name,
                path: None,
                children,
            });
        } else if path.extension().and_then(|s| s.to_str()) == Some("bin") {
            let rel = path
                .strip_prefix(cache_root)
                .unwrap_or(&path)
                .to_string_lossy()
                .replace('\\', "/");
            nodes.push(AtomTreeNode {
                name,
                path: Some(rel),
                children: Vec::new(),
            });
        }
    }

    Ok(nodes)
}

fn load_person_atom(cache_root: &Path, atom_name: &str) -> Result<Value, String> {
    let person_dir = cache_root.join("atoms").join("Person");
    let candidate = if atom_name.to_ascii_lowercase().ends_with(".bin") {
        person_dir.join(atom_name)
    } else {
        person_dir.join(format!("{}.bin", atom_name))
    };
    let path = if candidate.exists() {
        candidate
    } else {
        find_atom_file(&person_dir, atom_name)
            .ok_or_else(|| format!("atom not found: {}", atom_name))?
    };
    let contents = fs::read_to_string(&path).map_err(|err| err.to_string())?;
    serde_json::from_str(&contents).map_err(|err| err.to_string())
}

fn load_core_control(cache_root: &Path) -> Result<Value, String> {
    let base_dir = cache_root.join("atoms").join("(base)CoreControl");
    let mut files = Vec::new();
    if base_dir.exists() {
        for entry in fs::read_dir(&base_dir).map_err(|err| err.to_string())? {
            let entry = entry.map_err(|err| err.to_string())?;
            let path = entry.path();
            if path.extension().and_then(|s| s.to_str()) == Some("bin") {
                files.push(path);
            }
        }
    }
    let first = files.first().ok_or_else(|| "CoreControl not found".to_string())?;
    let contents = fs::read_to_string(first).map_err(|err| err.to_string())?;
    serde_json::from_str(&contents).map_err(|err| err.to_string())
}

fn save_preset(
    state: &AppState,
    var_name: &str,
    atom: &Value,
    morphs: bool,
    hair: bool,
    clothing: bool,
    skin: bool,
    breast: bool,
    glute: bool,
    save_names: &mut Vec<Value>,
    character_gender: &mut String,
    ignore_gender: bool,
    person_order: u32,
) -> Result<(), String> {
    let mut json_preset = json!({ "setUnlistedParamsToDefault": "false", "storables": [] });
    let mut json_morphs = json!({ "setUnlistedParamsToDefault": "true", "storables": [] });
    let mut json_breast = json!({ "setUnlistedParamsToDefault": "true", "storables": [] });
    let mut json_glute = json!({ "setUnlistedParamsToDefault": "true", "storables": [] });
    let mut json_skin = json!({ "setUnlistedParamsToDefault": "true", "storables": [] });
    let mut json_hair = json!({ "setUnlistedParamsToDefault": "true", "storables": [] });
    let mut json_clothing = json!({ "setUnlistedParamsToDefault": "true", "storables": [] });

    let skin_ids = [
        "skin",
        "textures",
        "teeth",
        "tongue",
        "mouth",
        "FemaleEyelashes",
        "MaleEyelashes",
        "lacrimals",
        "sclera",
        "irises",
    ];
    let breast_ids = ["BreastControl", "BreastPhysicsMesh"];
    let glute_ids = ["GluteControl", "LowerPhysicsMesh"];
    let mut hair_ids = Vec::new();
    let mut clothing_ids = Vec::new();

    if let Some(storables) = atom.get("storables").and_then(|v| v.as_array()) {
        for storable in storables {
            if storable.get("id").and_then(|v| v.as_str()) == Some("geometry") {
                let preset_geom = json!({ "id": "geometry" });
                let mut preset_geom = preset_geom;
                let morphs_geom = json!({ "id": "geometry" });
                let mut morphs_geom = morphs_geom;
                let breast_geom = json!({ "id": "geometry" });
                let mut breast_geom = breast_geom;
                let glute_geom = json!({ "id": "geometry" });
                let skin_geom = json!({ "id": "geometry" });
                let mut skin_geom = skin_geom;
                let hair_geom = json!({ "id": "geometry" });
                let mut hair_geom = hair_geom;
                let clothing_geom = json!({ "id": "geometry" });
                let mut clothing_geom = clothing_geom;

                if let Some(val) = storable.get("useFemaleMorphsOnMale") {
                    morphs_geom["useFemaleMorphsOnMale"] = val.clone();
                }
                if let Some(character) = storable.get("character").and_then(|v| v.as_str()) {
                    *character_gender = get_character_gender(character).to_ascii_lowercase();
                    skin_geom["character"] = Value::String(character.to_string());
                    if skin {
                        preset_geom["character"] = Value::String(character.to_string());
                    }
                }
                if let Some(morphs_val) = storable.get("morphs") {
                    morphs_geom["morphs"] = morphs_val.clone();
                }
                if clothing {
                    if let Some(clothing_val) = storable.get("clothing") {
                        preset_geom["clothing"] = clothing_val.clone();
                        clothing_geom["clothing"] = clothing_val.clone();
                    }
                }
                if hair {
                    if let Some(hair_val) = storable.get("hair") {
                        preset_geom["hair"] = hair_val.clone();
                        hair_geom["hair"] = hair_val.clone();
                    }
                }
                if let Some(val) = storable.get("useAuxBreastColliders") {
                    breast_geom["useAuxBreastColliders"] = val.clone();
                }

                collect_internal_ids(&preset_geom, "clothing", &mut clothing_ids);
                collect_internal_ids(&clothing_geom, "clothing", &mut clothing_ids);
                collect_internal_ids(&preset_geom, "hair", &mut hair_ids);
                collect_internal_ids(&hair_geom, "hair", &mut hair_ids);

                push_storable(&mut json_preset, preset_geom);
                push_storable(&mut json_morphs, morphs_geom);
                push_storable(&mut json_breast, breast_geom);
                push_storable(&mut json_glute, glute_geom);
                push_storable(&mut json_skin, skin_geom);
                push_storable(&mut json_hair, hair_geom);
                push_storable(&mut json_clothing, clothing_geom);
                break;
            }
        }

        for storable in storables {
            let id = storable.get("id").and_then(|v| v.as_str()).unwrap_or("");
            if clothing {
                if starts_with_any(id, &clothing_ids) {
                    push_storable(&mut json_preset, storable.clone());
                }
            }
            if starts_with_any(id, &clothing_ids) {
                push_storable(&mut json_clothing, storable.clone());
            }
            if hair {
                if starts_with_any(id, &hair_ids) {
                    push_storable(&mut json_preset, storable.clone());
                }
            }
            if starts_with_any(id, &hair_ids) {
                push_storable(&mut json_hair, storable.clone());
            }
            if skin {
                if skin_ids.contains(&id) {
                    push_storable(&mut json_preset, storable.clone());
                }
            }
            if skin_ids.contains(&id) {
                push_storable(&mut json_skin, storable.clone());
            }
            if breast_ids.contains(&id) {
                push_storable(&mut json_breast, storable.clone());
            }
            if glute_ids.contains(&id) {
                push_storable(&mut json_glute, storable.clone());
            }
        }
    }

    if skin {
        save_static_preset(state, "Custom\\Atom\\Person\\Appearance\\Preset_eyeDefault.vap", DEFAULT_EYE_COLOR)?;
        add_preset_resource(save_names, "looks", "Custom/Atom/Person/Appearance/Preset_eyeDefault.vap", character_gender, ignore_gender, person_order + 1);
    }
    if clothing {
        save_static_preset(state, "Custom\\Atom\\Person\\Clothing\\Preset_ClothNaked.vap", CLOTH_NAKED)?;
        add_preset_resource(save_names, "clothing", "Custom/Atom/Person/Clothing/Preset_ClothNaked.vap", character_gender, ignore_gender, person_order + 1);
    }
    if hair {
        save_static_preset(state, "Custom\\Atom\\Person\\Hair\\Preset_HairBald.vap", HAIR_BALD)?;
        add_preset_resource(save_names, "hairstyle", "Custom/Atom/Person/Hair/Preset_HairBald.vap", character_gender, ignore_gender, person_order + 1);
    }
    if morphs {
        save_json_preset(state, var_name, "Custom\\Atom\\Person\\Morphs\\Preset_temp.vap", &json_morphs)?;
        add_preset_resource(save_names, "morphs", "Custom/Atom/Person/Morphs/Preset_temp.vap", character_gender, ignore_gender, person_order + 1);
    }
    if breast {
        save_json_preset(state, var_name, "Custom\\Atom\\Person\\BreastPhysics\\Preset_temp.vap", &json_breast)?;
        add_preset_resource(save_names, "breast", "Custom/Atom/Person/BreastPhysics/Preset_temp.vap", character_gender, ignore_gender, person_order + 1);
    }
    if glute {
        save_json_preset(state, var_name, "Custom\\Atom\\Person\\GlutePhysics\\Preset_temp.vap", &json_glute)?;
        add_preset_resource(save_names, "glute", "Custom/Atom/Person/GlutePhysics/Preset_temp.vap", character_gender, ignore_gender, person_order + 1);
    }
    if clothing || hair || skin {
        save_json_preset(state, var_name, "Custom\\Atom\\Person\\Appearance\\Preset_temp.vap", &json_preset)?;
        add_preset_resource(save_names, "looks", "Custom/Atom/Person/Appearance/Preset_temp.vap", character_gender, ignore_gender, person_order + 1);
    }

    Ok(())
}

fn save_plugin_preset(
    state: &AppState,
    var_name: &str,
    atom: &Value,
    save_names: &mut Vec<Value>,
    character_gender: &str,
    ignore_gender: bool,
    person_order: u32,
) -> Result<(), String> {
    let mut json_plugin = json!({ "setUnlistedParamsToDefault": "true", "storables": [] });
    let mut plugin_ids = Vec::new();
    if let Some(storables) = atom.get("storables").and_then(|v| v.as_array()) {
        for storable in storables {
            if storable.get("id").and_then(|v| v.as_str()) == Some("PluginManager") {
                push_storable(&mut json_plugin, storable.clone());
                if let Some(plugins) = storable.get("plugins").and_then(|v| v.as_object()) {
                    for key in plugins.keys() {
                        plugin_ids.push(key.clone());
                    }
                }
            }
        }
        for storable in storables {
            let id = storable.get("id").and_then(|v| v.as_str()).unwrap_or("");
            if plugin_ids.iter().any(|pid| id.starts_with(pid)) {
                push_storable(&mut json_plugin, storable.clone());
            }
        }
    }
    save_json_preset(state, var_name, "Custom\\Atom\\Person\\Plugins\\Preset_temp.vap", &json_plugin)?;
    add_preset_resource(save_names, "plugin", "Custom/Atom/Person/Plugins/Preset_temp.vap", character_gender, ignore_gender, person_order + 1);
    Ok(())
}

fn save_pose_preset(
    state: &AppState,
    var_name: &str,
    atom: &Value,
    save_names: &mut Vec<Value>,
    character_gender: &str,
    ignore_gender: bool,
    person_order: u32,
) -> Result<(), String> {
    let mut json_pose = json!({ "setUnlistedParamsToDefault": "true", "storables": [] });
    if let Some(storables) = atom.get("storables").and_then(|v| v.as_array()) {
        for storable in storables {
            if storable.get("id").and_then(|v| v.as_str()) == Some("geometry") {
                let mut geom = json!({ "id": "geometry" });
                if let Some(morphs) = storable.get("morphs") {
                    geom["morphs"] = morphs.clone();
                }
                push_storable(&mut json_pose, geom);
            }
            let id = storable.get("id").and_then(|v| v.as_str()).unwrap_or("");
            if POSE_CONTROL_IDS.contains(&id) || POSE_OBJECT_IDS.contains(&id) {
                push_storable(&mut json_pose, storable.clone());
            }
        }
    }
    save_json_preset(state, var_name, "Custom\\Atom\\Person\\Pose\\Preset_temp.vap", &json_pose)?;
    add_preset_resource(save_names, "pose", "Custom/Atom/Person/Pose/Preset_temp.vap", character_gender, ignore_gender, person_order + 1);
    Ok(())
}

fn save_animation_preset(
    state: &AppState,
    _var_name: &str,
    atom: &Value,
    core: &Value,
    save_names: &mut Vec<Value>,
    character_gender: &str,
    ignore_gender: bool,
    person_order: u32,
) -> Result<(), String> {
    let mut json_animation = json!({ "setUnlistedParamsToDefault": "true", "storables": [] });
    let mut control_ids = Vec::new();
    if let Some(storables) = atom.get("storables").and_then(|v| v.as_array()) {
        for storable in storables {
            let id = storable.get("id").and_then(|v| v.as_str()).unwrap_or("");
            if id.ends_with("Animation") {
                push_storable(&mut json_animation, storable.clone());
                control_ids.push(animation_id_to_control(id));
            }
        }
        for storable in storables {
            let id = storable.get("id").and_then(|v| v.as_str()).unwrap_or("");
            if control_ids.iter().any(|cid| cid == id) {
                push_storable(&mut json_animation, storable.clone());
            }
        }
    }

    let master = find_motion_animation_master(core)
        .ok_or_else(|| "MotionAnimationMaster not found".to_string())?;
    json_animation["motionAnimationMaster"] = master;

    save_raw_json(state, "Custom\\Atom\\Person\\AnimationPresets\\Preset_temp.bin", &json_animation)?;
    add_preset_resource(
        save_names,
        "animation",
        "Custom/Atom/Person/AnimationPresets/Preset_temp.bin",
        character_gender,
        ignore_gender,
        person_order + 1,
    );
    Ok(())
}

fn find_motion_animation_master(core: &Value) -> Option<Value> {
    core.get("storables")
        .and_then(|v| v.as_array())
        .and_then(|storables| {
            storables.iter().find_map(|storable| {
                if storable.get("id").and_then(|v| v.as_str()) == Some("MotionAnimationMaster") {
                    Some(storable.clone())
                } else {
                    None
                }
            })
        })
}

fn animation_id_to_control(id: &str) -> String {
    match id {
        "eyeTargetControlAnimation" | "lNippleControlAnimation" | "rNippleControlAnimation" => {
            id.replace("Animation", "")
        }
        _ => id.replace("Animation", "Control"),
    }
}

fn add_atom_resources(
    state: &AppState,
    cache_root: &Path,
    atom_paths: &[String],
    ignore_gender: bool,
    person_order: u32,
    as_subscene: bool,
) -> Result<Vec<Value>, String> {
    let (_, vampath) = config_paths(state)?;
    let vampath = vampath.ok_or_else(|| "vampath is required in config.json".to_string())?;
    let plugin_data = vampath.join("Custom").join("PluginData").join("feelfar");
    if plugin_data.exists() {
        let _ = fs::remove_dir_all(&plugin_data);
    }
    fs::create_dir_all(&plugin_data).map_err(|err| err.to_string())?;

    let mut resources = Vec::new();
    for atom_path in atom_paths {
        let src = resolve_atom_source(cache_root, atom_path);
        if !src.exists() {
            continue;
        }
        let file_name = src
            .file_name()
            .and_then(|s| s.to_str())
            .ok_or_else(|| "invalid atom file name".to_string())?;
        let dest = plugin_data.join(file_name);
        fs::copy(&src, &dest).map_err(|err| err.to_string())?;
        let save_name = dest.to_string_lossy().replace('\\', "/");
        add_preset_resource(
            &mut resources,
            if as_subscene { "atomSubscene" } else { "atom" },
            &save_name,
            "unknown",
            ignore_gender,
            person_order + 1,
        );
    }
    Ok(resources)
}

pub(crate) fn set_hide_fav(
    state: &AppState,
    var_name: Option<&str>,
    scene_path: &str,
    hide_fav: i32,
) -> Result<(), String> {
    let (_, vampath) = config_paths(state)?;
    let vampath = vampath.ok_or_else(|| "vampath is required in config.json".to_string())?;
    let scenepath = Path::new(scene_path)
        .parent()
        .map(|p| p.to_string_lossy().to_string())
        .unwrap_or_default();
    let scenename = Path::new(scene_path)
        .file_name()
        .and_then(|s| s.to_str())
        .unwrap_or("")
        .to_string();
    let mut use_root = var_name.unwrap_or("").trim().to_string();
    if use_root == "(save)." || use_root == "save" {
        use_root.clear();
    }

    let pathhide;
    let pathfav;
    if use_root.is_empty() {
        pathhide = vampath.join(format!("{}.hide", scene_path.replace('/', "\\")));
        pathfav = vampath.join(format!("{}.fav", scene_path.replace('/', "\\")));
    } else {
        pathhide = vampath
            .join("AddonPackagesFilePrefs")
            .join(&use_root)
            .join(&scenepath)
            .join(format!("{}.hide", scenename));
        pathfav = vampath
            .join("AddonPackagesFilePrefs")
            .join(&use_root)
            .join(&scenepath)
            .join(format!("{}.fav", scenename));
    }

    match hide_fav {
        -1 => {
            if pathfav.exists() {
                let _ = fs::remove_file(&pathfav);
            }
            if !pathhide.exists() {
                if let Some(parent) = pathhide.parent() {
                    fs::create_dir_all(parent).map_err(|err| err.to_string())?;
                }
                let _ = fs::File::create(&pathhide);
            }
        }
        0 => {
            if pathfav.exists() {
                let _ = fs::remove_file(&pathfav);
            }
            if pathhide.exists() {
                let _ = fs::remove_file(&pathhide);
            }
        }
        1 => {
            if pathhide.exists() {
                let _ = fs::remove_file(&pathhide);
            }
            if !pathfav.exists() {
                if let Some(parent) = pathfav.parent() {
                    fs::create_dir_all(parent).map_err(|err| err.to_string())?;
                }
                let _ = fs::File::create(&pathfav);
            }
        }
        _ => {}
    }
    Ok(())
}

fn build_loadscene(
    state: &AppState,
    reporter: &JobReporter,
    vampath: &Path,
    json_ls: &mut Value,
    merge: bool,
    depend_vars: Option<Vec<String>>,
    character_gender: &str,
    ignore_gender: bool,
    person_order: u32,
) -> Result<SceneLoadResult, String> {
    let resources = json_ls
        .get_mut("resources")
        .and_then(|v| v.as_array_mut())
        .ok_or_else(|| "resources required".to_string())?;
    let mut delete_temp = Vec::new();
    for resource in resources.iter_mut() {
        if !resource.get("merge").is_some() {
            resource["merge"] = Value::String(merge.to_string().to_ascii_lowercase());
        }
        if !resource.get("characterGender").is_some() {
            resource["characterGender"] = Value::String(character_gender.to_string());
        }
        if !resource.get("ignoreGender").is_some() {
            resource["ignoreGender"] = Value::String(ignore_gender.to_string().to_ascii_lowercase());
        }
        if !resource.get("personOrder").is_some() {
            resource["personOrder"] = Value::String(person_order.to_string());
        }
        if delete_temp.is_empty() {
            if resource.get("type").and_then(|v| v.as_str()) == Some("scenes") {
                delete_temp = collect_temp_links(vampath)?;
            }
        }
    }

    let mut deps = depend_vars.unwrap_or_else(|| {
        resources
            .iter()
            .filter_map(|res| res.get("saveName").and_then(|v| v.as_str()))
            .filter_map(|save| save.split_once(":/").map(|(base, _)| base.to_string()))
            .collect()
    });
    deps = distinct(deps);

    let (temp_installed, rescan) = install_temp(state, reporter, &deps)?;
    for installed in &temp_installed {
        let target = format!("{}.var", installed.to_ascii_lowercase());
        delete_temp.retain(|f| f != &target);
    }

    json_ls["rescan"] = Value::String(rescan.to_string());

    let loadscene = loadscene_path(vampath);
    if let Some(parent) = loadscene.parent() {
        fs::create_dir_all(parent).map_err(|err| err.to_string())?;
    }
    if loadscene.exists() {
        let _ = fs::remove_file(&loadscene);
    }
    fs::write(&loadscene, serde_json::to_string_pretty(json_ls).map_err(|err| err.to_string())?)
        .map_err(|err| err.to_string())?;

    if !delete_temp.is_empty() {
        spawn_delete_temp_thread(vampath.to_path_buf(), delete_temp);
    }

    Ok(SceneLoadResult {
        rescan,
        temp_installed,
        loadscene_path: loadscene.to_string_lossy().to_string(),
    })
}

fn install_temp(state: &AppState, reporter: &JobReporter, deps: &[String]) -> Result<(Vec<String>, bool), String> {
    let (varspath, vampath) = config_paths(state)?;
    let vampath = vampath.ok_or_else(|| "vampath is required in config.json".to_string())?;

    let pool = &state.db_pool;
    let handle = tokio::runtime::Handle::current();
    let mut varnames = handle.block_on(vars_dependencies(pool, deps.to_vec()))?;
    varnames = distinct(varnames);
    let installed_links = fs_util::collect_installed_links_ci(&vampath);
    varnames.retain(|v| !installed_links.contains_key(&v.to_ascii_lowercase()));

    let temp_dir = temp_links_dir(&vampath);
    fs::create_dir_all(&temp_dir).map_err(|err| err.to_string())?;

    let mut installed = Vec::new();
    let mut rescan = false;
    for var_name in varnames {
        if !handle.block_on(var_exists_conn(pool, &var_name))? {
            reporter.log(format!("missing var: {}", var_name));
            continue;
        }
        match install_temp_var(&varspath, &temp_dir, &var_name) {
            Ok(InstallOutcome::Installed) => {
                installed.push(var_name);
                rescan = true;
            }
            Ok(InstallOutcome::AlreadyInstalled) => {}
            Err(err) => reporter.log(format!("temp install failed {} ({})", var_name, err)),
        }
    }
    Ok((installed, rescan))
}

fn install_temp_var(
    varspath: &Path,
    temp_dir: &Path,
    var_name: &str,
) -> Result<InstallOutcome, String> {
    let link_path = temp_dir.join(format!("{}.var", var_name));
    let disabled_path = link_path.with_extension("var.disabled");
    if disabled_path.exists() {
        let _ = fs::remove_file(&disabled_path);
    }
    if link_path.exists() {
        return Ok(InstallOutcome::AlreadyInstalled);
    }
    let dest = resolve_var_file_path(varspath, var_name)?;
    winfs::create_symlink_file(&link_path, &dest)?;
    set_link_times(&link_path, &dest)?;
    Ok(InstallOutcome::Installed)
}

fn collect_temp_links(vampath: &Path) -> Result<Vec<String>, String> {
    let dir = temp_links_dir(vampath);
    fs::create_dir_all(&dir).map_err(|err| err.to_string())?;
    let mut files = Vec::new();
    for entry in fs::read_dir(&dir).map_err(|err| err.to_string())? {
        let entry = entry.map_err(|err| err.to_string())?;
        let path = entry.path();
        if path.is_file() && fs_util::is_symlink(&path) {
            if let Some(name) = path.file_name().and_then(|s| s.to_str()) {
                files.push(name.to_ascii_lowercase());
            }
        }
    }
    Ok(files)
}

fn spawn_delete_temp_thread(vampath: PathBuf, files: Vec<String>) {
    thread::spawn(move || {
        let loadscene = loadscene_path(&vampath);
        loop {
            thread::sleep(Duration::from_secs(2));
            if loadscene.exists() {
                continue;
            }
            thread::sleep(Duration::from_secs(20));
            let temp_dir = temp_links_dir(&vampath);
            for file in files {
                let path = temp_dir.join(&file);
                let _ = fs::remove_file(&path);
            }
            break;
        }
    });
}

fn resolve_atom_source(cache_root: &Path, atom_path: &str) -> PathBuf {
    let candidate = PathBuf::from(atom_path);
    if candidate.is_absolute() {
        return candidate;
    }
    cache_root.join(atom_path)
}

fn write_json_file(path: &Path, value: &Value) -> Result<(), String> {
    fs::write(path, serde_json::to_string(value).map_err(|err| err.to_string())?)
        .map_err(|err| err.to_string())
}

fn save_json_preset(state: &AppState, var_name: &str, rel: &str, value: &Value) -> Result<(), String> {
    let (_, vampath) = config_paths(state)?;
    let vampath = vampath.ok_or_else(|| "vampath is required in config.json".to_string())?;
    let path = vampath.join(rel);
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent).map_err(|err| err.to_string())?;
    }
    let mut content = serde_json::to_string(value).map_err(|err| err.to_string())?;
    content = content.replace("\"SELF:/", &format!("\"{}:/", var_name));
    fs::write(&path, content).map_err(|err| err.to_string())?;
    Ok(())
}

fn save_raw_json(state: &AppState, rel: &str, value: &Value) -> Result<(), String> {
    let (_, vampath) = config_paths(state)?;
    let vampath = vampath.ok_or_else(|| "vampath is required in config.json".to_string())?;
    let path = vampath.join(rel);
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent).map_err(|err| err.to_string())?;
    }
    fs::write(&path, serde_json::to_string(value).map_err(|err| err.to_string())?)
        .map_err(|err| err.to_string())?;
    Ok(())
}

fn save_static_preset(state: &AppState, rel: &str, content: &str) -> Result<(), String> {
    let (_, vampath) = config_paths(state)?;
    let vampath = vampath.ok_or_else(|| "vampath is required in config.json".to_string())?;
    let path = vampath.join(rel);
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent).map_err(|err| err.to_string())?;
    }
    fs::write(&path, content).map_err(|err| err.to_string())?;
    Ok(())
}

fn add_preset_resource(
    save_names: &mut Vec<Value>,
    resource_type: &str,
    save_name: &str,
    character_gender: &str,
    ignore_gender: bool,
    person_order: u32,
) {
    save_names.push(json!({
        "type": resource_type,
        "saveName": save_name.replace('\\', "/"),
        "characterGender": character_gender.to_ascii_lowercase(),
        "ignoreGender": ignore_gender.to_string().to_ascii_lowercase(),
        "personOrder": person_order.to_string(),
    }));
}

fn push_storable(target: &mut Value, storable: Value) {
    if let Some(arr) = target.get_mut("storables").and_then(|v| v.as_array_mut()) {
        arr.push(storable);
    }
}

fn collect_internal_ids(source: &Value, key: &str, out: &mut Vec<String>) {
    if let Some(arr) = source.get(key).and_then(|v| v.as_array()) {
        for item in arr {
            if let Some(id) = item.get("internalId").and_then(|v| v.as_str()) {
                out.push(id.to_string());
            }
        }
    }
}

fn starts_with_any(id: &str, prefixes: &[String]) -> bool {
    prefixes.iter().any(|prefix| id.starts_with(prefix))
}

fn extract_dependencies(json: &str) -> Result<Vec<String>, String> {
    let regex = Regex::new(
        r"\x22(([^\r\n\x22\x3A\x2E]{1,60})\x2E([^\r\n\x22\x3A\x2E]{1,80})\x2E(\d+|latest))(\x22?\s*)\x3A",
    )
    .map_err(|err| err.to_string())?;
    let mut deps = Vec::new();
    for cap in regex.captures_iter(json) {
        if let Some(m) = cap.get(1) {
            let mut dep = m.as_str().to_string();
            if let Some(idx) = dep.find('/') {
                dep = dep[idx + 1..].to_string();
            }
            deps.push(dep);
        }
    }
    Ok(distinct(deps))
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

fn read_lines(path: &Path) -> Result<Vec<String>, String> {
    let contents = fs::read_to_string(path).map_err(|err| err.to_string())?;
    Ok(contents
        .lines()
        .map(|line| line.trim().to_string())
        .filter(|line| !line.is_empty())
        .collect())
}

fn cache_dir(var_name: &str, entry_name: &str) -> PathBuf {
    let key = if var_name == "(save)." || var_name.is_empty() {
        "save"
    } else {
        var_name
    };
    exe_dir()
        .join(CACHE_DIR)
        .join(util::valid_file_name(key))
        .join(util::valid_file_name(&util::normalize_entry_name(entry_name)))
}

fn normalize_cache_key(var_name: &str, entry_name: &str) -> (String, String) {
    let key = if var_name == "(save)." || var_name.is_empty() {
        "save"
    } else {
        var_name
    };
    (key.to_string(), entry_name.to_string())
}

fn save_name_split(save_name: &str) -> (String, String) {
    if let Some((var_name, entry)) = save_name.split_once(":/") {
        return (var_name.to_string(), entry.to_string());
    }
    ("save".to_string(), save_name.to_string())
}

fn find_atom_file(root: &Path, atom_name: &str) -> Option<PathBuf> {
    if !root.exists() {
        return None;
    }
    for entry in fs::read_dir(root).ok()? {
        let entry = entry.ok()?;
        let path = entry.path();
        if path.extension().and_then(|s| s.to_str()) != Some("bin") {
            continue;
        }
        let file_name = path.file_name().and_then(|s| s.to_str()).unwrap_or("");
        if file_name.eq_ignore_ascii_case(atom_name)
            || file_name.eq_ignore_ascii_case(&format!("{}.bin", atom_name))
        {
            return Some(path);
        }
    }
    None
}

fn set_link_times(link: &Path, target: &Path) -> Result<(), String> {
    let meta = fs::metadata(target).map_err(|err| err.to_string())?;
    let modified = meta.modified().map_err(|err| err.to_string())?;
    let created = meta.created().unwrap_or(modified);
    winfs::set_symlink_file_times(link, created, modified)
}

enum InstallOutcome {
    Installed,
    AlreadyInstalled,
}
