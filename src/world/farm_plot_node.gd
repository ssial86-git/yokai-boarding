class_name FarmPlotNode
extends Interactable
## 텃밭 한 칸의 화면 표현 + 상호작용. 상태는 GameState.farm 이 갖고, 규칙은 FarmSystem 이 판단한다.
## 그림은 코드 자리표시(팔레트 색 사각형·새싹) — 정식 타일은 아트 트랙 몫.

var index: int = 0
var plot_width: float = 16.0

var _farm_system: FarmSystem
var _color_empty: Color = Color.SADDLE_BROWN
var _color_tilled: Color = Color.BLACK
var _color_sprout: Color = Color.GREEN
var _color_ready: Color = Color.ORANGE


func setup(plot_index: int, farm_system: FarmSystem) -> void:
	index = plot_index
	_farm_system = farm_system
	var tuning := DataRegistry.tuning
	plot_width = float(tuning.get_int("farm_plot_width_px"))
	_color_empty = Color.html(tuning.get_string("farm_plot_color_empty"))
	_color_tilled = Color.html(tuning.get_string("farm_plot_color_tilled"))
	_color_sprout = Color.html(tuning.get_string("crop_sprout_color"))
	_color_ready = Color.html(tuning.get_string("crop_ready_color"))
	interact_priority = 1
	set_box(Vector2(plot_width, 24.0), Vector2(0, -12.0))
	prompt_provider = func() -> String: return _farm_system.prompt_for(index)
	enabled_check = func() -> bool: return _farm_system.can_act(index)
	action = func(_player: Node) -> void: _farm_system.act(index)
	Events.farm_changed.connect(func(changed: int) -> void:
		if changed == index or changed < 0:
			queue_redraw())


func _draw() -> void:
	var plot := GameState.farm.get_plot(index)
	if plot == null:
		return
	var half := plot_width * 0.5
	var soil := Rect2(Vector2(-half, -6.0), Vector2(plot_width, 6.0))
	draw_rect(soil, _color_empty if plot.state == Farm.PlotState.EMPTY else _color_tilled)
	draw_rect(soil, Color(0.1, 0.08, 0.12), false, 1.0)  # 칸 경계 — 6칸이 구분되게
	match plot.state:
		Farm.PlotState.GROWING:
			var crop := DataRegistry.get_crop(plot.crop_id)
			var total := float(crop.grow_days) if crop != null else 1.0
			var height := 2.0 + 8.0 * clampf(plot.growth / maxf(total, 1.0), 0.0, 1.0)
			draw_rect(Rect2(Vector2(-1.0, -4.0 - height), Vector2(2.0, height)), _color_sprout)
			if plot.water >= Farm.FULL_WATER:
				draw_rect(Rect2(Vector2(-half, -1.0), Vector2(plot_width, 1.0)), Color(0.4, 0.6, 0.9, 0.8))
		Farm.PlotState.READY:
			draw_rect(Rect2(Vector2(-1.0, -14.0), Vector2(2.0, 10.0)), _color_sprout)
			draw_circle(Vector2(0.0, -15.0), 3.0, _color_ready)
		_:
			pass
