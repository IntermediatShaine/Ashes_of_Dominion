class_name UniverseFactory
extends RefCounted
## Creates a fresh UniverseState for a character. Everything universe-bound
## (settlement, factions, discovery, rng streams, protagonist condition) is
## initialised here and nowhere else, so universe replacement has a single
## well-defined entry point.

const HOME_LANDMARK_ID := "emberfall"
const HOME_SETTLEMENT_ID := "stl_emberfall"


## content: the Content autoload (or any object exposing table()/balance()).
static func create(world_seed: int, difficulty: Dictionary, world_settings: Dictionary, character: CharacterState, multiverse: MultiverseState, content) -> OpResult:
	var landmarks: Dictionary = content.table("landmarks")
	if not landmarks.has(HOME_LANDMARK_ID):
		return OpResult.failure("Landmark data has no home landmark '%s'" % HOME_LANDMARK_ID)
	var u := UniverseState.new()
	multiverse.universe_counter += 1
	u.universe_id = IdFactory.universe_id(multiverse.universe_counter, world_seed)
	u.world_seed = world_seed
	u.generation_version = UniverseState.CURRENT_GENERATION_VERSION
	u.difficulty = difficulty.duplicate(true)
	u.world_settings = world_settings.duplicate(true)
	u.current_day = 1
	u.time_of_day_minutes = clampi(DictUtil.get_int(content.balance("time"), "start_minute", UniverseState.DEFAULT_START_MINUTE), 0, UniverseState.MINUTES_PER_DAY - 1)
	u.rng_states = RngRegistry.create_fresh(world_seed).to_dict()

	# discovery: starting knowledge only
	for id in DictUtil.sorted_keys(landmarks):
		if DictUtil.get_bool(landmarks[id], "known_at_start", false):
			u.discover_landmark(String(id))

	# home settlement
	var s := SettlementState.new()
	s.settlement_id = HOME_SETTLEMENT_ID
	s.display_name = DictUtil.get_string(landmarks[HOME_LANDMARK_ID], "name", "Emberfall")
	s.landmark_id = HOME_LANDMARK_ID
	var start := DictUtil.get_dict(content.table("balance"), "starting_settlement")
	# The founders are residents from day one; names come from the content pool,
	# picked by seed (no runtime rng stream is touched).
	for i in DictUtil.get_int(start, "population", 6):
		s.add_resident("founder", u.current_day)
	PopulationRules.ensure_names(s, PopulationRules.name_pool(content), world_seed)
	s.base_population_capacity = DictUtil.get_int(start, "population_capacity", 6)
	s.base_storage_capacity = DictUtil.get_int(start, "storage_capacity", 40)
	s.loyalty = DictUtil.get_int(start, "loyalty", 50)
	s.morale = DictUtil.get_int(start, "morale", 40)
	s.productivity = DictUtil.get_int(start, "productivity", 50)
	s.freedom = DictUtil.get_int(start, "freedom", 60)
	s.discipline = DictUtil.get_int(start, "discipline", 30)
	s.military_strength = DictUtil.get_int(start, "military_strength", 0)
	s.resources = DictUtil.int_map(DictUtil.get_dict(start, "resources"))
	for rid in content.ids("resources"):
		if not s.resources.has(rid):
			s.resources[rid] = 0
	u.settlements[s.settlement_id] = s
	u.home_settlement_id = s.settlement_id

	# the protagonist starts in the home village
	var maps: Dictionary = content.table("maps")
	var home_map := MapRegistry.map_for_settlement(maps, s.settlement_id)
	if home_map == "":
		return OpResult.failure("Map data has no village map for settlement '%s'" % s.settlement_id)
	u.location = MapLocation.make(home_map, MapRegistry.entry_for(maps, home_map))

	# factions
	var faction_defs: Dictionary = content.table("factions")
	for fid in DictUtil.sorted_keys(faction_defs):
		var fd: Dictionary = faction_defs[fid]
		var f := FactionState.new()
		f.faction_id = String(fid)
		f.player_reputation = ReputationRules.initial_reputation(character, fd)
		f.relations = DictUtil.int_map(DictUtil.get_dict(fd, "relations"))
		f.territory = DictUtil.string_array(DictUtil.get_array(fd, "territory"))
		f.aggression = DictUtil.get_float(fd, "aggression", 0.5)
		u.factions[f.faction_id] = f
		for t in f.territory:
			u.territory_state[t] = f.faction_id

	# threat / protagonist
	u.threat_state = ThreatRules.init_state(DictUtil.get_int(difficulty, "grace_period_expeditions", 5))
	u.protagonist_condition = {"health": ProgressionRules.max_health(character, content.balance("character")), "tools": [], "equipment": "", "equipment_attack": 0}
	var errors := u.validate()
	if not errors.is_empty():
		return OpResult.failure("Universe invalid: " + "; ".join(errors))
	return OpResult.success(u)
