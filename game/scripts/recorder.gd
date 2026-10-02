class_name Recorder
extends HBoxContainer
## Record yourself saying a line, then hear your take alone or straight after
## the model voice. Nothing is saved: the take lives only until the next one.

const MAX_SECONDS := 20.0

var audio := ""          # the model line to compare against
var _take: AudioStreamWAV
var _rec: Button
var _mine: Button
var _both: Button
var _elapsed := 0.0


func _init(audio_id := "") -> void:
	audio = audio_id
	add_theme_constant_override("separation", 8)
	_rec = UI.button("● Grabar", "small", UI.RED)
	_rec.focus_mode = Control.FOCUS_NONE
	_rec.pressed.connect(_toggle)
	add_child(_rec)
	_mine = UI.button("Mi voz", "small", UI.TEAL)
	_mine.focus_mode = Control.FOCUS_NONE
	_mine.disabled = true
	_mine.pressed.connect(func(): Game.play_take(_take))
	add_child(_mine)
	_both = UI.button("Comparar", "small", UI.TEAL)
	_both.focus_mode = Control.FOCUS_NONE
	_both.disabled = true
	_both.tooltip_text = "Primero el modelo, después tu voz"
	_both.pressed.connect(func(): Game.play_voice_then_take(audio, _take))
	add_child(_both)


func _ready() -> void:
	# Godot switches _process on at ready; the timer should only run while recording.
	set_process(false)


func _toggle() -> void:
	if Game.recording:
		_stop()
		return
	Game.stop_voice()
	if not Game.start_recording():
		_rec.text = "Sin micrófono"
		_rec.disabled = true
		return
	_elapsed = 0.0
	_rec.text = "■ Parar"
	set_process(true)


func _stop() -> void:
	set_process(false)
	_rec.text = "● Grabar otra vez"
	var take := Game.stop_recording()
	if take == null or take.get_length() < 0.2:
		return
	_take = take
	_mine.disabled = false
	_both.disabled = audio == "" or not Game.has_voice(audio)
	if _both.disabled:
		Game.play_take(_take)
	else:
		Game.play_voice_then_take(audio, _take)


func _process(delta: float) -> void:
	_elapsed += delta
	_rec.text = "■ Parar  %d s" % int(_elapsed)
	if _elapsed >= MAX_SECONDS:
		_stop()


func _exit_tree() -> void:
	# Moving on mid-recording must not leave the microphone open.
	if Game.recording:
		Game.stop_recording()
