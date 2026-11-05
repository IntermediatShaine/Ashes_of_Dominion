extends MapSceneBase
## The walkable home village.
##
## Everything generic — ground, borders, props, the gate, spawning the player,
## the camera, interactions, remembering where the player stood — is
## MapSceneBase, the same foundation POIs will use. This scene adds the
## building sites and the village interface, and wires them to
## SettlementService:
##
##   state  -> views   `service.settlement_changed` => every site view and the
##                     HUD are refreshed from a fresh snapshot
##   player -> state   the HUD reports what was asked for; this controller
##                     calls the service (and autosaves); nothing here or in
##                     the HUD edits settlement values
##
## Interacting with the Village Hearth (or pressing V) opens Village
## Management; interacting with any other site opens its inspection card.

const HudScript := preload("res://scripts/interface/village_hud.gd")
const SiteViewScript := preload("res://scripts/gameplay/village/village_site_view.gd")

var service: SettlementService
var hud: CanvasLayer
## site id -> site view node
var site_views: Dictionary = {}


func _load_map_definition() -> MapDefinition:
	service = Session.settlement_service
	var layout := service.layout()
	if layout.is_empty():
		return null
	return MapDefinition.from_dict(layout)


func _build_content() -> void:
	for site_def in map_def.sites:
		var site_id := String(site_def["id"])
		var view := Node2D.new()
		view.set_script(SiteViewScript)
		view.setup(site_id, map_def.site_rect(site_def), map_def.site_anchor(site_def))
		view.interacted.connect(_on_site_interacted)
		entities.add_child(view)
		site_views[site_id] = view
		view.refresh(service.inspect_site(site_id))
	service.settlement_changed.connect(_on_settlement_changed)


func _build_hud() -> void:
	hud = CanvasLayer.new()
	hud.name = "VillageHud"
	hud.set_script(HudScript)
	add_child(hud)
	hud.improvement_requested.connect(func(site_id: String, action: String, definition_id: String): request_improvement(site_id, action, definition_id))
	hud.worker_change_requested.connect(func(target_id: String, delta: int): change_workers(target_id, delta))
	hud.job_cancel_requested.connect(func(job_id: String): cancel_job(job_id))
	hud.rest_requested.connect(rest_until_dawn)
	hud.craft_requested.connect(func(recipe_id: String):
		var result := service.craft(recipe_id)
		hud.toast(("Crafted." + _autosave_suffix()) if result.ok else result.error, 4.0))
	hud.save_requested.connect(save_game)
	hud.leave_requested.connect(leave_village)
	hud.settings_requested.connect(open_settings)
	hud.main_menu_requested.connect(quit_to_main_menu)
	_refresh_hud()


func _after_ready() -> void:
	if not Session.pending_expedition_summary.is_empty():
		var summary := Session.pending_expedition_summary
		Session.pending_expedition_summary = {}
		hud.show_message(ExpeditionSummary.title(summary), ExpeditionSummary.text(summary))
	elif not Session.last_messages.is_empty():
		hud.toast(" ".join(Session.last_messages), 5.0)
	Session.last_messages.clear()


func _exit_tree() -> void:
	super._exit_tree()
	if service != null and service.settlement_changed.is_connected(_on_settlement_changed):
		service.settlement_changed.disconnect(_on_settlement_changed)
	# A panel may have paused the tree; never leave it paused behind us.
	if is_inside_tree():
		get_tree().paused = false


func _dynamic_solid_rects() -> Array:
	var out: Array = []
	for site_def in map_def.sites:
		if SiteViewScript.is_solid_state(DictUtil.get_string(service.inspect_site(String(site_def["id"])), "state")):
			out.append(map_def.site_rect(site_def))
	return out


func _show_prompt(text: String) -> void:
	if hud != null:
		hud.set_prompt(text)


func _notify(text: String) -> void:
	if hud != null:
		hud.toast(text, 4.0)


# --- state -> views -----------------------------------------------------------------

func _on_settlement_changed(_reason: String) -> void:
	for site_id in site_views.keys():
		site_views[site_id].refresh(service.inspect_site(String(site_id)))
	_refresh_hud()


func _refresh_hud() -> void:
	if hud != null:
		hud.refresh(service.snapshot(), _protagonist_lines())


## Lines about the protagonist and the factions for the Overview tab. They are
## character / universe facts, not settlement state, so they are gathered here.
func _protagonist_lines() -> Array[String]:
	var c := Session.character()
	var u := Session.universe()
	var cbal := Content.balance("character")
	var lines: Array[String] = []
	var ancestry := DictUtil.get_string(Content.get_def("ancestries", c.primary_ancestry), "name")
	if c.is_mixed_ancestry():
		ancestry += " / " + DictUtil.get_string(Content.get_def("ancestries", c.secondary_ancestry), "name")
	lines.append("%s — %s, %s, level %d (XP %d / %d)" % [c.character_name, ancestry, DictUtil.get_string(Content.get_def("classes", c.current_class), "name"), c.level, c.experience, ProgressionRules.xp_for_next_level(c.level, Content.balance("progression"))])
	lines.append("Health %d / %d · Attack %d · Defense %d · Morality: %s (%d)" % [DictUtil.get_int(u.protagonist_condition, "health"), ProgressionRules.max_health(c, cbal), ProgressionRules.attack(c, cbal), ProgressionRules.defense(c, cbal), MoralityRules.label(c.morality), c.morality])
	var standings: Array[String] = []
	for fid in DictUtil.sorted_keys(u.factions):
		var faction: FactionState = u.factions[fid]
		standings.append("%s: %s (%d)" % [DictUtil.get_string(Content.get_def("factions", String(fid)), "name"), ReputationRules.label(faction.player_reputation), faction.player_reputation])
	lines.append("Standing — " + " · ".join(standings))
	return lines


# --- player -> state (all through the service) --------------------------------------

func _on_site_interacted(site_id: String) -> void:
	if DictUtil.get_string(map_def.site(site_id), "role") == "hearth":
		hud.open_management(HudScript.TAB_OVERVIEW)
	else:
		hud.open_inspect(site_id)


## Carries out an improvement offered at a site and autosaves on success.
func request_improvement(site_id: String, action: String, definition_id: String = "") -> OpResult:
	var r := service.request_improvement(site_id, action, definition_id)
	if not r.ok:
		hud.toast(r.error, 4.0)
		return r
	var value: Dictionary = r.value
	var what := DictUtil.get_string(service.inspect_site(site_id), "name")
	var text := ""
	if DictUtil.get_bool(value, "completed", false):
		text = {SettlementService.ACTION_BUILD: "%s built.", SettlementService.ACTION_UPGRADE: "%s improved.", SettlementService.ACTION_REPAIR: "%s repaired."}.get(action, "%s changed.") % what
	else:
		var days := DictUtil.get_int(DictUtil.get_dict(value, "job"), "work_required", 1)
		text = "Work has begun on the %s (%d day%s). Rest at the hearth or go on an expedition to let time pass." % [what, days, "" if days == 1 else "s"]
	hud.toast(text + _autosave_suffix(), 5.0)
	return r


func change_workers(target_id: String, delta: int) -> OpResult:
	var r := service.assign_idle_worker(target_id) if delta > 0 else service.unassign_one_worker(target_id)
	if not r.ok:
		hud.toast(r.error, 3.0)
	return r


func cancel_job(job_id: String) -> OpResult:
	var r := service.cancel_job(job_id)
	hud.toast(("Work abandoned; materials returned." + _autosave_suffix()) if r.ok else r.error, 4.0)
	return r


func rest_until_dawn() -> Dictionary:
	var out := service.rest_until_dawn()
	var notes: Array[String] = ["Dawn of day %d." % Session.universe().current_day]
	for day in DictUtil.get_array(out, "sim"):
		var mine := DictUtil.get_dict(DictUtil.get_dict(day, "settlements"), service.settlement_id)
		for job in DictUtil.get_array(mine, "jobs_completed"):
			notes.append("Work on the %s is finished." % DictUtil.get_string(Content.get_def("buildings", DictUtil.get_string(job, "definition_id")), "name"))
		if DictUtil.get_bool(mine, "starved", false):
			notes.append("Emberfall went hungry.")
	if DictUtil.get_int(out, "recruits") > 0:
		notes.append("%d newcomer(s) settled in." % DictUtil.get_int(out, "recruits"))
	hud.toast(" ".join(notes) + _autosave_suffix(), 5.0)
	return out


func save_game() -> OpResult:
	var r := Session.save_game()
	hud.toast(("Saved to slot %d." % Session.current_slot) if r.ok else ("Save failed: " + r.error), 3.0)
	return r


## Out through the gate to the world map (also bound to M).
func leave_village() -> void:
	for e in map_def.exits:
		if String(e["to"]) == "world_map":
			use_exit(String(e["id"]))
			return


func open_settings() -> void:
	# Come back to the same spot afterwards.
	Session.travel.remember_position(player.position)
	_leave_to("settings")


func quit_to_main_menu() -> void:
	_leaving = true
	Session.end_session()
	Router.go("main_menu")


func _autosave_suffix() -> String:
	var w := Session.save_game()
	return " Saved." if w.ok else " SAVE FAILED: " + w.error
