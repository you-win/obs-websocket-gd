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
	"op": 1,
	"d": {
		"rpcVersion": 1,
		"authentication": "Dj6cLS+jrNA0HpCArRg0Z/Fc+YHdt2FQfAvgD1mip6Y=",
	}
}

var good_data1 := {
	"op": 1,
	"d": {
		"rpcVersion": 1,
		"authentication": "Dj6cLS+jrNA0HpCArRg0Z/Fc+YHdt2FQfAvgD1mip6Y=",
		"eventSubscriptions": 0 # None
	}
}

func test_identify_pass():
	var m0 := Identify.new(
		1
		,"Dj6cLS+jrNA0HpCArRg0Z/Fc+YHdt2FQfAvgD1mip6Y="
	)

	assert_eq(m0.op, good_data0.op)
	assert_eq(m0.rpc_version, good_data0.d.rpcVersion)
	assert_eq(m0.authentication, good_data0.d.authentication)
	assert_eq(m0.event_subscriptions, OpCodeEnums.EventSubscription.All.IDENTIFIER_VALUE)

	var m1 := Identify.new(
		1,
		"Dj6cLS+jrNA0HpCArRg0Z/Fc+YHdt2FQfAvgD1mip6Y=",
		0
	)

	assert_eq(m1.authentication, good_data1.d.authentication)
	assert_eq(m1.event_subscriptions, OpCodeEnums.EventSubscription.None.IDENTIFIER_VALUE)

