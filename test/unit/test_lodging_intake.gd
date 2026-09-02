class_name TestLodgingIntake
extends GdUnitTestSuite


func _room(id: String, kind: String, capacity: int) -> RoomData:
	var room := RoomData.new()
	room.id = id
	room.kind = kind
	room.capacity = capacity
	return room


func _grid() -> RoomGrid:
	var catalog := {
		"empty_lot": _room("empty_lot", "empty", 0),
		"guest_room": _room("guest_room", "lodging", 2),
		"gate": _room("gate", "gate", 1),
	}
	var grid := RoomGrid.new(catalog, 3, 4)
	grid.configure_costs(0, 1.0, 0.0)
	grid.apply_layout(0, ["gate", "guest_room", "empty_lot", "empty_lot"])
	return grid


func _params() -> Intake.Params:
	var p := Intake.Params.new()
	p.stay_nights = 1
	p.accept_reputation_gain = 1
	p.decline_reputation_penalty = 1
	p.decline_omen_threshold = 2
	return p


func _guest_visitor(omen: int) -> VisitorRoll.Visitor:
	var v := VisitorRoll.Visitor.new()
	v.visitor_id = "v_guest"
	v.kind = "guest"
	v.species_id = "g_ibulnang"
	v.omen = omen
	return v


func test_beds_count_lodging_capacity() -> void:
	var grid := _grid()
	var residents: Array[String] = ["a", "b"]
	assert_int(Lodging.total_beds(grid)).is_equal(2)
	assert_int(Lodging.free_beds(grid, residents, [])).is_equal(0)
	grid.place_room(Vector2i(2, 0), "guest_room", 0)
	assert_int(Lodging.free_beds(grid, residents, [{}])).is_equal(1)


func test_accept_guest_creates_stay_record() -> void:
	var result := Intake.decide(_guest_visitor(0), Intake.Decision.ACCEPT, 1, 3, _params())
	assert_int(result.outcome).is_equal(Intake.Outcome.ACCEPTED)
	assert_int(result.reputation_delta).is_equal(1)
	assert_dict(result.guest).contains_key_value("species_id", "g_ibulnang")
	assert_int(result.guest["depart_day"]).is_equal(4)
	assert_str(result.joined_yokai_id).is_empty()


func test_accept_without_bed_is_refused() -> void:
	var result := Intake.decide(_guest_visitor(0), Intake.Decision.ACCEPT, 0, 3, _params())
	assert_int(result.outcome).is_equal(Intake.Outcome.NO_BED)
	assert_int(result.reputation_delta).is_equal(0)


func test_decline_penalty_only_for_low_omen() -> void:
	assert_int(Intake.decide(_guest_visitor(0), Intake.Decision.DECLINE, 1, 1, _params()).reputation_delta).is_equal(-1)
	assert_int(Intake.decide(_guest_visitor(3), Intake.Decision.DECLINE, 1, 1, _params()).reputation_delta).is_equal(0)


func test_erased_visitor_joins_as_resident() -> void:
	var v := VisitorRoll.Visitor.new()
	v.kind = "erased"
	v.yokai_id = "y03_dalgael"
	var result := Intake.decide(v, Intake.Decision.ACCEPT, 1, 2, _params())
	assert_int(result.outcome).is_equal(Intake.Outcome.ACCEPTED)
	assert_str(result.joined_yokai_id).is_equal("y03_dalgael")
	assert_dict(result.guest).is_empty()
	var round_trip := VisitorRoll.Visitor.from_dict(v.to_dict())
	assert_str(round_trip.yokai_id).is_equal("y03_dalgael")
	assert_str(round_trip.kind).is_equal("erased")
