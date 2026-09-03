class_name TestDialogueEvents
extends GdUnitTestSuite


func _dialogue() -> DialogueData:
	var data := DialogueData.new()
	data.id = "d_test"
	data.nodes = [
		{"node": "start", "speaker": "y01", "text_ko": "안녕", "portrait": "y01", "next": "2", "option1_ko": "", "option1_next": "", "option2_ko": "", "option2_next": "", "effect": ""},
		{"node": "2", "speaker": "player", "text_ko": "", "portrait": "", "next": "", "option1_ko": "A", "option1_next": "a", "option2_ko": "B", "option2_next": "end", "effect": "affinity:+1"},
		{"node": "a", "speaker": "y01", "text_ko": "끝", "portrait": "y01", "next": "end", "option1_ko": "", "option1_next": "", "option2_ko": "", "option2_next": "", "effect": "item:record_piece:-1;flag:done;money:+50"},
	]
	return data


func test_parse_effects_and_options() -> void:
	var nodes := DialogueGraph.parse(_dialogue())
	assert_int(nodes.size()).is_equal(3)
	var option_node: DialogueGraph.DialogueNode = nodes["2"]
	assert_bool(option_node.has_options()).is_true()
	assert_int(option_node.options.size()).is_equal(2)
	assert_array(option_node.effects).contains_exactly([{"kind": "affinity", "target": "", "amount": 1}])
	var last: DialogueGraph.DialogueNode = nodes["a"]
	assert_array(last.effects).contains_exactly([
		{"kind": "item", "target": "record_piece", "amount": -1},
		{"kind": "flag", "target": "done", "amount": 1},
		{"kind": "money", "target": "", "amount": 50},
	])


func test_runner_walks_default_and_choice() -> void:
	var runner := DialogueGraph.Runner.new(DialogueGraph.parse(_dialogue()))
	var node := runner.start()
	assert_str(node.id).is_equal("start")
	node = runner.advance()
	assert_str(node.id).is_equal("2")
	assert_object(runner.advance()).is_same(node)  # 선택지 노드에서는 advance 무시
	node = runner.choose(0)
	assert_str(node.id).is_equal("a")
	assert_object(runner.advance()).is_null()
	assert_bool(runner.finished).is_true()

	var runner2 := DialogueGraph.Runner.new(DialogueGraph.parse(_dialogue()))
	runner2.start()
	runner2.advance()
	assert_object(runner2.choose(1)).is_null()
	assert_bool(runner2.finished).is_true()


func _event(id: String, phase: String, day_min: int, yokai: String = "", min_aff: int = 0, item: String = "", flag: String = "", priority: int = 0, once: bool = true, day_max: int = 0) -> EventData:
	var e := EventData.new()
	e.id = id
	e.timeband = phase
	e.day_min = day_min
	e.day_max = day_max
	e.yokai_id = yokai
	e.min_affinity = min_aff
	e.requires_item = item
	e.requires_flag = flag
	e.priority = priority
	e.once = once
	return e


func test_scheduler_conditions_and_priority() -> void:
	var events := {
		"tut": _event("tut", "morning", 1, "", 0, "", "", 100, true, 1),
		"a1": _event("a1", "night", 1, "y1", 0, "", "", 10),
		"a2": _event("a2", "night", 3, "y1", 1, "", "", 10),
		"b1": _event("b1", "night", 1, "y2", 0, "", "", 9),
		"k": _event("k", "night", 1, "y1", 0, "record_piece", "", 50),
		"f": _event("f", "any", 1, "", 0, "", "flag_x", 60),
	}
	var ctx := EventScheduler.Context.new()
	ctx.day = 1
	ctx.timeband = "night"
	ctx.residents = ["y1"]
	assert_str(EventScheduler.pick(events, ctx).id).is_equal("a1")  # y2 미입주, k 는 아이템 없음, f 는 플래그 없음
	ctx.seen = ["a1"]
	assert_object(EventScheduler.pick(events, ctx)).is_null()
	ctx.day = 3
	assert_object(EventScheduler.pick(events, ctx)).is_null()  # a2 는 호감도 1 필요
	ctx.affinity = {"y1": 1}
	assert_str(EventScheduler.pick(events, ctx).id).is_equal("a2")
	ctx.inventory.add("record_piece", 1)
	assert_str(EventScheduler.pick(events, ctx).id).is_equal("k")
	ctx.flags = {"flag_x": true}
	assert_str(EventScheduler.pick(events, ctx).id).is_equal("f")
	ctx.timeband = "morning"
	ctx.day = 2
	assert_str(EventScheduler.pick(events, ctx).id).is_equal("f")  # tut 은 day_max 1
	ctx.day = 1
	assert_str(EventScheduler.pick(events, ctx).id).is_equal("tut")
