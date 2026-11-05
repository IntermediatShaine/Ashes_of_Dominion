class_name SiteRules
extends RefCounted
## Building sites of a village: which building may stand where, and what state
## a site is in. Pure functions over the static layout (one entry of
## data/village/village_layouts.json) and the SettlementState.
##
## A site never stores anything: "what stands here" is the building instance
## whose site_id names the site, "what is being built here" the construction
## job with that site_id.

const KIND_CORE := "core"
const KIND_PLOT := "plot"

## Nothing built on a reserved (core) site yet: shown as that building's ruin.
const STATE_RUIN := "ruin"
## A free plot.
const STATE_EMPTY := "empty"
## A build job is in progress on the site.
const STATE_CONSTRUCTION := "construction"
const STATE_STANDING := "standing"
## A building stands here but its condition is 0.
const STATE_DESTROYED := "destroyed"


static func sites(layout: Dictionary) -> Array:
	return DictUtil.get_array(layout, "sites")


static func site_ids(layout: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for site in sites(layout):
		if site is Dictionary:
			out.append(DictUtil.get_string(site, "id"))
	return out


static func site(layout: Dictionary, site_id: String) -> Dictionary:
	for candidate in sites(layout):
		if candidate is Dictionary and DictUtil.get_string(candidate, "id") == site_id:
			return candidate
	return {}


## Definition ids that may be built on a site, in sorted order.
static func allowed_definitions(layout: Dictionary, site_id: String, building_defs: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var site_def := site(layout, site_id)
	if site_def.is_empty():
		return out
	if DictUtil.get_string(site_def, "kind") == KIND_CORE:
		var reserved := DictUtil.get_string(site_def, "reserved_for")
		if building_defs.has(reserved):
			out.append(reserved)
		return out
	for id in DictUtil.sorted_keys(building_defs):
		if DictUtil.get_string(building_defs[id], "placement") != "reserved":
			out.append(String(id))
	return out


## Why a definition cannot be placed on a site; empty means it can.
static func placement_blocking_reasons(s: SettlementState, layout: Dictionary, site_id: String, definition_id: String, building_defs: Dictionary) -> Array[String]:
	var reasons: Array[String] = []
	if site(layout, site_id).is_empty():
		reasons.append("Unknown building site '%s'" % site_id)
		return reasons
	if not s.building_at_site(site_id).is_empty():
		reasons.append("The site is already built on")
	if not s.job_at_site(site_id).is_empty():
		reasons.append("Work is already under way here")
	if not allowed_definitions(layout, site_id, building_defs).has(definition_id):
		reasons.append("%s cannot be built on this site" % DictUtil.get_string(DictUtil.get_dict(building_defs, definition_id), "name", definition_id))
	return reasons


## The site a new building of `definition_id` goes to when the caller does not
## choose one: its reserved site if that is free, else the first free plot in
## layout order. "" when there is nowhere to put it.
static func find_site_for(s: SettlementState, layout: Dictionary, definition_id: String, building_defs: Dictionary) -> String:
	var fallback := ""
	for candidate in sites(layout):
		if not (candidate is Dictionary):
			continue
		var site_id := DictUtil.get_string(candidate, "id")
		if not placement_blocking_reasons(s, layout, site_id, definition_id, building_defs).is_empty():
			continue
		if DictUtil.get_string(candidate, "kind") == KIND_CORE:
			return site_id
		if fallback == "":
			fallback = site_id
	return fallback


static func state(s: SettlementState, layout: Dictionary, site_id: String) -> String:
	var instance := s.building_at_site(site_id)
	if not instance.is_empty():
		return STATE_STANDING if BuildingRules.is_functional(instance) else STATE_DESTROYED
	if not s.job_at_site(site_id).is_empty():
		return STATE_CONSTRUCTION
	return STATE_RUIN if DictUtil.get_string(site(layout, site_id), "kind") == KIND_CORE else STATE_EMPTY


## Gives every building without a site (saves from before the village existed,
## or instances created without a layout) a free site, deterministically in
## instance order. Buildings that do not fit stay unplaced: they keep working
## and are listed in the management view, they just have no spot in the village.
## Returns how many were placed.
static func place_unplaced(s: SettlementState, layout: Dictionary, building_defs: Dictionary) -> int:
	var placed := 0
	var known := site_ids(layout)
	for b in s.buildings:
		if not (b is Dictionary):
			continue
		var current := DictUtil.get_string(b, "site_id")
		if current != "" and known.has(current):
			continue
		b["site_id"] = ""
		var target := find_site_for(s, layout, DictUtil.get_string(b, "definition_id"), building_defs)
		if target != "":
			b["site_id"] = target
			placed += 1
	return placed
