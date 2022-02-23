extends CanvasLayer

const ObsWebsocket: GDScript = preload("res://addons/obs-websocket-gd/obs_websocket.gd")
#const ObsUi: PackedScene = preload("res://addons/obs_websocket_gd/obs_ui.tscn")

var obs_websocket: Node
var obs_ui: Control

###############################################################################
# Builtin functions                                                           #
###############################################################################

func _ready() -> void:
	obs_websocket = ObsWebsocket.new()
	add_child(obs_websocket)
	
#	obs_ui = ObsUi.instance()
#	add_child(obs_ui)
	
#	obs_ui.obs_websocket = obs_websocket
	obs_websocket.establish_connection()
	
	yield(obs_websocket, "obs_authenticated")
	
	obs_websocket.send_command("GetVersion")

###############################################################################
# Connections                                                                 #
###############################################################################

###############################################################################
# Private functions                                                           #
###############################################################################

###############################################################################
# Public functions                                                            #
###############################################################################
