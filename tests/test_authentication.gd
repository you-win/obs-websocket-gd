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

# Authentication is a subobject inside of Hello, so the test data will be missing
# the "op" and "d" keys

var good_data0 := {
	"challenge": "some_long_string",
	"salt": "other_long_string"
}

# In theory this is impossible
var good_data1 := {
	"challenge": "some_challenge",
	"salt": "some_salt",
	"what": "is this"
}

var bad_data0 := {
	"challenge": "bleh"
}

var bad_data1 := {
	"salt": "meh"
}

var bad_data2 := {
	"lol": "wut"
}

func test_parse_pass():
	var a0 := Authentication.new()

	assert_eq(a0.parse(good_data0), OK)
	assert_eq(a0.challenge, "some_long_string")
	assert_eq(a0.salt, "other_long_string")

	var a1 := Authentication.new()

	assert_eq(a1.parse(good_data1), OK)
	assert_eq(a1.challenge, "some_challenge")
	assert_eq(a1.salt, "some_salt")

func test_parse_fail():
	var a0 := Authentication.new()

	assert_eq(a0.parse(bad_data0), Error.MISSING_AUTHENTICATION_SALT)
	assert_eq(a0.challenge, "bleh")
	assert_eq(a0.salt, "") # Default value

	var a1 := Authentication.new()

	assert_eq(a1.parse(bad_data1), Error.MISSING_AUTHENTICATION_CHALLENGE)
	assert_eq(a1.challenge, "")
	assert_eq(a1.salt, "meh")

	var a2 := Authentication.new()

	# We return the top-most error on the stack
	assert_eq(a2.parse(bad_data2), Error.MISSING_AUTHENTICATION_SALT)
	assert_eq(a2.challenge, "")
	assert_eq(a2.salt, "")
