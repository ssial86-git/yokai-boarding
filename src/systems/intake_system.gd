class_name IntakeSystem
extends Node
## 저녁 심사 플로우 (docs/07 2절): 정산이 끝나면 방문자를 뽑아 GameState.pending_visitor 에 두고
## visitor_knocked 를 쏜다. 대화창이 열려 있으면 닫힐 때까지 미룬다. 결정은 decide() 로 받는다.

const ERASED_VISITOR_ID := "v_erased"
const JOINED_FLAG_FORMAT := "joined_%s"

## 대화 진행 중 여부를 묻는 콜백 (StorySystem.is_busy). main.gd 가 넣는다.
var is_dialogue_busy: Callable

var _knock_pending: bool = false


func _ready() -> void:
	Events.day_settled.connect(func(_summary: Dictionary) -> void: roll_visitor())
	Events.dialogue_finished.connect(func(_event_id: String) -> void: _try_knock())
	Events.game_loaded.connect(func(_slot: int) -> void:
		_knock_pending = not GameState.pending_visitor.is_empty()
		_try_knock())


func has_pending() -> bool:
	return not GameState.pending_visitor.is_empty()


func roll_visitor() -> void:
	var visitor := VisitorRoll.scripted(DataRegistry.yokai, GameState.residents, GameState.day, ERASED_VISITOR_ID)
	if visitor == null:
		# 음기 배율 (P2-S1): 날씨의 이승/마계 손님 배율 × 소절기 이벤트의 마계 배율
		var multipliers := WeatherRoll.guest_multipliers(
			DataRegistry.get_weather(GameState.weather),
			GameState.calendar.demon_guest_multiplier(DataRegistry.season_events))
		visitor = VisitorRoll.roll(
			DataRegistry.visitors, DataRegistry.guest_species, GameState.rng,
			DataRegistry.tuning.get_float("visitor_chance"), GameState.weather, multipliers,
		)
	if visitor == null:
		GameState.pending_visitor = {}
		Events.visitor_knocked.emit({})
		return
	GameState.pending_visitor = visitor.to_dict()
	_knock_pending = true
	_try_knock()


func free_beds() -> int:
	return Lodging.free_beds(GameState.room_grid, GameState.residents, GameState.guests)


func decide(decision: Intake.Decision) -> Intake.Outcome:
	if not has_pending():
		return Intake.Outcome.DECLINED
	var visitor := VisitorRoll.Visitor.from_dict(GameState.pending_visitor)
	var params := Intake.Params.from_tuning(DataRegistry.tuning)
	var result := Intake.decide(visitor, decision, free_beds(), GameState.day, params)
	if result.outcome == Intake.Outcome.NO_BED:
		Events.intake_decided.emit(GameState.pending_visitor, result.outcome)
		return result.outcome
	GameState.add_reputation(result.reputation_delta)
	if result.outcome == Intake.Outcome.ACCEPTED:
		if not result.joined_yokai_id.is_empty():
			# events.csv 의 requires_flag 로 도착 이벤트를 걸 수 있도록 joined_<yokai_id> 플래그를 남긴다
			GameState.flags[JOINED_FLAG_FORMAT % result.joined_yokai_id] = true
			GameState.add_resident(result.joined_yokai_id)
		else:
			GameState.guests.append(result.guest)
			var species_id := str(result.guest.get("species_id", ""))
			GameState.ledger[species_id] = int(GameState.ledger.get(species_id, 0)) + 1
			Events.ledger_changed.emit(species_id, int(GameState.ledger[species_id]))
			Events.guests_changed.emit()
	var visitor_dict := GameState.pending_visitor
	GameState.pending_visitor = {}
	_knock_pending = false
	Events.intake_decided.emit(visitor_dict, result.outcome)
	return result.outcome


func _try_knock() -> void:
	if not _knock_pending or not has_pending():
		return
	if is_dialogue_busy.is_valid() and is_dialogue_busy.call():
		return
	_knock_pending = false
	Events.visitor_knocked.emit(GameState.pending_visitor)
