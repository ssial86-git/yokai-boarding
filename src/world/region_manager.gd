class_name RegionManager
extends Node2D
## 구역 전환: 하숙집(HouseRegion, 상주)과 야외 구역(RegionView, regions.csv 로 그때그때 조립) 중 하나만 보이고,
## 플레이어는 이 노드의 자식으로 남아 구역 사이를 옮겨 다닌다. 문 통과 = travel().

const HOUSE_REGION_ID := HouseRegion.REGION_ID
const EXPEDITION_KIND := "expedition"
const REGION_KIND_MARKET := "market"
const REGION_KIND_VILLAGE := "village"
## 밤 변형을 여는 unlocks feature id 형식 (P2-S4). 가리키는 행이 없으면 늘 열림
const NIGHT_FEATURE_FORMAT := "night_%s"

var player: PlayerController
var house_region: HouseRegion
var farm_system: FarmSystem
var gather_system: GatherSystem
var unlock_system: UnlockSystem
var fishing_system: FishingSystem
var camera: HouseCamera
## (npc_id: String, shop_id: String) -> void. 상점 NPC 앞에서 E (P2-S3·P3-S2). main.gd 가 넣는다.
var merchant_action: Callable

var current_region_id: String = ""
var _outdoor: RegionView


func _ready() -> void:
	house_region.travel = travel
	Events.game_loaded.connect(func(_slot: int) -> void:
		travel(GameState.player_region, "", GameState.player_position))


func current_view() -> Node2D:
	return house_region if current_region_id == HOUSE_REGION_ID else _outdoor


func bounds() -> Rect2:
	if current_region_id == HOUSE_REGION_ID:
		return house_region.bounds()
	return _outdoor.bounds() if _outdoor != null else Rect2()


func is_region_open(region_id: String) -> bool:
	# 밤 변형("<base>@night")의 해금은 기본 구역을 따른다
	if unlock_system != null and not unlock_system.is_region_open(DataRegistry.base_region_id(region_id)):
		return false
	return is_region_open_now(region_id)


## 밤 변형 (P2-S4): 밤이고 변형이 있고(feature night_<base> 해금) 이면 "<base>@night", 아니면 기본 구역.
func resolve_variant(region_id: String) -> String:
	var base_id := DataRegistry.base_region_id(region_id)
	var base := DataRegistry.get_region(base_id)
	if base == null or not DataRegistry.has_night_variant(base) or Clock.band != Clock.Band.NIGHT:
		return base_id
	if unlock_system != null and not unlock_system.is_feature_open(NIGHT_FEATURE_FORMAT % base_id):
		return base_id
	return DataRegistry.night_variant_id(base_id)


## 시간·날씨 조건: 회색 시장(kind market)은 음기 짙은 날 또는 밤에만(P2-S3), 마을 상점가(kind village)는 밤에 닫힌다(P3-S2).
func is_region_open_now(region_id: String) -> bool:
	var region := DataRegistry.get_region(region_id)
	if region == null:
		return true
	if region.kind == REGION_KIND_MARKET:
		return MarketPrices.is_open(GameState.yin, DataRegistry.tuning.get_int("market_yin_threshold", 2), Clock.band == Clock.Band.NIGHT)
	if region.kind == REGION_KIND_VILLAGE:
		return Clock.band_name() != DataRegistry.tuning.get_string("village_closed_band", "night")
	return true


## region_id 로 이동. 잠겨 있으면 false. at 이 주어지면 그 발 위치에, 아니면 from 쪽 문 앞에 선다.
func travel(requested_region_id: String, from_region_id: String = "", at: Vector2 = Vector2(NAN, NAN)) -> bool:
	var region_id := resolve_variant(requested_region_id)
	var region := DataRegistry.get_region(region_id)
	if region == null:
		push_error("RegionManager: 구역 없음 %s" % region_id)
		return false
	if not is_region_open(region_id):
		Events.message_posted.emit(DataRegistry.text("msg_region_locked"))
		return false
	var origin := from_region_id if not from_region_id.is_empty() else current_region_id
	if _outdoor != null:
		_outdoor.queue_free()
		_outdoor = null
	# 숨길 때는 처리도 끈다 — 보이지 않아도 방 앞 상호작용 영역·벽 충돌체가 마당 좌표에 남아 있으면 안 된다
	if region_id == HOUSE_REGION_ID:
		house_region.visible = true
		house_region.process_mode = Node.PROCESS_MODE_INHERIT
	else:
		house_region.visible = false
		house_region.process_mode = Node.PROCESS_MODE_DISABLED
		_outdoor = RegionView.new()
		_outdoor.name = "Region_%s" % region_id
		_outdoor.is_region_open = is_region_open
		_outdoor.fishing_system = fishing_system
		_outdoor.merchant_action = merchant_action
		_outdoor.setup(region, func(target: String) -> void: travel(target), farm_system, gather_system)
		add_child(_outdoor)
		move_child(_outdoor, 0)  # 플레이어보다 뒤에 그린다
	current_region_id = region_id
	var spawn := at if not is_nan(at.x) else (
		house_region.spawn_position(origin) if region_id == HOUSE_REGION_ID else _outdoor.spawn_position(origin))
	player.place(spawn)
	GameState.set_player_location(region_id, spawn)
	if camera != null:
		camera.bounds = bounds().grow(float(DataRegistry.tuning.get_int("camera_bounds_margin_px")))
		camera.snap_to_follow()
	if region.kind == EXPEDITION_KIND and region.stamina_enter_cost > 0 and origin != region_id:
		GameState.stamina.spend(float(region.stamina_enter_cost))  # 탐험지 진입 비용 (docs/01 v3: 스태미너 예산)
	Events.region_entered.emit(region_id)
	Metrics.record("region_entered", {"region": region_id})
	if region_id.ends_with(DataRegistry.NIGHT_SUFFIX) and origin != region_id:
		Events.message_posted.emit(DataRegistry.text("msg_night_variant_entered", {"name": DataRegistry.get_region(DataRegistry.base_region_id(region_id)).name_ko}))
		Metrics.record("night_region_entered", {"region": region_id})
	if region.kind == EXPEDITION_KIND:
		Metrics.record("explore_enter", {"region": region_id})
	return true
