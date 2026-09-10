extends CanvasLayer
## HUD mínimo pro MVP: só a barra de limpeza e o aviso quando a janela bate 100%.
## Sem tempo/pontuação — isso é MVP pra testar se limpar vidro é divertido, não corrida.

const WIN_CLEAN := 0.999

@onready var clean_bar: ProgressBar = $Margin/VBox/CleanBar
@onready var tool_label: Label = $Margin/VBox/ToolLabel
@onready var banner: Label = $Banner

var window_pane = null
var player = null
var _finished := false

func _ready() -> void:
	banner.visible = false
	var panes := get_tree().get_nodes_in_group("window_pane")
	if not panes.is_empty():
		window_pane = panes[0]
	var players := get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		player = players[0]

func _process(_delta: float) -> void:
	if player != null:
		tool_label.text = "Ferramenta: %s" % player.TOOL_NAMES[player.active_tool_index]

	if window_pane == null:
		return
	var st: Dictionary = window_pane.stats()
	clean_bar.value = st.clean * 100.0
	if not _finished and st.clean >= WIN_CLEAN:
		_finish()

func _finish() -> void:
	_finished = true
	banner.text = "Janela limpa!"
	banner.visible = true
