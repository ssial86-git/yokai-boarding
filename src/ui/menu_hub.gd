class_name MenuHub
extends ListMenu
## 장부 메뉴 (UI 정리 2026-09-04): 창고 · 하숙부 · 명부를 탭 하나로 묶는다. Tab 으로 열고 닫고, I/J/L 로 탭을 바로 연다.
## 유사 게임의 관행(스타듀밸리의 탭 메뉴)을 따라 "메뉴 열기 → 탭" 두 단계 이상 들어가지 않게 한다. ESC 는 닫기.

enum Tab { INVENTORY, ROSTER, LEDGER }

const TAB_KEYS: Array[String] = ["tab_inventory", "tab_roster", "tab_ledger"]
const TAB_HINT_KEYS: Array[String] = ["key_hint_inventory", "key_hint_roster", "key_hint_ledger"]
## 창고 표시 순서 (items.kind)
const KIND_ORDER: Array[String] = ["food", "crop", "material", "fish", "seed", "talisman", "misc", "key"]

var current_tab: Tab = Tab.INVENTORY

var _tab_buttons: Array[Button] = []


func _ready() -> void:
	super()
	var tabs := HBoxContainer.new()
	for index in TAB_KEYS.size():
		var button := Button.new()
		button.text = "%s %s" % [DataRegistry.text(TAB_KEYS[index]), DataRegistry.text(TAB_HINT_KEYS[index])]
		button.toggle_mode = true
		button.pressed.connect(func() -> void: open_tab(index as Tab))
		tabs.add_child(button)
		_tab_buttons.append(button)
	var column := _title.get_parent()
	column.add_child(tabs)
	column.move_child(tabs, 1)
	Events.item_added.connect(func(_id: String, _count: int) -> void: _refresh_if_open())
	Events.item_removed.connect(func(_id: String, _count: int) -> void: _refresh_if_open())
	Events.affinity_changed.connect(func(_id: String, _value: int) -> void: _refresh_if_open())
	Events.ledger_changed.connect(func(_id: String, _count: int) -> void: _refresh_if_open())
	Events.game_loaded.connect(func(_slot: int) -> void: _refresh_if_open())


func toggle(tab: int = -1) -> void:
	if visible and (tab < 0 or tab == current_tab):
		close()
	else:
		open_tab(current_tab if tab < 0 else tab as Tab)


func open_tab(tab: Tab) -> void:
	current_tab = tab
	for index in _tab_buttons.size():
		_tab_buttons[index].button_pressed = index == tab
	open_with_title(DataRegistry.text("ui_menu_title"))
	refresh()


func refresh() -> void:
	clear_rows()
	match current_tab:
		Tab.INVENTORY:
			_build_inventory()
		Tab.ROSTER:
			_build_roster()
		Tab.LEDGER:
			_build_ledger()


func _refresh_if_open() -> void:
	if visible:
		refresh()


## 창고: 종류별 소제목 아래 "이름 ×n · 개당 값". 판매는 대문간 메뉴가 맡는다.
func _build_inventory() -> void:
	var items := GameState.inventory.items()
	if items.is_empty():
		add_header(DataRegistry.text("ui_inventory_empty"))
		return
	var by_kind: Dictionary = {}
	for item_id: String in items:
		var item := DataRegistry.get_item(item_id)
		var kind := item.kind if item != null else "misc"
		if not by_kind.has(kind):
			by_kind[kind] = []
		(by_kind[kind] as Array).append(item_id)
	for kind in KIND_ORDER:
		if not by_kind.has(kind):
			continue
		add_header(DataRegistry.text("kind_%s" % kind))
		var ids: Array = by_kind[kind]
		ids.sort()
		for item_id: String in ids:
			var item := DataRegistry.get_item(item_id)
			var value := item.base_value if item != null else 0
			add_row(DataRegistry.text("ui_inventory_row", {"name": DataRegistry.item_name(item_id), "count": items[item_id]})
				+ "   " + DataRegistry.text("ui_inventory_value", {"value": value}))


func _build_roster() -> void:
	if GameState.residents.is_empty():
		add_header(DataRegistry.text("ui_roster_empty"))
		return
	for yokai_id in GameState.residents:
		var yokai := DataRegistry.get_yokai(yokai_id)
		if yokai == null:
			continue
		var story_ids := DataRegistry.story_event_ids(yokai_id)
		var seen := 0
		for event_id in story_ids:
			if GameState.seen_events.has(event_id):
				seen += 1
		add_row(DataRegistry.text("ui_roster_row", {
			"name": yokai.name_ko, "species": yokai.species_ko,
			"affinity": int(GameState.affinity.get(yokai_id, 0)), "seen": seen, "total": story_ids.size()}))


func _build_ledger() -> void:
	var ids := GameState.ledger.keys()
	ids.sort()
	if ids.is_empty():
		add_header(DataRegistry.text("ui_ledger_empty"))
		return
	for species_id: String in ids:
		var species := DataRegistry.get_guest_species(species_id)
		add_row(DataRegistry.text("ui_ledger_row", {
			"name": species.name_ko if species != null else species_id,
			"rarity": DataRegistry.text("rarity_%s" % (species.rarity if species != null else "common")),
			"count": GameState.ledger[species_id]}))
