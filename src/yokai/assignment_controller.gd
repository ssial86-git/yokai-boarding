class_name AssignmentController
extends Node
## 아침 배치 조작: 페이즈·입주 여부를 검사한 뒤 Assignment(GameState 소유)에 반영하고 Events 로 알린다.

## 앞 4개는 Assignment.Outcome 과 같은 순서·값이다.
enum Outcome { OK, NOT_BUILT, NOT_WORKPLACE, FULL, NOT_MORNING, UNKNOWN_YOKAI }


func can_assign(yokai_id: String, cell: Vector2i) -> Outcome:
	var gate := _gate(yokai_id)
	if gate != Outcome.OK:
		return gate
	return GameState.assignment.check(GameState.room_grid, cell, yokai_id) as Outcome


func try_assign(yokai_id: String, cell: Vector2i) -> Outcome:
	var outcome := _gate(yokai_id)
	if outcome == Outcome.OK:
		outcome = GameState.assignment.assign(GameState.room_grid, cell, yokai_id) as Outcome
	if outcome == Outcome.OK:
		Events.assignment_changed.emit(yokai_id, cell)
	else:
		Events.assignment_failed.emit(yokai_id, outcome)
	return outcome


func try_rest(yokai_id: String) -> Outcome:
	var outcome := _gate(yokai_id)
	if outcome == Outcome.OK:
		GameState.assignment.rest(yokai_id)
		Events.assignment_changed.emit(yokai_id, Assignment.REST)
	else:
		Events.assignment_failed.emit(yokai_id, outcome)
	return outcome


static func outcome_text_key(outcome: int) -> String:
	return "assign_outcome_%s" % (Outcome.keys()[outcome] as String).to_lower()


func _gate(yokai_id: String) -> Outcome:
	if not GameState.residents.has(yokai_id):
		return Outcome.UNKNOWN_YOKAI
	if Clock.phase != Clock.Phase.MORNING:
		return Outcome.NOT_MORNING
	return Outcome.OK
