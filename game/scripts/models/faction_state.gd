class_name FactionState
extends RefCounted
## Runtime state of one faction inside a universe. Static identity (name,
## type, attitudes) lives in data/factions.json; this holds what changes.

var faction_id: String = ""
## -100 (hated) .. +100 (revered). Independent of character morality.
var player_reputation: int = 0
## faction_id -> -100..100
var relations: Dictionary = {}
var territory: Array[String] = []
var aggression: float = 0.5
var flags: Dictionary = {}
## Append-only log: {id, kind, delta, day}
var reputation_log: Array = []


func to_dict() -> Dictionary:
	return {
		"faction_id": faction_id,
		"player_reputation": player_reputation,
		"relations": relations.duplicate(),
		"territory": territory.duplicate(),
		"aggression": aggression,
		"flags": flags.duplicate(true),
		"reputation_log": reputation_log.duplicate(true),
	}


static func from_dict(d: Dictionary) -> FactionState:
	var f := FactionState.new()
	f.faction_id = DictUtil.get_string(d, "faction_id")
	f.player_reputation = DictUtil.get_int(d, "player_reputation")
	f.relations = DictUtil.int_map(DictUtil.get_dict(d, "relations"))
	f.territory = DictUtil.string_array(DictUtil.get_array(d, "territory"))
	f.aggression = DictUtil.get_float(d, "aggression", 0.5)
	f.flags = DictUtil.get_dict(d, "flags").duplicate(true)
	f.reputation_log = DictUtil.get_array(d, "reputation_log").duplicate(true)
	return f


func validate() -> Array[String]:
	var errors: Array[String] = []
	if faction_id == "":
		errors.append("faction_id is required")
	if player_reputation < -100 or player_reputation > 100:
		errors.append("faction %s reputation out of range" % faction_id)
	if aggression < 0.0 or aggression > 1.0:
		errors.append("faction %s aggression out of range" % faction_id)
	return errors
