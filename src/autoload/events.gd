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

# --- 플레이어·세계 (P1-S2) ---
## 플레이어가 다른 구역(regions.csv)에 들어섰다.
signal region_entered(region_id: String)
## 상호작용 안내 문구 ("E: 캐기"). 빈 문자열이면 숨김.
signal prompt_changed(text: String)
signal stamina_changed(value: float, max_value: float)
## 텃밭 칸 상태 변화. index 가 -1 이면 전체 (확장·하루 성장).
signal farm_changed(index: int)
signal gather_point_changed(region_id: String, index: int)
## 도구 갈래의 레벨이 올랐다.
signal tool_changed(kind: String, level: int)
## unlocks.csv 의 항목이 열렸다.
signal unlocked(unlock_id: String)

# --- 요리·제작·낚시 (P1-S3) ---
## 작업대(kitchen/workshop)의 작업이 시작·완료됐다.
signal station_changed(station_id: String)
signal fishing_started(region_id: String)
## item_id 가 비어 있으면 놓친 것.
signal fishing_ended(region_id: String, item_id: String)
## 배식으로 오늘 능력치가 올랐다 (amount 는 누적 후 값).
signal buff_applied(yokai_id: String, stat: String, amount: int)

# --- 절기·날씨 (P2-S1) ---
## 절기가 바뀌었다 (취침으로 마지막 날을 넘긴 순간).
signal season_changed(season_id: String)
## 아침 날씨·음기 추첨 결과. weather_changed 뒤에 온다.
signal weather_rolled(weather: String, yin: int)
## 소절기 이벤트(season_events.csv)가 오늘 시작했다.
signal season_event_started(event_id: String)

# --- 목표·명절 (P2-S2) ---
## 플레이어의 활동 하나가 끝났다. verb 는 "gather" / "farm.harvest" / "cook" 같은 카운터 키, detail 은 대상 id (없으면 빈 문자열).
signal activity_done(verb: String, detail: String, amount: int)
signal goal_completed(goal_id: String)
## 명절 당일 아침. decorated 는 장식 목표가 충족돼 집에 등이 걸리는지.
signal festival_started(festival_id: String, decorated: bool)
signal festival_scored(festival_id: String, score: int, max_score: int)

# --- 가호·회색 시장 (P2-S3) ---
## 하숙생이 아이템에 가호를 붙였다. item_id 는 가호가 붙은 합성 id.
signal blessing_granted(yokai_id: String, item_id: String)
## 회색 시장 거래. kind 는 "buy" / "sell".
signal market_traded(kind: String, item_id: String, count: int, money: int)

# --- 챕터·승격 (P2-S4) ---
signal chapter_changed(chapter_id: String)
## 뜨내기가 장기 계약을 청한다 (오늘 저녁 심사 카드로 온다).
signal promotion_offered(yokai_id: String)

# --- 세이브 ---
signal game_saved(slot: int)
signal game_loaded(slot: int)
