extends CanvasLayer

const ObsWebsocket: PackedScene = preload("res://addons/obs_websocket_gd/obs_websocket.tscn")
const ObsUi: PackedScene = preload("res://addons/obs_websocket_gd/obs_ui.tscn")

var obs_websocket: Node
var obs_ui: Control

###############################################################################
# Builtin functions                                                           #
###############################################################################

func _ready() -> void:
	obs_websocket = ObsWebsocket.instance()
	add_child(obs_websocket)
	
	obs_ui = ObsUi.instance()
	add_child(obs_ui)
	
	obs_ui.obs_websocket = obs_websocket
	obs_websocket.establish_connection()

###############################################################################
# Connections                                                                 #
###############################################################################

###############################################################################
# Private functions                                                           #
###############################################################################

###############################################################################
# Public functions                                                            #
###############################################################################
