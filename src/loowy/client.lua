--
-- Project: Loowy
-- LUA WAMP client
--
-- User: Konstantin Burkalev
-- https://github.com/KSDaemon/Loowy
--
-- Copyright 2014 KSDaemon. Licensed under the MIT License.
-- See @license text at http://www.opensource.org/licenses/mit-license.php
-- Date: 20.11.14
--

require "debug.var_dump"

local _M = {
	_VERSION = '0.0.1'
}

-- _M.__index = _M -- I think don't needed

-- Get Wamp client suported features
function _M.getWampFeatures()
	return {
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
end

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

local WAMP_ERROR_MSG = {
	SUCCESS = { code = 0, description = "Success!" },
	URI_ERROR = { code = 1, description = "Topic URI doesn't meet requirements!" },
	NO_BROKER = { code = 2, description = "Server doesn't provide broker role!" },
	NO_CALLBACK_SPEC = { code = 3, description = "No required callback function specified!" },
	INVALID_PARAM = { code = 4, description = "Invalid parameter(s) specified!" },
	NON_EXIST_SUBSCRIBE_CONFIRM = { code = 5, description = "Received subscribe confirmation to non existent subscription!" },
	NON_EXIST_SUBSCRIBE_ERROR = { code = 6, description = "Received error for non existent subscription!" },
	NON_EXIST_UNSUBSCRIBE = { code = 7, description = "Trying to unsubscribe from non existent subscription!" },
	NON_EXIST_SUBSCRIBE_UNSUBSCRIBED = { code = 8, description = "Received unsubscribe confirmation to non existent subscription!" },
	NON_EXIST_PUBLISH_ERROR = { code = 9, description = "Received error for non existent publication!" },
	NON_EXIST_PUBLISH_PUBLISHED = { code = 10, description = "Received publish confirmation for non existent publication!" },
	NON_EXIST_SUBSCRIBE_EVENT = { code = 11, description = "Received event for non existent subscription!" },
	NO_DEALER = { code = 12, description = "Server doesn't provide dealer role!" },
	NON_EXIST_CALL_RESULT = { code = 13, description = "Received rpc result for non existent call!" },
	NON_EXIST_CALL_ERROR = { code = 14, description = "Received rpc call error for non existent call!" },
	RPC_ALREADY_REGISTERED = { code = 15, description = "RPC already registered!" },
	NON_EXIST_RPC_REG = { code = 16, description = "Received rpc registration confirmation for non existent rpc!" },
	NON_EXIST_RPC_UNREG = { code = 17, description = "Received rpc unregistration confirmation for non existent rpc!" },
	NON_EXIST_RPC_ERROR = { code = 18, description = "Received error for non existent rpc!" },
	NON_EXIST_RPC_INVOCATION = { code = 19, description = "Received invocation for non existent rpc!" }
}

-- Loowy client class
--local Loowy = {}
--Loowy.__index = Loowy -- failed table lookups on the instances should fallback to the class table, to get methods

----------------------------------------------
-- Create a new Loowy instance
--
-- url - WAMP router url (optional)
-- opts - Configuration options (optional)
----------------------------------------------
function _M.new(url, opts)
	-- local loowy = setmetatable({}, Loowy)
	local loowy = {}

	-------------------------
	-- Instance private data
	-------------------------

	local cache = {
		-- WS url
		-- @type string
		url = nil,

		-- WS supported protocols
		-- @type array of strings
		protocols = { 'wamp.2.json' },

		-- WAMP Session ID
		-- @type string
		sessionId = nil,

		-- Server WAMP roles and features
		serverWampFeatures = {
			roles = {}
		},

		-- Are we in state of saying goodbye
		-- @type boolean
		isSayingGoodbye = false,

		-- Status of last operation
		opStatus = {
			code = 0,
			description = 'Success!'
		},

		-- Timer for reconnection
		timer = nil,

		-- Reconnection attempts
		-- @type number
		reconnectingAttempts = 0
	}

	-- WebSocket object
	local ws = nil

	-- Internal queue for websocket requests, for case of disconnect
	-- @type array
	local wsQueue = {}

	-- Internal queue for wamp requests
	-- @type object
	local requests = {}

	-- Stored RPC
	-- @type object
	local calls = {}

	-- Stored Pub/Sub
	-- @type object
	local subscriptions = {}

	-- Stored Pub/Sub topics
	-- @type array
	local subsTopics = {}

	-- Stored RPC Registrations
	-- @type object
	local rpcRegs = {}

	-- Stored RPC names
	-- @type array
	local rpcNames = {}

	-- Options hash-table
	-- @type object
	local options = {
		-- Reconnecting flag
		-- @type boolean
		autoReconnect = true,

		-- Reconnecting interval (in ms)
		-- @type number
		reconnectInterval = 2 * 1000,

		-- Maximum reconnection retries
		-- @type number
		maxRetries = 25,

		-- Message serializer
		-- @type string
		transportEncoding = 'json',

		-- WAMP Realm to join
		-- @type string
		realm = nil,

		-- onConnect callback
		-- @type function
		onConnect = nil,

		-- onClose callback
		-- @type function
		onClose = nil,

		-- onError callback
		-- @type function
		onError = nil,

		-- onReconnect callback
		-- @type function
		onReconnect = nil
	}

	--------------------------------
	-- End of Instance private data
	--------------------------------

	----------------------------
	-- Instance private methods
	----------------------------

	---------------------------------
	-- Get the new unique request id
	---------------------------------
	local function _getReqId()
		local reqId

		math.randomseed(os.time()) -- TODO  Precision - only seconds, which is not acceptable

		repeat
			-- regId = math.random(9007199254740992)    -- returns numbers in scientific format after encoding :(
			reqId = math.random(100000000000000)
		until requests[reqId] ~= nil
	end

	--------------------------------------------
	-- Set websocket protocols based on options
	--------------------------------------------
	local function _setWsProtocols()
		if options.transportEncoding == 'msgpack' then
			table.insert(cache.protocols, 1, 'wamp.2.msgpack')
		end
	end

	-------------------------
	-- Validate uri
	--
	-- uri - uri to validate
	-- @return boolean
	-------------------------
	local function _validateURI(uri)
		-- create something like /^([0-9a-z_]{2,}\.)*([0-9a-z_]{2,})$/
		if string.find(uri, "^.$") == nil or string.find(uri, "wamp") == 1 then
			return false
		else
			return true
		end
	end

	--------------------------------------------
	-- Encode WAMP message
	--
	-- msg - message to encode
	-- @return encoder specific encoded message
	--------------------------------------------
	local function _encode(msg)

	end

	--------------------------------------------
	-- Decode WAMP message
	--
	-- msg - message to decode
	-- @return encoder specific decoded message
	--------------------------------------------
	local function _decode(msg)

	end

	--------------------------------------------
	-- Send encoded message to server
	--
	-- msg - message to send
	--------------------------------------------
	local function _send(msg)

	end

	----------------------------------
	-- Reset internal state and cache
	----------------------------------
	local function _resetState()

	end

	-------------------------------------------
	-- Initialize internal websocket callbacks
	-------------------------------------------
	local function _initWsCallbacks()

	end

	-------------------------------------------
	-- Connection open callback
	-------------------------------------------
	local function _wsOnOpen()

	end

	-------------------------------------------
	-- Connection close callback
	-------------------------------------------
	local function _wsOnClose()

	end

	-------------------------------------------
	-- Connection message callback
	--
	-- event - received data
	-------------------------------------------
	local function _wsOnMessage(event)

	end

	-------------------------------------------
	-- Connection error callback
	--
	-- error - received error
	-------------------------------------------
	local function _wsOnError(error)

	end

	-------------------------------------------
	-- Reconnection to WAMP server
	-------------------------------------------
	local function _wsReconnect()

	end

	-------------------------------------------
	-- Renew subscriptions after reconnection to WAMP server
	-------------------------------------------
	local function _renewSubscriptions()

	end

	-------------------------------------------
	-- Renew RPC registrations after reconnection to WAMP server
	-------------------------------------------
	local function _renewRegistrations()

	end

	-----------------------------------
	-- End of Instance private methods
	-----------------------------------

	-----------------------------
	-- Loowy instance public API
	-----------------------------


	---------------------------------------------------
	-- Get or set options
	--
	-- To get options - call without parameters
	-- To set options - pass table with options values
	---------------------------------------------------
	function loowy:options(opts)
		if opts == nil then
			return options
		else
			for k, v in pairs(opts) do
				options[k] = v
			end
		end
	end

	-----------------------------------------------------
	-- Get the status of last operation
	--
	-- @return {code, description}
	--          code: 0 - if operation was successful
	--          code > 0 - if error occurred
	--          description contains details about error
	-----------------------------------------------------
	function loowy:getOpStatus()
		return cache.opStatus
	end

	---------------------------
	-- Get the WAMP Session ID
	---------------------------
	function loowy:getSessionId()
		return cache.sessionId
	end

	------------------------------------
	-- Connect to server
	--
	-- url - WAMP Server url (optional)
	------------------------------------
	function loowy:connect(url)

	end

	---------------------------
	-- Disconnect from server
	---------------------------
	function loowy:disconnect()

	end

	------------------------------------
	-- Abort WAMP session establishment
	------------------------------------
	function loowy:abort()

	end

	-------------------------------------------------------------------------------------------
	-- Subscribe to a topic on a broker
	--
	-- topicURI - topic to subscribe
	-- callbacks - if it is a function - it will be treated as published event callback
	--                           or it can be hash table of callbacks:
	--                           { onSuccess: will be called when subscribe would be confirmed
	--                             onError: will be called if subscribe would be aborted
	--                             onEvent: will be called on receiving published event }
	-------------------------------------------------------------------------------------------
	function loowy:subscribe(topicURI, callbacks)

	end

	---------------------------------------------------------------------------------------------
	-- Unsubscribe from topic
	--
	-- topicURI - topic to unsubscribe
	-- callbacks - if it is a function - it will be treated as unsubscribe event callback
	--                           or it can be hash table of callbacks:
	--                           { onSuccess: will be called when unsubscribe would be confirmed
	--                             onError: will be called if unsubscribe would be aborted }
	---------------------------------------------------------------------------------------------
	function loowy:unsubscribe(topicURI, callbacks)

	end

	----------------------------------------------------------------------------------------------------------------
	-- Publish a event to topic
	--
	-- topicURI - topic to publish
	-- payload - optional parameter.
	-- callbacks - optional table of callbacks:
	--                           { onSuccess: will be called when publishing would be confirmed
	--                             onError: will be called if publishing would be aborted }
	-- advancedOptions - optional parameter. Must include any or all of the options:
	--                   { exclude: integer|array WAMP session id(s) that won't receive a published event,
	--                              even though they may be subscribed
	--                     eligible: integer|array WAMP session id(s) that are allowed to receive a published event
	--                     exclude_me: bool flag of receiving publishing event by initiator
	--                     disclose_me: bool flag of disclosure of publisher identity (its WAMP session ID)
	--                                  to receivers of a published event }
	----------------------------------------------------------------------------------------------------------------
	function loowy:publish(topicURI, payload, callbacks, advancedOptions)

	end

	--------------------------------------------------------------------------------------------------------------------
	-- Remote Procedure Call
	--
	-- topicURI - topic to call
	-- payload - can be either a value of any type or null
	-- callbacks - if it is a function - it will be treated as result callback function
	--                     or it can be hash table of callbacks:
	--                     { onSuccess: will be called with result on successful call
	--                       onError: will be called if invocation would be aborted }
	-- advancedOptions - optional parameter. Must include any or all of the options:
	--                   { exclude: integer|array WAMP session id(s) providing an explicit list of (potential)
	--                              Callees that a call won't be forwarded to, even though they might be registered
	--                     eligible: integer|array WAMP session id(s) providing an explicit list of (potential)
	--                               Callees that are (potentially) forwarded the call issued
	--                     exclude_me: bool flag of potentially forwarding call to caller if he is registered as callee
	--                     disclose_me: bool flag of disclosure of Caller identity (WAMP session ID)
	--                                  to endpoints of a routed call }
	--------------------------------------------------------------------------------------------------------------------
	function loowy:call(topicURI, payload, callbacks, advancedOptions)

	end

	------------------------------------------------------------------------------------------
	-- RPC registration for invocation
	--
	-- topicURI - topic to register
	-- callbacks - if it is a function - it will be treated as rpc itself
	--                           or it can be hash table of callbacks:
	--                           { rpc: registered procedure
	--                             onSuccess: will be called on successful registration
	--                             onError: will be called if registration would be aborted }
	------------------------------------------------------------------------------------------
	function loowy:register(topicURI, callbacks)

	end

	-------------------------------------------------------------------------------------------
	-- RPC unregistration for invocation
	--
	-- topicURI - topic to unregister
	-- callbacks - if it is a function, it will be called on successful unregistration
	--                          or it can be hash table of callbacks:
	--                          { onSuccess: will be called on successful unregistration
	--                            onError: will be called if unregistration would be aborted }
	-------------------------------------------------------------------------------------------
	function loowy:unregister(topicURI, callbacks)

	end

	------------------------------------
	-- End of Loowy instance public API
	------------------------------------


	if url ~= nil then
		cache.url = url
	end

	if opts ~= nil then
		-- Merging user options
		for k, v in pairs(opts) do
			options[k] = v
		end
	end

	return loowy
end

return _M
