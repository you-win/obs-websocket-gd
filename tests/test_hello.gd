extends "res://tests/base_test.gd"

# https://github.com/bitwes/Gut/wiki/Quick-Start

###############################################################################
# Builtin functions                                                           #
###############################################################################

func before_all():
	pass

func before_each():
	pass

func after_each():
	pass

func after_all():
	pass

###############################################################################
# Tests                                                                       #
###############################################################################

var good_data0 := {
	"op": 0,
	"d": {
		"obsWebSocketVersion": "5.0.0",
		"rpcVersion": 1,
		"authentication": {
			"challenge": "+IxH4CnCiqpX1rM9scsNynZzbOe4KhDeYcTNS3PDaeY=",
			"salt": "lM1GncleQOaCu9lT1yeUZhFYnqhsLLP1G5lAGo3ixaI="
		}
	}
}

# Authentication is technically optional
var good_data1 := {
	"op": 0,
	"d": {
		"obsWebSocketVersion": "5.0.0",
		"rpcVersion": 1
	}
}

var bad_data0 := {
	"bleh": "meh"
}

var bad_data1 := {
	"op": 0,
	"d": {
		"rpcVersion": 1,
		"authentication": {
			"challenge": "+IxH4CnCiqpX1rM9scsNynZzbOe4KhDeYcTNS3PDaeY=",
			"salt": "lM1GncleQOaCu9lT1yeUZhFYnqhsLLP1G5lAGo3ixaI="
		}
	}
}

var bad_data2 := {
	"op": 0,
	"d": {
		"obsWebSocketVersion": "5.0.0",
		"rpcVersion": 1,
		"authentication": {
			"challenge": "+IxH4CnCiqpX1rM9scsNynZzbOe4KhDeYcTNS3PDaeY=",
		}
	}
}

func test_hello_pass():
	var m0 := Hello.new()

	assert_eq(m0.parse(good_data0), OK)

	assert_eq(m0.op, 0)
	assert_eq(m0.obs_websocket_version, "5.0.0")
	assert_eq(m0.rpc_version, 1)
	assert_eq(m0.authentication.challenge, "+IxH4CnCiqpX1rM9scsNynZzbOe4KhDeYcTNS3PDaeY=")
	assert_eq(m0.authentication.salt, "lM1GncleQOaCu9lT1yeUZhFYnqhsLLP1G5lAGo3ixaI=")

	var m1 := Hello.new()

	assert_eq(m1.parse(good_data1), OK)
	
	assert_eq(m1.op, 0)
	assert_eq(m1.obs_websocket_version, "5.0.0")
	assert_eq(m1.rpc_version, 1)

func test_hello_fail():
	var m0 := Hello.new()

	assert_eq(m0.parse(bad_data0), Error.MISSING_OP_CODE)

	var m1 := Hello.new()

	assert_eq(m1.parse(bad_data1), Error.MISSING_HELLO_OBS_WEBSOCKET_VERSION)

	var m2 := Hello.new()

	assert_eq(m2.parse(bad_data2), Error.MISSING_AUTHENTICATION_SALT)
