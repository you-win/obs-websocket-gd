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

const DUMMY_OP_CODE: int = 1000

var good_data0 := {
	"op": DUMMY_OP_CODE, # Dummy OpCode
	"d": {
		"test": "value",
		"dict": {
			"some_key": "some_value",
			"some_array": [
				"test"
			]
		},
		"arr": [
			"some_data"
		]
	}
}

var good_data1 := {
	"bad_key": "wee", # Value should be ignored
	"op": DUMMY_OP_CODE,
	"d": {
		"some_data": "data_value"
	}
}

var good_data2 := {
	"op": DUMMY_OP_CODE,
	"d": {}
}

var bad_data0 := {
	"bleh": "meh",
	"d": {}
}

var bad_data1 := {
	"bleh": 2
}

var bad_data2 := {
	"op": DUMMY_OP_CODE
}

func test_obs_message_parse_pass():
	var m0 := ObsMessage.new()
	
	assert_eq(m0.parse(good_data0), OK)

	assert_eq(m0.op, DUMMY_OP_CODE)
	assert_eq(m0.d.test, "value")
	assert_eq(m0.d.dict.some_key, "some_value")
	assert_eq(m0.d.dict.some_array[0], "test")
	assert_eq(m0.d.arr[0], "some_data")
	
	var m1 := ObsMessage.new()
	
	assert_eq(m1.parse(good_data1), OK)

	assert_null(m1.get("bad_key"))
	assert_eq(m1.op, DUMMY_OP_CODE)
	assert_eq(m1.d.some_data, "data_value")

	var m2 := ObsMessage.new()
	
	assert_eq(m2.parse(good_data2), OK)
	assert_eq(m2.d.size(), 0)

func test_obs_message_parse_fail():
	var m0 := ObsMessage.new()

	assert_eq(m0.parse(bad_data0), Error.MISSING_OP_CODE)

	# OpCode is currently checked before data
	var m1 := ObsMessage.new()

	assert_eq(m1.parse(bad_data1), Error.MISSING_OP_CODE)

	var m2 := ObsMessage.new()

	assert_eq(m2.parse(bad_data2), Error.MISSING_DATA)

func test_obs_message_get_as_json():
	var m0 := ObsMessage.new()

	assert_eq(m0.parse(good_data0), OK)

	var data := JSON.parse(m0.get_as_json())
	assert_eq(data.error, OK)

	var m1 := ObsMessage.new()

	assert_eq(m1.parse(data.result), OK)
	assert_true(m1.d.empty())
