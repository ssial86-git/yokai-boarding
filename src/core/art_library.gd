class_name ArtLibrary
extends RefCounted
## 아트 매니페스트(art_assets.csv → DataRegistry.art_assets) 로 논리 키를 텍스처·SpriteFrames 로 푼다.
## 행이 없거나 파일이 없으면 자리표시(art_generated) 로 폴백해 게임이 늘 돌아간다. 캐시는 정적.
## 키 규칙은 ArtAssetData 참조. 렌더러(요괴·플레이어·동료·적·NPC·방·배경·소품·초상·UI)는 전부 이 클래스만 거친다.

const ANIM_IDLE := "idle"
const ANIM_WALK := "walk"
const ANIM_WORK := "work"
const DEFAULT_FPS := 6.0
## 행이 없을 때 쓰는 자리표시 경로 (키 접두 → 파일 형식)
const FALLBACK_FORMATS: Dictionary = {
	"char.": "res://assets/art_generated/yokai_%s.png",
	"guest.": "res://assets/art_generated/guest_%s.png",
	"room.": "res://assets/art_generated/room_%s.png",
	"illust.": "res://assets/art_generated/illust_%s.png",
}
const PLAYER_FALLBACK := "res://assets/art_generated/player.png"

static var _textures: Dictionary = {}  # key -> Texture2D
static var _frames: Dictionary = {}  # key -> SpriteFrames


static func clear_cache() -> void:
	_textures.clear()
	_frames.clear()


static func data(key: String) -> ArtAssetData:
	return DataRegistry.get_art_asset(key)


## 매니페스트 행이 있고 파일이 실재하는가 (자리표시 폴백은 세지 않는다).
static func has(key: String) -> bool:
	var row := data(key)
	return row != null and ResourceLoader.exists(row.file)


## 파일 경로: 행 → 폴백 순. 없으면 빈 문자열.
static func path_for(key: String) -> String:
	var row := data(key)
	if row != null and ResourceLoader.exists(row.file):
		return row.file
	if key == "char.player":
		return PLAYER_FALLBACK if ResourceLoader.exists(PLAYER_FALLBACK) else ""
	for prefix: String in FALLBACK_FORMATS:
		if key.begins_with(prefix):
			var path := String(FALLBACK_FORMATS[prefix]) % key.trim_prefix(prefix)
			return path if ResourceLoader.exists(path) else ""
	return ""


## 전체 이미지 텍스처 (시트면 시트 전체). 없으면 null.
static func texture(key: String) -> Texture2D:
	if _textures.has(key):
		return _textures[key]
	var path := path_for(key)
	var tex: Texture2D = load(path) as Texture2D if not path.is_empty() else null
	_textures[key] = tex
	return tex


## 한 프레임의 크기. 시트가 아니면 이미지 크기. 없으면 0.
static func frame_size(key: String) -> Vector2i:
	var row := data(key)
	var tex := texture(key)
	if tex == null:
		return Vector2i.ZERO
	if row != null and row.frame_w > 0 and row.frame_h > 0 and ResourceLoader.exists(row.file):
		return Vector2i(row.frame_w, row.frame_h)
	return Vector2i(tex.get_width(), tex.get_height())


## 첫 프레임(정지 그림) — 카드·심사 아이콘용.
static func icon(key: String) -> Texture2D:
	var tex := texture(key)
	var size := frame_size(key)
	if tex == null or size == Vector2i(tex.get_width(), tex.get_height()):
		return tex
	var atlas := AtlasTexture.new()
	atlas.atlas = tex
	atlas.region = Rect2(Vector2.ZERO, Vector2(size))
	return atlas


## 애니메이션 프레임 집합. 행에 anims 가 없으면 idle 한 프레임. 없으면 null.
static func frames(key: String) -> SpriteFrames:
	if _frames.has(key):
		return _frames[key]
	var tex := texture(key)
	if tex == null:
		_frames[key] = null
		return null
	var size := frame_size(key)
	var columns := maxi(int(tex.get_width() / size.x), 1)
	var total := columns * maxi(int(tex.get_height() / size.y), 1)
	var row := data(key)
	var result := SpriteFrames.new()
	result.remove_animation("default")
	var spec := row.anims if row != null and ResourceLoader.exists(row.file) else ""
	var defined := false
	for part in spec.split(";", false):
		var pieces := part.strip_edges().split(":")
		if pieces.size() < 2:
			continue
		var name := pieces[0]
		var range_text := pieces[1].split("-")
		var first := int(range_text[0])
		var last := int(range_text[1]) if range_text.size() > 1 else first
		var fps := float(pieces[2]) if pieces.size() > 2 else DEFAULT_FPS
		result.add_animation(name)
		result.set_animation_speed(name, fps)
		result.set_animation_loop(name, true)
		for index in range(first, last + 1):
			if index < 0 or index >= total:
				continue
			result.add_frame(name, _frame_texture(tex, size, columns, index))
		defined = true
	if not defined:
		result.add_animation(ANIM_IDLE)
		result.set_animation_speed(ANIM_IDLE, DEFAULT_FPS)
		result.add_frame(ANIM_IDLE, _frame_texture(tex, size, columns, 0))
	_frames[key] = result
	return result


static func _frame_texture(tex: Texture2D, size: Vector2i, columns: int, index: int) -> Texture2D:
	if size == Vector2i(tex.get_width(), tex.get_height()):
		return tex
	var atlas := AtlasTexture.new()
	atlas.atlas = tex
	@warning_ignore("integer_division")
	atlas.region = Rect2(Vector2(float(index % columns) * size.x, float(index / columns) * size.y), Vector2(size))
	return atlas


## 발이 원점에 오는 AnimatedSprite2D. 그림이 없으면 null (호출자가 자리표시를 그린다).
static func make_sprite(key: String) -> AnimatedSprite2D:
	var sheet := frames(key)
	if sheet == null:
		return null
	var sprite := AnimatedSprite2D.new()
	sprite.sprite_frames = sheet
	sprite.centered = true
	sprite.offset = Vector2(0, -frame_size(key).y * 0.5)
	sprite.play(ANIM_IDLE if sheet.has_animation(ANIM_IDLE) else sheet.get_animation_names()[0])
	return sprite


## 있는 애니메이션만 재생한다 (walk/work 가 없으면 idle 유지).
static func play(sprite: AnimatedSprite2D, anim: String) -> void:
	if sprite == null or sprite.sprite_frames == null:
		return
	if sprite.sprite_frames.has_animation(anim):
		if sprite.animation != anim:
			sprite.play(anim)
	elif sprite.sprite_frames.has_animation(ANIM_IDLE) and sprite.animation != ANIM_IDLE:
		sprite.play(ANIM_IDLE)


## 시트에 이 애니메이션 구간이 정의돼 있는가 (자리표시 bob 대체 판단용).
static func has_anim(key: String, anim: String) -> bool:
	var sheet := frames(key)
	return sheet != null and sheet.has_animation(anim) and sheet.get_frame_count(anim) > 1
