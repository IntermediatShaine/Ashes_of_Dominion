class_name VillageVisuals
extends RefCounted
## The only place that decides which visual id a village object shows.
##
## It maps *state* (what SettlementService.inspect_site reports) to *ids*; the
## visual registry maps ids to images. Neither side knows a file name, and no
## gameplay rule reads anything from here.
##
##   building.<definition>.level_<n>   a standing building, n >= 1
##   building.<definition>.level_0     its ruin (not rebuilt yet, or destroyed)
##   site.plot.empty                   a free building plot
##   site.construction                 scaffolding over a site being built on
##   marker.work_in_progress           badge over a building being upgraded or repaired
##   icon.resource.<resource>          resource icons in the interface
##   icon.population

const PLOT_EMPTY := "site.plot.empty"
const CONSTRUCTION := "site.construction"
const WORK_BADGE := "marker.work_in_progress"
const ICON_POPULATION := "icon.population"


static func building(definition_id: String, level: int) -> String:
	return "building.%s.level_%d" % [definition_id, maxi(0, level)]


static func resource_icon(resource_id: String) -> String:
	return "icon.resource." + resource_id


## Main visual of a site, from its inspection.
static func site_visual(inspection: Dictionary) -> String:
	var definition_id := DictUtil.get_string(inspection, "definition_id")
	match DictUtil.get_string(inspection, "state"):
		SiteRules.STATE_STANDING:
			return building(definition_id, DictUtil.get_int(inspection, "level", 1))
		SiteRules.STATE_DESTROYED:
			return building(definition_id, 0)
		SiteRules.STATE_RUIN:
			return building(definition_id, 0)
		SiteRules.STATE_CONSTRUCTION:
			# A reserved site keeps showing its ruin under the scaffolding.
			return building(definition_id, 0) if DictUtil.get_string(inspection, "kind") == SiteRules.KIND_CORE else PLOT_EMPTY
	return PLOT_EMPTY


## Visual drawn over the main one while work is under way ("" = none).
static func site_overlay(inspection: Dictionary) -> String:
	var job := DictUtil.get_dict(inspection, "job")
	if job.is_empty():
		return ""
	return CONSTRUCTION if DictUtil.get_string(job, "kind") == SettlementState.JOB_BUILD else WORK_BADGE


## Every visual id the village can ask for, given the content tables — used by
## tests to prove the registry covers them and by docs/ART_SWAP_GUIDE.md.
static func required_ids(building_defs: Dictionary, layout: Dictionary, resources: Dictionary) -> Array[String]:
	var out: Array[String] = [PLOT_EMPTY, CONSTRUCTION, WORK_BADGE, ICON_POPULATION]
	var reserved := {}
	for site in DictUtil.get_array(layout, "sites"):
		if site is Dictionary and DictUtil.get_string(site, "reserved_for") != "":
			reserved[DictUtil.get_string(site, "reserved_for")] = true
	for id in DictUtil.sorted_keys(building_defs):
		# Only buildings with a reserved site are ever shown as a ruin.
		if reserved.has(id):
			out.append(building(String(id), 0))
		for level in range(1, BuildingRules.max_level(building_defs[id]) + 1):
			out.append(building(String(id), level))
	for id in DictUtil.sorted_keys(resources):
		out.append(resource_icon(String(id)))
	var ground := DictUtil.get_dict(layout, "ground")
	out.append(DictUtil.get_string(ground, "base"))
	for patch in DictUtil.get_array(ground, "patches"):
		out.append(DictUtil.get_string(patch, "visual"))
	for prop in DictUtil.get_array(layout, "props"):
		out.append(DictUtil.get_string(prop, "visual"))
	for exit_def in DictUtil.get_array(layout, "exits"):
		if DictUtil.get_string(exit_def, "visual") != "":
			out.append(DictUtil.get_string(exit_def, "visual"))
	if DictUtil.get_string(DictUtil.get_dict(layout, "border"), "visual") != "":
		out.append(DictUtil.get_string(DictUtil.get_dict(layout, "border"), "visual"))
	var unique: Array[String] = []
	for id in out:
		if id != "" and not unique.has(id):
			unique.append(id)
	return unique
