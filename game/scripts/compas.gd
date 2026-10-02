extends VBoxContainer
## A small flamenco compás demo: the counts light up in a row, the accented
## ones get a loud clap, and the player can clap along.

const PALOS := {
	"solea": {"label": "Soleá: doce tiempos, acentos en 3, 6, 8, 10 y 12",
		"counts": 12, "accents": [3, 6, 8, 10, 12], "bpm": 96.0},
	"bulerias": {"label": "Bulerías: los mismos doce tiempos, mucho más rápido",
		"counts": 12, "accents": [3, 6, 8, 10, 12], "bpm": 190.0},
	"tangos": {"label": "Tangos: cuatro tiempos, acentos en 2, 3 y 4",
		"counts": 4, "accents": [2, 3, 4], "bpm": 120.0},
}
const WINDOW := 0.14    # seconds either side of an accent that count as on the beat

var palo := "solea"
var _cfg: Dictionary
var _playing := false
var _time := 0.0
var _beat := -1
var _hits := 0
var _row: Control
var _score: Label
var _toggle: Button
var _strong: AudioStreamPlayer
var _soft: AudioStreamPlayer
var _hand: AudioStreamPlayer


func _ready() -> void:
	_cfg = PALOS.get(palo, PALOS.solea)
	add_theme_constant_override("separation", 6)
	add_child(UI.label(_cfg.label, 17, UI.INK, "bold"))
	_row = Control.new()
	_row.custom_minimum_size = Vector2(0, 52)
	_row.draw.connect(_draw_row)
	add_child(_row)

	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	_toggle = UI.button("Empezar", "ghost", UI.RED)
	_toggle.pressed.connect(_on_toggle)
	h.add_child(_toggle)
	var clap := UI.button("¡Palma!  (tecla P)", "ghost", UI.INK)
	clap.focus_mode = Control.FOCUS_NONE
	clap.pressed.connect(_clap)
	h.add_child(clap)
	_score = UI.label("Da una palma en cada acento.", 15, UI.MUTED)
	h.add_child(_score)
	add_child(h)

	_strong = _player(_make_clap(0.9, 0.020))
	_soft = _player(_make_clap(0.28, 0.010))
	_hand = _player(_make_clap(0.6, 0.014))


func _player(stream: AudioStream) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = stream
	add_child(p)
	return p


## A clap is close enough to a burst of noise with a fast decay.
func _make_clap(level: float, decay: float) -> AudioStreamWAV:
	var rate := 22050
	var n := int(rate * 0.09)
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in n:
		var env := exp(-float(i) / (rate * decay))
		var v: float = clamp(rng.randf_range(-1.0, 1.0) * env * level, -1.0, 1.0)
		data.encode_s16(i * 2, int(v * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = data
	return w


func _on_toggle() -> void:
	_playing = not _playing
	_toggle.text = "Parar" if _playing else "Empezar"
	_time = 0.0
	_beat = -1
	_hits = 0
	_row.queue_redraw()


func _process(delta: float) -> void:
	if not _playing:
		return
	_time += delta
	var beat := int(_time * _cfg.bpm / 60.0)
	if beat != _beat:
		_beat = beat
		if (_beat % int(_cfg.counts)) + 1 in _cfg.accents:
			_strong.play()
		else:
			_soft.play()
		_row.queue_redraw()


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_P:
		_clap()


func _clap() -> void:
	_hand.play()
	if not _playing:
		return
	var period: float = 60.0 / _cfg.bpm
	var nearest := int(round(_time / period))
	var off: float = abs(_time - nearest * period)
	if off <= WINDOW and (nearest % int(_cfg.counts)) + 1 in _cfg.accents:
		_hits += 1
		_score.text = "¡Olé!  Palmas a compás: %d" % _hits
	else:
		_score.text = "Fuera de compás. Palmas a compás: %d" % _hits


func _draw_row() -> void:
	var n := int(_cfg.counts)
	var step: float = min(56.0, _row.size.x / n)
	var now := (_beat % n) + 1 if _playing and _beat >= 0 else 0
	for i in range(1, n + 1):
		var c := Vector2((i - 0.5) * step, 26)
		var accent: bool = i in _cfg.accents
		var r := 20.0 if accent else 14.0
		var col := UI.RED if accent else UI.SAND
		if i == now:
			col = UI.GOLD
			r += 3.0
		_row.draw_circle(c, r, col)
		var txt := str(i)
		var w := UI.font("bold").get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		_row.draw_string(UI.font("bold"), c + Vector2(-w / 2.0, 5), txt,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color.WHITE if accent or i == now else UI.INK)
