class_name WebField
extends Node
## In a browser, typing goes through a real HTML <input> laid exactly over the
## game's LineEdit. Godot's own text entry relies on focus tricks that fail on
## phones (no on-screen keyboard) and inside embedded frames; a real input
## works everywhere. The LineEdit underneath stays the source of truth for the
## game: this node copies the typed text into it and relays Enter.
## On desktop builds attach() does nothing.

const BASE := Vector2(1280, 720)

var _edit: LineEdit
var _el: JavaScriptObject
var _canvas: JavaScriptObject
var _on_input: JavaScriptObject
var _on_key: JavaScriptObject
var _last_box := ""
var _shown := true


static func attach(edit: LineEdit, autofocus := false) -> void:
	if not OS.has_feature("web"):
		return
	var f := WebField.new()
	f.name = "WebField"
	f.set_meta("autofocus", autofocus)
	edit.add_child(f)


## Type a character at the cursor (the accent buttons use this).
func insert(ch: String) -> void:
	var start: int = _el.selectionStart
	var stop: int = _el.selectionEnd
	_el.setRangeText(ch, start, stop, "end")
	_edit.text = str(_el.value)
	_edit.text_changed.emit(_edit.text)
	_el.focus()


func take_focus() -> void:
	if _el:
		_el.focus()


func _ready() -> void:
	_edit = get_parent()
	# The HTML input does the typing; keep Godot from also trying to.
	_edit.focus_mode = Control.FOCUS_NONE
	_edit.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var doc: JavaScriptObject = JavaScriptBridge.get_interface("document")
	_canvas = doc.getElementById("canvas")
	_el = doc.createElement("input")
	_el.type = "text"
	_el.value = _edit.text
	_el.placeholder = _edit.placeholder_text
	_el.setAttribute("lang", "es")
	_el.setAttribute("autocomplete", "off")
	_el.setAttribute("autocapitalize", "off")
	_el.setAttribute("autocorrect", "off")
	_el.setAttribute("spellcheck", "false")
	_el.setAttribute("enterkeyhint", "done")
	_el.setAttribute("aria-label", _edit.placeholder_text)
	var st: JavaScriptObject = _el.style
	st.position = "fixed"
	st.zIndex = "20"
	st.boxSizing = "border-box"
	st.margin = "0"
	st.border = "2px solid #2e6f8e"
	st.background = "#ffffff"
	st.color = "#1f3a4d"
	st.outline = "none"
	st.fontFamily = "'Source Sans 3', 'Segoe UI', system-ui, -apple-system, Arial, sans-serif"
	doc.body.appendChild(_el)
	_on_input = JavaScriptBridge.create_callback(func(_args: Array):
		_edit.text = str(_el.value)
		_edit.text_changed.emit(_edit.text))
	_on_key = JavaScriptBridge.create_callback(func(args: Array):
		if str(args[0].key) == "Enter":
			_edit.text = str(_el.value)
			_edit.text_submitted.emit(_edit.text))
	_el.addEventListener("input", _on_input)
	_el.addEventListener("keydown", _on_key)
	_place()
	if get_meta("autofocus", false):
		_el.focus()


func _process(_delta: float) -> void:
	_place()
	# The game can change the text too (clearing it, or an accent button).
	if str(_el.value) != _edit.text:
		_el.value = _edit.text


func _place() -> void:
	var visible_now := _edit.is_visible_in_tree() and _edit.editable
	if visible_now != _shown:
		_shown = visible_now
		_el.style.display = "block" if visible_now else "none"
	if not visible_now:
		return
	var r: JavaScriptObject = _canvas.getBoundingClientRect()
	var scale: float = min(float(r.width) / BASE.x, float(r.height) / BASE.y)
	var off := Vector2((float(r.width) - BASE.x * scale) / 2.0, (float(r.height) - BASE.y * scale) / 2.0)
	# where the field is on screen, which is not where it is in the game once zoomed in
	var box: Rect2 = _edit.get_viewport().canvas_transform * _edit.get_global_rect()
	var css := "%.1f,%.1f,%.1f,%.1f,%.3f" % [float(r.left) + off.x + box.position.x * scale,
		float(r.top) + off.y + box.position.y * scale, box.size.x * scale, box.size.y * scale, scale]
	if css == _last_box:
		return
	_last_box = css
	var st: JavaScriptObject = _el.style
	st.left = "%.1fpx" % (float(r.left) + off.x + box.position.x * scale)
	st.top = "%.1fpx" % (float(r.top) + off.y + box.position.y * scale)
	st.width = "%.1fpx" % (box.size.x * scale)
	st.height = "%.1fpx" % (box.size.y * scale)
	# 16px minimum: below that, phones zoom the whole page when the field is tapped.
	st.fontSize = "%.1fpx" % max(16.0, 20.0 * scale)
	st.padding = "0 %.1fpx" % (10.0 * scale)
	st.borderRadius = "%.1fpx" % (8.0 * scale)


func _exit_tree() -> void:
	if _el:
		_el.removeEventListener("input", _on_input)
		_el.removeEventListener("keydown", _on_key)
		_el.remove()
		_el = null
	# hand the keyboard back to the game, so A/B/C and Enter keep working
	if _canvas:
		_canvas.focus()
