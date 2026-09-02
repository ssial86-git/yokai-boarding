extends SceneTree
## 개발용 진단: 루트 뷰포트·창의 스케일/오버샘플링 상태와 기본 폰트 정보를 출력하고 종료한다.
## 사용: & $env:GODOT_BIN --path . -s res://test/tools/diag_viewport.gd


func _initialize() -> void:
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var window := root.get_window()
	print("[diag] window.size=", window.size, " content_scale_size=", window.content_scale_size,
		" content_scale_mode=", window.content_scale_mode, " content_scale_factor=", window.content_scale_factor,
		" stretch_scale_mode=", window.content_scale_stretch)
	print("[diag] root.size=", root.size, " visible_rect=", root.get_visible_rect(),
		" oversampling=", root.oversampling, " oversampling_override=", root.oversampling_override)
	print("[diag] screen dpi=", DisplayServer.screen_get_dpi(), " scale=", DisplayServer.screen_get_scale())
	var font: Font = ThemeDB.fallback_font
	print("[diag] fallback_font=", font, " size=", ThemeDB.fallback_font_size)
	if font is FontFile:
		var ff := font as FontFile
		print("[diag] font aa=", ff.antialiasing, " hinting=", ff.hinting, " subpixel=", ff.subpixel_positioning,
			" oversampling=", ff.oversampling, " msdf=", ff.multichannel_signed_distance_field,
			" fixed_size=", ff.fixed_size, " embedded_bitmaps_disabled=", ff.disable_embedded_bitmaps)
	var camera: Camera2D = main.get("camera")
	var view: Node2D = main.get("house_view")
	print("[diag] camera pos=", camera.position, " offset=", camera.offset, " zoom=", camera.zoom,
		" screen_center=", camera.get_screen_center_position())
	print("[diag] house bounds=", view.call("house_bounds"), " cells=", view.call("get_cell_count"),
		" view visible=", view.visible, " world visible=", view.get_parent().visible)
	var hud: Control = main.get("hud")
	var panel: Control = main.get("assignment_panel")
	print("[diag] hud bar=", hud.call("bar_height"), " panel size=", panel.size, " panel pos=", panel.position)
	for child in view.get_children():
		if child is Sprite2D:
			print("[diag] first sprite global=", (child as Sprite2D).global_position, " visible=", child.visible, " z=", child.z_index)
			break
	quit(0)
