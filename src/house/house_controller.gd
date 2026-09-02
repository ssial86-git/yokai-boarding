class_name HouseController
extends Node
## RoomGrid(GameState 소유) 조작 + 돈 차감·환불 + Events 발신.
## 규칙과 비용 계산은 RoomGrid 에 있고, 여기서는 돈이라는 외부 상태와 묶기만 한다.


func grid() -> RoomGrid:
	return GameState.room_grid


## 빈터면 설치, 다른 방이면 개조.
func try_place_room(coords: Vector2i, room_id: String) -> RoomGrid.Outcome:
	var g := grid()
	var cost := g.get_place_cost(room_id)
	var outcome := g.place_room(coords, room_id, GameState.money)
	if outcome == RoomGrid.Outcome.OK:
		GameState.add_money(-cost)
		Events.room_changed.emit(coords, room_id)
	else:
		Events.house_action_failed.emit(outcome)
	return outcome


func try_demolish(coords: Vector2i) -> RoomGrid.Outcome:
	var g := grid()
	var refund := g.get_demolish_refund(coords)
	var outcome := g.demolish_room(coords)
	if outcome == RoomGrid.Outcome.OK:
		GameState.add_money(refund)
		Events.room_changed.emit(coords, g.get_empty_room_id())
	else:
		Events.house_action_failed.emit(outcome)
	return outcome


func try_add_floor() -> RoomGrid.Outcome:
	var g := grid()
	var cost := g.get_next_floor_cost()
	var outcome := g.add_floor(GameState.money)
	if outcome == RoomGrid.Outcome.OK:
		GameState.add_money(-cost)
		Events.floor_added.emit(g.built_floors - 1)
	else:
		Events.house_action_failed.emit(outcome)
	return outcome
