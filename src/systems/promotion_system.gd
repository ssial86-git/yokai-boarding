class_name PromotionSystem
extends Node
## 뜨내기 승격 (P2-S4): promotable 종족이 방문 누계·평판 조건을 채우면 아침에 "오늘 저녁 장기 계약을 청한다" 고 예고하고
## 플래그에 하숙생 id 를 남긴다. IntakeSystem 이 그날 저녁 심사 카드(kind promotion)로 내밀고, 받으면 yokai.csv 행(join_mode intake)이 입주한다.

const FEATURE_PROMOTION := "promotion"
## 오늘 저녁 장기 계약을 청하는 하숙생 id (플래그 값)
const FLAG_PENDING := "promotion_pending"

var unlock_system: UnlockSystem


func _ready() -> void:
	Events.day_started.connect(func(_day: int) -> void: offer_today())
	Events.game_loaded.connect(func(_slot: int) -> void: offer_today())


func is_open() -> bool:
	return unlock_system == null or unlock_system.is_feature_open(FEATURE_PROMOTION)


## 조건을 채운 종족이 있으면 하나만 예고한다 (id 순). 예고했으면 그 하숙생 id, 아니면 빈 문자열.
func offer_today() -> String:
	if not is_open() or GameState.flags.has(FLAG_PENDING):
		return ""
	var tuning := DataRegistry.tuning
	var candidates := ChapterRules.promotable_yokai(
		DataRegistry.guest_species, GameState.ledger, GameState.reputation, GameState.residents,
		tuning.get_int("promote_visits", 2), tuning.get_int("promote_reputation", 5))
	if candidates.is_empty():
		return ""
	var yokai_id := candidates[0]
	GameState.flags[FLAG_PENDING] = yokai_id
	var species := ChapterRules.species_for_yokai(DataRegistry.guest_species, yokai_id)
	Events.message_posted.emit(DataRegistry.text("msg_promotion_offer", {"name": species.name_ko if species != null else yokai_id}))
	Metrics.record("promotion_offered", {"yokai": yokai_id, "species": species.id if species != null else ""})
	Events.promotion_offered.emit(yokai_id)
	return yokai_id
