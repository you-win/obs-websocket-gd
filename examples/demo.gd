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
	
	obs_websocket.connect("obs_data_received",Callable(self,"_on_obs_data_received"))
	
#	obs_ui = ObsUi.instantiate()
#	add_child(obs_ui)
	
#	obs_ui.obs_websocket = obs_websocket
	obs_websocket.establish_connection()
	
	await obs_websocket.obs_authenticated
	
	obs_websocket.send_command("GetVersion")

###############################################################################
# Connections                                                                 #
###############################################################################

func _on_obs_data_received(data):
	print(data.get_as_json())

###############################################################################
# Private functions                                                           #
###############################################################################

###############################################################################
# Public functions                                                            #
###############################################################################
