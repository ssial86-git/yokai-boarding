class_name HudText
extends RefCounted
## 시스템 이벤트를 사람용 문장으로 바꾸는 순수 도우미. 문구는 전부 strings_ko.csv.


static func item_list(items: Dictionary) -> String:
	var parts: Array[String] = []
	for item_id: String in items:
		parts.append(DataRegistry.text("hud_inventory_item",
			{"name": DataRegistry.item_name(item_id), "count": items[item_id]}))
	return ", ".join(parts)


static func assignment(yokai_id: String, cell: Vector2i) -> String:
	var yokai_name := DataRegistry.yokai_name(yokai_id)
	if cell == Assignment.REST:
		return DataRegistry.text("msg_rested", {"name": yokai_name})
	if cell == Assignment.FIELD:
		return DataRegistry.text("msg_assigned_field", {"name": yokai_name})
	if cell == Assignment.PARTY:
		return DataRegistry.text("msg_assigned_party", {"name": yokai_name})
	var room_name := DataRegistry.room_name(GameState.room_grid.get_room_id(cell))
	return DataRegistry.text("msg_assigned", {"name": yokai_name, "room": room_name})


static func room_changed(room_id: String) -> String:
	var room := DataRegistry.get_room(room_id)
	if room == null or room.kind == RoomGrid.ROOM_KIND_EMPTY:
		return DataRegistry.text("msg_demolished")
	return DataRegistry.text("msg_built", {"name": room.name_ko})


static func settlement(summary: Dictionary) -> String:
	var day: int = summary.get("day", GameState.day)
	var totals: Dictionary = summary.get("totals", {})
	var lines: Array[String] = []
	if totals.is_empty():
		lines.append(DataRegistry.text("msg_settled_none", {"day": day}))
	else:
		lines.append(DataRegistry.text("msg_settled", {"day": day, "summary": item_list(totals)}))
	for yokai_id: String in summary.get("noise_hits", {}):
		lines.append(DataRegistry.text("msg_noise_hit", {"name": DataRegistry.yokai_name(yokai_id)}))
	lines.append_array(rent_lines(summary.get("rent", {})))
	return "\n".join(lines)


static func rent_lines(rent: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	var parts: Array[String] = []
	var money: int = rent.get("money", 0)
	if money > 0:
		parts.append(DataRegistry.text("msg_rent_money", {"amount": money}))
	for item_id: String in rent.get("items", {}):
		parts.append(DataRegistry.text("msg_rent_item",
			{"item": DataRegistry.item_name(item_id), "amount": rent["items"][item_id]}))
	var bonus: int = rent.get("condition_bonus", 0)
	if bonus > 0:
		parts.append(DataRegistry.text("msg_rent_buff", {"amount": bonus}))
	if not parts.is_empty():
		lines.append(DataRegistry.text("msg_rent_summary", {"list": ", ".join(parts)}))
	for text: Variant in rent.get("dish_texts", []):
		lines.append(str(text))
	for guest: Dictionary in rent.get("departed", []):
		var species_id := str(guest.get("species_id", ""))
		var species := DataRegistry.get_guest_species(species_id)
		lines.append(DataRegistry.text("msg_guest_checkout", {
			"name": DataRegistry.species_name(species_id),
			"rent": species.rent_note_ko if species != null else DataRegistry.text("msg_rent_none"),
		}))
	for mishap: String in rent.get("mishap_texts", []):
		lines.append(mishap)
	return lines


static func intake(visitor: Dictionary, outcome: int) -> String:
	var name := DataRegistry.species_name(str(visitor.get("species_id", "")))
	if str(visitor.get("kind", "")) == "erased":
		name = DataRegistry.yokai_name(str(visitor.get("yokai_id", "")))
	match outcome:
		Intake.Outcome.ACCEPTED:
			return DataRegistry.text("msg_intake_accepted", {"name": name})
		Intake.Outcome.DECLINED:
			return DataRegistry.text("msg_intake_declined", {"name": name})
		_:
			return DataRegistry.text("msg_intake_no_bed")
