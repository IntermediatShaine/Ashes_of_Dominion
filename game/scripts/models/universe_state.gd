class_name UniverseState
extends RefCounted
## State of ONE generated world. Replaced wholesale on a universe transfer.
##
## Immutable generation parameters (world_seed, generation_version) are kept
## separate from mutable world state (discovery, settlements, modifications).
## The strategic world graph and wilderness layouts are NOT stored: they are
## regenerated deterministically from the parameters; only what the player
## changed is persisted (see `world_modifications`, `discovered_landmark_ids`).

const CURRENT_GENERATION_VERSION: int = 1
const MINUTES_PER_DAY: int = 1440
const DEFAULT_START_MINUTE: int = 480

# --- immutable generation parameters ---
var universe_id: String = ""
var world_seed: int = 0
var generation_version: int = CURRENT_GENERATION_VERSION
## Difficulty configuration frozen at universe creation (see data/difficulty.json).
var difficulty: Dictionary = {}
## World settings frozen at universe creation: {mist_enabled: bool}
var world_settings: Dictionary = {}

# --- mutable world state ---
var current_day: int = 1
## Minute of the current day (0..MINUTES_PER_DAY-1). `current_day` plus this is
## the single in-game clock; the settlement reads it, it never keeps its own.
var time_of_day_minutes: int = DEFAULT_START_MINUTE
## Where the protagonist is: {map_id, entry_id, return_stack:[{map_id, entry_id}],
## position:[x, y] (optional exact resume point)}. Written through MapLocation.
var location: Dictionary = {"map_id": "", "entry_id": "", "return_stack": []}
var discovered_landmark_ids: Array[String] = []
var revealed_edge_ids: Array[String] = []
## area_id -> {"harvested": {node_key: day}, "defeated": {...}}
var world_modifications: Dictionary = {}
var settlements: Dictionary = {}          # settlement_id -> SettlementState
var home_settlement_id: String = ""
var factions: Dictionary = {}             # faction_id -> FactionState
var npc_states: Dictionary = {}
var companion_states: Dictionary = {}
var territory_state: Dictionary = {}      # landmark_id -> faction_id
var threat_state: Dictionary = {"completed_expeditions": 0, "awareness": 0, "grace_period": 5}
var world_events: Array = []
var expeditions: Dictionary = {}          # expedition_id -> ExpeditionRecord
var expedition_history: Array[String] = []
var active_expedition_id: String = ""
var story_flags: Dictionary = {}
## decision_id -> chosen option id (each narrative decision resolves once per universe)
var decision_log: Dictionary = {}
## Ephemeral-but-persisted protagonist condition: {health: int}
var protagonist_condition: Dictionary = {}
var death_count: int = 0
var id_counters: Dictionary = {}
var rng_states: Dictionary = {}


func home_settlement() -> SettlementState:
	return settlements.get(home_settlement_id)


func faction(faction_id: String) -> FactionState:
	return factions.get(faction_id)


func is_landmark_discovered(landmark_id: String) -> bool:
	return discovered_landmark_ids.has(landmark_id)


func discover_landmark(landmark_id: String) -> bool:
	if discovered_landmark_ids.has(landmark_id):
		return false
	discovered_landmark_ids.append(landmark_id)
	return true


func reveal_edge(edge_id: String) -> bool:
	if revealed_edge_ids.has(edge_id):
		return false
	revealed_edge_ids.append(edge_id)
	return true


func mist_enabled() -> bool:
	return DictUtil.get_bool(world_settings, "mist_enabled", true)


func active_expedition() -> ExpeditionRecord:
	if active_expedition_id == "":
		return null
	return expeditions.get(active_expedition_id)


func to_dict() -> Dictionary:
	var settlements_out := {}
	for k in DictUtil.sorted_keys(settlements):
		settlements_out[k] = (settlements[k] as SettlementState).to_dict()
	var factions_out := {}
	for k in DictUtil.sorted_keys(factions):
		factions_out[k] = (factions[k] as FactionState).to_dict()
	var expeditions_out := {}
	for k in DictUtil.sorted_keys(expeditions):
		expeditions_out[k] = (expeditions[k] as ExpeditionRecord).to_dict()
	return {
		"universe_id": universe_id,
		"world_seed": str(world_seed),  # string: 64-bit safe through JSON
		"generation_version": generation_version,
		"difficulty": difficulty.duplicate(true),
		"world_settings": world_settings.duplicate(true),
		"current_day": current_day,
		"time_of_day_minutes": time_of_day_minutes,
		"location": location.duplicate(true),
		"discovered_landmark_ids": discovered_landmark_ids.duplicate(),
		"revealed_edge_ids": revealed_edge_ids.duplicate(),
		"world_modifications": world_modifications.duplicate(true),
		"settlements": settlements_out,
		"home_settlement_id": home_settlement_id,
		"factions": factions_out,
		"npc_states": npc_states.duplicate(true),
		"companion_states": companion_states.duplicate(true),
		"territory_state": territory_state.duplicate(true),
		"threat_state": threat_state.duplicate(true),
		"world_events": world_events.duplicate(true),
		"expeditions": expeditions_out,
		"expedition_history": expedition_history.duplicate(),
		"active_expedition_id": active_expedition_id,
		"story_flags": story_flags.duplicate(true),
		"decision_log": decision_log.duplicate(true),
		"protagonist_condition": protagonist_condition.duplicate(true),
		"death_count": death_count,
		"id_counters": id_counters.duplicate(),
		"rng_states": rng_states.duplicate(true),
	}


static func from_dict(d: Dictionary) -> UniverseState:
	var u := UniverseState.new()
	u.universe_id = DictUtil.get_string(d, "universe_id")
	u.world_seed = DictUtil.get_int(d, "world_seed")
	u.generation_version = DictUtil.get_int(d, "generation_version", CURRENT_GENERATION_VERSION)
	u.difficulty = DictUtil.get_dict(d, "difficulty").duplicate(true)
	u.world_settings = DictUtil.get_dict(d, "world_settings").duplicate(true)
	u.current_day = DictUtil.get_int(d, "current_day", 1)
	u.time_of_day_minutes = DictUtil.get_int(d, "time_of_day_minutes", DEFAULT_START_MINUTE)
	u.location = MapLocation.normalized(DictUtil.get_dict(d, "location"))
	u.discovered_landmark_ids = DictUtil.string_array(DictUtil.get_array(d, "discovered_landmark_ids"))
	u.revealed_edge_ids = DictUtil.string_array(DictUtil.get_array(d, "revealed_edge_ids"))
	u.world_modifications = DictUtil.get_dict(d, "world_modifications").duplicate(true)
	for k in DictUtil.get_dict(d, "settlements").keys():
		u.settlements[String(k)] = SettlementState.from_dict(d["settlements"][k])
	u.home_settlement_id = DictUtil.get_string(d, "home_settlement_id")
	for k in DictUtil.get_dict(d, "factions").keys():
		u.factions[String(k)] = FactionState.from_dict(d["factions"][k])
	u.npc_states = DictUtil.get_dict(d, "npc_states").duplicate(true)
	u.companion_states = DictUtil.get_dict(d, "companion_states").duplicate(true)
	u.territory_state = DictUtil.get_dict(d, "territory_state").duplicate(true)
	u.threat_state = DictUtil.int_map(DictUtil.get_dict(d, "threat_state"))
	u.world_events = DictUtil.get_array(d, "world_events").duplicate(true)
	for k in DictUtil.get_dict(d, "expeditions").keys():
		u.expeditions[String(k)] = ExpeditionRecord.from_dict(d["expeditions"][k])
	u.expedition_history = DictUtil.string_array(DictUtil.get_array(d, "expedition_history"))
	u.active_expedition_id = DictUtil.get_string(d, "active_expedition_id")
	u.story_flags = DictUtil.get_dict(d, "story_flags").duplicate(true)
	u.decision_log = DictUtil.get_dict(d, "decision_log").duplicate(true)
	u.protagonist_condition = DictUtil.int_map(DictUtil.get_dict(d, "protagonist_condition"))
	u.death_count = DictUtil.get_int(d, "death_count")
	u.id_counters = DictUtil.int_map(DictUtil.get_dict(d, "id_counters"))
	u.rng_states = DictUtil.get_dict(d, "rng_states").duplicate(true)
	return u


func validate() -> Array[String]:
	var errors: Array[String] = []
	if universe_id == "":
		errors.append("universe_id is required")
	if generation_version < 1 or generation_version > CURRENT_GENERATION_VERSION:
		errors.append("unsupported generation_version %d" % generation_version)
	if current_day < 1:
		errors.append("current_day must be >= 1")
	if time_of_day_minutes < 0 or time_of_day_minutes >= MINUTES_PER_DAY:
		errors.append("time_of_day_minutes out of range: %d" % time_of_day_minutes)
	errors.append_array(MapLocation.validate(location))
	if home_settlement_id == "" or not settlements.has(home_settlement_id):
		errors.append("home_settlement_id does not reference a settlement")
	for k in settlements.keys():
		errors.append_array((settlements[k] as SettlementState).validate())
	for k in factions.keys():
		errors.append_array((factions[k] as FactionState).validate())
	for k in expeditions.keys():
		errors.append_array((expeditions[k] as ExpeditionRecord).validate())
	if active_expedition_id != "":
		if not expeditions.has(active_expedition_id):
			errors.append("active_expedition_id references unknown expedition")
		elif not (expeditions[active_expedition_id] as ExpeditionRecord).is_active():
			errors.append("active expedition is not in active status")
	if not discovered_landmark_ids.has(home_landmark_id()):
		errors.append("home landmark must be discovered")
	for name in RngRegistry.STREAM_NAMES:
		if not rng_states.has(name):
			errors.append("missing rng stream state: " + name)
	if int(threat_state.get("awareness", 0)) < 0 or int(threat_state.get("awareness", 0)) > 100:
		errors.append("threat awareness out of range")
	if int(protagonist_condition.get("health", 1)) < 0:
		errors.append("protagonist health must be >= 0")
	return errors


func home_landmark_id() -> String:
	var home := home_settlement()
	return home.landmark_id if home != null else ""
