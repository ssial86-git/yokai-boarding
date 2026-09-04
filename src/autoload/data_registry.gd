extends Node
## data/resources/*.tres 를 로드해 제공한다. 런타임은 이 노드를 통해서만 데이터에 접근한다.
## .tres 는 build_resources.py 생성물이므로 여기서 CSV 를 직접 읽지 않는다.

const RESOURCE_ROOT := "res://data/resources/"
const TUNING_PATH := RESOURCE_ROOT + "tuning.tres"
const STRINGS_PATH := RESOURCE_ROOT + "strings_ko.tres"

var yokai: Dictionary = {}  # id -> YokaiData
var guest_species: Dictionary = {}  # id -> GuestSpeciesData
var rooms: Dictionary = {}  # id -> RoomData
var items: Dictionary = {}  # id -> ItemData
var visitors: Dictionary = {}  # id -> VisitorData
var spirits: Dictionary = {}  # id -> SpiritData
var events: Dictionary = {}  # id -> EventData
var dialogues: Dictionary = {}  # id -> DialogueData
var hints: Dictionary = {}  # id -> HintData
var sfx: Dictionary = {}  # id -> SfxData
# --- P1 신설 (docs/01 v3 5절) ---
var materials: Dictionary = {}  # id -> MaterialData
var crops: Dictionary = {}  # id -> CropData
var fish: Dictionary = {}  # id -> FishData
var talismans: Dictionary = {}  # id -> TalismanData
var tools: Dictionary = {}  # id -> ToolData
var regions: Dictionary = {}  # id -> RegionData
var enemies: Dictionary = {}  # id -> EnemyData
var unlocks: Dictionary = {}  # id -> UnlockData
var chains: Dictionary = {}  # content_id -> ChainData
var metrics_events: Dictionary = {}  # id -> MetricsEventData
var recipes: Dictionary = {}  # id -> RecipeData
# --- P2-S1: 절기·날씨 ---
var seasons: Dictionary = {}  # id -> SeasonData
var weather: Dictionary = {}  # id -> WeatherData
var season_events: Dictionary = {}  # id -> SeasonEventData
# --- P2-S2: 목표·명절 ---
var goals: Dictionary = {}  # id -> GoalData
var festivals: Dictionary = {}  # id -> FestivalData
# --- P2-S3: 가호·회색 시장 ---
var blessings: Dictionary = {}  # id -> BlessingData
var synergies: Dictionary = {}  # id -> SynergyData
var market_prices: Dictionary = {}  # item_id -> MarketPriceData
# --- P2-S4: 챕터·밤 변형 ---
var chapters: Dictionary = {}  # id -> ChapterData
## 밤 변형 구역 id 접미. "<base>@night" 는 base 의 밤 풀·색으로 파생한 RegionData
const NIGHT_SUFFIX := "@night"
var _night_variants: Dictionary = {}  # variant id -> RegionData
var tuning: TuningData = TuningData.new()
var strings: StringTableData = StringTableData.new()


func _ready() -> void:
	reload()


func reload() -> void:
	yokai = _load_dir(RESOURCE_ROOT + "yokai")
	guest_species = _load_dir(RESOURCE_ROOT + "guest_species")
	rooms = _load_dir(RESOURCE_ROOT + "rooms")
	items = _load_dir(RESOURCE_ROOT + "items")
	visitors = _load_dir(RESOURCE_ROOT + "visitors")
	spirits = _load_dir(RESOURCE_ROOT + "spirits")
	events = _load_dir(RESOURCE_ROOT + "events")
	dialogues = _load_dir(RESOURCE_ROOT + "dialogue")
	hints = _load_dir(RESOURCE_ROOT + "hints")
	sfx = _load_dir(RESOURCE_ROOT + "sfx")
	materials = _load_dir(RESOURCE_ROOT + "materials")
	crops = _load_dir(RESOURCE_ROOT + "crops")
	fish = _load_dir(RESOURCE_ROOT + "fish")
	talismans = _load_dir(RESOURCE_ROOT + "talismans")
	tools = _load_dir(RESOURCE_ROOT + "tools")
	regions = _load_dir(RESOURCE_ROOT + "regions")
	enemies = _load_dir(RESOURCE_ROOT + "enemies")
	unlocks = _load_dir(RESOURCE_ROOT + "unlocks")
	chains = _load_dir(RESOURCE_ROOT + "chains")
	metrics_events = _load_dir(RESOURCE_ROOT + "metrics_events")
	recipes = _load_dir(RESOURCE_ROOT + "recipes")
	seasons = _load_dir(RESOURCE_ROOT + "seasons")
	weather = _load_dir(RESOURCE_ROOT + "weather")
	season_events = _load_dir(RESOURCE_ROOT + "season_events")
	goals = _load_dir(RESOURCE_ROOT + "goals")
	festivals = _load_dir(RESOURCE_ROOT + "festivals")
	blessings = _load_dir(RESOURCE_ROOT + "blessings")
	synergies = _load_dir(RESOURCE_ROOT + "synergies")
	market_prices = _load_dir(RESOURCE_ROOT + "market_prices")
	chapters = _load_dir(RESOURCE_ROOT + "chapters")
	_night_variants.clear()
	tuning = _load_single(TUNING_PATH, TuningData.new()) as TuningData
	strings = _load_single(STRINGS_PATH, StringTableData.new()) as StringTableData


func get_yokai(id: String) -> YokaiData:
	return yokai.get(id) as YokaiData


func get_guest_species(id: String) -> GuestSpeciesData:
	return guest_species.get(id) as GuestSpeciesData


func get_room(id: String) -> RoomData:
	return rooms.get(id) as RoomData


## 가호가 붙은 합성 id("item@blessing")도 기본 아이템 데이터를 돌려준다 (P2-S3).
func get_item(id: String) -> ItemData:
	return items.get(BlessingRules.base_id(id)) as ItemData


func get_blessing(id: String) -> BlessingData:
	return blessings.get(id) as BlessingData


## 하숙생의 가호. 없으면 null.
func blessing_of_yokai(yokai_id: String) -> BlessingData:
	for blessing: BlessingData in blessings.values():
		if blessing.yokai_id == yokai_id:
			return blessing
	return null


func get_market_price(item_id: String) -> MarketPriceData:
	return market_prices.get(BlessingRules.base_id(item_id)) as MarketPriceData


func get_visitor(id: String) -> VisitorData:
	return visitors.get(id) as VisitorData


func get_spirit(id: String) -> SpiritData:
	return spirits.get(id) as SpiritData


func get_event(id: String) -> EventData:
	return events.get(id) as EventData


func get_dialogue(id: String) -> DialogueData:
	return dialogues.get(id) as DialogueData


func get_sfx(id: String) -> SfxData:
	return sfx.get(id) as SfxData


func get_material(id: String) -> MaterialData:
	return materials.get(id) as MaterialData


func get_crop(id: String) -> CropData:
	return crops.get(id) as CropData


func get_fish(id: String) -> FishData:
	return fish.get(id) as FishData


func get_talisman(id: String) -> TalismanData:
	return talismans.get(id) as TalismanData


func get_tool(id: String) -> ToolData:
	return tools.get(id) as ToolData


## 밤 변형 id("<base>@night")도 받는다 — base 의 밤 풀·색으로 파생한 리소스를 만들어 캐시한다 (P2-S4).
func get_region(id: String) -> RegionData:
	if id.ends_with(NIGHT_SUFFIX):
		if _night_variants.has(id):
			return _night_variants[id]
		var base := regions.get(base_region_id(id)) as RegionData
		if base == null or not has_night_variant(base):
			return null
		var variant := base.duplicate() as RegionData
		variant.id = id
		variant.name_ko = text("region_night_name", {"name": base.name_ko})
		variant.parent_id = base.id
		variant.gather_pool = base.night_gather_pool.duplicate()
		variant.enemy_pool = base.night_enemy_pool.duplicate()
		variant.enemy_count = base.night_enemy_count
		variant.sky_color = base.night_sky_color
		# 적이 나오는 밤은 탐험지 규칙(동료 전투·진입 비용)을 따른다
		if not base.night_enemy_pool.is_empty():
			variant.kind = "expedition"
		_night_variants[id] = variant
		return variant
	return regions.get(id) as RegionData


func has_night_variant(region: RegionData) -> bool:
	return region != null and not region.night_gather_pool.is_empty()


func night_variant_id(base_id: String) -> String:
	return base_id + NIGHT_SUFFIX


## 변형 id 를 기본 구역 id 로. 변형이 아니면 그대로.
func base_region_id(id: String) -> String:
	return id.trim_suffix(NIGHT_SUFFIX)


func get_chapter(id: String) -> ChapterData:
	return chapters.get(id) as ChapterData


func get_enemy(id: String) -> EnemyData:
	return enemies.get(id) as EnemyData


func get_unlock(id: String) -> UnlockData:
	return unlocks.get(id) as UnlockData


func get_chain(content_id: String) -> ChainData:
	return chains.get(content_id) as ChainData


func get_metrics_event(id: String) -> MetricsEventData:
	return metrics_events.get(id) as MetricsEventData


func get_recipe(id: String) -> RecipeData:
	return recipes.get(id) as RecipeData


func get_season(id: String) -> SeasonData:
	return seasons.get(id) as SeasonData


func get_weather(id: String) -> WeatherData:
	return weather.get(id) as WeatherData


func get_season_event(id: String) -> SeasonEventData:
	return season_events.get(id) as SeasonEventData


func get_goal(id: String) -> GoalData:
	return goals.get(id) as GoalData


func get_festival(id: String) -> FestivalData:
	return festivals.get(id) as FestivalData


## 날씨 표시 이름. weather.csv 에 없으면 strings 의 weather_<id> 로.
func weather_name(id: String) -> String:
	var data := get_weather(id)
	return data.name_ko if data != null else text("weather_%s" % id)


## 레시피를 티어, id 순으로 (메뉴 표시용).
func recipes_sorted() -> Array[RecipeData]:
	var result: Array[RecipeData] = []
	for recipe: RecipeData in recipes.values():
		result.append(recipe)
	result.sort_custom(func(a: RecipeData, b: RecipeData) -> bool:
		if a.tier != b.tier:
			return a.tier < b.tier
		return a.id < b.id)
	return result


## 요리(output_item) → 레시피. 배식·손님 만족은 창고의 아이템에서 레시피를 거꾸로 찾는다. 가호 합성 id 도 기본 요리로 찾는다.
func recipe_for_dish(item_id: String) -> RecipeData:
	var base := BlessingRules.base_id(item_id)
	for recipe: RecipeData in recipes.values():
		if recipe.output_item == base:
			return recipe
	return null


## 해금 일정을 expected_day, day_min, id 순으로 (케이던스 검사·안내 순서용).
func unlocks_sorted() -> Array[UnlockData]:
	var result: Array[UnlockData] = []
	for unlock: UnlockData in unlocks.values():
		result.append(unlock)
	result.sort_custom(func(a: UnlockData, b: UnlockData) -> bool:
		if a.expected_day != b.expected_day:
			return a.expected_day < b.expected_day
		if a.day_min != b.day_min:
			return a.day_min < b.day_min
		return a.id < b.id)
	return result


## 하숙생의 사연(story) 이벤트 id 목록, id 순.
func story_event_ids(yokai_id: String) -> Array[String]:
	var result: Array[String] = []
	for event: EventData in events.values():
		if event.kind == "story" and event.yokai_id == yokai_id:
			result.append(event.id)
	result.sort()
	return result


## UI 문자열. args 는 {name} 자리표시자를 채운다.
func text(key: String, args: Dictionary = {}) -> String:
	return strings.get_text(key).format(args)


# --- 표시용 이름. 데이터가 없으면 id 를 그대로 (누락이 눈에 띄도록) ---

## 가호가 붙은 아이템은 "[뚝] 무 씨앗" 처럼 가호 표시를 앞에 붙인다.
func item_name(id: String) -> String:
	var item := get_item(id)
	var base := item.name_ko if item != null else BlessingRules.base_id(id)
	var blessing := get_blessing(BlessingRules.blessing_of(id))
	if blessing == null:
		return base
	return text("blessed_item_name", {"short": blessing.short_ko, "name": base})


func room_name(id: String) -> String:
	var room := get_room(id)
	return room.name_ko if room != null else id


func yokai_name(id: String) -> String:
	var yokai_data := get_yokai(id)
	return yokai_data.name_ko if yokai_data != null else id


func species_name(id: String) -> String:
	var species := get_guest_species(id)
	return species.name_ko if species != null else id


## 대사 화자 이름: 하숙생 / 가택신 / 플레이어.
func speaker_name(id: String) -> String:
	if id == DialogueGraph.SPEAKER_PLAYER:
		return text("speaker_player")
	var spirit := get_spirit(id)
	if spirit != null:
		return spirit.name_ko
	return yokai_name(id)


## 방 목록을 건설 비용 오름차순으로 (UI 메뉴용). 빈터(kind=empty)는 제외.
func rooms_buildable_sorted() -> Array[RoomData]:
	var result: Array[RoomData] = []
	for room: RoomData in rooms.values():
		if room.kind != RoomGrid.ROOM_KIND_EMPTY:
			result.append(room)
	result.sort_custom(func(a: RoomData, b: RoomData) -> bool: return a.build_cost < b.build_cost)
	return result


## 슬라이스에 등장하는 하숙생 id (in_slice=true), id 순. 파이프라인 검증용 행(Y04~)은 제외된다.
func slice_yokai_ids() -> Array[String]:
	var result: Array[String] = []
	for yokai_data: YokaiData in yokai.values():
		if yokai_data.in_slice:
			result.append(yokai_data.id)
	result.sort()
	return result


## 새 게임 시작부터 입주해 있는 하숙생 id (in_slice 이고 join_mode=start), id 순.
func starting_yokai_ids() -> Array[String]:
	var result: Array[String] = []
	for yokai_data: YokaiData in yokai.values():
		if yokai_data.in_slice and yokai_data.join_mode == "start":
			result.append(yokai_data.id)
	result.sort()
	return result


func _load_single(path: String, fallback: Resource) -> Resource:
	if ResourceLoader.exists(path):
		return load(path)
	push_warning("DataRegistry: %s 없음 — build_resources.py 를 실행했는가?" % path)
	return fallback


func _load_dir(dir_path: String) -> Dictionary:
	var result: Dictionary = {}
	var dir := DirAccess.open(dir_path)
	if dir == null:
		push_warning("DataRegistry: 폴더 없음 %s" % dir_path)
		return result
	for file_name: String in dir.get_files():
		# 익스포트 빌드에서는 .tres 가 .tres.remap 으로 보이므로 접미사를 벗긴다.
		var clean_name := file_name.trim_suffix(".remap")
		if not clean_name.ends_with(".tres"):
			continue
		var res := load(dir_path.path_join(clean_name)) as Resource
		if res == null:
			push_error("DataRegistry: 로드 실패 %s" % clean_name)
			continue
		var id: String = res.get("id")
		if id.is_empty():
			push_error("DataRegistry: id 없음 %s" % clean_name)
			continue
		result[id] = res
	return result
