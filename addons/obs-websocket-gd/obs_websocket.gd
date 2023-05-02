extends Node

signal obs_authenticated()
signal obs_data_received(data)

enum ObsError {
	NONE = 0,
	
	MISSING_OP_CODE,
	MISSING_DATA,

	NO_NEED_TO_PARSE,

	#region Hello

	MISSING_HELLO_OBS_WEBSOCKET_VERSION,
	MISSING_HELLO_RPC_VERSION,

	#region Authentication

	MISSING_AUTHENTICATION_CHALLENGE,
	MISSING_AUTHENTICATION_SALT,

	#endregion

	#endregion

	#region Identified

	MISSING_IDENTIFIED_NEGOTIATED_RPC_VERSION,

	#endregion

	#region Event

	MISSING_EVENT_TYPE,
	MISSING_EVENT_INTENT,
	MISSING_EVENT_DATA,
	UNEXPECTED_EVENT_DATA_TYPE,

	#endregion

	#region Request

	MISSING_REQUEST_TYPE,
	MISSING_REQUEST_ID,
	MISSING_REQUEST_STATUS,

	#region RequestStatus

	MISSING_REQUEST_STATUS_RESULT,
	MISSING_REQUEST_STATUS_CODE,

	#endregion

	#endregion

	#region RequestBatchResponse

	MISSING_REQUEST_BATCH_RESPONSE_REQUEST_ID,
	MISSING_REQUEST_BATCH_RESPONSE_RESULTS

	#endregion
}

const RPC_VERSION: int = 1

#region OpCode model

#region Base objects

class ObsMessage:
	const NO_NEED_TO_PARSE := "There is no need to parse Client messages since all values are passed to new(...)"

	const OP := "op"
	const D := "d"

	var op: int
	var d: Dictionary
	
	func _to_string() -> String:
		return get_as_json()
	
	func parse(data: Dictionary) -> int:
		op = data.get(OP, -1)
		d = data.get(D, {})

		if not data.has(OP):
			return ObsError.MISSING_OP_CODE
		if not data.has(D):
			return ObsError.MISSING_DATA

		return OK

	func get_as_json(skip_empty: bool = false) -> String:
		var json := {"d": {}}
		for i in get_property_list():
			var prop_name: String = i["name"]
			if prop_name in ["Object", "RefCounted", "script", "Script Variables", "d"]:
				continue
			
			var prop = get(prop_name)
			
			var should_skip := false
			if skip_empty:
				match typeof(prop):
					TYPE_ARRAY, TYPE_DICTIONARY:
						if prop.is_empty():
							should_skip = true
					TYPE_INT:
						if prop < 0:
							should_skip = true
			if should_skip:
				continue
			
			var split_name: PackedStringArray = prop_name.split("_")
			prop_name = split_name[0]
			for s in range(1, split_name.size()):
				prop_name = "%s%s" % [prop_name, split_name[s].capitalize()]
			
			if prop_name == "op":
				json[prop_name] = prop
			else:
				json["d"][prop_name] = prop
		
		var json_obj := JSON.new()
		return json_obj.stringify(json, "\t")

class ClientObsMessage extends ObsMessage:
	func parse(_data: Dictionary) -> int:
		printerr(NO_NEED_TO_PARSE)
		
		return ObsError.NO_NEED_TO_PARSE

class ServerObsMessage extends ObsMessage:
	func parse(data: Dictionary) -> int:
		return super.parse(data)

#endregion

#region Initialization

## FROM obs TO client
class Hello extends ServerObsMessage:
	const OBS_WEBSOCKET_VERSION := "obsWebSocketVersion"
	const RPC_VERSION := "rpcVersion"
	const AUTHENTICATION := "authentication"

	var obs_websocket_version: String
	var rpc_version: int
	var authentication: Authentication

	func parse(data: Dictionary) -> int:
		var err := super.parse(data)
		if err != OK:
			return err

		if not d.has(OBS_WEBSOCKET_VERSION):
			err = ObsError.MISSING_HELLO_OBS_WEBSOCKET_VERSION
		if not d.has(RPC_VERSION):
			err = ObsError.MISSING_HELLO_RPC_VERSION

		obs_websocket_version = d.get(OBS_WEBSOCKET_VERSION, "")
		rpc_version = d.get(RPC_VERSION, -1)
		if d.has(AUTHENTICATION):
			var a := Authentication.new()
			var auth_err: int = a.parse(d.get(AUTHENTICATION, {}))
			err = auth_err if auth_err != OK else err
			authentication = a
		else:
			authentication = null

		return err

class Authentication:
	const CHALLENGE := "challenge"
	const SALT := "salt"

	var challenge: String
	var salt: String

	func _to_string() -> String:
		var json := JSON.new()
		return json.stringify({
			"challenge": challenge,
			"salt": salt
		}, "\t")

	func parse(data: Dictionary) -> int:
		var err: int = OK

		if not data.has(CHALLENGE):
			err = ObsError.MISSING_AUTHENTICATION_CHALLENGE
		if not data.has(SALT):
			err = ObsError.MISSING_AUTHENTICATION_SALT

		challenge = data.get(CHALLENGE, "")
		salt = data.get(SALT, "")

		return err

#endregion

#region Identification

## FROM client TO obs
##
## event_subscriptions is a bitmask
class Identify extends ClientObsMessage:
	var rpc_version: int
	var authentication: String
	var event_subscriptions: int

	func _init(p_rpc_version: int,p_authentication: String,p_event_subscriptions: int = OpCodeEnums.EventSubscription.All.IDENTIFIER_VALUE):
		op = 1

		rpc_version = p_rpc_version
		authentication = p_authentication
		event_subscriptions = p_event_subscriptions

## FROM obs TO client
class Identified extends ServerObsMessage:
	const NEGOTIATED_RPC_VERSION := "negotiatedRpcVersion"

	var negotiated_rpc_version: int

	func parse(data: Dictionary) -> int:
		var err := super.parse(data)
		if err != OK:
			return err

		if not d.has(NEGOTIATED_RPC_VERSION):
			err = ObsError.MISSING_IDENTIFIED_NEGOTIATED_RPC_VERSION

		negotiated_rpc_version = d.get(NEGOTIATED_RPC_VERSION, -1)

		return err

## FROM client TO obs
##
## event_subscriptions is a bitmask
class Reidentify extends ClientObsMessage:
	var event_subscriptions: int

	func _init(p_event_subscriptions: int = 33):
		op = 3
		
		event_subscriptions = p_event_subscriptions

#endregion

#region Event

## FROM obs TO client
##
## event_data is optional and could be anything, so just store it wholesale. This means that
## all keys are still camelCase, not snake_case
class Event extends ServerObsMessage:
	const EVENT_TYPE := "eventType"
	const EVENT_INTENT := "eventIntent"
	const EVENT_DATA := "eventData"

	var event_type: String
	var event_intent: int
	var event_data: Dictionary

	func parse(data: Dictionary) -> int:
		var err := super.parse(data)
		if err != OK:
			return err

		if not d.has(EVENT_TYPE):
			err = ObsError.MISSING_EVENT_TYPE
		if not d.has(EVENT_INTENT):
			err = ObsError.MISSING_EVENT_INTENT

		event_type = d.get(EVENT_TYPE, "")
		event_intent = d.get(EVENT_INTENT, -1)
		event_data = d.get(EVENT_DATA, {})

		if typeof(event_data) != TYPE_DICTIONARY:
			err = ObsError.UNEXPECTED_EVENT_DATA_TYPE

		return err

#endregion

#region Request

## FROM client TO obs
##
## request_data is optional and could be anything. All values need to be camelCased
class Request extends ClientObsMessage:
	var request_type: String
	var request_id: String
	var request_data: Dictionary

	func _init(p_request_type: String,p_request_id: String,p_request_data: Dictionary = {}):
		op = 6

		request_type = p_request_type
		request_id = p_request_id
		request_data = p_request_data

## FROM obs TO client
##
## response_data is optional
class RequestResponse extends ServerObsMessage:
	const REQUEST_TYPE := "requestType"
	const REQUEST_ID := "requestId"
	const REQUEST_STATUS := "requestStatus"
	const RESPONSE_DATA := "responseData"

	var request_type: String
	var request_id: String
	var request_status: RequestStatus
	var response_data: Dictionary

	func parse(data: Dictionary) -> int:
		var err := super.parse(data)
		if err != OK:
			return err

		if not d.has(REQUEST_TYPE):
			err = ObsError.MISSING_REQUEST_TYPE
		if not d.has(REQUEST_ID):
			err = ObsError.MISSING_REQUEST_ID
		# if not d.has(REQUEST_STATUS): # TODO this appears to be optional for some requests
		# 	err = Error.MISSING_REQUEST_STATUS

		request_type = d.get(REQUEST_TYPE, "")
		request_id = d.get(REQUEST_ID, "")
		var rs := RequestStatus.new()
		var rs_err: int = rs.parse(d.get(REQUEST_STATUS, {}))
		# err = rs_err if rs_err != OK else err # TODO this appears to be optional for some requests
		request_status = rs
		response_data = d.get(RESPONSE_DATA, {})

		return err

class RequestStatus:
	const RESULT := "request"
	const CODE := "code"
	const COMMENT := "comment"

	# true if the request was successful
	var result: bool
	var code: int
	# Optional, provided by server on error
	var comment: String

	func _to_string() -> String:
		var json := JSON.new()
		return json.stringify({
			"result": result,
			"code": code,
			"comment": comment
		}, "\t")

	func parse(data: Dictionary) -> int:
		var err: int = OK

		if not data.has(RESULT):
			err = ObsError.MISSING_REQUEST_STATUS_RESULT
		if not data.has(CODE):
			err = ObsError.MISSING_REQUEST_STATUS_CODE
		
		result = data.get(RESULT, false)
		code = data.get(CODE, -1)
		comment = data.get(COMMENT, "")
		
		return err

#endregion

#region RequestBatch

## FROM client TO obs
##
## Requests are processed in order by obs-websocket. requests is an array of dictionaries
##
## halt_on_failure and execution_type are technically optional
##
## When halt_on_failure is true, the RequestBatchResponse will only contain the successfully
## processed requests
class RequestBatch extends ClientObsMessage:
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

## FROM obs TO client
##
## results is an array of dictionaries
class RequestBatchResponse extends ServerObsMessage:
	const REQUEST_ID := "requestId"
	const RESULTS := "results"

	var request_id: String
	var results: Array

	func parse(data: Dictionary) -> int:
		var err := super.parse(data)
		if err != OK:
			return err

		if not d.has(REQUEST_ID):
			err = ObsError.MISSING_REQUEST_BATCH_RESPONSE_REQUEST_ID
		if not d.has(RESULTS):
			err = ObsError.MISSING_REQUEST_BATCH_RESPONSE_RESULTS

		request_id = d.get(REQUEST_ID, "")
		results = d.get(RESULTS, [])

		return err

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
			"IDENTIFIER_VALUE": 0,
			"LATEST_SUPPORTED_RPC_VERSION": 1
		},
		"UnknownReason": {
			"IDENTIFIER_VALUE": 4000,
			"LATEST_SUPPORTED_RPC_VERSION": 1
		},
		"MessageDecodeError": {
			"IDENTIFIER_VALUE": 4002,
			"LATEST_SUPPORTED_RPC_VERSION": 1
		},
		"MissingDataField": {
			"IDENTIFIER_VALUE": 4003,
			"LATEST_SUPPORTED_RPC_VERSION": 1
		},
		"InvalidDataFieldType": {
			"IDENTIFIER_VALUE": 4004,
			"LATEST_SUPPORTED_RPC_VERSION": 1
		},
		"InvalidDataFieldValue": {
			"IDENTIFIER_VALUE": 4005,
			"LATEST_SUPPORTED_RPC_VERSION": 1
		},
		"UnknownOpCode": {
			"IDENTIFIER_VALUE": 4006,
			"LATEST_SUPPORTED_RPC_VERSION": 1
		},
		"NotIdentified": {
			"IDENTIFIER_VALUE": 4007,
			"LATEST_SUPPORTED_RPC_VERSION": 1
		},
		"AlreadyIdentified": {
			"IDENTIFIER_VALUE": 4008,
			"LATEST_SUPPORTED_RPC_VERSION": 1
		},
		"AuthenticationFailed": {
			"IDENTIFIER_VALUE": 4009,
			"LATEST_SUPPORTED_RPC_VERSION": 1
		},
		"UnsupportedRpcVersion": {
			"IDENTIFIER_VALUE": 4010,
			"LATEST_SUPPORTED_RPC_VERSION": 1
		},
		"SessionInvalidated": {
			"IDENTIFIER_VALUE": 4011,
			"LATEST_SUPPORTED_RPC_VERSION": 1
		},
		"UnsupportedFeature": {
			"IDENTIFIER_VALUE": 4012,
			"LATEST_SUPPORTED_RPC_VERSION": 1
		},
	},

	"RequestBatchExecutionType": {
		"None": {
			"IDENTIFIER_VALUE": -1,
			"LATEST_SUPPORTED_RPC_VERSION": 1
		},
		"SerialRealtime": {
			"IDENTIFIER_VALUE": 0,
			"LATEST_SUPPORTED_RPC_VERSION": 1
		},
		"SerialFrame": {
			"IDENTIFIER_VALUE": 1,
			"LATEST_SUPPORTED_RPC_VERSION": 1
		},
		"Parallel": {
			"IDENTIFIER_VALUE": 2,
			"LATEST_SUPPORTED_RPC_VERSION": 1
		},
	},

	"RequestStatus": {
		"Unknown": {
			"IDENTIFIER_VALUE": 0,
			"LATEST_SUPPORTED_RPC_VERSION": 1
		},
		"NoError": {
			"IDENTIFIER_VALUE": 10,
			"LATEST_SUPPORTED_RPC_VERSION": 1
		},
		"Success": {
			"IDENTIFIER_VALUE": 100,
			"LATEST_SUPPORTED_RPC_VERSION": 1
		},
		"MissingRequestType": {
			"IDENTIFIER_VALUE": 203,
			"LATEST_SUPPORTED_RPC_VERSION": 1
		},
		"UnknownRequestType": {
			"IDENTIFIER_VALUE": 204,
			"LATEST_SUPPORTED_RPC_VERSION": 1
		},
		"GenericError": {
			"IDENTIFIER_VALUE": 205,
			"LATEST_SUPPORTED_RPC_VERSION": 1
		},
		"UnsupportedRequestBatchExecutionType": {
			"IDENTIFIER_VALUE": 206,
			"LATEST_SUPPORTED_RPC_VERSION": 1
		},
		"MissingRequestField": {
			"IDENTIFIER_VALUE": 300,
			"LATEST_SUPPORTED_RPC_VERSION": 1
		},
		"MissingRequestData": {
			"IDENTIFIER_VALUE": 301,
			"LATEST_SUPPORTED_RPC_VERSION": 1
		},
		"InvalidRequestField": {
			"IDENTIFIER_VALUE": 400,
			"LATEST_SUPPORTED_RPC_VERSION": 1
		},
		"InvalidRequestFieldType": {
			"IDENTIFIER_VALUE": 401,
			"LATEST_SUPPORTED_RPC_VERSION": 1
		},
		"RequestFieldOutOfRange": {
			"IDENTIFIER_VALUE": 402,
			"LATEST_SUPPORTED_RPC_VERSION": 1
		},
		"RequestFieldEmpty": {
			"IDENTIFIER_VALUE": 403,
			"LATEST_SUPPORTED_RPC_VERSION": 1
		},
		"TooManyRequestFields": {
			"IDENTIFIER_VALUE": 404,
			"LATEST_SUPPORTED_RPC_VERSION": 1
		},
		"OutputRunning": {
			"IDENTIFIER_VALUE": 500,
			"LATEST_SUPPORTED_RPC_VERSION": 1
		},
		"OutputNotRunning": {
			"IDENTIFIER_VALUE": 501,
			"LATEST_SUPPORTED_RPC_VERSION": 1
		},
		"OutputPaused": {
			"IDENTIFIER_VALUE": 502,
			"LATEST_SUPPORTED_RPC_VERSION": 1
		},
		"OutputNotPaused": {
			"IDENTIFIER_VALUE": 503,
			"LATEST_SUPPORTED_RPC_VERSION": 1
		},
		"OutputDisabled": {
			"IDENTIFIER_VALUE": 504,
			"LATEST_SUPPORTED_RPC_VERSION": 1
		},
		"StudioModeActive": {
			"IDENTIFIER_VALUE": 505,
			"LATEST_SUPPORTED_RPC_VERSION": 1
		},
		"StudioModeNotActive": {
			"IDENTIFIER_VALUE": 506,
			"LATEST_SUPPORTED_RPC_VERSION": 1
		},
		"ResourceNotFound": {
			"IDENTIFIER_VALUE": 600,
			"LATEST_SUPPORTED_RPC_VERSION": 1
		},
		"ResourceAlreadyExists": {
			"IDENTIFIER_VALUE": 601,
			"LATEST_SUPPORTED_RPC_VERSION": 1
		},
		"InvalidResourceType": {
			"IDENTIFIER_VALUE": 602,
			"LATEST_SUPPORTED_RPC_VERSION": 1
		},
		"NotEnoughResources": {
			"IDENTIFIER_VALUE": 603,
			"LATEST_SUPPORTED_RPC_VERSION": 1
		},
		"InvalidResourceState": {
			"IDENTIFIER_VALUE": 604,
			"LATEST_SUPPORTED_RPC_VERSION": 1
		},
		"InvalidInputKind": {
			"IDENTIFIER_VALUE": 605,
			"LATEST_SUPPORTED_RPC_VERSION": 1
		},
		"ResourceNotConfigurable": {
			"IDENTIFIER_VALUE": 606,
			"LATEST_SUPPORTED_RPC_VERSION": 1
		},
		"ResourceCreationFailed": {
			"IDENTIFIER_VALUE": 700,
			"LATEST_SUPPORTED_RPC_VERSION": 1
		},
		"ResourceActionFailed": {
			"IDENTIFIER_VALUE": 701,
			"LATEST_SUPPORTED_RPC_VERSION": 1
		},
		"RequestProcessingFailed": {
			"IDENTIFIER_VALUE": 702,
			"LATEST_SUPPORTED_RPC_VERSION": 1
		},
		"CannotAct": {
			"IDENTIFIER_VALUE": 703,
			"LATEST_SUPPORTED_RPC_VERSION": 1
		},
	},

	"EventSubscription": {
		"None": {
			"IDENTIFIER_VALUE": 0,
			"LATEST_SUPPORTED_RPC_VERSION": 1
		},
		"General": {
			"IDENTIFIER_VALUE": 1 << 0,
			"LATEST_SUPPORTED_RPC_VERSION": 1
		},
		"Config": {
			"IDENTIFIER_VALUE": 1 << 1,
			"LATEST_SUPPORTED_RPC_VERSION": 1
		},
		"Scenes": {
			"IDENTIFIER_VALUE": 1 << 2,
			"LATEST_SUPPORTED_RPC_VERSION": 1
		},
		"Inputs": {
			"IDENTIFIER_VALUE": 1 << 3,
			"LATEST_SUPPORTED_RPC_VERSION": 1
		},
		"Transitions": {
			"IDENTIFIER_VALUE": 1 << 4,
			"LATEST_SUPPORTED_RPC_VERSION": 1
		},
		"Filters": {
			"IDENTIFIER_VALUE": 1 << 5,
			"LATEST_SUPPORTED_RPC_VERSION": 1
		},
		"Outputs": {
			"IDENTIFIER_VALUE": 1 << 6,
			"LATEST_SUPPORTED_RPC_VERSION": 1
		},
		"SceneItems": {
			"IDENTIFIER_VALUE": 1 << 7,
			"LATEST_SUPPORTED_RPC_VERSION": 1
		},
		"MediaInputs": {
			"IDENTIFIER_VALUE": 1 << 8,
			"LATEST_SUPPORTED_RPC_VERSION": 1
		},
		"Vendors": {
			"IDENTIFIER_VALUE": 1 << 9,
			"LATEST_SUPPORTED_RPC_VERSION": 1
		},
		"Ui": {
			"IDENTIFIER_VALUE": 1 << 10,
			"LATEST_SUPPORTED_RPC_VERSION": 1
		},
		"All": {
			"IDENTIFIER_VALUE": (
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
			"IDENTIFIER_VALUE": 1 << 16,
			"LATEST_SUPPORTED_RPC_VERSION": 1
		},
		"InputActiveStateChanged": {
			"IDENTIFIER_VALUE": 1 << 17,
			"LATEST_SUPPORTED_RPC_VERSION": 1
		},
		"InputShowStateChanged": {
			"IDENTIFIER_VALUE": 1 << 18,
			"LATEST_SUPPORTED_RPC_VERSION": 1
		},
		"SceneItemTransformChanged": {
			"IDENTIFIER_VALUE": 1 << 19,
			"LATEST_SUPPORTED_RPC_VERSION": 1
		},
	}
}

#endregion

signal connection_established()
signal connection_authenticated()
signal connection_closed()
signal data_received(data: ObsMessage)

const URL_PATH: String = "ws://%s:%s"

var obs_client := WebSocketPeer.new()

@export var poll_time: float = 1.0
var _poll_counter: float = 0.0
var _poll_handler := _handle_hello

@export var host: String = "127.0.0.1"
@export var port: String = "4455"
@export var password: String = "password" # It's plaintext lmao, you should be changing this programmatically

###############################################################################
# Builtin functions                                                           #
###############################################################################

func _ready() -> void:
	set_process(false)

func _process(delta: float) -> void:
	_poll_counter += delta
	if _poll_counter >= poll_time:
		_poll_counter = 0.0
		match obs_client.get_ready_state():
			WebSocketPeer.STATE_OPEN, WebSocketPeer.STATE_CONNECTING, WebSocketPeer.STATE_CLOSING:
				obs_client.poll()
				
				while obs_client.get_available_packet_count():
					var err: Error = _poll_handler.call()
					if err != OK:
						printerr(err)
					
			WebSocketPeer.STATE_CLOSED:
				print_debug("Connection closed!")
				
				connection_closed.emit()
				set_process(false)

###############################################################################
# Private functions                                                           #
###############################################################################

func _handle_hello() -> Error:
	print_debug("hello received")
	
	var message := _get_message()
	if message.is_empty():
		printerr("Unable to handle hello message from obs-websocket")
		return ERR_CANT_CONNECT
	
	var hello := Hello.new()
	if hello.parse(message) != OK:
		printerr("Unable to handle Hello message from obs-websocket")
		return ERR_PARSE_ERROR
	
	if hello.op != OpCodeEnums.WebSocketOpCode.Hello.IDENTIFIER_VALUE:
		printerr("Unexpected op code from obs-websocket: ", hello.get_as_json())
		return ERR_CONNECTION_ERROR
	
	_poll_handler = _handle_identify
	
	var identify := Identify.new(
		RPC_VERSION,
		_generate_auth(password, hello.authentication.challenge, hello.authentication.salt)
	)
	
	connection_established.emit()
	
	_send_message(identify.get_as_json(true).to_utf8_buffer())
	
	return OK

func _handle_identify() -> Error:
	print_debug("identify received")
	
	var message := _get_message()
	if message.is_empty():
		printerr("Unable to handle Identify message from obs-websocket")
		return ERR_CANT_CONNECT
	
	if OS.is_debug_build():
		var identified := Identified.new()
		if identified.parse(message) != OK:
			printerr("Unable to parse Identified message from obs-websocket")
			return ERR_PARSE_ERROR
		
		if identified.op != OpCodeEnums.WebSocketOpCode.Identified.IDENTIFIER_VALUE:
			printerr("Unexpected op code from obs-websocket: ", identified.get_as_json())
			return ERR_CONNECTION_ERROR
	
	connection_authenticated.emit()
	
	_poll_handler = _handle_data_received
	
	return OK

func _handle_data_received() -> Error:
	var message := _get_message()
	if message.is_empty() or not message.has("op"):
		printerr("Invalid data received, bailing out: ", message)
		return ERR_INVALID_DATA
	
	var data: ServerObsMessage = null
	
	match int(message.op):
		OpCodeEnums.WebSocketOpCode.Hello.IDENTIFIER_VALUE:
			print("Hello op code received again, this is weird: ", message)
			data = Hello.new()
		OpCodeEnums.WebSocketOpCode.Identified.IDENTIFIER_VALUE:
			print("Idenfied op code received again, this is weird: ", message)
			data = Identified.new()
		OpCodeEnums.WebSocketOpCode.Event.IDENTIFIER_VALUE:
			data = Event.new()
		OpCodeEnums.WebSocketOpCode.RequestResponse.IDENTIFIER_VALUE:
			data = RequestResponse.new()
		OpCodeEnums.WebSocketOpCode.RequestBatchResponse.IDENTIFIER_VALUE:
			data = RequestBatchResponse.new()
		_:
			printerr("Unhandled message: ", message)
			return ERR_INVALID_DATA
	
	var err := data.parse(message)
	if err != OK:
		return err
	
	data_received.emit(data)
	
	return OK

func _get_message() -> Dictionary:
	var json: Variant = JSON.parse_string(obs_client.get_packet().get_string_from_utf8())
	if not json is Dictionary:
		printerr("Unexpected data from obs-websocket: %s\nAborting connection" % str(json))
		return {}
	
	return json as Dictionary

func _send_message(data: PackedByteArray) -> void:
	# TODO even though a text session is never requested, obs-websocket assumes a text session?
	obs_client.send(data, WebSocketPeer.WRITE_MODE_TEXT)

static func _generate_auth(password: String, challenge: String, salt: String) -> String:
	var combined_secret := "%s%s" % [password, salt]
	var base64_secret := Marshalls.raw_to_base64(combined_secret.sha256_buffer())
	var combined_auth := "%s%s" % [base64_secret, challenge]
	return Marshalls.raw_to_base64(combined_auth.sha256_buffer())

###############################################################################
# Public functions                                                            #
###############################################################################

func establish_connection() -> int:
	print_debug("Establishing connection")
	
	set_process(true)
	return obs_client.connect_to_url(URL_PATH % [host, port], TLSOptions.client())

func break_connection(reason: String = "") -> void:
	obs_client.close(1000, reason)

func send_command(command: String, data: Dictionary = {}) -> void:
	var req := Request.new(command, "1", data)
	
	_send_message(req.get_as_json().to_utf8_buffer())
