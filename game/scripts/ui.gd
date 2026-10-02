class_name UI
extends RefCounted
## Palette, fonts and small widget factories shared by every screen.

const BG := Color("f6e7c8")
const PAPER := Color("fffaf0")
const INK := Color("1f3a4d")
const MUTED := Color("6b7780")
const ORANGE := Color("d9622b")
const RED := Color("b8402a")
const TEAL := Color("2e6f8e")
const GREEN := Color("3f7d4e")
const GOLD := Color("e8a33d")
const SAND := Color("e9d3a1")
const LINE := Color("d8c49a")

const ACCENTS := ["á", "é", "í", "ó", "ú", "ñ", "ü", "¿", "¡"]

static var _fonts: Dictionary = {}


static func font(kind := "regular") -> Font:
	if _fonts.is_empty():
		# Bundled open-licence fonts (see fonts/OFL-*.txt): a web build has no
		# system fonts to fall back on, and this keeps every platform identical.
		var symbols: Font = load("res://fonts/NotoSansSymbols2.ttf")
		_fonts["regular"] = _weight(load("res://fonts/SourceSans3.ttf"), 400, symbols, -3)
		_fonts["bold"] = _weight(load("res://fonts/SourceSans3.ttf"), 700, symbols, -3)
		_fonts["italic"] = _weight(load("res://fonts/SourceSans3-Italic.ttf"), 400, symbols, -3)
		_fonts["serif"] = _weight(load("res://fonts/Lora.ttf"), 700, symbols, -4)
	return _fonts[kind]


## tighten: these fonts carry generous built-in line gaps; trim them (pixels,
## split between top and bottom) so text blocks stay compact.
static func _weight(base: Font, weight: int, fallback: Font, tighten := 0) -> FontVariation:
	var f := FontVariation.new()
	f.base_font = base
	f.set_spacing(TextServer.SPACING_TOP, tighten / 2)
	f.set_spacing(TextServer.SPACING_BOTTOM, tighten - tighten / 2)
	f.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
	f.fallbacks = [fallback]
	return f


static func box(color: Color, radius := 10, border := Color.TRANSPARENT, width := 0,
		pad := 10) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	sb.set_border_width_all(width)
	sb.border_color = border
	sb.set_content_margin_all(pad)
	return sb


static func theme() -> Theme:
	var t := Theme.new()
	t.default_font = font()
	t.default_font_size = 18
	t.set_color("font_color", "Label", INK)
	t.set_color("default_color", "RichTextLabel", INK)
	t.set_font("normal_font", "RichTextLabel", font())
	t.set_font("bold_font", "RichTextLabel", font("bold"))
	t.set_font("italics_font", "RichTextLabel", font("italic"))
	t.set_stylebox("normal", "LineEdit", box(Color.WHITE, 8, LINE, 2, 10))
	t.set_stylebox("focus", "LineEdit", box(Color.WHITE, 8, TEAL, 2, 10))
	t.set_color("font_color", "LineEdit", INK)
	t.set_color("font_placeholder_color", "LineEdit", Color(MUTED, 0.7))
	t.set_color("caret_color", "LineEdit", INK)
	t.set_font_size("font_size", "LineEdit", 20)
	t.set_stylebox("panel", "PanelContainer", box(PAPER, 12, LINE, 1, 14))
	t.set_color("font_color", "CheckBox", INK)
	t.set_color("font_hover_color", "CheckBox", INK)
	t.set_color("font_pressed_color", "CheckBox", INK)
	t.set_color("font_hover_pressed_color", "CheckBox", INK)
	t.set_color("font_focus_color", "CheckBox", INK)
	for icon in ["checked", "checked_disabled"]:
		t.set_icon(icon, "CheckBox", _check_icon(true))
	for icon in ["unchecked", "unchecked_disabled"]:
		t.set_icon(icon, "CheckBox", _check_icon(false))
	t.set_constant("h_separation", "CheckBox", 8)

	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		t.set_stylebox(state, "OptionButton", box(Color.WHITE, 8,
			TEAL if state in ["hover", "focus"] else LINE, 2, 8))
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color",
			"font_hover_pressed_color"]:
		t.set_color(c, "OptionButton", INK)
	t.set_constant("modulate_arrow", "OptionButton", 1)
	t.set_stylebox("panel", "PopupMenu", box(Color.WHITE, 8, LINE, 2, 6))
	t.set_stylebox("hover", "PopupMenu", box(SAND, 4, Color.TRANSPARENT, 0, 4))
	t.set_color("font_color", "PopupMenu", INK)
	t.set_color("font_hover_color", "PopupMenu", INK)
	t.set_icon("radio_checked", "PopupMenu", _dot_icon(true))
	t.set_icon("radio_unchecked", "PopupMenu", _dot_icon(false))
	return t


## A 22px tick box drawn in code, so it matches the palette instead of the
## engine's dark default.
static func _check_icon(on: bool) -> ImageTexture:
	var n := 22
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	for y in n:
		for x in n:
			var edge: bool = x < 2 or y < 2 or x >= n - 2 or y >= n - 2
			var corner: bool = (x < 2 or x >= n - 2) and (y < 2 or y >= n - 2)
			if corner:
				continue
			if on:
				img.set_pixel(x, y, TEAL)
			else:
				img.set_pixel(x, y, MUTED if edge else Color.WHITE)
	if on:
		# the tick: a short stroke down-right, then a long one up-right
		for i in 5:
			for w in 3:
				img.set_pixel(5 + i, 10 + i + w, Color.WHITE)
		for i in 9:
			for w in 3:
				img.set_pixel(9 + i, 14 - i + w, Color.WHITE)
	return ImageTexture.create_from_image(img)


static func _dot_icon(on: bool) -> ImageTexture:
	var n := 14
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	var c := Vector2(n / 2.0, n / 2.0)
	for y in n:
		for x in n:
			var d := Vector2(x + 0.5, y + 0.5).distance_to(c)
			if on and d < 4.5:
				img.set_pixel(x, y, TEAL)
	return ImageTexture.create_from_image(img)


static func label(text: String, size := 18, color := INK, kind := "regular") -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font(kind))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


## kind: "primary" (filled), "ghost" (outlined), "small" (compact outlined)
static func button(text: String, kind := "primary", color := ORANGE) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var small := kind == "small"
	var pad_x := 10 if small else 18
	var pad_y := 4 if small else 9
	var fill := kind == "primary"
	var normal := box(color if fill else PAPER, 8, color, 0 if fill else 2, pad_y)
	normal.content_margin_left = pad_x
	normal.content_margin_right = pad_x
	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = color.lightened(0.12) if fill else color.lightened(0.85)
	var pressed: StyleBoxFlat = normal.duplicate()
	pressed.bg_color = color.darkened(0.12) if fill else color.lightened(0.7)
	var disabled: StyleBoxFlat = normal.duplicate()
	disabled.bg_color = Color("ddd3bd") if fill else PAPER
	disabled.border_color = Color("cfc4a8")
	var focus: StyleBoxFlat = normal.duplicate()
	focus.bg_color = Color.TRANSPARENT
	focus.border_color = INK
	focus.set_border_width_all(2)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("disabled", disabled)
	b.add_theme_stylebox_override("focus", focus)
	var fg := Color.WHITE if fill else color
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color",
			"font_hover_pressed_color"]:
		b.add_theme_color_override(c, fg)
	b.add_theme_color_override("font_disabled_color", Color("9a927e"))
	b.add_theme_font_override("font", font("bold"))
	b.add_theme_font_size_override("font_size", 14 if small else 18)
	return b


static func spacer(w := 0, h := 0, expand := false) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(w, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if expand:
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return c


static func panel(color := PAPER, radius := 12, border := LINE, width := 1,
		pad := 14) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box(color, radius, border, width, pad))
	return p


static func stars(n: int, total := 3) -> String:
	return "★".repeat(n) + "☆".repeat(total - n)


static func esc(s: String) -> String:
	return s.replace("[", "[lb]")


## A row of buttons that type accented characters into a LineEdit, for
## keyboards without a Spanish layout.
static func accent_row(edit: LineEdit) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	for ch in ACCENTS:
		var b := button(ch, "small", TEAL)
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(34, 30)
		b.pressed.connect(func():
			var web := edit.get_node_or_null("WebField")
			if web:
				web.insert(ch)
			else:
				edit.insert_text_at_caret(ch)
				edit.grab_focus())
		row.add_child(b)
	return row


## Give a control keyboard focus once it is in the tree (it may already have
## been replaced by then, so check first).
static func focus(c: Control) -> void:
	(func():
		if not is_instance_valid(c) or not c.is_inside_tree():
			return
		var web := c.get_node_or_null("WebField")
		if web:
			web.take_focus()
		elif c.focus_mode != Control.FOCUS_NONE:
			c.grab_focus()).call_deferred()


static func plain(segs: Array) -> String:
	var s := ""
	for seg in segs:
		s += str(seg[0])
	return s


## The sentence of `text` that the character at `pos` belongs to.
static func sentence_at(text: String, pos: int) -> String:
	var start := 0
	var end := text.length()
	for i in text.length() - 1:
		if text[i] in ".?!…" and text[i + 1] == " ":
			if i < pos:
				start = i + 2
			else:
				end = i + 1
				break
	return text.substr(start, end - start).strip_edges()


# ------------------------------------------------------------ answer checking

static func norm(s: String, strip_accents := false) -> String:
	s = s.to_lower().strip_edges()
	for ch in ["¿", "?", "¡", "!", ".", ",", ";", ":", "\"", "(", ")", "…"]:
		s = s.replace(ch, "")
	while s.contains("  "):
		s = s.replace("  ", " ")
	if strip_accents:
		var pairs := {"á": "a", "é": "e", "í": "i", "ó": "o", "ú": "u", "ü": "u", "ñ": "n"}
		for k in pairs:
			s = s.replace(k, pairs[k])
	return s.strip_edges()


static func distance(a: String, b: String) -> int:
	var prev: Array = range(b.length() + 1)
	for i in range(1, a.length() + 1):
		var cur: Array = [i]
		for j in range(1, b.length() + 1):
			var cost := 0 if a[i - 1] == b[j - 1] else 1
			cur.append(min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + cost))
		prev = cur
	return prev[b.length()]


## Returns "exact", "accent" (right apart from tildes/ñ), "close" or "no",
## plus the accepted answer that came nearest.
static func check(input: String, answers: Array) -> Dictionary:
	var typed := norm(input)
	var bare := norm(input, true)
	var best := str(answers[0])
	var best_d := 9999
	for a in answers:
		if norm(a) == typed:
			return {"verdict": "exact", "best": a}
	for a in answers:
		if norm(a, true) == bare:
			return {"verdict": "accent", "best": a}
		var d := distance(bare, norm(a, true))
		if d < best_d:
			best_d = d
			best = a
	var allowed: int = max(2, int(norm(best).length() * 0.15))
	if typed != "" and best_d <= allowed:
		return {"verdict": "close", "best": best}
	return {"verdict": "no", "best": best}
