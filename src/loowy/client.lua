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

--local printdump = require("loowy.vardump").printdump

local _M = {
    _VERSION = '0.3.1'
}

-- _M.__index = _M -- I think no needed

setmetatable(_M, { __call = function (cls, ...)
    return cls.new(...)
end })

local WAMP_FEATURES = {
    agent = "Loowy/Lua v" .. _M._VERSION,
    roles = {
        publisher = {
            features = {
                subscriber_blackwhite_listing = true,
                publisher_exclusion = true,
                publisher_identification = true
            }
        },
        subscriber = {
            features = {
                pattern_based_subscription = true,
                publication_trustlevels = true
            }
        },
        caller = {
            features = {
                caller_identification = true,
                progressive_call_results = true,
                call_canceling = true,
                call_timeout = true
            }
        },
        callee = {
            features = {
                caller_identification = true,
                call_trustlevels = true,
                pattern_based_registration = true,
                shared_registration = true
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
    INVALID_SERIALIZER_TYPE = { code = 5, description = "Serializer with unsupported type provided!" },
    NO_SERIALIZER_AVAILABLE = { code = 6, description = "Server has chosen a serializer, which is not available!" },
    NON_EXIST_UNSUBSCRIBE = { code = 7, description = "Trying to unsubscribe from non existent subscription!" },
    NO_DEALER = { code = 12, description = "Server doesn't provide dealer role!" },
    RPC_ALREADY_REGISTERED = { code = 15, description = "RPC already registered!" },
    NON_EXIST_RPC_UNREG = { code = 17, description = "Received rpc unregistration confirmation for non existent rpc!" },
    NON_EXIST_RPC_INVOCATION = { code = 19, description = "Received invocation for non existent rpc!" },
    NON_EXIST_RPC_REQ_ID = { code = 20, description = "No RPC calls in action with specified request ID!" },
    NO_REALM = { code = 21, description = "No realm specified!" },
    NO_WS_OR_URL = { code = 22, description = "No websocket provided or URL specified is incorrect!" },
    NO_CRA_CB_OR_ID = { code = 23, description = "No onChallenge callback or authid was provided for authentication!" },
    CRA_EXCEPTION = { code = 24, description = "Exception raised during CRA challenge processing" }
}

---------------------------------------------------
--- Create a new Loowy instance
---
--- @param url string WAMP router url (optional)
--- @param opts table Configuration options (optional)
---------------------------------------------------
function _M.new(url, opts)
    -- local loowy = setmetatable({}, Loowy)
    local loowy = {}

    ---------------------------------------------------
    -- Instance private data
    ---------------------------------------------------

    local cache = {
        -- WS url
        -- @type string
        url = nil,

        -- WS supported protocols
        -- @type array of strings
        protocols = { 'wamp.2.json', 'wamp.2.msgpack' },

        -- WAMP Session ID
        -- @type string
        sessionId = nil,

        -- Session scope requests ID
        -- @type int
        reqId = 0,

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
            description = 'Success!',
            reqId = 0
        },

        -- Timer for reconnection
        timer = nil,

        -- Reconnection attempts
        -- @type number
        reconnectingAttempts = 0
    }

    -- WebSocket object
    local ws

    -- Serializer instance to use for message encoding
    local serializer

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
        -- Logging
        -- @type boolean
        debug = false,

        -- Reconnecting flag
        -- @type boolean
        autoReconnect = true,

        -- Reconnecting interval (in seconds)
        -- @type number
        reconnectInterval = 2,

        -- Maximum reconnection retries
        -- @type number
        maxRetries = 25,

        -- Message serializer
        -- @type string
        transportEncoding = 'json',

        -- Transport message type
        -- @type string
        transportType = nil,

        -- WAMP Realm to join
        -- @type string
        realm = nil,

        -- Custom attributes to send to router on hello
        -- @type object
        helloCustomDetails = nil,

         -- Authentication id to use in challenge
         -- @type string
        authid = nil,

         -- Supported authentication methods
         -- @type array
        authmethods = {},

         -- onChallenge callback
         -- @type function
        onChallenge = nil,

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
        onReconnect = nil,

        -- onReconnectSuccess callback
        -- @type function
        onReconnectSuccess = nil
    }

    ---------------------------------------------------
    -- End of Instance private data
    ---------------------------------------------------

    ---------------------------------------------------
    -- Instance private methods
    ---------------------------------------------------

    -- function is defined later
    local _wsReconnect

    ---------------------------------------------------
    --- Internal logging
    ---------------------------------------------------
    local function _log(...)
        local args={... }
        local getdump = require("loowy.vardump").getdump
        if options.debug == true then
            local printResult = ''
            for _, v in ipairs(args) do
                printResult = printResult .. '[DEBUG] ' .. getdump(v) .. '\n'
            end
            print(printResult)
        end
    end

    ---------------------------------------------------
    --- Return index of obj in array t
    ---
    --- @param t table array table
    --- @param obj any object to search
    --- @return number index of obj or -1 if not found
    ---------------------------------------------------
    local function _arrayIndexOf(t, obj)
        if type(t) == 'table' then
            for i = 1, #t do
                if t[i] == obj then
                    return i
                end
            end

            return -1
        else
            error("table.indexOf expects table for first argument, " .. type(t) .. " given")
        end
    end

    ---------------------------------------------------
    --- Merge two tables
    ---
    --- @param dest table Destination table
    --- @param source table Source table
    --- @return table merged table
    ---------------------------------------------------
    local function _tableMerge(dest, source)
        if type(source) == "table" then
            for k, v in pairs(source) do
                if (type(v) == "table" and type(dest[k]) == "table") then
                    -- don't overwrite one table with another
                    -- instead merge them recurisvely
                    _tableMerge(dest[k], v)
                else
                    dest[k] = v
                end
            end
        end

        return dest
    end

    ---------------------------------------------------
    --- Get the new unique request id
    ---
    --- @return number unique request id
    ---------------------------------------------------
    local function _getReqId()
        cache.reqId = cache.reqId + 1
        return cache.reqId
    end

    ---------------------------------------------------
    --- Set websocket protocols based on options
    ---------------------------------------------------
    local function _setWsProtocols()
        local te = 'wamp.2.' .. options.transportEncoding
        local idx = _arrayIndexOf(cache.protocols, te)

        -- moving chosen encoding to first place (may be server choose it)
        if idx > 1 then
            table.remove(cache.protocols, idx)
            table.insert(cache.protocols, 1, te)
        end
    end

    ---------------------------------------------------
    --- Validate uri
    ---
    --- @param uri string uri to validate
    --- @param patternBased boolean allow wamp pattern based syntax or no
    --- @param allowWAMP boolean allow wamp special prefixed uris or no
    --- @return boolean if uri valid?
    ---------------------------------------------------
    local function _validateURI(uri, patternBased, allowWAMP)
        -- TODO create something like /^([0-9a-z_]+\.)*([0-9a-z_]+)$/
        local re = "^[0-9a-zA-Z_.]*[0-9a-zA-Z_]+$"
        -- TODO create something like /^([0-9a-zA-Z_]+\.{1,2})*([0-9a-zA-Z_]+)$/;
        local rePattern = "^[0-9a-zA-Z_.]*[0-9a-zA-Z_]+$"

        if patternBased == true then
            re = rePattern
        end

        if string.find(uri, re) == nil then
            return false
        elseif string.find(uri, "wamp.") == 1 and allowWAMP ~= true then
            return false
        else
            return true
        end
    end

    ---------------------------------------------------
    --- Prerequisite checks for any api call
    ---
    --- @param topicType table object { topic = URI, patternBased = true|false, allowWAMP = true|false }
    --- @param role string
    --- @param callbacks table api call callbacks
    --- @return boolean
    ---------------------------------------------------
    local function _preReqChecks(topicType, role, callbacks)
        local flag = true

        if cache.sessionId and not cache.serverWampFeatures.roles[role] then
            cache.opStatus = WAMP_ERROR_MSG['NO_' .. string.upper(role)]
            flag = false
        end

        if topicType ~= nil and not _validateURI(topicType.topic, topicType.patternBased, topicType.allowWAMP) then
            cache.opStatus = WAMP_ERROR_MSG.URI_ERROR
            flag = false
        end

        if flag then
            return true
        end

        if type(callbacks) == 'table' and type(callbacks.onError) == 'function' then
            callbacks.onError({ error = cache.opStatus.description })
        end
        return false
    end

    ---------------------------------------------------
    --- Encode WAMP message
    ---
    --- @param msg any message to encode
    --- @return any encoder specific encoded message
    ---------------------------------------------------
    local function _encode(msg)
        return serializer.encode(msg)
    end

    ---------------------------------------------------
    --- Decode WAMP message
    ---
    --- @param msg any message to decode
    --- @return any encoder specific decoded message
    ---------------------------------------------------
    local function _decode(msg)
        return serializer.decode(msg)
    end

    ---------------------------------------------------
    --- Send encoded message to server
    ---
    --- @param msg any message to send
    ---------------------------------------------------
    local function _send(msg)
        if msg ~= nil then
            table.insert(wsQueue, _encode(msg))
        end

        if ws ~= nil and ws.state == 'OPEN' and cache.sessionId ~= nil then
            while #wsQueue > 0 do
                _log('Sending message to server', 'Payload: ', wsQueue[1])
                ws:send(table.remove(wsQueue, 1), options.transportType)
            end
        end
    end

    ---------------------------------------------------
    --- Reset internal state and cache
    ---------------------------------------------------
    local function _resetState()
        wsQueue = {}
        requests = {}
        calls = {}
        subscriptions = {}
        subsTopics = {}
        rpcRegs = {}
        rpcNames = {}

        cache.protocols = { 'wamp.2.json' }
        cache.sessionId = nil
        cache.reqId = 0
        cache.serverWampFeatures = {
            roles = {}
        }
        cache.isSayingGoodbye = false
        cache.opStatus = {
            code = 0,
            description = 'Success!',
            reqId = 0
        }
        cache.timer = nil
        cache.reconnectingAttempts = 0

    end

    ---------------------------------------------------
    --- Connection open callback
    ---
    --- @param wsProtocol string Server choosen websocket subprotocol
    ---------------------------------------------------
    local function _wsOnOpen(wsProtocol)
        _log('websocket OnOpen event fired')

        if cache.timer ~= nil then
            local ev = require 'ev'
            cache.timer:stop(ev.Loop.default)
            cache.timer = nil
        end

        local runtimeOptions = _tableMerge(_tableMerge({}, options.helloCustomDetails), WAMP_FEATURES)

        if options.authid then
            runtimeOptions.authid = options.authid
            runtimeOptions.authmethods = options.authmethods
        end

        options.transportEncoding = string.match(wsProtocol,'.*%.([^.]+)$')

        local ws_meta = require('websocket')
        if options.transportEncoding == 'json' then
            options.transportType = ws_meta.TEXT
            serializer = require('loowy.json_serializer')
        else --if options.transportEncoding == 'msgpack' then
            options.transportType = ws_meta.BINARY
            serializer = require('loowy.msgpack_serializer')
        end

        ws:send(_encode({ WAMP_MSG_SPEC.HELLO, options.realm, runtimeOptions }), options.transportType)
    end

    ---------------------------------------------------
    --- Connection close callback
    ---------------------------------------------------
    local function _wsOnClose()
        _log('websocket OnClose event fired')

        if (cache.sessionId or cache.reconnectingAttempts) and options.autoReconnect and
            cache.reconnectingAttempts < options.maxRetries and not cache.isSayingGoodbye then
            cache.sessionId = nil
            local ev = require 'ev'
            cache.timer = ev.Timer.new(_wsReconnect, options.reconnectInterval, options.reconnectInterval)
            cache.timer:start(ev.Loop.default)
        else
            _resetState()
            ws = nil
            serializer = nil

            if type(options.onClose) == 'function' then
                options.onClose()
            end
        end
    end

    ---------------------------------------------------
    --- Renew subscriptions after reconnection to WAMP server
    ---------------------------------------------------
    local function _renewSubscriptions()
        local subs, st = subscriptions, subsTopics

        subscriptions, subsTopics = {}, {}

        for _, v in ipairs(st) do
            for _, vv in ipairs(subs[v].callbacks) do
                loowy:subscribe(v, vv)
            end
        end
    end

    ---------------------------------------------------
    --- Renew RPC registrations after reconnection to WAMP server
    ---------------------------------------------------
    local function _renewRegistrations()
        local rpcs, rn = rpcRegs, rpcNames

        rpcRegs, rpcNames = {}, {}

        for _, v in ipairs(rn) do
            loowy:register(v, { rpc = rpcs[v].callbacks[1] })
        end
    end

    ---------------------------------------------------
    --- Connection message callback
    ---
    --- @param event any received data
    ---------------------------------------------------
    local function _wsOnMessage(event)
        _log('websocket OnMessage event fired')

        local data = _decode(event);

        _log('Message received:', data)
        _log('WAMP message type is ' .. data[1])

        if data[1] == WAMP_MSG_SPEC.WELCOME then
            -- WAMP SPEC: [WELCOME, Session|id, Details|dict]

            cache.sessionId = data[2]
            cache.serverWampFeatures = data[3]

            if cache.reconnectingAttempts > 0 then
                -- There was reconnection
                cache.reconnectingAttempts = 0

                if type(options.onReconnectSuccess) == 'function' then
                    options.onReconnectSuccess()
                end

                _renewSubscriptions()
                _renewRegistrations()
            else
                if type(options.onConnect) == 'function' then
                    options.onConnect()
                end
            end

            -- Send local queue if there is something out there
            _send();

        elseif data[1] == WAMP_MSG_SPEC.ABORT then
            -- WAMP SPEC: [ABORT, Details|dict, Reason|uri]
            if type(options.onError) == 'function' then
                options.onError({ error = data[3], details = data[2] })
            end

            ws:close()
            ws = nil

        elseif data[1] == WAMP_MSG_SPEC.CHALLENGE then
            -- WAMP SPEC: [CHALLENGE, AuthMethod|string, Extra|dict]
            -- TODO implement CRA

        elseif data[1] == WAMP_MSG_SPEC.GOODBYE then
            -- WAMP SPEC: [GOODBYE, Details|dict, Reason|uri]

            if not cache.isSayingGoodbye then
                -- get goodbye, initiated by server
                cache.isSayingGoodbye = true
                _send({ WAMP_MSG_SPEC.GOODBYE, {}, 'wamp.error.goodbye_and_out' })
            end

            cache.sessionId = nil
            ws:close()
            ws = nil

        elseif data[1] == WAMP_MSG_SPEC.ERROR then
            -- WAMP SPEC: [ERROR, REQUEST.Type|int, REQUEST.Request|id, Details|dict,
            --             Error|uri, (Arguments|list, ArgumentsKw|dict)]

            if data[2] == WAMP_MSG_SPEC.SUBSCRIBE or
                data[2] == WAMP_MSG_SPEC.UNSUBSCRIBE or
                data[2] == WAMP_MSG_SPEC.PUBLISH or
                data[2] == WAMP_MSG_SPEC.REGISTER or
                data[2] == WAMP_MSG_SPEC.UNREGISTER then

                if requests[data[3]] then

                    if type(requests[data[3]].callbacks.onError) == 'function' then
                        requests[data[3]].callbacks.onError({
                            error = data[5],
                            details = data[4],
                            argsList = data[6],
                            argsDict = data[7]
                        })
                    end

                    requests[data[3]] = nil
                end

            -- elseif data[2] == WAMP_MSG_SPEC.INVOCATION then

            elseif data[2] == WAMP_MSG_SPEC.CALL then

                if calls[data[3]] then

                    if type(calls[data[3]].onError) == 'function' then
                        -- WAMP SPEC: [ERROR, CALL, CALL.Request|id, Details|dict,
                        --             Error|uri, Arguments|list, ArgumentsKw|dict]

                        calls[data[3]].onError({
                            error = data[5],
                            details = data[4],
                            argsList = data[6],
                            argsDict = data[7]
                        })
                    end

                    calls[data[3]] = nil
                end
            else
                _log('Received non-compliant WAMP ERROR message')
            end
        elseif data[1] == WAMP_MSG_SPEC.SUBSCRIBED then
            -- WAMP SPEC: [SUBSCRIBED, SUBSCRIBE.Request|id, Subscription|id]
            if requests[data[2]] then

                subscriptions[requests[data[2]].topic] = {
                    id = data[3],
                    callbacks = { requests[data[2]].callbacks.onEvent }
                }
                subscriptions[data[3]] = subscriptions[requests[data[2]].topic]

                table.insert(subsTopics, requests[data[2]].topic)

                if type(requests[data[2]].callbacks.onSuccess) == 'function' then
                    requests[data[2]].callbacks.onSuccess()
                end

                requests[data[2]] = nil
            end
        elseif data[1] == WAMP_MSG_SPEC.UNSUBSCRIBED then
            -- WAMP SPEC: [UNSUBSCRIBED, UNSUBSCRIBE.Request|id]
            if requests[data[2]] then

                local id = subscriptions[requests[data[2]].topic].id
                subscriptions[requests[data[2]].topic] = nil
                subscriptions[id] = nil

                local i = _arrayIndexOf(subsTopics, requests[data[2]].topic)
                if i > 0 then
                   table.remove(subsTopics, i)
                end

                if type(requests[data[2]].callbacks.onSuccess) == 'function' then
                    requests[data[2]].callbacks.onSuccess()
                end

                requests[data[2]] = nil
            end
        elseif data[1] == WAMP_MSG_SPEC.PUBLISHED then
            -- WAMP SPEC: [PUBLISHED, PUBLISH.Request|id, Publication|id]
            if requests[data[2]] then

                if type(requests[data[2]].callbacks.onSuccess) == 'function' then
                    requests[data[2]].callbacks.onSuccess()
                end

                requests[data[2]] = nil
            end
        elseif data[1] == WAMP_MSG_SPEC.EVENT then
            -- WAMP SPEC: [EVENT, SUBSCRIBED.Subscription|id, PUBLISHED.Publication|id,
            --             Details|dict, PUBLISH.Arguments|list, PUBLISH.ArgumentKw|dict]
            if subscriptions[data[2]] then

                for _, callback in ipairs(subscriptions[data[2]].callbacks) do
                    callback({
                        details = data[4],
                        argsList = data[5],
                        argsDict = data[6]
                    })
                end
            end
        elseif data[1] == WAMP_MSG_SPEC.RESULT then
            -- WAMP SPEC: [RESULT, CALL.Request|id, Details|dict, YIELD.Arguments|list, YIELD.ArgumentsKw|dict]
            if calls[data[2]] then

                calls[data[2]].onSuccess(data[4], data[5])
                if not (data[3].progress) then
                    -- We've received final result (progressive or not)
                    calls[data[2]] = nil
                end
            end
        elseif data[1] == WAMP_MSG_SPEC.REGISTERED then
            -- WAMP SPEC: [REGISTERED, REGISTER.Request|id, Registration|id]
            if requests[data[2]] then

                rpcRegs[requests[data[2]].topic] = {
                    id = data[3],
                    callbacks = { requests[data[2]].callbacks.rpc }
                }
                rpcRegs[data[3]] = rpcRegs[requests[data[2]].topic]

                table.insert(rpcNames, requests[data[2]].topic)

                if type(requests[data[2]].callbacks.onSuccess) == 'function' then
                    requests[data[2]].callbacks.onSuccess()
                end

                requests[data[2]] = nil
            end
        elseif data[1] == WAMP_MSG_SPEC.UNREGISTERED then
            -- WAMP SPEC: [UNREGISTERED, UNREGISTER.Request|id]
            if requests[data[2]] then

                local id = rpcRegs[requests[data[2]].topic].id
                rpcRegs[requests[data[2]].topic] = nil
                rpcRegs[id] = nil

                local i = _arrayIndexOf(rpcNames, requests[data[2]].topic)
                if i > 0 then
                   table.remove(rpcNames, i)
                end

                if type(requests[data[2]].callbacks.onSuccess) == 'function' then
                    requests[data[2]].callbacks.onSuccess()
                end

                requests[data[2]] = nil
            end
        elseif data[1] == WAMP_MSG_SPEC.INVOCATION then
            -- WAMP SPEC: [INVOCATION, Request|id, REGISTERED.Registration|id,
            --             Details|dict, CALL.Arguments|list, CALL.ArgumentsKw|dict]
            if rpcRegs[data[3]] then

                local msg
                local status, result = pcall(rpcRegs[data[3]].callbacks[1], {
                    details = data[4],
                    argsList = data[5],
                    argsDict = data[6]
                })

                _log('RPC invocation status: ', status, 'result: ', result)

                if status then

                    msg =  { WAMP_MSG_SPEC.YIELD, data[2], {} }
                    -- WAMP SPEC: [YIELD, INVOCATION.Request|id, Options|dict, (Arguments|list, ArgumentsKw|dict)]

                    if type(result) == 'table' then

                        if type(result.options) == 'table' then
                            msg[3] = result.options
                        end

                        if type(result.argsList) == 'table' then
                            if result.argsList[1] ~= nil then
                                table.insert(msg, result.argsList)
                            else    -- assume it's empty table
                                table.insert(msg, setmetatable({}, { __jsontype = 'array' }))
                            end
                        elseif result.argsList ~= nil then
                            table.insert(msg, { result.argsList })
                        end

                        if result.argsDict then
                            if #msg == 3 then
                                table.insert(msg, setmetatable({}, { __jsontype = 'array' }))
                            end
                            table.insert(msg, result.argsDict)
                        end

                    end
                else
                    -- WAMP SPEC: [ERROR, INVOCATION, INVOCATION.Request|id, Details|dict,
                    --             Error|uri, Arguments|list, ArgumentsKw|dict]
                    msg = { WAMP_MSG_SPEC.ERROR, WAMP_MSG_SPEC.INVOCATION, data[2],
                                  {}, 'wamp.error.invocation_exception' }

                    if type(result) == 'table' then

                        if result.details then
                            msg[4] = result.details
                        end

                        if result.error then
                            msg[5] = result.error
                        end

                        if type(result.argsList) == 'table' then
                            if result.argsList[1] ~= nil then
                                table.insert(msg, result.argsList)
                            else    -- assume it's empty table
                                table.insert(msg, setmetatable({}, { __jsontype = 'array' }))
                            end
                        elseif result.argsList ~= nil then
                            table.insert(msg, { result.argsList })
                        end

                        if result.argsDict then
                            if #msg == 5 then
                                table.insert(msg, setmetatable({}, { __jsontype = 'array' }))
                            end
                            table.insert(msg, result.argsDict)
                        end
                    end
                end
                _send(msg)
            else
                -- WAMP SPEC: [ERROR, INVOCATION, INVOCATION.Request|id, Details|dict, Error|uri]
                _send({ WAMP_MSG_SPEC.ERROR, WAMP_MSG_SPEC.INVOCATION,
                            data[2], {}, 'wamp.error.no_such_procedure' });

                cache.opStatus = WAMP_ERROR_MSG.NON_EXIST_RPC_INVOCATION
            end
--        elseif data[1] == WAMP_MSG_SPEC.INTERRUPT then

        else
            _log('Received non-compliant WAMP message')
        end

    end

    ---------------------------------------------------
    --- Connection error callback
    ---
    --- @param error any received error
    ---------------------------------------------------
    local function _wsOnError(error)
        _log('websocket OnError event fired with error: ' .. error)

        if type(options.onError) == 'function' then
            options.onError({ error = error })
        end
    end

    ---------------------------------------------------
    --- Initialize internal callbacks
    ---------------------------------------------------
    local function _initWsCallbacks()
        ws:on_open(function(_, wsProtocol, headers)
            _wsOnOpen(wsProtocol, headers)
        end)
        ws:on_close(function() --ws, was_clean,code,reason
            _wsOnClose()
        end)
        ws:on_message(function(_, msg)
            _wsOnMessage(msg)
        end)
        ws:on_error(function(_, err)
            if err ~= 'closed' then
                _wsOnError(err)
            end
        end)
    end

    ---------------------------------------------------
    --- Reconnection to WAMP server
    ---------------------------------------------------
    _wsReconnect = function ()
        _log('Reconnecting to websocket... Attempt No ' .. cache.reconnectingAttempts)

        if cache.reconnectingAttempts >= options.maxRetries then
            if cache.timer ~= nil then
                local ev = require 'ev'
                cache.timer:stop(ev.Loop.default)
                cache.timer = nil
            end

            if type(options.onClose) == 'function' then
                options.onClose()
            end

            _resetState()
            ws = nil
        else
            if type(options.onReconnect) == 'function' then
                options.onReconnect()
            end

            cache.reconnectingAttempts = cache.reconnectingAttempts + 1

            loowy:connect()
        end
    end

    ---------------------------------------------------
    -- End of Instance private methods
    ---------------------------------------------------

    ---------------------------------------------------
    -- Loowy instance public API
    ---------------------------------------------------

    ---------------------------------------------------
    --- Get or set options
    ---
    --- To get options - call without parameters
    --- To set options - pass table with options values
    --- @param newOpts table Hash-table with new options (optional)
    --- @return table without argument returns current options
    ---------------------------------------------------
    function loowy:options(newOpts)
        if newOpts == nil then
            return options
        else
            _tableMerge(options, newOpts)
            _setWsProtocols()
        end
    end

    ---------------------------------------------------
    --- Get the status of last operation
    ---
    --- @return table { code, description }
    ---          code: 0 - if operation was successful
    ---          code > 0 - if error occurred
    ---          description contains details about error
    ---          reqId: last send request ID
    ---------------------------------------------------
    function loowy:getOpStatus()
        return cache.opStatus
    end

    ---------------------------------------------------
    --- Get the WAMP Session ID
    ---
    --- @return number session ID
    ---------------------------------------------------
    function loowy:getSessionId()
        return cache.sessionId
    end

    ---------------------------------------------------
    --- Connect to server
    ---
    --- @param wampurl string WAMP Server url (optional)
    ---------------------------------------------------
    function loowy:connect(wampurl)
        if wampurl ~= nil then
            cache.url = wampurl
        end

        if options.realm then
            ws = require('websocket.client').ev()
            ws:connect(cache.url, cache.protocols)
            _initWsCallbacks()
        else
            cache.opStatus = WAMP_ERROR_MSG.NO_REALM
        end
    end

    ---------------------------------------------------
    --- Disconnect from server
    ---------------------------------------------------
    function loowy:disconnect()
        if cache.sessionId ~= nil then
            -- need to send goodbye message to server
            cache.isSayingGoodbye = true
            _send({ WAMP_MSG_SPEC.GOODBYE, {}, 'wamp.error.system_shutdown' })
        elseif ws ~= nil then
            ws:close()
            ws = nil
            serializer = nil
        end

        cache.opStatus = WAMP_ERROR_MSG.SUCCESS
    end

    ---------------------------------------------------
    --- Abort WAMP session establishment
    ---------------------------------------------------
    function loowy:abort()
        if not cache.sessionId and ws.state == 'OPEN' then
            _send({ WAMP_MSG_SPEC.ABORT, {}, 'wamp.error.abort' })
            cache.sessionId = nil
        end

        ws:close()
        ws = nil
        serializer = nil

        cache.opStatus = WAMP_ERROR_MSG.SUCCESS
    end

    -------------------------------------------------------------------------------------------
    --- Subscribe to a topic on a broker
    ---
    --- @param topicURI string topic to subscribe
    --- @param callbacks function|table if it is a function - it will be treated as published event callback
    ---             or it can be hash table of callbacks:
    ---             {
    ---                 onSuccess: will be called when subscribe would be confirmed
    ---                 onError: will be called if subscribe would be aborted
    ---                 onEvent: will be called on receiving published event
    ---             }
    --- @param advancedOptions table optional parameter. Must include any or all of the options:
    ---             {
    ---                 match: string matching policy ("prefix"|"wildcard")
    ---             }
    -------------------------------------------------------------------------------------------
    function loowy:subscribe(topicURI, callbacks, advancedOptions)
        local reqId
        local patternBased = false
        local subscribeOptions = {}

        if type(advancedOptions) == 'table' and type(advancedOptions.match) == 'string' then

            if string.find(advancedOptions.match, '^prefix$') or
               string.find(advancedOptions.match, '^wildcard$') then
                subscribeOptions.match = advancedOptions.match
                patternBased = true
            end
        end

        if not _preReqChecks({ topic = topicURI, patternBased = patternBased, allowWAMP = true },
            'broker', callbacks) then
            return
        end

        if type(callbacks) == 'function' then
            callbacks = { onEvent = callbacks }
        elseif type(callbacks) ~= 'table' or type(callbacks.onEvent) ~= 'function' then
            cache.opStatus = WAMP_ERROR_MSG.NO_CALLBACK_SPEC

            if type(callbacks.onError) == 'function' then
                callbacks.onError({ error = cache.opStatus.description })
            end

            return
        end

        if not subscriptions[topicURI] or #subscriptions[topicURI].callbacks == 0 then     -- no such subscription

            reqId = _getReqId()

            requests[reqId] = { topic = topicURI, callbacks = callbacks }

            -- WAMP SPEC: [SUBSCRIBE, Request|id, Options|dict, Topic|uri]
            _send({ WAMP_MSG_SPEC.SUBSCRIBE, reqId, subscribeOptions, topicURI })

        else    -- already have subscription to this topic

            -- There is no such callback yet
            if _arrayIndexOf(subscriptions[topicURI].callbacks, callbacks.onEvent) < 0 then
                table.insert(subscriptions[topicURI].callbacks, callbacks.onEvent)
            end

            if type(callbacks.onSuccess) == 'function' then
                callbacks.onSuccess()
            end

        end

        cache.opStatus = WAMP_ERROR_MSG.SUCCESS
        cache.opStatus.reqId = reqId;
    end

    ---------------------------------------------------------------------------------------------
    --- Unsubscribe from topic
    ---
    --- @param topicURI string topic to unsubscribe
    --- @param callbacks function|table if it is a function - it will be treated as
    ---             published event callback to remove or it can be hash table of callbacks:
    ---             {
    ---                 onSuccess: will be called when unsubscribe would be confirmed
    ---                 onError: will be called if unsubscribe would be aborted
    ---                 onEvent: published event callback to remove (and allow others
    ---             }
    ---------------------------------------------------------------------------------------------
    function loowy:unsubscribe(topicURI, callbacks)
        local reqId
        local i = -1

        if not _preReqChecks(nil, 'broker', callbacks) then
            return
        end

        if subscriptions[topicURI] then

            reqId = _getReqId()

            if callbacks == nil then
                subscriptions[topicURI].callbacks = {}
                callbacks = {}
            elseif type(callbacks) == 'function' then
                i = _arrayIndexOf(subscriptions[topicURI].callbacks, callbacks)
                callbacks = {}
            elseif type(callbacks.onEvent) == 'function' then
                i = _arrayIndexOf(subscriptions[topicURI].callbacks, callbacks.onEvent)
            else
                subscriptions[topicURI].callbacks = {}
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
                callbacks.onError({ error = cache.opStatus.description })
            end

            return
        end

        cache.opStatus = WAMP_ERROR_MSG.SUCCESS
        cache.opStatus.reqId = reqId;
    end

    ----------------------------------------------------------------------------------------------------------------
    --- Publish a event to topic
    ---
    --- @param topicURI string topic to publish
    --- @param payload any optional parameter, can be either a value of any type or null.  Also it is possible
    ---           to pass array and object-like data simultaneously.
    ---           In this case pass a  table with next attributes:
    ---           {
    ---              argsList: array payload (may be omitted)
    ---              argsDict: object payload (may be omitted)
    ---           }
    --- @param callbacks table optional table of callbacks:
    ---           {
    ---              onSuccess: will be called when publishing would be confirmed
    ---              onError: will be called if publishing would be aborted
    ---           }
    --- @param advancedOptions table optional parameter. Must include any or all of the options:
    ---           {
    ---              exclude: integer|array WAMP session id(s) that won't receive a published event,
    ---                                     even though they may be subscribed
    ---              exclude_authid: string|array Authentication id(s) that won't receive
    ---                                     a published event, even though they may be subscribed
    ---              exclude_authrole: string|array Authentication role(s) that won't receive
    ---                                     a published event, even though they may be subscribed
    ---              eligible: integer|array WAMP session id(s) that are allowed
    ---                                     to receive a published event
    ---              eligible_authid: string|array Authentication id(s) that are allowed
    ---                                     to receive a published event
    ---              eligible_authrole: string|array Authentication role(s) that are allowed
    ---                                     to receive a published event
    ---              exclude_me: bool flag of receiving publishing event by initiator
    ---              disclose_me: bool flag of disclosure of publisher identity (its WAMP session ID)
    ---                                     to receivers of a published event
    ---           }
    ----------------------------------------------------------------------------------------------------------------
    function loowy:publish(topicURI, payload, callbacks, advancedOptions)
        local reqId, msg
        local publishOptions = {}
        local err = false

        if not _preReqChecks({ topic = topicURI, patternBased = false, allowWAMP = false },
            'broker', callbacks) then
            return
        end

        if type(callbacks) == 'table' then
            publishOptions.acknowledge = true
        end

        if type(advancedOptions) == 'table' then

            if advancedOptions.exclude then
                if type(advancedOptions.exclude) == 'table' then
                    publishOptions.exclude = advancedOptions.exclude
                elseif type(advancedOptions.exclude) == 'number' then
                    publishOptions.exclude = { advancedOptions.exclude }
                else
                    err = true
                end
            end

            if advancedOptions.exclude_authid then
                if type(advancedOptions.exclude_authid) == 'table' then
                    publishOptions.exclude_authid = advancedOptions.exclude_authid
                elseif type(advancedOptions.exclude_authid) == 'string' then
                    publishOptions.exclude_authid = { advancedOptions.exclude_authid }
                else
                    err = true
                end
            end

            if advancedOptions.exclude_authrole then
                if type(advancedOptions.exclude_authrole) == 'table' then
                    publishOptions.exclude_authrole = advancedOptions.exclude_authrole
                elseif type(advancedOptions.exclude_authrole) == 'string' then
                    publishOptions.exclude_authrole = { advancedOptions.exclude_authrole }
                else
                    err = true
                end
            end

            if advancedOptions.eligible then
                if type(advancedOptions.eligible) == 'table' then
                    publishOptions.eligible = advancedOptions.eligible
                elseif type(advancedOptions.eligible) == 'number' then
                    publishOptions.eligible = { advancedOptions.eligible }
                else
                    err = true
                end
            end

            if advancedOptions.eligible_authid then
                if type(advancedOptions.eligible_authid) == 'table' then
                    publishOptions.eligible_authid = advancedOptions.eligible_authid
                elseif type(advancedOptions.eligible_authid) == 'string' then
                    publishOptions.eligible_authid = { advancedOptions.eligible_authid }
                else
                    err = true
                end
            end

            if advancedOptions.eligible_authrole then
                if type(advancedOptions.eligible_authrole) == 'table' then
                    publishOptions.eligible_authrole = advancedOptions.eligible_authrole
                elseif type(advancedOptions.eligible_authrole) == 'string' then
                    publishOptions.eligible_authrole = { advancedOptions.eligible_authrole }
                else
                    err = true
                end
            end

            if type(advancedOptions.exclude_me) == 'boolean' then
                publishOptions.exclude_me = advancedOptions.exclude_me ~= false
            elseif advancedOptions.exclude_me ~= nil then
                err = true
            end

            if type(advancedOptions.disclose_me) == 'boolean' then
                publishOptions.disclose_me = advancedOptions.disclose_me == true
            elseif advancedOptions.disclose_me ~= nil then
                err = true
            end

            if err then

                cache.opStatus = WAMP_ERROR_MSG.INVALID_PARAM

                if type(callbacks.onError) == 'function' then
                    callbacks.onError({ error = cache.opStatus.description })
                end

                return
            end
        end

        reqId = _getReqId()

        if callbacks ~= nil then
            requests[reqId] = {
                topic = topicURI,
                callbacks = callbacks
            }
        end


        -- WAMP_SPEC: [PUBLISH, Request|id, Options|dict, Topic|uri(, Arguments|list (, ArgumentsKw|dict))]
        msg = { WAMP_MSG_SPEC.PUBLISH, reqId, publishOptions, topicURI }

        if payload ~= nil then

            if type(payload) == 'table' and payload[1] ~= nil then -- assume it's an array
                table.insert(msg, payload)
            elseif type(payload) == 'table' then    -- it's a dict

                -- check for unified form of payload passing
                if payload.argsList or payload.argsDict then

                    if type(payload.argsList) == 'table' then
                        if payload.argsList[1] ~= nil then
                            table.insert(msg, payload.argsList)
                        end
                    elseif payload.argsList ~= nil then
                        table.insert(msg, { payload.argsList })
                    end

                    if payload.argsDict then
                        if #msg == 4 then
                            table.insert(msg, setmetatable({}, { __jsontype = 'array' }))
                        end
                        table.insert(msg, payload.argsDict)
                    end
                else
                    table.insert(msg, setmetatable({}, { __jsontype = 'array' }))
                    table.insert(msg, payload)
                end
            else    -- assume it's a single value
                table.insert(msg, { payload })
            end
        end

        _send(msg)
        cache.opStatus = WAMP_ERROR_MSG.SUCCESS
        cache.opStatus.reqId = reqId;
    end

    --------------------------------------------------------------------------------------------------------------------
    --- Remote Procedure Call
    ---
    --- @param topicURI string topic to call
    --- @param payload any optional parameter, can be either a value of any type or null.  Also it is possible
    ---           to pass array and object-like data simultaneously.
    ---           In this case pass a  table with next attributes:
    ---           {
    ---              argsList: array payload (may be omitted)
    ---              argsDict: object payload (may be omitted)
    ---           }
    --- @param callbacks function|table if it is a function - it will be treated as result callback function
    ---                     or it can be hash table of callbacks:
    ---           {
    ---               onSuccess: will be called with result on successful call
    ---               onError: will be called if invocation would be aborted
    ---           }
    --- @param advancedOptions table optional parameter. Must include any or all of the options:
    ---           {
    ---               disclose_me: bool flag of disclosure of Caller identity (WAMP session ID)
    ---                                  to endpoints of a routed call
    ---               receive_progress: bool flag for receiving progressive results. In this case
    ---                                  onSuccess function will be called every time on receiving result
    ---               timeout: integer timeout (in seconds) for the call to finish
    ---           }
    --------------------------------------------------------------------------------------------------------------------
    function loowy:call(topicURI, payload, callbacks, advancedOptions)
        local reqId, msg
        local callOptions = {}
        local err = false

        if not _preReqChecks({ topic = topicURI, patternBased = false, allowWAMP = true },
            'dealer', callbacks) then
            return
        end

        if type(callbacks) == 'function' then
            callbacks = { onSuccess = callbacks }
        elseif type(callbacks) ~= 'table' or type(callbacks.onSuccess) ~= 'function' then
            cache.opStatus = WAMP_ERROR_MSG.NO_CALLBACK_SPEC

            if type(callbacks.onError) == 'function' then
                callbacks.onError({ error = cache.opStatus.description })
            end

            return
        end

        if type(advancedOptions) == 'table' then

            if type(advancedOptions.disclose_me) == 'boolean' then
                callOptions.disclose_me = advancedOptions.disclose_me == true
            elseif advancedOptions.disclose_me ~= nil then
                err = true
            end

            if type(advancedOptions.receive_progress) == 'boolean' then
                callOptions.receive_progress = advancedOptions.receive_progress == true
            elseif advancedOptions.receive_progress ~= nil then
                err = true
            end

            if type(advancedOptions.timeout) == 'number' then
                callOptions.timeout = advancedOptions.timeout
            elseif advancedOptions.timeout ~= nil then
                err = true
            end

            if err then

                cache.opStatus = WAMP_ERROR_MSG.INVALID_PARAM

                if type(callbacks.onError) == 'function' then
                    callbacks.onError({ error = cache.opStatus.description })
                end

                return
            end
        end

        reqId = _getReqId()
        while calls[reqId] ~= nil do
            reqId = _getReqId()
        end

        calls[reqId] = callbacks

        -- WAMP SPEC: [CALL, Request|id, Options|dict, Procedure|uri, (Arguments|list, ArgumentsKw|dict)]
        msg = { WAMP_MSG_SPEC.CALL, reqId, callOptions, topicURI }

        if payload ~= nil then

            if type(payload) == 'table' and payload[1] ~= nil then -- assume it's an array
                table.insert(msg, payload)
            elseif type(payload) == 'table' then    -- it's a dict

                -- check for unified form of payload passing
                if payload.argsList or payload.argsDict then
                    if type(payload.argsList) == 'table' then
                        if payload.argsList[1] ~= nil then
                            table.insert(msg, payload.argsList)
                        end
                    elseif payload.argsList ~= nil then
                        table.insert(msg, { payload.argsList })
                    end

                    if payload.argsDict then
                        if #msg == 4 then
                            table.insert(msg, setmetatable({}, { __jsontype = 'array' }))
                        end
                        table.insert(msg, payload.argsDict)
                    end
                else
                    table.insert(msg, setmetatable({}, { __jsontype = 'array' }))
                    table.insert(msg, payload)
                end
            else    -- assume it's a single value
                table.insert(msg, { payload })
            end
        end

        _send(msg)
        cache.opStatus = WAMP_ERROR_MSG.SUCCESS
        cache.opStatus.reqId = reqId;
    end

    ------------------------------------------------------------------------------------------
    --- RPC invocation cancelling
    ---
    --- @param reqId number RPC call request ID
    --- @param callbacks function|table if it is a function - it will be called if successfully
    ---             sent canceling message or it can be hash table of callbacks:
    ---             {
    ---                 onSuccess: will be called if successfully sent canceling message
    ---                 onError: will be called if some error occurred
    ---             }
    --- @param advancedOptions table optional parameter. Must include any or all of the options:
    ---             {
    ---                 mode: string|one of the possible modes: "skip" | "kill" | "killnowait". Skip is default
    ---             }
    ------------------------------------------------------------------------------------------
    function loowy:cancel(reqId, callbacks, advancedOptions)
        local cancelOptions = {}
        local err = false

        if not _preReqChecks(nil, 'dealer', callbacks) then
            return
        end

        if not reqId or not calls[reqId] then
            cache.opStatus = WAMP_ERROR_MSG.NON_EXIST_RPC_REQ_ID

            if type(callbacks.onError) == 'function' then
                callbacks.onError({ error = cache.opStatus.description })
            end

            return
        end

        if type(advancedOptions) == 'table' then

            if type(advancedOptions.mode) == 'string' then

                if string.find(advancedOptions.mode, '^skip$') or
                        string.find(advancedOptions.mode, '^kill$') or
                        string.find(advancedOptions.mode, '^killnowait$') then
                    cancelOptions.mode = advancedOptions.mode
                else
                    err = true
                end
            else
                err = true
            end

            if err then

                cache.opStatus = WAMP_ERROR_MSG.INVALID_PARAM

                if type(callbacks.onError) == 'function' then
                    callbacks.onError({ error = cache.opStatus.description })
                end

                return
            end
        end

        _send({ WAMP_MSG_SPEC.CANCEL, reqId, cancelOptions })
        cache.opStatus = WAMP_ERROR_MSG.SUCCESS
        cache.opStatus.reqId = reqId;

        if type(callbacks.onSuccess) == 'function' then
            callbacks.onSuccess()
        end
    end

    ------------------------------------------------------------------------------------------
    --- RPC registration for invocation
    ---
    --- @param topicURI string topic to register
    --- @param callbacks function|table if it is a function - it will be treated as rpc itself
    ---             or it can be hash table of callbacks:
    ---             {
    ---                 rpc: registered procedure
    ---                 onSuccess: will be called on successful registration
    ---                 onError: will be called if registration would be aborted
    ---             }
    --- @param advancedOptions table optional parameter. Must include any or all of the options:
    ---             {
    ---                 match: string matching policy ("prefix"|"wildcard")
    ---                 invoke: string invocation policy ("single"|"roundrobin"|"random"|"first"|"last")
    ---             }
    ------------------------------------------------------------------------------------------
    function loowy:register(topicURI, callbacks, advancedOptions)
        local reqId
        local patternBased = false
        local registerOptions = {}
        local err = false

        if type(advancedOptions) == 'table' then

            if type(advancedOptions.match) == 'string' then

                if string.find(advancedOptions.mode, '^prefix$') or
                        string.find(advancedOptions.mode, '^wildcard$') then
                    registerOptions.match = advancedOptions.match
                    patternBased = true
                else
                    err = true
                end
            else
                err = true
            end

            if type(advancedOptions.invoke) == 'string' then

                if string.find(advancedOptions.invoke, '^single$') or
                        string.find(advancedOptions.invoke, '^roundrobin$') or
                        string.find(advancedOptions.invoke, '^random$') or
                        string.find(advancedOptions.invoke, '^first$') or
                        string.find(advancedOptions.invoke, '^last$') then
                    registerOptions.invoke = advancedOptions.invoke
                else
                    err = true
                end
            else
                err = true
            end

            if err then

                cache.opStatus = WAMP_ERROR_MSG.INVALID_PARAM

                if type(callbacks.onError) == 'function' then
                    callbacks.onError({ error = cache.opStatus.description })
                end

                return
            end
        end

        if not _preReqChecks({ topic = topicURI, patternBased = patternBased, allowWAMP = false },
            'dealer', callbacks) then
            return
        end

        if type(callbacks) == 'function' then
            callbacks = { rpc = callbacks }
        elseif type(callbacks) ~= 'table' or type(callbacks.rpc) ~= 'function' then
            cache.opStatus = WAMP_ERROR_MSG.NO_CALLBACK_SPEC

            if type(callbacks.onError) == 'function' then
                callbacks.onError({ error = cache.opStatus.description })
            end

            return
        end

        if not rpcRegs[topicURI] or #rpcRegs[topicURI].callbacks == 0 then     -- no such registration

            reqId = _getReqId()

            requests[reqId] = { topic = topicURI, callbacks = callbacks }

            -- WAMP SPEC: [REGISTER, Request|id, Options|dict, Procedure|uri]
            _send({ WAMP_MSG_SPEC.REGISTER, reqId, registerOptions, topicURI })
            cache.opStatus = WAMP_ERROR_MSG.SUCCESS
            cache.opStatus.reqId = reqId;

        else    -- already have registration with such topicURI

            cache.opStatus = WAMP_ERROR_MSG.RPC_ALREADY_REGISTERED

            if type(callbacks.onError) == 'function' then
                callbacks.onError({ error = cache.opStatus.description })
            end

        end
    end

    -------------------------------------------------------------------------------------------
    --- RPC unregistration for invocation
    ---
    --- @param topicURI string topic to unregister
    --- @param callbacks function|table if it is a function, it will be called on successful unregistration
    ---             or it can be hash table of callbacks:
    ---             {
    ---                 onSuccess: will be called on successful unregistration
    ---                 onError: will be called if unregistration would be aborted
    ---             }
    -------------------------------------------------------------------------------------------
    function loowy:unregister(topicURI, callbacks)
        local reqId

        if not _preReqChecks({ topic = topicURI, patternBased = false, allowWAMP = false },
            'dealer', callbacks) then
            return
        end

        if type(callbacks) == 'function' then
            callbacks = { onSuccess = callbacks }
        end

        if rpcRegs[topicURI] then   -- there is such registration

            reqId = _getReqId()

            requests[reqId] = { topic = topicURI, callbacks = callbacks }

            -- WAMP SPEC: [UNREGISTER, Request|id, REGISTERED.Registration|id]
            _send({ WAMP_MSG_SPEC.UNREGISTER, reqId, rpcRegs[topicURI].id })
            cache.opStatus = WAMP_ERROR_MSG.SUCCESS
            cache.opStatus.reqId = reqId;
        else    -- already have registration with such topicURI

            cache.opStatus = WAMP_ERROR_MSG.NON_EXIST_RPC_UNREG

            if type(callbacks.onError) == 'function' then
                callbacks.onError({ error = cache.opStatus.description })
            end
        end
    end

    ---------------------------------------------------
    -- End of Loowy instance public API
    ---------------------------------------------------

    if opts ~= nil then
        -- Merging user options
        _tableMerge(options, opts)
        _setWsProtocols()
    end

    if url ~= nil then
        loowy:connect(url)
    end

    return loowy
end

return _M
