class_name Interactable
extends Area2D
## 플레이어가 E 로 상호작용하는 대상 (문·채집 포인트·텃밭 칸·방·요괴). 규칙은 갖지 않는다 —
## 안내 문구·가능 여부·행동은 Callable 로 조립자(RegionView / HouseRegion)가 넣는다.

const LAYER_BIT := 2

## () -> String. 빈 문자열이면 안내를 숨긴다.
var prompt_provider: Callable
## () -> bool. false 면 안내는 보이되 E 가 듣지 않는다.
var enabled_check: Callable
## (player: Node) -> void
var action: Callable
## 여러 대상이 겹칠 때 큰 쪽이 이긴다
var interact_priority: int = 0


func _init() -> void:
	collision_layer = LAYER_BIT
	collision_mask = 0
	monitoring = false
	monitorable = true


## 상호작용 범위 상자. offset 은 발 위치 기준.
func set_box(size: Vector2, offset: Vector2 = Vector2.ZERO) -> void:
	for child in get_children():
		if child is CollisionShape2D:
			child.queue_free()
	var shape := RectangleShape2D.new()
	shape.size = size
	var collider := CollisionShape2D.new()
	collider.shape = shape
	collider.position = offset
	add_child(collider)


func prompt() -> String:
	return str(prompt_provider.call()) if prompt_provider.is_valid() else ""


func can_interact() -> bool:
	return bool(enabled_check.call()) if enabled_check.is_valid() else true


func interact(player: Node) -> void:
	if action.is_valid():
		action.call(player)
