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

		math.randomseed(os.time()) -- TODO  Precision - only seconds, which is not acceptable, use posix

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
		-- TODO create something like /^([0-9a-z_]{2,}\.)*([0-9a-z_]{2,})$/
		if string.find(uri, "^.$") == nil or string.find(uri, "wamp") == 1 then
			return false
		else
			return true
		end
	end

	--------------------------------------------
	-- Return index of obj in array t
	--
	-- t - array table
	-- obj - object to search
	-- @return index of obj or -1 if not found
	--------------------------------------------
	local function arrayIndexOf(t, obj)
		if type(t) == 'table' then
			for i = 1, #t do
				if t[i] == object then
					return i
				end
			end

			return -1
		else
			error("table.indexOf expects table for first argument, " .. type(t) .. " given")
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
		wsQueue = {}
		requests = {}
		calls = {}
		subscriptions = {}
		subsTopics = {}
		rpcRegs = {}
		rpcNames = {}

		cache = {
			sessionId = nil,
			serverWampFeatures = {
				roles = {}
			},
			isSayingGoodbye = false,
			opStatus = {
				code = 0,
				description = 'Success!'
			},
			timer = nil,
			reconnectingAttempts = 0
		}

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
		local data, id, i, d, result, msg;

		data = _decode(event);

		if data[1] == WAMP_MSG_SPEC.WELCOME then

		elseif data[1] == WAMP_MSG_SPEC.ABORT then

		elseif data[1] == WAMP_MSG_SPEC.CHALLENGE then

		elseif data[1] == WAMP_MSG_SPEC.GOODBYE then

		elseif data[1] == WAMP_MSG_SPEC.HEARTBEAT then

		elseif data[1] == WAMP_MSG_SPEC.ERROR then

			if data[2] == WAMP_MSG_SPEC.SUBSCRIBE or
				data[2] == WAMP_MSG_SPEC.UNSUBSCRIBE then

			elseif data[2] == WAMP_MSG_SPEC.PUBLISH then

			elseif data[2] == WAMP_MSG_SPEC.REGISTER or
				data[2] == WAMP_MSG_SPEC.UNREGISTER then

			elseif data[2] == WAMP_MSG_SPEC.INVOCATION then

			elseif data[2] == WAMP_MSG_SPEC.CALL then

			end
		elseif data[1] == WAMP_MSG_SPEC.SUBSCRIBED then

		elseif data[1] == WAMP_MSG_SPEC.UNSUBSCRIBED then

		elseif data[1] == WAMP_MSG_SPEC.PUBLISHED then

		elseif data[1] == WAMP_MSG_SPEC.EVENT then

		elseif data[1] == WAMP_MSG_SPEC.RESULT then

		elseif data[1] == WAMP_MSG_SPEC.REGISTER then

		elseif data[1] == WAMP_MSG_SPEC.REGISTERED then

		elseif data[1] == WAMP_MSG_SPEC.UNREGISTER then

		elseif data[1] == WAMP_MSG_SPEC.UNREGISTERED then

		elseif data[1] == WAMP_MSG_SPEC.INVOCATION then

		elseif data[1] == WAMP_MSG_SPEC.INTERRUPT then

		elseif data[1] == WAMP_MSG_SPEC.YIELD then

		end

	end

	-------------------------------------------
	-- Connection error callback
	--
	-- error - received error
	-------------------------------------------
	local function _wsOnError(error)
		if type(options.onError) == 'function' then
			options.onError(options.onError, error)
		end
	end

	-------------------------------------------
	-- Reconnection to WAMP server
	-------------------------------------------
	local function _wsReconnect()
		if type(options.onReconnect) == 'function' then
			options.onReconnect()
		end

		cache.reconnectingAttempts = cache.reconnectingAttempts + 1
		-- TODO Try to establish connection

		_initWsCallbacks()
	end

	-------------------------------------------
	-- Renew subscriptions after reconnection to WAMP server
	-------------------------------------------
	local function _renewSubscriptions()
		local subs, st = subscriptions, subsTopics

		subscriptions, subsTopics = {}, {}

		for k, v in ipairs(st) do
			for kk, vv in ipairs(subs[v].callbacks) do
				self:subscribe(v, vv)
			end
		end
	end

	-------------------------------------------
	-- Renew RPC registrations after reconnection to WAMP server
	-------------------------------------------
	local function _renewRegistrations()
		local rpcs, rn = rpcRegs, rpcNames

		rpcRegs, rpcNames = {}, {}

		for k, v in ipairs(rn) do
			self:register(v, { rpc = rpcs[v].callbacks[0] })
		end
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
		local reqId

		if cache.sessionId and not cache.serverWampFeatures.roles.broker then
			cache.opStatus = WAMP_ERROR_MSG.NO_BROKER

			if type(callbacks.onError) == 'function' then
				callbacks.onError(cache.opStatus.description)
			end

			return
		end

		if not _validateURI(topicURI) then
			cache.opStatus = WAMP_ERROR_MSG.URI_ERROR

			if type(callbacks.onError) == 'function' then
				callbacks.onError(cache.opStatus.description)
			end

			return
		end

		if type(callbacks) == 'function' then
			callbacks = { onEvent = callbacks }
		elseif type(callbacks.onEvent) == 'function' then
			-- nothing to do
		else
			cache.opStatus = WAMP_ERROR_MSG.NO_CALLBACK_SPEC

			if type(callbacks.onError) == 'function' then
				callbacks.onError(cache.opStatus.description)
			end

			return
		end

		if not subscriptions[topicURI] then     -- no such subscription

			reqId = _getReqId()

			requests[reqId] = { topic = topicURI, callbacks: callbacks }

			-- WAMP SPEC: [SUBSCRIBE, Request|id, Options|dict, Topic|uri]
			_send({ WAMP_MSG_SPEC.SUBSCRIBE, reqId, {}, topicURI })

		else    -- already have subscription to this topic
			-- There is no such callback yet
			if arrayIndexOf(subscriptions[topicURI].callbacks, callbacks.onEvent) < 0 then
				table.insert(subscriptions[topicURI].callbacks, callbacks.onEvent)
			end

			if type(callbacks.onSuccess) == 'function' then
				callbacks.onSuccess()
			end

		end

		cache.opStatus = WAMP_ERROR_MSG.SUCCESS

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
		local reqId, i

		if cache.sessionId and not cache.serverWampFeatures.roles.broker then
			cache.opStatus = WAMP_ERROR_MSG.NO_BROKER

			if type(callbacks.onError) == 'function' then
				callbacks.onError(cache.opStatus.description)
			end

			return
		end

		if subscriptions[topicURI] then

			reqId = _getReqId()

			if callbacks == nil then
				subscriptions[topicURI].callbacks = {}
				callbacks = {}
			elseif type(callbacks) == 'function' then
				i = arrayIndexOf(subscriptions[topicURI].callbacks, callbacks)
				callbacks = { onEvent: callbacks }
			else
				i = arrayIndexOf(subscriptions[topicURI].callbacks, callbacks.onEvent)
			end

			if i > 0 then
				table.remove(subscriptions[topicURI].callbacks, i)
			end

			if #subscriptions[topicURI].callbacks > 0 then
				-- There are another callbacks for this topic
				cache.opStatus = WAMP_ERROR_MSG.SUCCESS

				return
			end

			requests[reqId] = { topic = topicURI, callbacks = callbacks }

			-- WAMP_SPEC: [UNSUBSCRIBE, Request|id, SUBSCRIBED.Subscription|id]
			_send({ WAMP_MSG_SPEC.UNSUBSCRIBE, reqId, subscriptions[topicURI].id })
		else
			cache.opStatus = WAMP_ERROR_MSG.NON_EXIST_UNSUBSCRIBE

			if type(callbacks.onError) == 'function' then
				callbacks.onError(cache.opStatus.description)
			end

			return
		end

		cache.opStatus = WAMP_ERROR_MSG.SUCCESS

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
		local reqId, msg
		local options = {}
		local err = false

		if cache.sessionId and not cache.serverWampFeatures.roles.broker then
			cache.opStatus = WAMP_ERROR_MSG.NO_BROKER

			if type(callbacks.onError) == 'function' then
				callbacks.onError(cache.opStatus.description)
			end

			return
		end

		if not _validateURI(topicURI) then
			cache.opStatus = WAMP_ERROR_MSG.URI_ERROR

			if type(callbacks.onError) == 'function' then
				callbacks.onError(cache.opStatus.description)
			end

			return
		end

		if type(callbacks) == 'table' then
			options.acknowledge = true
		end

		if type(advancedOptions) == 'table' then

			if advancedOptions.exclude then
				if type(advancedOptions.exclude) == 'table' then
					options.exclude = advancedOptions.exclude
				elseif type(advancedOptions.exclude) == 'number' then
					options.exclude = { advancedOptions.exclude }
				else
					err = true
				end
			end

			if advancedOptions.eligible then
				if type(advancedOptions.eligible) == 'table' then
					options.eligible = advancedOptions.eligible
				elseif type(advancedOptions.eligible) == 'number' then
					options.eligible = { advancedOptions.eligible }
				else
					err = true
				end
			end

			if advancedOptions.exclude_me then
				options.exclude_me = advancedOptions.exclude_me ~= false
			end

			if advancedOptions.disclose_me then
				options.disclose_me = advancedOptions.disclose_me == true
			end

			if err then

				cache.opStatus = WAMP_ERROR_MSG.INVALID_PARAM

				if type(callbacks.onError) == 'function' then
					callbacks.onError(cache.opStatus.description)
				end

				return
			end

		end

		reqId = _getReqId()

		if payload == nil and callbacks == nil and advancedOptions == nil then
			-- WAMP_SPEC: [PUBLISH, Request|id, Options|dict, Topic|uri]
			msg = { WAMP_MSG_SPEC.PUBLISH, reqId, options, topicURI }
		elseif callbacks == nil and advancedOptions == nil then
			-- WAMP_SPEC: [PUBLISH, Request|id, Options|dict, Topic|uri, Arguments|list (, ArgumentsKw|dict)]
			if payload[1] ~= nil then -- assume it's an array
				msg = { WAMP_MSG_SPEC.PUBLISH, reqId, options, topicURI, payload }
			elseif type(payload) == 'table' then    -- it's a dict
				msg = { WAMP_MSG_SPEC.PUBLISH, reqId, options, topicURI, {}, payload }
			else    -- assume it's a single value
				msg = { WAMP_MSG_SPEC.PUBLISH, reqId, options, topicURI, { payload } }
			end
		end

		_send(msg)
		cache.opStatus = WAMP_ERROR_MSG.SUCCESS

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
		local reqId, msg
		local options = {}
		local err = false

		if cache.sessionId and not cache.serverWampFeatures.roles.dealer then
			cache.opStatus = WAMP_ERROR_MSG.NO_DEALER

			if type(callbacks.onError) == 'function' then
				callbacks.onError(cache.opStatus.description)
			end

			return
		end

		if not _validateURI(topicURI) then
			cache.opStatus = WAMP_ERROR_MSG.URI_ERROR

			if type(callbacks.onError) == 'function' then
				callbacks.onError(cache.opStatus.description)
			end

			return
		end

		if type(callbacks) == 'function' then
			callbacks = { onSuccess = callbacks }
		elseif type(callbacks.onSuccess) == 'function' then
			-- nothing to do
		else
			cache.opStatus = WAMP_ERROR_MSG.NO_CALLBACK_SPEC

			if type(callbacks.onError) == 'function' then
				callbacks.onError(cache.opStatus.description)
			end

			return
		end

		if type(advancedOptions) == 'table' then

			if advancedOptions.exclude then
				if type(advancedOptions.exclude) == 'table' then
					options.exclude = advancedOptions.exclude
				elseif type(advancedOptions.exclude) == 'number' then
					options.exclude = { advancedOptions.exclude }
				else
					err = true
				end
			end

			if advancedOptions.eligible then
				if type(advancedOptions.eligible) == 'table' then
					options.eligible = advancedOptions.eligible
				elseif type(advancedOptions.eligible) == 'number' then
					options.eligible = { advancedOptions.eligible }
				else
					err = true
				end
			end

			if advancedOptions.exclude_me then
				options.exclude_me = advancedOptions.exclude_me ~= false
			end

			if advancedOptions.disclose_me then
				options.disclose_me = advancedOptions.disclose_me == true
			end

			if err then

				cache.opStatus = WAMP_ERROR_MSG.INVALID_PARAM

				if type(callbacks.onError) == 'function' then
					callbacks.onError(cache.opStatus.description)
				end

				return
			end

		end

		repeat
			reqId = _getReqId()
		until calls[reqId] ~= nil

		calls[reqId] = callbacks

		-- WAMP SPEC: [CALL, Request|id, Options|dict, Procedure|uri, (Arguments|list, ArgumentsKw|dict)]

		if payload == nil  then
			msg = { WAMP_MSG_SPEC.CALL, reqId, options, topicURI }
		elseif payload[1] ~= nil then -- assume it's an array
			msg = { WAMP_MSG_SPEC.CALL, reqId, options, topicURI, payload }
		elseif type(payload) == 'table' then    -- it's a dict
			msg = { WAMP_MSG_SPEC.CALL, reqId, options, topicURI, {}, payload }
		else -- assume it's a single value
			msg = { WAMP_MSG_SPEC.CALL, reqId, options, topicURI, {payload} }
		end

		_send(msg)
		cache.opStatus = WAMP_ERROR_MSG.SUCCESS

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
		local reqId

		if cache.sessionId and not cache.serverWampFeatures.roles.dealer then
			cache.opStatus = WAMP_ERROR_MSG.NO_DEALER

			if type(callbacks.onError) == 'function' then
				callbacks.onError(cache.opStatus.description)
			end

			return
		end

		if not _validateURI(topicURI) then
			cache.opStatus = WAMP_ERROR_MSG.URI_ERROR

			if type(callbacks.onError) == 'function' then
				callbacks.onError(cache.opStatus.description)
			end

			return
		end

		if type(callbacks) == 'function' then
			callbacks = { rpc = callbacks }
		elseif type(callbacks.rpc) == 'function' then
			-- nothing to do
		else
			cache.opStatus = WAMP_ERROR_MSG.NO_CALLBACK_SPEC

			if type(callbacks.onError) == 'function' then
				callbacks.onError(cache.opStatus.description)
			end

			return
		end

		if not rpcRegs[topicURI] then     -- no such registration

			reqId = _getReqId()

			requests[reqId] = { topic = topicURI, callbacks: callbacks }

			-- WAMP SPEC: [REGISTER, Request|id, Options|dict, Procedure|uri]
			_send({ WAMP_MSG_SPEC.REGISTER, reqId, {}, topicURI })

		else    -- already have registration with such topicURI

			cache.opStatus = WAMP_ERROR_MSG.RPC_ALREADY_REGISTERED

			if type(callbacks.onError) == 'function' then
				callbacks.onError(cache.opStatus.description)
			end

		end

		cache.opStatus = WAMP_ERROR_MSG.SUCCESS

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
		local reqId

		if cache.sessionId and not cache.serverWampFeatures.roles.dealer then
			cache.opStatus = WAMP_ERROR_MSG.NO_DEALER

			if type(callbacks.onError) == 'function' then
				callbacks.onError(cache.opStatus.description)
			end

			return
		end

		if not _validateURI(topicURI) then
			cache.opStatus = WAMP_ERROR_MSG.URI_ERROR

			if type(callbacks.onError) == 'function' then
				callbacks.onError(cache.opStatus.description)
			end

			return
		end

		if type(callbacks) == 'function' then
			callbacks = { onSuccess = callbacks }
		end

		if rpcRegs[topicURI] then   -- there is such registration

			reqId = _getReqId()

			requests[reqId] = { topic = topicURI, callbacks: callbacks }

			-- WAMP SPEC: [UNREGISTER, Request|id, REGISTERED.Registration|id]
			_send({ WAMP_MSG_SPEC.UNREGISTER, reqId, rpcRegs[topicURI].id })
			cache.opStatus = WAMP_ERROR_MSG.SUCCESS
		else    -- already have registration with such topicURI

			cache.opStatus = WAMP_ERROR_MSG.RPC_ALREADY_REGISTERED

			if type(callbacks.onError) == 'function' then
				callbacks.onError(cache.opStatus.description)
			end
		end

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
