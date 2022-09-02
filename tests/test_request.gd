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

func test_request_pass():
	var r0 := Request.new(
		"SetCurrentScene",
		"some_id",
		{
			"sceneName": "Scene 12"
		}
	)
	
	assert_eq(r0.op, 6)
	assert_eq(r0.request_type, "SetCurrentScene")
	assert_eq(r0.request_id, "some_id")
	assert_eq(r0.request_data.sceneName, "Scene 12") # request_data is a dict, values are left as-is

	var r1 := Request.new(
		"some type",
		"id i guess"
	)

	assert_eq(r1.request_type, "some type")
	assert_eq(r1.request_id, "id i guess")
	assert_true(r1.request_data.is_empty())
