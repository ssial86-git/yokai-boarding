class_name RegionLayout
extends RefCounted
## regions.csv 의 레이아웃 문자열(ground / doors / gather_span / farm_x)을 기하로 푼다. 씬은 이 값으로 조립된다.
## 월드 좌표: 기준 바닥이 y=0, 위로 갈수록 y 감소. 단차는 경사로(ramp)로만 잇는다 — 정밀 플랫포밍 없음 (CLAUDE.md 5.7).


class Segment:
	extends RefCounted
	var x0: float = 0.0
	var x1: float = 0.0
	var y: float = 0.0


class Door:
	extends RefCounted
	var region_id: String = ""
	var x: float = 0.0


var width_px: float = 0.0
var segments: Array[Segment] = []
var doors: Array[Door] = []
var gather_x0: float = 0.0
var gather_x1: float = 0.0
var farm_x: float = 0.0


static func from_region(region: RegionData) -> RegionLayout:
	var layout := RegionLayout.new()
	layout.width_px = float(region.width_px)
	layout.segments = parse_segments(region.ground)
	layout.doors = parse_doors(region.doors)
	var span := parse_pair(region.gather_span)
	layout.gather_x0 = span.x
	layout.gather_x1 = span.y
	layout.farm_x = float(region.farm_x)
	return layout


## "x0:x1:y" 목록. 형식이 틀린 항목은 건너뛴다 (빌드가 이미 검증했다).
static func parse_segments(entries: Array) -> Array[Segment]:
	var result: Array[Segment] = []
	for entry: Variant in entries:
		var parts := str(entry).split(":")
		if parts.size() != 3:
			continue
		var segment := Segment.new()
		segment.x0 = float(parts[0])
		segment.x1 = float(parts[1])
		segment.y = float(parts[2])
		result.append(segment)
	return result


## "region_id:x" 목록.
static func parse_doors(entries: Array) -> Array[Door]:
	var result: Array[Door] = []
	for entry: Variant in entries:
		var parts := str(entry).split(":")
		if parts.size() != 2:
			continue
		var door := Door.new()
		door.region_id = parts[0]
		door.x = float(parts[1])
		result.append(door)
	return result


static func parse_pair(text: String) -> Vector2:
	var parts := text.split(":")
	if parts.size() != 2:
		return Vector2.ZERO
	return Vector2(float(parts[0]), float(parts[1]))


## 바닥 윤곽선. 높이가 다른 구간 사이는 ramp_px 폭의 경사로 잇는다.
func profile(ramp_px: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in segments.size():
		var segment := segments[i]
		var left_ramp := i > 0 and segments[i - 1].y != segment.y
		var right_ramp := i < segments.size() - 1 and segments[i + 1].y != segment.y
		var half := ramp_px * 0.5
		points.append(Vector2(segment.x0 + (half if left_ramp else 0.0), segment.y))
		points.append(Vector2(segment.x1 - (half if right_ramp else 0.0), segment.y))
	return points


## x 위치의 바닥 높이 (경사로 위는 보간). 구간 밖이면 0.
func ground_y_at(x: float, ramp_px: float) -> float:
	var points := profile(ramp_px)
	if points.is_empty():
		return 0.0
	if x <= points[0].x:
		return points[0].y
	for i in range(1, points.size()):
		var a := points[i - 1]
		var b := points[i]
		if x <= b.x:
			if b.x == a.x:
				return b.y
			return lerpf(a.y, b.y, (x - a.x) / (b.x - a.x))
	return points[points.size() - 1].y


## 채집 포인트 x 좌표를 gather_span 안에 고르게 편다.
func gather_positions(count: int) -> Array[float]:
	var result: Array[float] = []
	if count <= 0 or gather_x1 <= gather_x0:
		return result
	var span := gather_x1 - gather_x0
	for k in count:
		result.append(gather_x0 + span * (float(k) + 0.5) / float(count))
	return result


## 텃밭 칸 x 좌표 (farm_x 부터 plot_width 간격).
func farm_positions(count: int, plot_width: float) -> Array[float]:
	var result: Array[float] = []
	for k in count:
		result.append(farm_x + plot_width * float(k))
	return result


## 목적지 region_id 로 가는 문의 x. 없으면 -1.
func door_x(region_id: String) -> float:
	for door in doors:
		if door.region_id == region_id:
			return door.x
	return -1.0


## from_region 에서 들어왔을 때 서는 자리: 그쪽 문 앞, 문이 없으면 한가운데.
func spawn_x_from(from_region_id: String) -> float:
	var x := door_x(from_region_id)
	return x if x >= 0.0 else width_px * 0.5
