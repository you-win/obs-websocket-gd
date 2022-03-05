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
	"op": 5,
	"d": {
		"eventType": "StudioModeStateChanged",
		"eventIntent": 1,
		"eventData": {
			"studioModeEnabled": true
		}
	}
}

var good1 := {
	"op": 5,
	"d": {
		"eventType": "some event",
		"eventIntent": 100
	}
}

# In theory this should never happen
var good2 := {
	"op": 5,
	"d": {
		"eventType": "some event",
		"eventIntent": 100,
		"bleh": "meh"
	}
}

var good3 := {
	"op": 5,
	"d": {
		"eventType": "pew",
		"eventIntent": 100,
		"eventData": {

		}
	}
}

var bad0 := {
	"op": 5,
	"d": {
		"event_type": "StudioModeStateChanged",
		"event_intent": 100
	}
}

var bad1 := {
	"op": 5,
	"d": {
		"event_type": "StudioModeStateChanged",
		"eventIntent": 100
	}
}


var bad2 := {
	"op": 5,
	"d": {
		"eventType": "StudioModeStateChanged",
		"eventIntent": 100,
		"eventData": [
			"not possible"
		]
	}
}

func test_parse_pass():
	var e0 := Event.new()

	assert_eq(e0.parse(good0), OK)
	assert_eq(e0.event_type, "StudioModeStateChanged")
	assert_eq(e0.event_intent, 1)
	assert_eq(e0.event_data.studioModeEnabled, true) # Event data keys are kept as-is

	var e1 := Event.new()

	assert_eq(e1.parse(good1), OK)
	assert_eq(e1.event_type, "some event")
	assert_eq(e1.event_intent, 100)
	assert_true(e1.event_data.empty())

	var e2 := Event.new()

	assert_eq(e2.parse(good2), OK)
	assert_eq(e2.event_type, "some event")
	assert_eq(e2.event_intent, 100)
	assert_true(e2.event_data.empty())

	var e3 := Event.new()

	assert_eq(e3.parse(good3), OK)
	assert_eq(e3.event_type, "pew")
	assert_eq(e3.event_intent, 100)
	assert_true(e3.event_data.empty())

func test_parse_fail():
	var e0 := Event.new()

	assert_eq(e0.parse(bad0), Error.MISSING_EVENT_INTENT)
	assert_eq(e0.event_type, "")
	assert_eq(e0.event_intent, -1)
	assert_true(typeof(e0.event_data) == TYPE_DICTIONARY)

	var e1 := Event.new()

	assert_eq(e1.parse(bad1), Error.MISSING_EVENT_TYPE)
	assert_eq(e0.event_type, "")
	assert_eq(e0.event_intent, -1)
	assert_true(typeof(e0.event_data) == TYPE_DICTIONARY)

	# NOTE unable to test this since the debugger halts the application because of mismatched types
	# var e2 := Event.new()

	# assert_eq(e2.parse(bad2), Error.UNEXPECTED_EVENT_DATA_TYPE)
	# assert_eq(e2.event_type, "StudioModeStateChanged")
	# assert_eq(e2.event_intent, 100)
	# assert_true(typeof(e2.event_data) == TYPE_ARRAY)
	# assert_null(e2.event_data)
