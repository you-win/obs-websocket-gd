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

func test_reidentify_pass():
	var r0 := Reidentify.new(
		OpCodeEnums.EventSubscription.Scenes.IDENTIFIER_VALUE |
		OpCodeEnums.EventSubscription.General.IDENTIFIER_VALUE
	)

	assert_eq(
		r0.event_subscriptions,
		OpCodeEnums.EventSubscription.Scenes.IDENTIFIER_VALUE |
		OpCodeEnums.EventSubscription.General.IDENTIFIER_VALUE
	)
