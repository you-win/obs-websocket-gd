tool
extends PanelContainer

const CONNECT_TO_OBS: String = "Connect"
const DISCONNECT_TO_OBS: String = "Disconnect"

const START_STREAMING: String = "Start Streaming"
const STOP_STREAMING: String = "Stop Streaming"

const START_RECORDING: String = "Start Recording"
const STOP_RECORDING: String = "Stop Recording"

var obs_websocket

var current_scene: String =  "changeme"
onready var scenes: VBoxContainer = $VBoxContainer/HBoxContainer/Scenes

onready var sources: VBoxContainer = $VBoxContainer/HBoxContainer/Sources

onready var connect_button: Button = $VBoxContainer/HBoxContainer/Websocket/Connect
var is_connection_established := false
onready var host_value: LineEdit = $VBoxContainer/HBoxContainer/Websocket/Host/Value
onready var port_value: LineEdit = $VBoxContainer/HBoxContainer/Websocket/Port/Value

onready var stream: Button = $VBoxContainer/HBoxContainer/Controls/Stream
var is_streaming := false
onready var record: Button = $VBoxContainer/HBoxContainer/Controls/Record
var is_recording := false

###############################################################################
# Builtin functions                                                           #
###############################################################################

func _ready():
	obs_websocket = load("res://addons/obs_websocket_gd/obs_websocket.tscn").instance()
	add_child(obs_websocket)
	obs_websocket.connect("obs_updated", self, "_on_obs_updated")
	obs_websocket.connect("obs_connected", self, "_on_obs_connected")
	obs_websocket.connect("obs_scene_list_returned", self, "_on_obs_scene_list_returned")
	
	# Setup connection values from script
	host_value.text = obs_websocket.host
	port_value.text = obs_websocket.port
	
	connect_button.connect("pressed", self, "_on_connect_pressed")
	
	stream.text = START_STREAMING
	stream.connect("pressed", self, "_on_stream_pressed")
	
	record.text = START_RECORDING
	record.connect("pressed", self, "_on_record_pressed")

func _exit_tree() -> void:
	obs_websocket.free()

###############################################################################
# Connections                                                                 #
###############################################################################

func _on_connect_pressed() -> void:
	if (host_value.text.empty() or port_value.text.empty()):
		return
	
	obs_websocket.host = host_value.text
	obs_websocket.port = port_value.text
	
	match is_connection_established:
		true:
			obs_websocket.break_connection()
			connect_button.text = CONNECT_TO_OBS
		false:
			obs_websocket.establish_connection()
			connect_button.text = DISCONNECT_TO_OBS
	
	is_connection_established = not is_connection_established

func _on_stream_pressed() -> void:
	match is_streaming:
		true:
			obs_websocket.send_command("StopStreaming")
			stream.text = START_STREAMING
		false:
			obs_websocket.send_command("StartStreaming")
			stream.text = STOP_STREAMING
	
	is_streaming = not is_streaming

func _on_record_pressed() -> void:
	match is_recording:
		true:
			obs_websocket.send_command("StopRecording")
			record.text = START_RECORDING
		false:
			obs_websocket.send_command("StartRecording")
			record.text = STOP_RECORDING
	
	is_recording = not is_recording

func _on_obs_updated(obs_data: Dictionary) -> void:
	
	print(obs_data)

func _on_obs_connected() -> void:
	obs_websocket.get_scene_list()

func _on_obs_scene_list_returned(data) -> void:
	print("asdf")
	current_scene = data.current_scene
	
	for child in scenes.get_children():
		child.queue_free()
	
	for i in data.scenes:
		var button := Button.new()
		button.text = i.obs_name
		scenes.call_deferred("add_child", button)

###############################################################################
# Private functions                                                           #
###############################################################################

###############################################################################
# Public functions                                                            #
###############################################################################
