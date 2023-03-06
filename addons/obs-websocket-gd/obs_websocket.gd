extends Node

signal obs_authenticated()
signal obs_data_received(data)

enum Error {
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
			return Error.MISSING_OP_CODE
		if not data.has(D):
			return Error.MISSING_DATA

		return OK

	func get_as_json(skip_empty: bool = false) -> String:
		var json := {"d": {}}
		for i in get_property_list():
			var prop_name: String = i["name"]
			if prop_name in ["Object", "Reference", "script", "Script Variables", "d"]:
				continue
			
			var prop = get(prop_name)
			
			var should_skip := false
			if skip_empty:
				match typeof(prop):
					TYPE_ARRAY, TYPE_DICTIONARY:
						if prop.empty():
							should_skip = true
					TYPE_INT:
						if prop < 0:
							should_skip = true
			if should_skip:
				continue
			
			var split_name: PoolStringArray = prop_name.split("_")
			prop_name = split_name[0]
			for s in range(1, split_name.size()):
				prop_name = "%s%s" % [prop_name, split_name[s].capitalize()]
			
			if prop_name == "op":
				json[prop_name] = prop
			else:
				json["d"][prop_name] = prop
		
		return JSON.print(json, "\t")

class ClientObsMessage extends ObsMessage:
	func parse(_data: Dictionary) -> int:
		printerr(NO_NEED_TO_PARSE)
		
		return Error.NO_NEED_TO_PARSE

class ServerObsMessage extends ObsMessage:
	func parse(data: Dictionary) -> int:
		return .parse(data)

#endregion

#region Initialization

class Hello extends ServerObsMessage:
	"""
	FROM obs
	TO client
	"""
	const OBS_WEBSOCKET_VERSION := "obsWebSocketVersion"
	const RPC_VERSION := "rpcVersion"
	const AUTHENTICATION := "authentication"

	var obs_websocket_version: String
	var rpc_version: int
	var authentication: Authentication

	func parse(data: Dictionary) -> int:
		var err := .parse(data)
		if err != OK:
			return err

		if not d.has(OBS_WEBSOCKET_VERSION):
			err = Error.MISSING_HELLO_OBS_WEBSOCKET_VERSION
		if not d.has(RPC_VERSION):
			err = Error.MISSING_HELLO_RPC_VERSION

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
		return JSON.print({
			"challenge": challenge,
			"salt": salt
		}, "\t")

	func parse(data: Dictionary) -> int:
		var err: int = OK

		if not data.has(CHALLENGE):
			err = Error.MISSING_AUTHENTICATION_CHALLENGE
		if not data.has(SALT):
			err = Error.MISSING_AUTHENTICATION_SALT

		challenge = data.get(CHALLENGE, "")
		salt = data.get(SALT, "")

		return err

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

	func _init(p_rpc_version: int, p_authentication: String, p_event_subscriptions: int = OpCodeEnums.EventSubscription.All.IDENTIFIER_VALUE) -> void:
		op = 1

		rpc_version = p_rpc_version
		authentication = p_authentication
		event_subscriptions = p_event_subscriptions

class Identified extends ServerObsMessage:
	"""
	FROM obs
	TO client
	"""
	const NEGOTIATED_RPC_VERSION := "negotiatedRpcVersion"

	var negotiated_rpc_version: int

	func parse(data: Dictionary) -> int:
		var err := .parse(data)
		if err != OK:
			return err

		if not d.has(NEGOTIATED_RPC_VERSION):
			err = Error.MISSING_IDENTIFIED_NEGOTIATED_RPC_VERSION

		negotiated_rpc_version = d.get(NEGOTIATED_RPC_VERSION, -1)

		return err

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
	const EVENT_TYPE := "eventType"
	const EVENT_INTENT := "eventIntent"
	const EVENT_DATA := "eventData"

	var event_type: String
	var event_intent: int
	var event_data: Dictionary

	func parse(data: Dictionary) -> int:
		var err := .parse(data)
		if err != OK:
			return err

		if not d.has(EVENT_TYPE):
			err = Error.MISSING_EVENT_TYPE
		if not d.has(EVENT_INTENT):
			err = Error.MISSING_EVENT_INTENT

		event_type = d.get(EVENT_TYPE, "")
		event_intent = d.get(EVENT_INTENT, -1)
		event_data = d.get(EVENT_DATA, {})

		if typeof(event_data) != TYPE_DICTIONARY:
			err = Error.UNEXPECTED_EVENT_DATA_TYPE

		return err

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

class RequestResponse extends ServerObsMessage:
	"""
	FROM obs
	TO client

	response_data is optional
	"""
	const REQUEST_TYPE := "requestType"
	const REQUEST_ID := "requestId"
	const REQUEST_STATUS := "requestStatus"
	const RESPONSE_DATA := "responseData"

	var request_type: String
	var request_id: String
	var request_status: RequestStatus
	var response_data: Dictionary

	func parse(data: Dictionary) -> int:
		var err := .parse(data)
		if err != OK:
			return err

		if not d.has(REQUEST_TYPE):
			err = Error.MISSING_REQUEST_TYPE
		if not d.has(REQUEST_ID):
			err = Error.MISSING_REQUEST_ID
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
		return JSON.print({
			"result": result,
			"code": code,
			"comment": comment
		}, "\t")

	func parse(data: Dictionary) -> int:
		var err: int = OK

		if not data.has(RESULT):
			err = Error.MISSING_REQUEST_STATUS_RESULT
		if not data.has(CODE):
			err = Error.MISSING_REQUEST_STATUS_CODE
		
		result = data.get(RESULT, false)
		code = data.get(CODE, -1)
		comment = data.get(COMMENT, "")
		
		return err

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
	const REQUEST_ID := "requestId"
	const RESULTS := "results"

	var request_id: String
	var results: Array

	func parse(data: Dictionary) -> int:
		var err := .parse(data)
		if err != OK:
			return err

		if not d.has(REQUEST_ID):
			err = Error.MISSING_REQUEST_BATCH_RESPONSE_REQUEST_ID
		if not d.has(RESULTS):
			err = Error.MISSING_REQUEST_BATCH_RESPONSE_RESULTS

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

const URL_PATH: String = "ws://%s:%s"

const POLL_TIME: float = 1.0
var poll_counter: float = 0.0

class Logger:
	"""
	Util class pulled out of my usual Logger implementation so that
	obs_websocket.gd can be used completely standalone
	"""

	signal message_logged(message)

	enum LogType { NONE, INFO, DEBUG, TRACE, ERROR }

	var parent_name: String = "DEFAULT_LOGGER"

	var is_setup := false

	func _init(v = null) -> void:
		if v != null:
			setup(v)

	func _log(message: String, log_type: int) -> void:
		var datetime: Dictionary = OS.get_datetime()
		message = "%s %s-%s-%s_%s:%s:%s %s" % [
			parent_name,
			datetime["year"],
			datetime["month"],
			datetime["day"],
			datetime["hour"],
			datetime["minute"],
			datetime["second"],
			message
		]
		
		match log_type:
			LogType.INFO:
				message = "[INFO] %s" % message
			LogType.DEBUG:
				message = "[DEBUG] %s" % message
			LogType.TRACE:
				message = "[TRACE] %s" % message
				var stack_trace: Array = get_stack()
				for i in stack_trace.size() - 2:
					var data: Dictionary = stack_trace[i + 2]
					message = "%s\n\t%d - %s:%d - %s" % [
						message, i, data["source"], data["line"], data["function"]]
			LogType.ERROR:
				message = "[ERROR] %s" % message
				assert(false, message)
	
		print(message)
		emit_signal("message_logged", message)

	func setup(n) -> void:
		"""
		Initialize the logger with the containing object name. Prefer user-defined values but
		also try to intelligently get the calling object name as well
		"""
		if is_setup:
			return
		
		if typeof(n) == TYPE_STRING:
			parent_name = n
		elif n.get_script():
			parent_name = n.get_script().resource_path.get_file()
		elif n.get("name"):
			parent_name = n.name
		else:
			trace("Unable to setup logger using var: %s" % str(n))
		
		is_setup = true
	
	func info(message: String) -> void:
		_log(message, LogType.INFO)
	
	func debug(message: String) -> void:
		if OS.is_debug_build():
			_log(message, LogType.DEBUG)
	
	func trace(message: String) -> void:
		if OS.is_debug_build():
			_log(message, LogType.TRACE)
	
	func error(message: String) -> void:
		_log(message, LogType.ERROR)

var logger = Logger.new()

var obs_client := WebSocketClient.new()

export var host: String = "127.0.0.1"
export var port: String = "4444"
export var password: String = "password" # It's plaintext lmao, you should be changing this programmatically

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
	# obs_client.connect("data_received", self, "_on_data_received")
	obs_client.connect("data_received", self, "_on_hello_received")
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
func _reset_connection():
	if obs_client.is_connected("data_received", self, "_on_identified_received"):
		obs_client.disconnect("data_received", self, "_on_identified_received")
	if obs_client.is_connected("data_received", self, "_on_data_received"):
		obs_client.disconnect("data_received", self, "_on_data_received")
	if not obs_client.is_connected("data_received", self, "_on_hello_received"):
		obs_client.connect("data_received", self, "_on_hello_received")

func _on_connection_closed(_was_clean_close: bool) -> void:
	logger.info("OBS connection closed")
	_reset_connection()

func _on_connection_error() -> void:
	logger.info("OBS connection error")
	_reset_connection()

func _on_connection_established(protocol: String) -> void:
	logger.info("OBS connection established with protocol: %s" % protocol)
	
	obs_client.get_peer(1).set_write_mode(WebSocketPeer.WRITE_MODE_TEXT)

func _on_hello_received() -> void:
	logger.debug("hello received")
	
	var message: Dictionary = _get_message()
	if message.empty():
		logger.error("Invalid hello message, aborting")
		return

	var hello := Hello.new()
	hello.parse(message)
	
	if hello.op != 0:
		logger.error("Unexpected op code from obs-websocket: %s\nAborting connection" % JSON.print(
			hello.get_as_json(), "\t"))
		return
	
	obs_client.disconnect("data_received", self, "_on_hello_received")
	obs_client.connect("data_received", self, "_on_identified_received")
	_identify(hello)

func _on_identified_received() -> void:
	logger.debug("identified received")
	
	var message: Dictionary = _get_message()
	if message.empty():
		logger.error("Invalid identified message, aborting")
		return
	
	obs_client.disconnect("data_received", self, "_on_identified_received")
	obs_client.connect("data_received", self, "_on_data_received")
	
	emit_signal("obs_authenticated")
	
	logger.info("Connected to obs-websocket")

func _on_data_received() -> void:
	var message: Dictionary = _get_message()
	
	if message.empty() or not message.has("op"):
		logger.error("Invalid data received, bailing out")
		return

	var data: ServerObsMessage
	var err: int = Error.NONE
	
	match int(message.op):
		0:
			logger.info("Hello opcode received again, this is weird\n%s" % str(message))
			data = Hello.new()
			err = data.parse(message)
			if err != OK:
				logger.error(get_error_name(err))
		1, 3, 6, 8:
			logger.error("Invalid opcode received\n%s" % str(message))
			return
		2:
			logger.info("Identified opcode received again, this is weird\n%s" % str(message))
			data = Identified.new()
			err = data.parse(message)
			if err != OK:
				logger.error(get_error_name(err))
		5:
			data = Event.new()
			err = data.parse(message)
			if err != OK:
				logger.error(get_error_name(err))
		7:
			data = RequestResponse.new()
			err = data.parse(message)
			if err != OK:
				logger.error(get_error_name(err))
		9:
			data = RequestBatchResponse.new()
			err = data.parse(message)
			if err != OK:
				logger.error(get_error_name(err))
		_:
			logger.error("Unhandled opcode received\n%s" % str(message))

	emit_signal("obs_data_received", data)

func _on_server_close_request(code: int, reason: String) -> void:
	logger.info("OBS close request %d received with reason: %s" % [code, reason])
	obs_client.disconnect_from_host()

###############################################################################
# Private functions                                                           #
###############################################################################

func _get_message() -> Dictionary:
	var message: String = obs_client.get_peer(1).get_packet().get_string_from_utf8().strip_edges()

	var json_result: JSONParseResult = JSON.parse(message)
	if json_result.error != OK:
		logger.error("Unable to parse Hello from obs-websocket: %s\nAborting connection" % message)
		return {}

	var result = json_result.result
	if typeof(result) != TYPE_DICTIONARY:
		logger.error("Unexpected data from obs-websocket: %s\nAborting connection" % str(result))
		return {}

	return result

func _send_message(data: PoolByteArray) -> void:
	obs_client.get_peer(1).put_packet(data)

static func _generate_auth(password: String, challenge: String, salt: String) -> String:
	var combined_secret := "%s%s" % [password, salt]
	var base64_secret := Marshalls.raw_to_base64(combined_secret.sha256_buffer())
	var combined_auth := "%s%s" % [base64_secret, challenge]
	return Marshalls.raw_to_base64(combined_auth.sha256_buffer())

func _identify(hello: Hello, flags: int = 33) -> void:
	logger.info("Responding to Hello with Identify")
	
	var identify := Identify.new(
		RPC_VERSION,
		_generate_auth(password, hello.authentication.challenge, hello.authentication.salt))

	_send_message(identify.get_as_json(true).to_utf8())

###############################################################################
# Public functions                                                            #
###############################################################################

func establish_connection() -> int:
	return obs_client.connect_to_url(URL_PATH % [host, port], ["obswebsocket.json"])

func break_connection() -> void:
	obs_client.disconnect_from_host()

func send_command(command: String, data: Dictionary = {}) -> void:
	if waiting_for_response:
		logger.info("Still waiting for response for last command")
		return
	
	var req := Request.new(command, "1", data)
	
	_send_message(req.get_as_json().to_utf8())

func get_error_name(error: int) -> String:
	return Error.keys()[error]
