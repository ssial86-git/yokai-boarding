extends Node
## 전역 이벤트 버스. 시스템 간 통신은 이 시그널로만 한다 (CLAUDE.md 5.4).
## autoload 이름(Events)과 class_name 이 겹치면 Godot 이 충돌 경고를 내므로 class_name 을 붙이지 않는다.

# --- 게임 흐름 ---
signal game_started
signal day_started(day: int)
signal day_ended(day: int)
## band 는 Clock.Band 값. 시간대는 조명·이벤트 트리거일 뿐이고 하루를 끝내는 것은 취침(slept → day_ended)뿐이다.
signal timeband_changed(band: int, day: int)
## 취침. forced 는 시계가 다 흘러 자동으로 잠든 경우.
signal slept(day: int, forced: bool)

# --- 하숙집 구조 (M1) ---
signal room_changed(coords: Vector2i, room_id: String)
signal floor_added(floor_index: int)
## outcome 은 RoomGrid.Outcome 값.
signal house_action_failed(outcome: int)

# --- 요괴 (M2) ---
signal yokai_arrived(yokai_id: String)
## cell 이 Assignment.REST 면 휴식.
signal assignment_changed(yokai_id: String, cell: Vector2i)
## outcome 은 AssignmentController.Outcome 값.
signal assignment_failed(yokai_id: String, outcome: int)
signal condition_changed(yokai_id: String, value: int)
signal affinity_changed(yokai_id: String, value: int)
## 저녁 정산 결과 요약: {"day": int, "totals": {item_id: amount}, "noise_hits": {yokai_id: level}}
signal day_settled(summary: Dictionary)

# --- 경제 (M2~M3) ---
signal item_added(item_id: String, count: int)
signal item_removed(item_id: String, count: int)
signal money_changed(amount: int)

# --- 심사·서사 (M3) ---
## visitor 는 VisitorRoll.Visitor.to_dict() 형식.
signal visitor_knocked(visitor: Dictionary)
## outcome 은 Intake.Outcome 값.
signal intake_decided(visitor: Dictionary, outcome: int)
signal guests_changed
signal ledger_changed(species_id: String, count: int)
signal reputation_changed(value: int)
signal weather_changed(weather: String)
## rent 는 {"money": int, "items": {id: n}, "condition_bonus": int, "mishap_money": int, "mishap_texts": [String], "departed": [Dictionary]}
signal rent_settled(rent: Dictionary)
signal dialogue_started(event_id: String)
## 대사 노드가 화면에 나올 때마다 (효과음·연출용)
signal dialogue_node_shown(event_id: String, speaker: String)
signal dialogue_finished(event_id: String)
## 성주 영감 안내 문구. 빈 문자열이면 안내 없음.
signal hint_changed(text: String)
## HUD 메시지 로그 한 줄. 시스템들이 사람용 문장을 보낼 때 쓴다.
signal message_posted(text: String)
signal quest_completed(quest_id: String)

# --- 세이브 ---
signal game_saved(slot: int)
signal game_loaded(slot: int)
