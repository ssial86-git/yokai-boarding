class_name CameraBounds
extends RefCounted
## 카메라 중심 클램프 순수 계산. 화면이 경계보다 크면 그 축은 경계 중앙에 고정한다.


static func clamp_center(center: Vector2, bounds: Rect2, view_size: Vector2, zoom: float) -> Vector2:
	var half := view_size / (2.0 * zoom)
	return Vector2(
		_clamp_axis(center.x, bounds.position.x, bounds.end.x, half.x),
		_clamp_axis(center.y, bounds.position.y, bounds.end.y, half.y),
	)


static func _clamp_axis(value: float, low: float, high: float, half_extent: float) -> float:
	if high - low <= half_extent * 2.0:
		return (low + high) * 0.5
	return clampf(value, low + half_extent, high - half_extent)
