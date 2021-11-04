tool
extends PanelContainer

const CONNECT_TO_OBS: String = "Connect"
const DISCONNECT_TO_OBS: String = "Disconnect"

const START_STREAMING: String = "Start Streaming"
const STOP_STREAMING: String = "Stop Streaming"

const START_RECORDING: String = "Start Recording"
const STOP_RECORDING: String = "Stop Recording"

var obs_websocket

var scene_data: Dictionary = {} # String: ObsScene

var current_scene: String =  "changeme"

enum ButtonType { NONE = 0, SCENE, SOURCE }

onready var source_items: HBoxContainer = $VBoxContainer/SourceItems
onready var render: CheckButton = $VBoxContainer/SourceItems/Render

onready var scenes: VBoxContainer = $VBoxContainer/HBoxContainer/Scenes/ScenesScroll/VBoxContainer
var scene_button_group := ButtonGroup.new()

onready var sources: VBoxContainer = $VBoxContainer/HBoxContainer/Sources/SourcesScroll/VBoxContainer
var source_buttons := []

onready var connect_button: Button = $VBoxContainer/HBoxContainer/Websocket/Connect
var is_connection_established := false
onready var host_value: LineEdit = $VBoxContainer/HBoxContainer/Websocket/Host/Value
onready var port_value: LineEdit = $VBoxContainer/HBoxContainer/Websocket/Port/Value
onready var password_value: LineEdit = $VBoxContainer/HBoxContainer/Websocket/Password/Value

onready var refresh_data: Button = $VBoxContainer/HBoxContainer/Websocket/RefreshData

onready var stream: Button = $VBoxContainer/HBoxContainer/Controls/Stream
var is_streaming := false
onready var record: Button = $VBoxContainer/HBoxContainer/Controls/Record
var is_recording := false

onready var engine_version: Dictionary = Engine.get_version_info()

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
	password_value.text = obs_websocket.password
	
	password_value.connect("text_entered", self, "_on_password_text_entered")
	
	connect_button.connect("pressed", self, "_on_connect_pressed")
	
	refresh_data.connect("pressed", self, "_on_refresh_data_pressed")
	
	stream.text = START_STREAMING
	stream.connect("pressed", self, "_on_stream_pressed")
	
	record.text = START_RECORDING
	record.connect("pressed", self, "_on_record_pressed")
	
	

func _exit_tree() -> void:
	obs_websocket.free()

###############################################################################
# Connections                                                                 #
###############################################################################

func _on_password_text_entered(kastring)->void:
	_on_connect_pressed()

func _on_connect_pressed() -> void:
	if (host_value.text.empty() or port_value.text.empty()):
		return
	
	obs_websocket.host = host_value.text
	obs_websocket.port = port_value.text
	obs_websocket.password = password_value.text
	
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
	if (obs_data.has("update-type") and 
		(obs_data["update-type"] == "SceneItemVisibilityChanged" or obs_data["update-type"] == "TransitionEnd")):
		yield(get_tree(), "idle_frame")
		_on_refresh_data_pressed()
	print(obs_data)


func _on_obs_connected() -> void:
	obs_websocket.get_scene_list()

func _on_refresh_data_pressed() -> void:
	if obs_websocket.obs_client.get_connection_status() != WebSocketClient.CONNECTION_CONNECTED:
		return
	obs_websocket.get_scene_list()

func _on_obs_scene_list_returned(data) -> void:
	current_scene = data.current_scene
	
	scene_data.clear()
	
	for child in scenes.get_children():
		child.queue_free()
	
	for child in sources.get_children():
		child.queue_free()

	
	for i in data.scenes:
		var scene_button := CheckButton.new()
		scene_button.text = i.obs_name
		if scene_button.text == current_scene:
			if engine_version.major == 3:
				if engine_version.minor >= 4:
					scene_button.set_pressed_no_signal(true)
				else:
					scene_button.pressed = true
			else:
				print_debug("Unsupported engine version, exiting")
				get_tree().quit()
		scene_button.group = scene_button_group
		scene_button.connect("toggled", self, "_on_button_toggled_with_name", [scene_button.text, ButtonType.SCENE])
		scenes.call_deferred("add_child", scene_button)
		
		if i.obs_name == current_scene:
			for j in i.sources:
				_create_source_button(j.obs_name,j.render)
		
		scene_data[i.obs_name] = i

func _on_source_item_toggled(button_state: bool, button_name: String  ) -> void:
	obs_websocket.send_command("SetSceneItemRender", {
		"source": button_name,
		"render": button_state
	})
	
func _on_button_toggled_with_name(button_pressed: bool, button_name: String, button_type: int) -> void:
	# Buttons cannot be unpressed with a button group I guess, so just match positives
	if not button_pressed:
		return
	match button_type:
		ButtonType.SCENE:
			source_items.visible = false
			obs_websocket.send_command("SetCurrentScene", {"scene-name": button_name})
			for child in sources.get_children():
				child.free()
			for i in scene_data[button_name].sources:
				_create_source_button(i.obs_name, i.render)

###############################################################################
# Private functions                                                           #
###############################################################################

func _create_source_button(button_name: String, button_render: bool) -> void:
	var source_button := CheckButton.new()
	source_button.text = button_name
	source_button.set_pressed_no_signal(button_render)
	source_buttons.append(source_button)
	source_button.connect("toggled", self, "_on_source_item_toggled", [button_name])
	sources.call_deferred("add_child", source_button)


###############################################################################
# Public functions                                                            #
###############################################################################
