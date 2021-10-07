tool
extends Control

signal obs_updated(update_data)

const URL_PATH: String = "ws://127.0.0.1:4444"

const POLL_TIME: float = 1.0
var poll_counter: float = 0.0

var obs_client := WebSocketClient.new()

var request_counter: int = -1

###############################################################################
# Builtin functions                                                           #
###############################################################################

func _ready() -> void:
	obs_client.connect("connection_closed", self, "_on_connection_closed")
	obs_client.connect("connection_error", self, "_on_connection_error")
	obs_client.connect("connection_established", self, "_on_connection_established")
	obs_client.connect("data_received", self, "_on_data_received")
	obs_client.connect("server_close_request", self, "_on_server_close_request")
	
	obs_client.verify_ssl = false
	if obs_client.connect_to_url(URL_PATH) != OK:
		print("Could not connect to OBS websocket")

func _process(delta: float) -> void:
	poll_counter += delta
	if poll_counter >= POLL_TIME:
		poll_counter = 0.0
		if obs_client.get_connection_status() != WebSocketClient.CONNECTION_DISCONNECTED:
			obs_client.poll()

###############################################################################
# Connections                                                                 #
###############################################################################

func _on_connection_closed(_was_clean_close: bool) -> void:
	print("OBS connection closed")

func _on_connection_error() -> void:
	print("OBS connection error")

func _on_connection_established(_protocol: String) -> void:
	print("OBS connection established")
	
	obs_client.get_peer(1).set_write_mode(WebSocketPeer.WRITE_MODE_TEXT)
	_get_auth_required()

func _on_data_received() -> void:
	var message: String = obs_client.get_peer(1).get_packet().get_string_from_utf8().strip_edges().strip_escapes()
	
	var json_response = parse_json(message)
	if typeof(json_response) != TYPE_DICTIONARY:
		print("Invalid json_response: %s" % json_response)
		return
	
	if json_response.has("authRequired"):
		var secret_combined: String = "%s%s" % ["password", json_response["salt"]]
		var secret_base64 = Marshalls.raw_to_base64(secret_combined.sha256_buffer())
		var auth_combined: String = "%s%s" % [secret_base64, json_response["challenge"]]
		var auth_base64: String = Marshalls.raw_to_base64(auth_combined.sha256_buffer())
		_authenticate(auth_base64)
	if json_response.has("update-type") and json_response["update-type"] == "StreamStatus":
		return

	print(message)

func _on_server_close_request(_code: int, _reason: String) -> void:
	print("OBS close request received")
	obs_client.disconnect_from_host()

###############################################################################
# Private functions                                                           #
###############################################################################

func _get_auth_required() -> void:
	print("Sending GetAuthRequired message")
	var text := JSON.print({"message-id": _generate_message_id(), "request-type": "GetAuthRequired"})
	
	obs_client.get_peer(1).put_packet(text.to_utf8())

func _authenticate(auth: String) -> void:
	print("Sending auth response")
	var text := JSON.print({"message-id": _generate_message_id(), "request-type": "Authenticate", "auth": auth})
	
	obs_client.get_peer(1).put_packet(text.to_utf8())

func _generate_message_id() -> String:
	request_counter += 1
	return str(request_counter)

###############################################################################
# Public functions                                                            #
###############################################################################

func send_command(command: String, data: Dictionary = {}) -> void:
	data["request-type"] = command
	data["message-id"] = _generate_message_id()
	obs_client.get_peer(1).put_packet(JSON.print(data).to_utf8())
