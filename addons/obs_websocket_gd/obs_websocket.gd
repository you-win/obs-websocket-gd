extends Control

signal obs_connected()
signal obs_updated(data)
signal obs_scene_list_returned(data)

class ObsObject:
	var obs_name: String = "changeme"
	
	func _to_string() -> String:
		return obs_name

class ObsGetSceneListResponse:
	var current_scene: String
	var scenes: Array = [] # ObsScene
	
	func _to_string() -> String:
		return str({
			"current_scene": current_scene,
			"scenes": scenes
		})

class ObsScene extends ObsObject:
	var sources: Array = [] # ObsSceneItem
	
	func _to_string() -> String:
		return str({
			"obs_name": obs_name,
			"sources": sources
		})

class ObsSceneItem extends ObsObject:
	var cy: float
	var cx: float
	var alignment: float
	var id: int
	var render: bool
	var muted: bool
	var locked: bool
	var source_cx: float
	var source_cy: float
	var obs_type: String
	var volume: float
	var x: float
	var y: float
	# NOT YET IMPLMENTED
	# var parent_group_name: String # Optional
	# var group_children: Array # ObsSceneItem Optional
	
	func _init(
		p_cy: float,
		p_cx: float,
		p_alignment: float,
		p_name: String,
		p_id: int,
		p_render: bool,
		p_muted: bool,
		p_locked: bool,
		p_source_cx: float,
		p_source_cy: float,
		p_obs_type: String,
		p_volume: float,
		p_x: float,
		p_y: float,
		p_parent_group_name: String = "",
		p_group_children: Array = []
	) -> void:
		cy = p_cy
		cx = p_cx
		alignment = p_alignment
		obs_name = p_name
		id = p_id
		render = p_render
		muted = p_muted
		locked = p_locked
		source_cx = p_source_cx
		source_cy = p_source_cy
		obs_type = p_obs_type
		volume = p_volume
		x = p_x
		y = p_y
		# parent_group_name = p_parent_group_name
		# group_children = p_group_children
	
	func _to_string() -> String:
		return str({
			"cy": cy,
			"cx": cx,
			"alignment": alignment,
			"obs_name": obs_name,
			"id": id,
			"render": render,
			"muted": muted,
			"locked": locked,
			"source_cx": source_cx,
			"source_cy": source_cy,
			"obs_type": obs_type,
			"volume": volume,
			"x": x,
			"y": y
		})

#region OpCode model

#region Base objects

class ObsMessage:
	const NO_NEED_TO_PARSE := "There is no need to parse Identify since all values are passed to new(...)"

	var op: int
	var d: Dictionary
	
	func parse(data: Dictionary) -> void:
		op = data["op"]
		d = data["d"]

	func get_as_json(skip_empty: bool = false) -> String:
		var json := {}
		for i in get_property_list():
			var prop_name: String = i["name"]
			if prop_name in ["Object", "Reference", "script", "Script Variables"]:
				continue
			
			var prop = get(prop_name)
			
			if skip_empty:
				match typeof(prop):
					TYPE_ARRAY, TYPE_DICTIONARY:
						if prop.empty():
							continue
			
			json[prop_name] = get(prop_name)
		
		return JSON.print(json, "\t")

class ClientObsMessage extends ObsMessage:
	func parse(_data: Dictionary) -> void:
		printerr(NO_NEED_TO_PARSE)

class ServerObsMessage extends ObsMessage:
	func parse(data: Dictionary) -> void:
		.parse(data)

#endregion

#region Initialization

class Hello extends ServerObsMessage:
	"""
	FROM obs
	TO client
	"""
	var obs_websocket_version: String
	var rpc_version: int
	var authentication: Authentication

	func parse(data: Dictionary) -> void:
		.parse(data)

		obs_websocket_version = d["obsWebSocketVersion"]
		rpc_version = d["rpcVersion"]
		authentication = Authentication.new(d["authentication"]) if d.has("authentication") else null

class Authentication:
	var challenge: String
	var salt: String

	func _init(data: Dictionary) -> void:
		challenge = data["challenge"]
		salt = data["salt"]

#endregion

#region Identification

class Identify extends ClientObsMessage:
	"""
	FROM client
	TO obs

	event_subscriptions is a bitmask
	"""
	var rpc_version: int
	var authentication: String
	var event_subscriptions: int

	func _init(p_rpc_version: int, p_authentication: String, p_event_subscriptions: int = 33) -> void:
		op = 1

		rpc_version = p_rpc_version
		authentication = p_authentication
		event_subscriptions = p_event_subscriptions

class Identified extends ServerObsMessage:
	"""
	FROM obs
	TO client
	"""
	var negotiated_rpc_version: int

	func parse(data: Dictionary) -> void:
		.parse(data)

		negotiated_rpc_version = d["negotiatedRpcVersion"]

class Reidentify extends ClientObsMessage:
	"""
	FROM client
	TO obs

	event subscriptions is a bitmask
	"""
	var event_subscriptions: int

	func _init(p_event_subscriptions: int = 33) -> void:
		op = 3
		
		event_subscriptions = p_event_subscriptions

#endregion

#region Event

class Event extends ServerObsMessage:
	"""
	FROM obs
	TO client

	event_data is optional and could be anything, so just store it wholesale. This means that all keys are still
	camel-case not snake-case
	"""
	var event_type: String
	var event_intent: int
	var event_data: Dictionary

	func parse(data: Dictionary) -> void:
		.parse(data)

		event_type = d["eventType"]
		event_intent = d["eventIntent"]
		event_data = d["eventData"] if d.has("eventData") else {}

#endregion

#region Request

class Request extends ClientObsMessage:
	"""
	FROM client
	TO obs

	request_data is optional and could be anything. All values need to be camel-cased
	"""
	var request_type: String
	var request_id: String
	var request_data: Dictionary

	func _init(p_request_type: String, p_request_id: String, p_request_data: Dictionary = {}) -> void:
		op = 6

		request_type = p_request_type
		request_id = p_request_id
		request_data = p_request_data

class RequestResponse extends ObsMessage:
	"""
	FROM obs
	TO client

	response_data is optional
	"""
	var request_type: String
	var request_id: String
	var request_status: RequestStatus
	var response_data: Dictionary

	func parse(data: Dictionary) -> void:
		.parse(data)

		request_type = d["requestType"]
		request_id = d["requestId"]
		request_status = RequestStatus.new(d["requestStatus"])

class RequestStatus:
	# true if the request was successful
	var result: bool
	var code: int
	# Optional, provided by server on error
	var comment: String

	func _init(data: Dictionary) -> void:
		result = data["result"]
		code = data["code"]
		comment = data["comment"] if data.has("comment") else ""

#endregion

#region RequestBatch

class RequestBatch extends ClientObsMessage:
	"""
	FROM client
	TO obs

	Requests are processed in order by obs-websocket. requests is an array of dictionaries

	halt_on_failure and execution_type are technically optional

	When halt_on_failure is true, the RequestBatchResponse will contain only the successfully processed requests
	"""
	var request_id: String
	var halt_on_failure: bool
	var execution_type: int
	var requests: Array
	
	func _init(
			p_request_id: String,
			p_requests: Array,
			p_halt_on_failure: bool = false,
			p_execution_type: int = 0) -> void:
		op = 8

		request_id = p_request_id
		halt_on_failure = p_halt_on_failure
		execution_type = p_execution_type
		requests = p_requests

class RequestBatchResponse extends ServerObsMessage:
	"""
	FROM obs
	TO client

	results is an array of dictionaries
	"""
	var request_id: String
	var results: Array

	func parse(data: Dictionary) -> void:
		.parse(data)

		request_id = d["requestId"]
		results = d["results"]

#endregion

#endregion

#region OpCode enums

const OpCodeEnums := {
	"WebSocketOpCode": {
		"Hello": {
			"IDENTIFIER_VALUE": 0,
			"LATEST_SUPPORTED_RPC_VERSION": 1
		},

		"Identify": {
			"IDENTIFIER_VALUE": 1,
			"LATEST_SUPPORTED_RPC_VERSION": 1
		},

		"Identified": {
			"IDENTIFIER_VALUE": 2,
			"LATEST_SUPPORTED_RPC_VERSION": 1
		},

		"Reidentify": {
			"IDENTIFIER_VALUE": 3,
			"LATEST_SUPPORTED_RPC_VERSION": 1
		},

		"Event": {
			"IDENTIFIER_VALUE": 5,
			"LATEST_SUPPORTED_RPC_VERSION": 1
		},

		"Request": {
			"IDENTIFIER_VALUE": 6,
			"LATEST_SUPPORTED_RPC_VERSION": 1
		},

		"RequestResponse": {
			"IDENTIFIER_VALUE": 7,
			"LATEST_SUPPORTED_RPC_VERSION": 1
		},

		"RequestBatch": {
			"IDENTIFIER_VALUE": 8,
			"LATEST_SUPPORTED_RPC_VERSION": 1
		},

		"RequestBatchResponse": {
			"IDENTIFIER_VALUE": 9,
			"LATEST_SUPPORTED_RPC_VERSION": 1
		}
	},

	"WebSocketCloseCode": {
		"DontClose": {
			"IDENTIFER_VALUE": 0,
			"LATEST_SUPPORTED_RPC_VERSION": 1
		},
		"UnknownReason": {
			"IDENTIFER_VALUE": 4000,
			"LATEST_SUPPORTED_RPC_VERSION": 1
		},
		"MessageDecodeError": {
			"IDENTIFER_VALUE": 4002,
			"LATEST_SUPPORTED_RPC_VERSION": 1
		},
		"MissingDataField": {
			"IDENTIFER_VALUE": 4003,
			"LATEST_SUPPORTED_RPC_VERSION": 1
		},
		"InvalidDataFieldType": {
			"IDENTIFER_VALUE": 4004,
			"LATEST_SUPPORTED_RPC_VERSION": 1
		},
		"InvalidDataFieldValue": {
			"IDENTIFER_VALUE": 4005,
			"LATEST_SUPPORTED_RPC_VERSION": 1
		},
		"UnknownOpCode": {
			"IDENTIFER_VALUE": 4006,
			"LATEST_SUPPORTED_RPC_VERSION": 1
		},
		"NotIdentified": {
			"IDENTIFER_VALUE": 4007,
			"LATEST_SUPPORTED_RPC_VERSION": 1
		},
		"AlreadyIdentified": {
			"IDENTIFER_VALUE": 4008,
			"LATEST_SUPPORTED_RPC_VERSION": 1
		},
		"AuthenticationFailed": {
			"IDENTIFER_VALUE": 4009,
			"LATEST_SUPPORTED_RPC_VERSION": 1
		},
		"UnsupportedRpcVersion": {
			"IDENTIFER_VALUE": 4010,
			"LATEST_SUPPORTED_RPC_VERSION": 1
		},
		"SessionInvalidated": {
			"IDENTIFER_VALUE": 4011,
			"LATEST_SUPPORTED_RPC_VERSION": 1
		},
		"UnsupportedFeature": {
			"IDENTIFER_VALUE": 4012,
			"LATEST_SUPPORTED_RPC_VERSION": 1
		},
	},

	"RequestBatchExecutionType": {
		"None": {
			"IDENTIFER_VALUE": -1,
			"LATEST_SUPPORTED_RPC_VERSION": 1
		},
		"SerialRealtime": {
			"IDENTIFER_VALUE": 0,
			"LATEST_SUPPORTED_RPC_VERSION": 1
		},
		"SerialFrame": {
			"IDENTIFER_VALUE": 1,
			"LATEST_SUPPORTED_RPC_VERSION": 1
		},
		"Parallel": {
			"IDENTIFER_VALUE": 2,
			"LATEST_SUPPORTED_RPC_VERSION": 1
		},
	},

	"RequestStatus": {
		"Unknown": {
			"IDENTIFER_VALUE": 0,
			"LATEST_SUPPORTED_RPC_VERSION": 1
		},
		"NoError": {
			"IDENTIFER_VALUE": 10,
			"LATEST_SUPPORTED_RPC_VERSION": 1
		},
		"Success": {
			"IDENTIFER_VALUE": 100,
			"LATEST_SUPPORTED_RPC_VERSION": 1
		},
		"MissingRequestType": {
			"IDENTIFER_VALUE": 203,
			"LATEST_SUPPORTED_RPC_VERSION": 1
		},
		"UnknownRequestType": {
			"IDENTIFER_VALUE": 204,
			"LATEST_SUPPORTED_RPC_VERSION": 1
		},
		"GenericError": {
			"IDENTIFER_VALUE": 205,
			"LATEST_SUPPORTED_RPC_VERSION": 1
		},
		"UnsupportedRequestBatchExecutionType": {
			"IDENTIFER_VALUE": 206,
			"LATEST_SUPPORTED_RPC_VERSION": 1
		},
		"MissingRequestField": {
			"IDENTIFER_VALUE": 300,
			"LATEST_SUPPORTED_RPC_VERSION": 1
		},
		"MissingRequestData": {
			"IDENTIFER_VALUE": 301,
			"LATEST_SUPPORTED_RPC_VERSION": 1
		},
		"InvalidRequestField": {
			"IDENTIFER_VALUE": 400,
			"LATEST_SUPPORTED_RPC_VERSION": 1
		},
		"InvalidRequestFieldType": {
			"IDENTIFER_VALUE": 401,
			"LATEST_SUPPORTED_RPC_VERSION": 1
		},
		"RequestFieldOutOfRange": {
			"IDENTIFER_VALUE": 402,
			"LATEST_SUPPORTED_RPC_VERSION": 1
		},
		"RequestFieldEmpty": {
			"IDENTIFER_VALUE": 403,
			"LATEST_SUPPORTED_RPC_VERSION": 1
		},
		"TooManyRequestFields": {
			"IDENTIFER_VALUE": 404,
			"LATEST_SUPPORTED_RPC_VERSION": 1
		},
		"OutputRunning": {
			"IDENTIFER_VALUE": 500,
			"LATEST_SUPPORTED_RPC_VERSION": 1
		},
		"OutputNotRunning": {
			"IDENTIFER_VALUE": 501,
			"LATEST_SUPPORTED_RPC_VERSION": 1
		},
		"OutputPaused": {
			"IDENTIFER_VALUE": 502,
			"LATEST_SUPPORTED_RPC_VERSION": 1
		},
		"OutputNotPaused": {
			"IDENTIFER_VALUE": 503,
			"LATEST_SUPPORTED_RPC_VERSION": 1
		},
		"OutputDisabled": {
			"IDENTIFER_VALUE": 504,
			"LATEST_SUPPORTED_RPC_VERSION": 1
		},
		"StudioModeActive": {
			"IDENTIFER_VALUE": 505,
			"LATEST_SUPPORTED_RPC_VERSION": 1
		},
		"StudioModeNotActive": {
			"IDENTIFER_VALUE": 506,
			"LATEST_SUPPORTED_RPC_VERSION": 1
		},
		"ResourceNotFound": {
			"IDENTIFER_VALUE": 600,
			"LATEST_SUPPORTED_RPC_VERSION": 1
		},
		"ResourceAlreadyExists": {
			"IDENTIFER_VALUE": 601,
			"LATEST_SUPPORTED_RPC_VERSION": 1
		},
		"InvalidResourceType": {
			"IDENTIFER_VALUE": 602,
			"LATEST_SUPPORTED_RPC_VERSION": 1
		},
		"NotEnoughResources": {
			"IDENTIFER_VALUE": 603,
			"LATEST_SUPPORTED_RPC_VERSION": 1
		},
		"InvalidResourceState": {
			"IDENTIFER_VALUE": 604,
			"LATEST_SUPPORTED_RPC_VERSION": 1
		},
		"InvalidInputKind": {
			"IDENTIFER_VALUE": 605,
			"LATEST_SUPPORTED_RPC_VERSION": 1
		},
		"ResourceNotConfigurable": {
			"IDENTIFER_VALUE": 606,
			"LATEST_SUPPORTED_RPC_VERSION": 1
		},
		"ResourceCreationFailed": {
			"IDENTIFER_VALUE": 700,
			"LATEST_SUPPORTED_RPC_VERSION": 1
		},
		"ResourceActionFailed": {
			"IDENTIFER_VALUE": 701,
			"LATEST_SUPPORTED_RPC_VERSION": 1
		},
		"RequestProcessingFailed": {
			"IDENTIFER_VALUE": 702,
			"LATEST_SUPPORTED_RPC_VERSION": 1
		},
		"CannotAct": {
			"IDENTIFER_VALUE": 703,
			"LATEST_SUPPORTED_RPC_VERSION": 1
		},
	},

	"EventSubscription": {
		"None": {
			"IDENTIFER_VALUE": 0,
			"LATEST_SUPPORTED_RPC_VERSION": 1
		},
		"General": {
			"IDENTIFER_VALUE": 1 << 0,
			"LATEST_SUPPORTED_RPC_VERSION": 1
		},
		"Config": {
			"IDENTIFER_VALUE": 1 << 1,
			"LATEST_SUPPORTED_RPC_VERSION": 1
		},
		"Scenes": {
			"IDENTIFER_VALUE": 1 << 2,
			"LATEST_SUPPORTED_RPC_VERSION": 1
		},
		"Inputs": {
			"IDENTIFER_VALUE": 1 << 3,
			"LATEST_SUPPORTED_RPC_VERSION": 1
		},
		"Transitions": {
			"IDENTIFER_VALUE": 1 << 4,
			"LATEST_SUPPORTED_RPC_VERSION": 1
		},
		"Filters": {
			"IDENTIFER_VALUE": 1 << 5,
			"LATEST_SUPPORTED_RPC_VERSION": 1
		},
		"Outputs": {
			"IDENTIFER_VALUE": 1 << 6,
			"LATEST_SUPPORTED_RPC_VERSION": 1
		},
		"SceneItems": {
			"IDENTIFER_VALUE": 1 << 7,
			"LATEST_SUPPORTED_RPC_VERSION": 1
		},
		"MediaInputs": {
			"IDENTIFER_VALUE": 1 << 8,
			"LATEST_SUPPORTED_RPC_VERSION": 1
		},
		"Vendors": {
			"IDENTIFER_VALUE": 1 << 9,
			"LATEST_SUPPORTED_RPC_VERSION": 1
		},
		"Ui": {
			"IDENTIFER_VALUE": 1 << 10,
			"LATEST_SUPPORTED_RPC_VERSION": 1
		},
		"All": {
			"IDENTIFER_VALUE": (
				1 << 0 | # General
				1 << 1 | # Config
				1 << 2 | # Scenes
				1 << 3 | # Inputs
				1 << 4 | # Transitions
				1 << 5 | # Filters
				1 << 6 | # Outputs
				1 << 7 | # SceneItems
				1 << 8 | # MediaInputs
				1 << 9 # Vendors
			),
			"LATEST_SUPPORTED_RPC_VERSION": 1
		},
		"InputVolumeMeters": {
			"IDENTIFER_VALUE": 1 << 16,
			"LATEST_SUPPORTED_RPC_VERSION": 1
		},
		"InputActiveStateChanged": {
			"IDENTIFER_VALUE": 1 << 17,
			"LATEST_SUPPORTED_RPC_VERSION": 1
		},
		"InputShowStateChanged": {
			"IDENTIFER_VALUE": 1 << 18,
			"LATEST_SUPPORTED_RPC_VERSION": 1
		},
		"SceneItemTransformChanged": {
			"IDENTIFER_VALUE": 1 << 19,
			"LATEST_SUPPORTED_RPC_VERSION": 1
		},
	}
}

#endregion

const URL_PATH: String = "ws://%s:%s"

const POLL_TIME: float = 1.0
var poll_counter: float = 0.0

var logger = preload("res://addons/obs_websocket_gd/logger.gd").new()

var obs_client := WebSocketClient.new()

var request_counter: int = -1

export var host: String = "127.0.0.1"
export var port: String = "4444"
export var password: String = "" # It's plaintext lmao, you should be changing this programmatically

const PreconfiguredCommands = {
	"GET_SCENE_LIST": "GetSceneList"
}
var last_command: String = "n/a"
var waiting_for_response := false

###############################################################################
# Builtin functions                                                           #
###############################################################################

func _ready() -> void:
	logger.setup(self)

	obs_client.connect("connection_closed", self, "_on_connection_closed")
	obs_client.connect("connection_error", self, "_on_connection_error")
	obs_client.connect("connection_established", self, "_on_connection_established")
	obs_client.connect("data_received", self, "_on_data_received")
	obs_client.connect("server_close_request", self, "_on_server_close_request")
	
	obs_client.verify_ssl = false

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
	logger.info("OBS connection closed")

func _on_connection_error() -> void:
	logger.info("OBS connection error")

func _on_connection_established(protocol: String) -> void:
	logger.info("OBS connection established with protocol: %s" % protocol)
	
	obs_client.get_peer(1).set_write_mode(WebSocketPeer.WRITE_MODE_TEXT)

func _on_hello_received() -> void:
	var message: String = obs_client.get_peer(1).get_packet().get_string_from_utf8().strip_edges()
	
	var json_result: JSONParseResult = JSON.parse(message)
	if json_result.error != OK:
		logger.error("Unable to parse Hello from obs-websocket: %s\nAborting connection" % message)
		return
	
	var result = json_result
	if typeof(result) != TYPE_DICTIONARY:
		logger.error("Unexpected data from obs-websocket: %s\nAborting connection" % str(result))
		return
	
	if result["op"] != 0:
		logger.error("Unexpected op code from obs-websocket: %s\nAborting connection" % JSON.print(result, "\t"))
		return
	
	_identify(result)

func _on_data_received() -> void:
	var message: String = obs_client.get_peer(1).get_packet().get_string_from_utf8().strip_edges().strip_escapes()
	
	var json_response = parse_json(message)
	if typeof(json_response) != TYPE_DICTIONARY:
		print("Invalid json_response: %s" % json_response)
		return
		
	if json_response.has("error"):
		print(json_response)
		print("Error: %s" % json_response["error"])
	
	if json_response.has("authRequired"):
		var secret_combined: String = "%s%s" % [password, json_response["salt"]]
		var secret_base64 = Marshalls.raw_to_base64(secret_combined.sha256_buffer())
		var auth_combined: String = "%s%s" % [secret_base64, json_response["challenge"]]
		var auth_base64: String = Marshalls.raw_to_base64(auth_combined.sha256_buffer())
		_authenticate(auth_base64)
		return
	elif (json_response.has("message-id") and json_response["message-id"] == "1"):
		if json_response["status"] == "ok":
			emit_signal("obs_connected")
			return
	elif json_response.has("update-type") and json_response["update-type"] == "StreamStatus":
		return

	else:
		if waiting_for_response:
			match last_command:
				PreconfiguredCommands.GET_SCENE_LIST:
					# Courtesy null check
					if (not json_response.has("current-scene") or not json_response.has("scenes")):
						printerr("Invalid response from obs")
						return

					last_command = "N/A"
					var data := ObsGetSceneListResponse.new()
					data.current_scene = json_response["current-scene"]
					
					for i in json_response["scenes"]:
						var obs_scene := ObsScene.new()
						obs_scene.obs_name = i["name"]
						for j in i["sources"]:
							var obs_scene_item := ObsSceneItem.new(
								j["cy"],
								j["cx"],
								j["alignment"],
								j["name"],
								j["id"],
								j["render"],
								j["muted"],
								j["locked"],
								j["source_cx"],
								j["source_cy"],
								j["type"],
								j["volume"],
								j["x"],
								j["y"]
							)
							obs_scene.sources.append(obs_scene_item)
						data.scenes.append(obs_scene)
					emit_signal("obs_scene_list_returned", data)
					waiting_for_response = false
					return

	emit_signal("obs_updated", json_response)

func _on_server_close_request(_code: int, _reason: String) -> void:
	print("OBS close request received")
	obs_client.disconnect_from_host()

###############################################################################
# Private functions                                                           #
###############################################################################

#func _get_auth_required() -> void:
#	logger.info("Sending GetAuthRequired message")
#	var text := JSON.print({"message-id": _generate_message_id(), "request-type": "GetAuthRequired"})
#
#	obs_client.get_peer(1).put_packet(text.to_utf8())

func _identify(data: Dictionary) -> void:
	logger.info("Responding to Hello with Identify")
	
	

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

func establish_connection() -> int:
	return obs_client.connect_to_url(URL_PATH % [host, port], ["obswebsocket.json"])

func break_connection() -> void:
	obs_client.disconnect_from_host()

func send_command(command: String, data: Dictionary = {}) -> void:
	if waiting_for_response:
		print("Still waiting for response for last command")
		return
	
	data["request-type"] = command
	data["message-id"] = _generate_message_id()
	obs_client.get_peer(1).put_packet(JSON.print(data).to_utf8())

# Preconfigured commands

func get_scene_list() -> void:
	last_command = PreconfiguredCommands.GET_SCENE_LIST
	send_command(PreconfiguredCommands.GET_SCENE_LIST)
	waiting_for_response = true
