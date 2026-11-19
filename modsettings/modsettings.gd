class_name ModsListScreen
extends MenuScreen

const PAGE_SIZE := 10
const LIST_TOP := 96.0
const SAVE_DELAY := 0.25

const MENU_BTN := preload("res://ui/button/sobo_menu_button.tscn")
const BOOL_BTN := preload("res://ui/button/bool/sobo_menu_button_bool.tscn")
const ENUM_BTN := preload("res://ui/button/enum/sobo_menu_button_enum.tscn")
const FLOAT_BTN := preload("res://ui/button/float/sobo_menu_button_float.tscn")
const COLOR_BTN := preload("res://ui/button/color/sobo_menu_button_color.tscn")

static var registered := {}

var is_root := false
var list: VBoxContainer
var nav: HBoxContainer
var desc: Label
var entries: Array[SoboButton] = []
var page := 0

static func install(tree: SceneTree) -> void:
	while Menu._0 == null:
		await tree.process_frame
	if not Menu._0.is_node_ready():
		await Menu._0.ready
	print("modsettings loading")
	var script: GDScript = load("res://modsettings/modsettings.gd")
	inject(Menu._0, script.new())

func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = load("res://ui/theme.tres")

	list = VBoxContainer.new()
	list.custom_minimum_size = Vector2(512, 0)
	list.anchor_left = 0.5
	list.anchor_right = 0.5
	list.anchor_bottom = 1.0
	list.offset_left = -256.0
	list.offset_right = 256.0
	list.offset_top = LIST_TOP
	list.grow_horizontal = Control.GROW_DIRECTION_BOTH
	list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(list)

	nav = HBoxContainer.new()
	nav.alignment = BoxContainer.ALIGNMENT_CENTER
	nav.hide()
	list.add_child(nav)
	prev_btn = _make_arrow_btn(0, func():
		page -= 1
		refresh_page())
	next_btn = _make_arrow_btn(6, func():
		page += 1
		refresh_page())
	nav.add_child(prev_btn)
	nav.add_child(next_btn)

	desc = Label.new()
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size.y = 48
	desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	list.add_child(desc)

func _ready() -> void:
	desc.modulate = StyleManager.current_style.ui_highlight_color
	StyleManager.style_changed.connect(func():
		desc.modulate = StyleManager.current_style.ui_highlight_color)

func open() -> void:
	super()
	Ui._0.on_currently_hovered_changed.connect(_on_hover)
	if is_root:
		scan()

func close() -> void:
	super()
	Ui._0.on_currently_hovered_changed.disconnect(_on_hover)

func _on_hover(new: SoboButton, _old: SoboButton) -> void:
	desc.text = tr(new.tooltip_text) if new else ""

func add_entry(btn: SoboButton) -> void:
	entries.append(btn)
	list.add_child(btn)
	list.move_child(btn, desc.get_index())
	if first_button_hovered == null:
		first_button_hovered = btn
	refresh_page()

func add_page(page_name: String, sub: ModsListScreen) -> void:
	var menu := Menu._0
	sub.parent_screen = self
	menu.add_child(sub)
	menu.register_screen("mod_" + page_name.to_snake_case(), sub)
	sub.hide()
	add_entry(make_button(page_name, func(): menu.change_screen(sub)))

func refresh_page() -> void:
	page = clampi(page, 0, maxi(1, ceili(float(entries.size()) / PAGE_SIZE)) - 1)
	var start := page * PAGE_SIZE
	for i in entries.size():
		entries[i].visible = i >= start and i < start + PAGE_SIZE
	nav.visible = entries.size() > PAGE_SIZE
	prev_btn.disabled = page == 0
	next_btn.disabled = page >= maxi(1, ceili(float(entries.size()) / PAGE_SIZE)) - 1
	var h := SoboButton.currently_hovered
	if h and (not h.is_visible_in_tree() or h.disabled):
		SoboButton.currently_hovered = get_first_button_to_hover()

func _make_arrow_btn(symbol: int, on_press: Callable) -> SoboMenuButton:
	var b: SoboMenuButton = MENU_BTN.instantiate()
	b.label.hide()
	var arrow := Control.new()
	arrow.set_script(load("res://ui/ui_symbol.gd"))
	arrow.custom_minimum_size = Vector2(64, 64)
	arrow.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if symbol != 0:
		arrow.set("symbol", symbol)
	b.get_node("MarginContainer/HBoxContainer").add_child(arrow)
	var hl: Array[CanvasItem] = [arrow]
	b.highlight_elements = hl
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.release_press.connect(on_press)
	return b

func scan() -> void:
	var dirs: Array[String] = [""]
	for d: String in DirAccess.get_directories_at("user://"):
		dirs.append(d + "/")
	for dir: String in dirs:
		for f: String in DirAccess.get_files_at("user://" + dir):
			var path := "user://" + dir + f
			if f.get_extension() != "cfg" or registered.has(path):
				continue
			var cfg := ConfigFile.new()
			if cfg.load(path) != OK or not cfg.has_section_key("meta", "name"):
				continue
			registered[path] = true
			_build_page(path, cfg)

func _build_page(path: String, cfg: ConfigFile) -> void:
	var sub = get_script().new()
	for section: String in cfg.get_sections():
		if section == "meta":
			continue
		var ctl := _make_control(cfg, section, make_commit(path, section), path)
		if ctl == null:
			push_warning("modsettings: skipped '%s' in %s" % [section, path])
			continue
		ctl.tooltip_text = cfg.get_value(section, "description", "")
		sub.add_entry(ctl)

	add_page(cfg.get_value("meta", "name"), sub)
	entries.back().tooltip_text = cfg.get_value("meta", "description", "")

static func _make_control(cfg: ConfigFile, section: String, commit: Callable, path: String) -> SoboButton:
	var label: String = cfg.get_value(section, "label", section)
	match cfg.get_value(section, "type", ""):
		"action":
			return make_button(label, make_action(path, section))
		"bool":
			return make_bool(label, cfg.get_value(section, "value", false), commit)
		"choice":
			var options: Array = cfg.get_value(section, "options", [])
			if options.is_empty():
				return null
			return make_choice(label, options, int(cfg.get_value(section, "value", 0)), commit)
		"float":
			return make_float(label,
				float(cfg.get_value(section, "value", 0.0)),
				float(cfg.get_value(section, "min", 0.0)),
				float(cfg.get_value(section, "max", 1.0)),
				float(cfg.get_value(section, "step", 0.0)),
				commit)
		"color":
			return make_color(label, cfg.get_value(section, "value", Color.WHITE), commit)
	return null

static func make_commit(path: String, section: String) -> Callable:
	var gen := [0]
	return func(v):
		gen[0] += 1
		var mine: int = gen[0]
		Menu._0.get_tree().create_timer(SAVE_DELAY).timeout.connect(func():
			if gen[0] != mine:
				return
			var c := ConfigFile.new()
			if c.load(path) == OK:
				c.set_value(section, "value", v)
				if c.save(path) == OK:
					var broadcaster = Menu._0.get_tree().root.get_meta("modsettings_broadcaster", null)
					if broadcaster:
						broadcaster.config_changed.emit(path, section, v)
		)

static func make_action(path: String, section: String) -> Callable:
	return func():
		var broadcaster = Menu._0.get_tree().root.get_meta("modsettings_broadcaster", null)
		if broadcaster:
			broadcaster.action_triggered.emit(path, section)

static func make_button(text: String, on_press: Callable) -> SoboMenuButton:
	var b: SoboMenuButton = MENU_BTN.instantiate()
	b.label.text = text
	b.release_press.connect(on_press)
	return b

static func make_bool(text: String, value: bool, on_change: Callable) -> SoboMenuButtonBool:
	var b: SoboMenuButtonBool = BOOL_BTN.instantiate()
	var state := [value]
	b.label.text = text
	b.set_value(value)
	b.release_press.connect(func():
		state[0] = not state[0]
		b.set_value(state[0])
		on_change.call(state[0]))
	return b

static func make_choice(text: String, options: Array, index: int, on_change: Callable) -> SoboMenuButtonEnum:
	var b: SoboMenuButtonEnum = ENUM_BTN.instantiate()
	var state := [clampi(index, 0, options.size() - 1)]
	b.label.text = text
	b.set_value(str(options[state[0]]))
	b.release_press.connect(func():
		state[0] = (state[0] + 1) % options.size()
		b.set_value(str(options[state[0]]))
		on_change.call(state[0]))
	return b

static func make_float(text: String, value: float, lo: float, hi: float, step: float, on_change: Callable) -> SoboMenuButtonFloat:
	var b: SoboMenuButtonFloat = FLOAT_BTN.instantiate()
	var decimals := 2
	while decimals < 6 and step > 0.0 and not is_equal_approx(step * pow(10.0, decimals), roundf(step * pow(10.0, decimals))):
		decimals += 1
	b.min_value = lo
	b.max_value = hi
	b.set_value(value)
	b.label.text = "%s: %s" % [text, String.num(value, decimals)]
	b.on_value_changed.connect(func(v: float):
		if step > 0.0:
			v = snappedf(v, step)
		b.label.text = "%s: %s" % [text, String.num(v, decimals)]
		on_change.call(v))
	return b

static func make_color(text: String, value: Color, on_change: Callable) -> SoboMenuButtonColor:
	var b: SoboMenuButtonColor = COLOR_BTN.instantiate()
	b.label.text = text
	b.set_value(value)
	b.on_value_changed.connect(on_change)
	return b

static func inject(menu: Menu, mods_screen: MenuScreen) -> void:
	var ss: MenuScreen = menu.get_settings_screen()
	var ref: Control = ss.get("input_btn")
	if ref == null:
		push_warning("modsettings: no landmark button on %s" % ss.name)
		return
	var parent := ref.get_parent()
	if parent.has_node("ModsButton"):
		return
	mods_screen.parent_screen = ss
	if mods_screen.get_parent() == null:
		menu.add_child(mods_screen)
		menu.register_screen("mods_screen", mods_screen)
		mods_screen.hide()
	var btn := make_button("mods", func(): menu.change_screen(mods_screen))
	btn.name = "ModsButton"
	btn.tooltip_text = "Configure installed mods."
	parent.add_child(btn)
	parent.move_child(btn, ref.get_index() + 1)
	mods_screen.set("is_root", true)
