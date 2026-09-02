extends Node
## data/resources/*.tres 를 로드해 제공한다. 런타임은 이 노드를 통해서만 데이터에 접근한다.
## .tres 는 build_resources.py 생성물이므로 여기서 CSV 를 직접 읽지 않는다.

const RESOURCE_ROOT := "res://data/resources/"
const TUNING_PATH := RESOURCE_ROOT + "tuning.tres"

var yokai: Dictionary = {}  # id -> YokaiData
var guest_species: Dictionary = {}  # id -> GuestSpeciesData
var rooms: Dictionary = {}  # id -> RoomData
var tuning: TuningData = TuningData.new()


func _ready() -> void:
	reload()


func reload() -> void:
	yokai = _load_dir(RESOURCE_ROOT + "yokai")
	guest_species = _load_dir(RESOURCE_ROOT + "guest_species")
	rooms = _load_dir(RESOURCE_ROOT + "rooms")
	if ResourceLoader.exists(TUNING_PATH):
		tuning = load(TUNING_PATH) as TuningData
	else:
		push_warning("DataRegistry: tuning.tres 없음 — build_resources.py 를 실행했는가?")


func get_yokai(id: String) -> YokaiData:
	return yokai.get(id) as YokaiData


func get_guest_species(id: String) -> GuestSpeciesData:
	return guest_species.get(id) as GuestSpeciesData


func get_room(id: String) -> RoomData:
	return rooms.get(id) as RoomData


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
