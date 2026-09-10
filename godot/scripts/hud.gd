extends CanvasLayer
## HUD com as duas barras e o cronômetro; banner de conclusão com tempo e avaliação
## (etapa 7 do plano — sem dinheiro ainda).

const WIN_GRIME := 0.04
const WIN_RESIDUE := 0.05
const BEST_TIME_PATH := "user://best_time.save"

@onready var clean_bar: ProgressBar = $Margin/VBox/CleanBar
@onready var residue_bar: ProgressBar = $Margin/VBox/ResidueBar
@onready var timer_label: Label = $Margin/VBox/TimerLabel
@onready var banner: Label = $Banner

var window_pane = null
var elapsed := 0.0
var _started := false
var _finished := false

func _ready() -> void:
	banner.visible = false
	var panes := get_tree().get_nodes_in_group("window_pane")
	if not panes.is_empty():
		window_pane = panes[0]

func _process(delta: float) -> void:
	if window_pane == null:
		return

	if not _started and Input.is_action_just_pressed("clean"):
		_started = true

	var st: Dictionary = window_pane.stats()
	clean_bar.value = st.clean * 100.0
	residue_bar.value = (1.0 - st.residue) * 100.0

	if _started and not _finished:
		elapsed += delta
	timer_label.text = _format_time(elapsed)

	if not _finished and st.grime < WIN_GRIME and st.residue < WIN_RESIDUE:
		_finish()

func _finish() -> void:
	_finished = true
	var rating := "Ouro" if elapsed < 30.0 else ("Prata" if elapsed < 60.0 else "Bronze")
	banner.text = "Janela limpa! Tempo: %s — %s" % [_format_time(elapsed), rating]
	banner.visible = true
	_save_best_time(elapsed)

func _format_time(t: float) -> String:
	var m := int(t) / 60
	var s := int(t) % 60
	return "%02d:%02d" % [m, s]

func _save_best_time(t: float) -> void:
	var best := t
	if FileAccess.file_exists(BEST_TIME_PATH):
		var f := FileAccess.open(BEST_TIME_PATH, FileAccess.READ)
		best = minf(f.get_float(), t)
		f.close()
	var fw := FileAccess.open(BEST_TIME_PATH, FileAccess.WRITE)
	fw.store_float(best)
	fw.close()
