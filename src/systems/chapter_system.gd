class_name ChapterSystem
extends Node
## chapters.csv 의 런타임 측 (P2-S4 챕터 1): 목표가 완료될 때마다 현재 챕터의 게이트(병렬 목표 중 n개)를 보고
## 다음 챕터로 넘기며 flag chapter_<id> 를 남긴다 — 챕터 서사 이벤트(events.csv requires_flag)가 그 플래그로 열린다. 순수 판정은 ChapterRules.

const FLAG_FORMAT := "chapter_%s"


func _ready() -> void:
	Events.goal_completed.connect(func(_id: String) -> void: evaluate())
	Events.day_started.connect(func(_day: int) -> void: evaluate())
	Events.game_loaded.connect(func(_slot: int) -> void: evaluate())


func current() -> ChapterData:
	return GameState.current_chapter()


func gate_progress(chapter: ChapterData) -> Vector2i:
	return ChapterRules.gate_progress(chapter, GameState.goals_done) if chapter != null else Vector2i.ZERO


## 게이트가 찼으면 다음 챕터로. 넘어갔으면 true. 여러 챕터를 한 번에 넘을 수 있다.
func evaluate() -> bool:
	var advanced := false
	var chapter := current()
	while ChapterRules.gate_met(chapter, GameState.goals_done):
		var next := DataRegistry.get_chapter(chapter.next_id)
		if next == null:
			break
		GameState.chapter_id = next.id
		GameState.flags[FLAG_FORMAT % next.id] = true
		Events.message_posted.emit(DataRegistry.text("msg_chapter_advanced", {"order": next.order, "name": next.name_ko}))
		Metrics.record("chapter_advanced", {"chapter": next.id})
		Events.chapter_changed.emit(next.id)
		advanced = true
		chapter = next
	return advanced
