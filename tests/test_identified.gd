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

var good0 := {
	"op": 2,
	"d": {
		"negotiatedRpcVersion": 1
	}
}

# Technically not possible but we should ignore extra fields anyways
var good1 := {
	"op": 2,
	"d": {
		"negotiatedRpcVersion": 1,
		"some_garbage": "blah"
	}
}

var bad0 := {
	"op": 2,
	"d": {
		"negotiated_rpc_version": 1
	}
}

var bad1 := {
	"op": 2,
	"d": {
		"lul": "cat"
	}
}

func test_parse_pass():
	var i0 := Identified.new()

	assert_eq(i0.parse(good0), OK)
	assert_eq(i0.negotiated_rpc_version, 1)

	var i1 := Identified.new()

	assert_eq(i1.parse(good1), OK)
	assert_eq(i1.negotiated_rpc_version, 1)

func test_parse_fail():
	var i0 := Identified.new()

	assert_eq(i0.parse(bad0), Error.MISSING_IDENTIFIED_NEGOTIATED_RPC_VERSION)
	assert_eq(i0.negotiated_rpc_version, -1)

	var i1 := Identified.new()

	assert_eq(i1.parse(bad1), Error.MISSING_IDENTIFIED_NEGOTIATED_RPC_VERSION)
	assert_eq(i1.negotiated_rpc_version, -1)
