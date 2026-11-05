class_name TestFixtures
extends RefCounted
## Builders shared by tests. They go through the same factories the game uses
## but never touch the Session autoload, so each test owns its own state.


static func new_save(seed_value: int = 12345, preset: String = "challenging", archetype_id: String = "village_hunter", mist: bool = true) -> SaveGame:
	var c := CharacterFactory.create("Tester", archetype_id, Content.get_def("archetypes", archetype_id), Content.table("ancestries"))
	assert(c.ok, c.error)
	var d := DifficultyRules.from_preset(preset, Content.table("difficulty"))
	assert(d.ok, d.error)
	var m := MultiverseState.new()
	var u := UniverseFactory.create(seed_value, d.value, {"mist_enabled": mist}, c.value, m, Content)
	assert(u.ok, u.error)
	var s := SaveGame.new()
	s.character = c.value
	s.universe = u.value
	s.multiverse = m
	# Legacy regression scenarios deliberately model a six-resident village.
	# Actual new games start alone; Stage 2 acceptance tests exercise that path.
	for i in 6:
		s.universe.home_settlement().add_resident("founder", 1)
	PopulationRules.ensure_names(s.universe.home_settlement(), PopulationRules.name_pool(Content), seed_value)
	return s


## Bundle of services bound to a save, mirroring what Session builds.
class Bound:
	var save: SaveGame
	var world: WorldGraph
	var rng: RngRegistry
	var expeditions: ExpeditionService
	var transitions: TransitionService


static func bind(s: SaveGame) -> Bound:
	var b := Bound.new()
	b.save = s
	b.world = WorldGraphGenerator.generate(s.universe.world_seed, s.universe.generation_version, Content.table("landmarks"), Content.table("biomes"), DictUtil.get_dict(Content.table("balance"), "world_map"))
	b.rng = RngRegistry.from_dict(s.universe.rng_states, s.universe.world_seed)
	b.expeditions = ExpeditionService.new(s, b.world, b.rng, Content)
	b.transitions = TransitionService.new(s, b.expeditions)
	return b


## Starts an expedition to the first available destination; returns the id.
static func start_any_expedition(b: Bound) -> String:
	var dests := b.expeditions.available_destinations()
	assert(not dests.is_empty())
	var routes := b.expeditions.plan_routes(dests[0])
	assert(not routes.is_empty())
	var r := b.expeditions.start(dests[0], routes[0])
	assert(r.ok, r.error)
	return r.value


## Serialize with rng state synced, exactly like Session.save_game does.
static func round_trip(b: Bound) -> SaveGame:
	b.save.universe.rng_states = b.rng.to_dict()
	var text := JSON.stringify(b.save.to_dict())
	var data = JSON.parse_string(text)
	var r := SaveValidator.build_and_validate(data)
	assert(r.ok, r.error)
	return r.value
