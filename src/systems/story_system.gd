class_name StorySystem
extends Node
## 사연·튜토리얼 이벤트 진행: 페이즈가 바뀌거나 상태가 바뀌면 EventScheduler 로 이벤트를 골라
## DialogueGraph.Runner 를 돌리고, 노드에 들어갈 때 효과를 적용한다. 표시는 DialogueBox 가 한다.

signal node_entered(node: DialogueGraph.DialogueNode, event: EventData)
signal ended(event: EventData)

var current_event: EventData
var _runner: DialogueGraph.Runner


func _ready() -> void:
	Events.phase_changed.connect(func(phase: int, _day: int) -> void: try_show(phase))
	Events.intake_decided.connect(func(_visitor: Dictionary, _outcome: int) -> void: try_show(Clock.phase))
	Events.yokai_arrived.connect(func(_id: String) -> void: try_show(Clock.phase))


func is_busy() -> bool:
	return current_event != null


func current_node() -> DialogueGraph.DialogueNode:
	return _runner.current if _runner != null else null


## 지금 조건에 맞는 이벤트가 있으면 시작. 이미 대화 중이면 무시.
func try_show(phase: int) -> bool:
	if is_busy():
		return false
	var event := EventScheduler.pick(DataRegistry.events, build_context(phase))
	if event == null:
		return false
	start_event(event)
	return true


func build_context(phase: int) -> EventScheduler.Context:
	var ctx := EventScheduler.Context.new()
	ctx.day = GameState.day
	ctx.phase_name = (Clock.Phase.keys()[phase] as String).to_lower()
	ctx.residents = GameState.residents
	ctx.affinity = GameState.affinity
	ctx.flags = GameState.flags
	ctx.seen = GameState.seen_events
	ctx.inventory = GameState.inventory
	return ctx


func start_event(event: EventData) -> void:
	var dialogue := DataRegistry.get_dialogue(event.dialogue_id)
	if dialogue == null:
		push_error("StorySystem: 대화 없음 %s" % event.dialogue_id)
		return
	current_event = event
	_runner = DialogueGraph.Runner.new(DialogueGraph.parse(dialogue))
	Events.dialogue_started.emit(event.id)
	_enter(_runner.start())


func advance() -> void:
	if _runner == null:
		return
	_enter(_runner.advance())


func choose(index: int) -> void:
	if _runner == null:
		return
	_enter(_runner.choose(index))


func _enter(node: DialogueGraph.DialogueNode) -> void:
	if node == null:
		_finish()
		return
	for effect in node.effects:
		_apply_effect(effect)
	node_entered.emit(node, current_event)
	Events.dialogue_node_shown.emit(current_event.id, node.speaker)


func _finish() -> void:
	var event := current_event
	if event.once and not GameState.seen_events.has(event.id):
		GameState.seen_events.append(event.id)
	var bonus := DataRegistry.tuning.get_int("story_affinity_per_event")
	if bonus != 0 and not event.yokai_id.is_empty():
		GameState.add_affinity(event.yokai_id, bonus)
	current_event = null
	_runner = null
	ended.emit(event)
	Events.dialogue_finished.emit(event.id)
	# 튜토리얼은 안내일 뿐이므로 같은 페이즈의 사연(story)이 뒤이어 나온다. 사연끼리는 하루 하나만.
	if event.kind == "tutorial":
		try_show(Clock.phase)


func _apply_effect(effect: Dictionary) -> void:
	var amount := int(effect.get("amount", 0))
	var target := str(effect.get("target", ""))
	match str(effect.get("kind", "")):
		"affinity":
			var yokai_id := target if not target.is_empty() else current_event.yokai_id
			if not yokai_id.is_empty():
				GameState.add_affinity(yokai_id, amount)
		"money":
			GameState.add_money(amount)
		"item":
			if amount > 0:
				GameState.inventory.add(target, amount)
				Events.item_added.emit(target, amount)
			elif amount < 0 and GameState.inventory.remove(target, -amount):
				Events.item_removed.emit(target, -amount)
		"flag":
			GameState.flags[target] = true
