class_name AudioSystem
extends Node
## 임시 효과음: Events 를 sfx.csv 항목에 연결한다. 어떤 소리를 쓰는지는 데이터, 언제 울리는지는 여기(코드).
## 비 오는 날은 낮 동안 빗소리 루프를 튼다. 정식 사운드 교체 시 파일만 바꾸면 된다.

const AUDIO_DIR := "res://assets/audio/generated/"
const DUMMY_DRIVER := "Dummy"

var _players: Dictionary = {}  # sfx_id -> AudioStreamPlayer
var _last_money: int = 0
var _master_db: float = 0.0


func _ready() -> void:
	_master_db = DataRegistry.tuning.get_float("sfx_master_db")
	# headless(Dummy 드라이버)에서는 재생이 끝나지 않아 종료 시 스트림이 "still in use" 로 남는다. 플레이어를 만들지 않는다.
	if AudioServer.get_driver_name() == DUMMY_DRIVER:
		_connect_events()
		return
	for sfx: SfxData in DataRegistry.sfx.values():
		var path := AUDIO_DIR + sfx.file
		if not ResourceLoader.exists(path):
			push_warning("AudioSystem: 파일 없음 %s" % path)
			continue
		var stream := load(path) as AudioStream
		if sfx.loop and stream is AudioStreamWAV:
			(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
		var player := AudioStreamPlayer.new()
		player.name = "Sfx_%s" % sfx.id
		player.stream = stream
		player.volume_db = sfx.volume_db + _master_db
		add_child(player)
		_players[sfx.id] = player
	_connect_events()


func _connect_events() -> void:
	_last_money = GameState.money
	Events.room_changed.connect(func(_coords: Vector2i, room_id: String) -> void:
		var room := DataRegistry.get_room(room_id)
		play("build" if room != null and room.kind != RoomGrid.ROOM_KIND_EMPTY else "drop"))
	Events.floor_added.connect(func(_floor: int) -> void: play("build"))
	Events.assignment_changed.connect(func(_id: String, _cell: Vector2i) -> void: play("drop"))
	Events.house_action_failed.connect(func(_outcome: int) -> void: play("error"))
	Events.assignment_failed.connect(func(_id: String, _outcome: int) -> void: play("error"))
	Events.visitor_knocked.connect(func(visitor: Dictionary) -> void:
		if not visitor.is_empty():
			play("knock"))
	Events.dialogue_node_shown.connect(func(_event_id: String, _speaker: String) -> void: play("blip"))
	Events.timeband_changed.connect(_on_timeband_changed)
	Events.money_changed.connect(_on_money_changed)
	Events.weather_changed.connect(func(_weather: String) -> void: _update_ambient())
	Events.game_loaded.connect(func(_slot: int) -> void:
		_last_money = GameState.money
		_update_ambient())


## 종료 시 재생 중인 스트림이 "resource still in use" 로 남지 않도록 멈춘다.
func _exit_tree() -> void:
	for player: AudioStreamPlayer in _players.values():
		player.stop()
		player.stream = null


func has_sfx(sfx_id: String) -> bool:
	return _players.has(sfx_id)


func play(sfx_id: String) -> void:
	var player: AudioStreamPlayer = _players.get(sfx_id)
	if player != null:
		player.play()


func is_playing(sfx_id: String) -> bool:
	var player: AudioStreamPlayer = _players.get(sfx_id)
	return player != null and player.playing


func _on_timeband_changed(_band: int, _day: int) -> void:
	play("chime")
	_update_ambient()


func _on_money_changed(amount: int) -> void:
	if amount > _last_money:
		play("coin")
	_last_money = amount


## 비 오는 날 낮·저녁에만 빗소리.
func _update_ambient() -> void:
	var player: AudioStreamPlayer = _players.get("rain")
	if player == null:
		return
	var rainy := GameState.weather == DayCycle.RAIN and Clock.band in [Clock.Band.DAY, Clock.Band.EVENING]
	if rainy and not player.playing:
		player.play()
	elif not rainy and player.playing:
		player.stop()
