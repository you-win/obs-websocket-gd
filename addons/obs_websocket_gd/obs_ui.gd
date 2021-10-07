tool
extends PanelContainer

const START_STREAMING: String = "Start Streaming"
const STOP_STREAMING: String = "Stop Streaming"

const START_RECORDING: String = "Start Recording"
const STOP_RECORDING: String = "Stop Recording"

var obs_websocket

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
	
	stream.text = START_STREAMING
	stream.connect("pressed", self, "_on_stream_pressed")
	
	record.text = START_RECORDING
	record.connect("pressed", self, "_on_record_pressed")

func _exit_tree() -> void:
	obs_websocket.free()

###############################################################################
# Connections                                                                 #
###############################################################################

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

func _on_obs_updated(obs_data_string: String) -> void:
	pass

###############################################################################
# Private functions                                                           #
###############################################################################

###############################################################################
# Public functions                                                            #
###############################################################################
