extends Node
## 전역 이벤트 버스. 시스템 간 통신은 이 시그널로만 한다 (CLAUDE.md 5.4).
## autoload 이름(Events)과 class_name 이 겹치면 Godot 이 충돌 경고를 내므로 class_name 을 붙이지 않는다.

# --- 게임 흐름 ---
signal game_started
signal day_started(day: int)
signal day_ended(day: int)
## phase 는 Clock.Phase 값.
signal phase_changed(phase: int, day: int)

# --- 하숙집 구조 (M1) ---
signal room_changed(coords: Vector2i, room_id: String)
signal floor_added(floor_index: int)
## outcome 은 RoomGrid.Outcome 값.
signal house_action_failed(outcome: int)

# --- 요괴 (M2) ---
signal yokai_arrived(yokai_id: String)
signal yokai_assigned(yokai_id: String, coords: Vector2i)
signal affinity_changed(yokai_id: String, value: int)

# --- 경제 (M2~M3) ---
signal item_added(item_id: String, count: int)
signal item_removed(item_id: String, count: int)
signal money_changed(amount: int)

# --- 심사·서사 (M3) ---
signal visitor_knocked(visitor_id: String)
signal intake_decided(visitor_id: String, decision: String)
signal quest_completed(quest_id: String)

# --- 세이브 ---
signal game_saved(slot: int)
signal game_loaded(slot: int)
