class_name ExpeditionSummary
extends RefCounted
## Turns an expedition's resolution summary (ExpeditionService.resolve) into
## the lines shown when the protagonist is back home. Shared by the village
## and the older management screen so both tell the same story.


static func title(summary: Dictionary) -> String:
	return "Expedition %s" % String(summary.get("status", ""))


static func text(summary: Dictionary) -> String:
	var lines: Array[String] = []
	var delivered := DictUtil.get_dict(summary, "delivered")
	var lost := DictUtil.get_dict(summary, "lost")
	if delivered.is_empty() and lost.is_empty():
		lines.append("You brought nothing back.")
	for r in DictUtil.sorted_keys(delivered):
		if int(delivered[r]) > 0:
			lines.append("+%d %s" % [int(delivered[r]), String(r)])
	for r in DictUtil.sorted_keys(lost):
		if int(lost[r]) > 0:
			lines.append("%d %s lost (%s)" % [int(lost[r]), String(r), "no room in storage" if String(summary.get("status", "")) != "defeated" else "left where you fell"])
	lines.append("%d day%s passed." % [DictUtil.get_int(summary, "days_passed"), "" if DictUtil.get_int(summary, "days_passed") == 1 else "s"])
	if DictUtil.get_int(summary, "recruits") > 0:
		lines.append("%d newcomer(s) settled in Emberfall." % DictUtil.get_int(summary, "recruits"))
	var discovered := DictUtil.get_array(summary, "discovered")
	if not discovered.is_empty():
		var names: Array[String] = []
		for id in discovered:
			names.append(DictUtil.get_string(Content.get_def("landmarks", String(id)), "name", String(id)))
		lines.append("New places on the map: " + ", ".join(names))
	for day in DictUtil.get_array(summary, "sim"):
		for sid in DictUtil.get_dict(day, "settlements").keys():
			var settlement_day: Dictionary = day["settlements"][sid]
			if DictUtil.get_bool(settlement_day, "starved", false):
				lines.append("Day %d: Emberfall went hungry." % DictUtil.get_int(day, "day"))
			for job in DictUtil.get_array(settlement_day, "jobs_completed"):
				lines.append("Day %d: work on the %s was finished." % [DictUtil.get_int(day, "day"), DictUtil.get_string(Content.get_def("buildings", DictUtil.get_string(job, "definition_id")), "name", "building")])
	return "\n".join(lines)
