--
-- Project: Loowy
-- User: Konstantin Burkalev
-- Date: 20.11.14
--

require "debug.var_dump"

local _M = {
	_VERSION = '0.0.1'
}

_M.__index = _M

local wamp_features = {
	agent = "Loowy/Lua v0.0.1",
	roles = {
		broker = {
			features = {
				subscriber_blackwhite_listing = true,
				publisher_exclusion = true,
				publisher_identification = true
			}
		},
		dealer = {
			features = {
				callee_blackwhite_listing = true,
				caller_exclusion = true,
				caller_identification = true
			}
		}
	}
}

local WAMP_MSG_SPEC = {
	HELLO = 1,
	WELCOME = 2,
	ABORT = 3,
	CHALLENGE = 4,
	AUTHENTICATE = 5,
	GOODBYE = 6,
	HEARTBEAT = 7,
	ERROR = 8,
	PUBLISH = 16,
	PUBLISHED = 17,
	SUBSCRIBE = 32,
	SUBSCRIBED = 33,
	UNSUBSCRIBE = 34,
	UNSUBSCRIBED = 35,
	EVENT = 36,
	CALL = 48,
	CANCEL = 49,
	RESULT = 50,
	REGISTER = 64,
	REGISTERED = 65,
	UNREGISTER = 66,
	UNREGISTERED = 67,
	INVOCATION = 68,
	INTERRUPT = 69,
	YIELD = 70
}




















return _M
