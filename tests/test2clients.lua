--
-- Project: Loowy
-- User: kostik
-- Date: 09.02.17
--

package.path = "../src/?.lua;" .. package.path

local config = {}
local wsServer

for line in io.lines('config.ini') do
    local key, value = line:match("^(%w+)%s*=%s*(.+)$")
    if key and value then
        if tonumber(value) then value = tonumber(value) end
        if value == "true" then value = true end
        if value == "false" then value = false end

        if key == 'wsServer' then
            wsServer = value
        else
            config[key] = value
        end
    end
end

local printdump = require("loowy.vardump").printdump
local ev = require 'ev'
local loowy = require 'loowy.client'

local client1, client2

print('Connecting clients to WAMP Server: ' ..  wsServer)

client1 = loowy.new(wsServer, { transportEncoding = 'json',
    realm = config.realm,
    maxRetries = config.maxRetries,
    transportEncoding = config.transportEncoding,
    debug = config.debug,
    onConnect = function()
        print 'Got to WAMP Client instance 1 onConnect callback'

        print ('Subscribing to topic.test1')
        client1:subscribe('topic.test1', {
            onSuccess = function()
                print 'Got to topic topic.test1 instance 1 subscribe onSuccess'
            end,
            onError = function(err)
                print ('Got to topic topic.test1 instance 1 subscribe onError: ' .. err)
            end,
            onEvent = function(evt)
                print 'Got to topic topic.test1 instance 1 subscribe onEvent'
                print ('Event payload: ')
                printdump(evt)
            end
        })

        local publishTimer
        publishTimer = ev.Timer.new(function()
            publishTimer:stop(ev.Loop.default)
            print ('Publishing to topic.test1 instance 1 without payload')
            client1:publish('topic.test1', nil, {
                onSuccess = function()
                    print 'Got to publish to topic topic.test1 instance 1 onSuccess'
                end,
                onError = function(err)
                    print ('Got to publish to topic topic.test1 instance 1 onError: ' .. err)
                end
            })
        end, 10)
        publishTimer:start(ev.Loop.default)

        local unsubscribeTimer
        unsubscribeTimer = ev.Timer.new(function()
            unsubscribeTimer:stop(ev.Loop.default)
            print ('Unsubscribing from topic.test1 instance 1')
            client1:unsubscribe('topic.test1', {
                onSuccess = function()
                    print 'Got to unsubscribe from topic topic.test1 instance 1 onSuccess'
                end,
                onError = function(err)
                    print ('Got to unsubscribe from topic topic.test1 instance 1 onError: ' .. err)
                end
            })
        end, 10)
        unsubscribeTimer:start(ev.Loop.default)

        print ('Registering new RPC rpc.test1 instance 1')
        client1:register('rpc.test1', {
            rpc = function (data)
                print ('Invoked rpc.test1 instance 1')
                print ('RPC payload')
                printdump(data)
                return data
            end,
            onSuccess = function()
                print 'Got to register rpc rpc.test1 instance 1 onSuccess'
            end,
            onError = function(err)
                print ('Got to register rpc rpc.test1 instance 1 onError: ' .. err)
            end
        })

        local callTimer
        callTimer = ev.Timer.new(function()
            callTimer:stop(ev.Loop.default)
            print 'Calling rpc rpc.test2 from instance 1 with payload: string "string payload"'
            client1:call('rpc.test2', "string payload", {
                onSuccess = function(data)
                    print 'Got to rpc call rpc.test2 onSuccess'
                    print 'Call result'
                    printdump(data)
                end,
                onError = function(err)
                    print ('Got to rpc call rpc.test2 instance 1 onError: ' .. err)
                end

            })
        end, 10)
        callTimer:start(ev.Loop.default)

        local disconnectTimer
        disconnectTimer = ev.Timer.new(function()
            disconnectTimer:stop(ev.Loop.default)
            print ('Disconnecting from WAMP Server instance 1')
            client1:disconnect()
        end, 30)
        disconnectTimer:start(ev.Loop.default)

    end,
    onClose = function()
        print 'Got to WAMP Client instance 1 onClose callback'
    end,
    onError = function(err)
        print ('Got to WAMP Client instance 1 onError callback: ' .. err)
    end,
    onReconnect = function()
        print 'Got to WAMP Client instance 1 onReconnect callback'
    end
})

client2 = loowy.new(wsServer, { transportEncoding = 'json',
    realm = config.realm,
    maxRetries = config.maxRetries,
    transportEncoding = config.transportEncoding,
    debug = config.debug,
    onConnect = function()
        print 'Got to WAMP Client instance 2 onConnect callback'

        print ('Subscribing to topic.test1')
        client2:subscribe('topic.test1', {
            onSuccess = function()
                print 'Got to topic topic.test1 instance 2 subscribe onSuccess'
            end,
            onError = function(err)
                print ('Got to topic topic.test1 instance 2 subscribe onError: ' .. err)
            end,
            onEvent = function(evt)
                print 'Got to topic topic.test1 instance 2 subscribe onEvent'
                print ('Event payload: ')
                printdump(evt)
            end
        })

        local publishTimer
        publishTimer = ev.Timer.new(function()
            publishTimer:stop(ev.Loop.default)
            print ('Publishing to topic.test1 instance 2 without payload')
            client2:publish('topic.test1', nil, {
                onSuccess = function()
                    print 'Got to publish to topic topic.test1 instance 2 onSuccess'
                end,
                onError = function(err)
                    print ('Got to publish to topic topic.test1 instance 2 onError: ' .. err)
                end
            })
        end, 10)
        publishTimer:start(ev.Loop.default)

        local unsubscribeTimer
        unsubscribeTimer = ev.Timer.new(function()
            unsubscribeTimer:stop(ev.Loop.default)
            print ('Unsubscribing from topic.test1 instance 2')
            client2:unsubscribe('topic.test1', {
                onSuccess = function()
                    print 'Got to unsubscribe from topic topic.test1 instance 2 onSuccess'
                end,
                onError = function(err)
                    print ('Got to unsubscribe from topic topic.test1 instance 2 onError: ' .. err)
                end
            })
        end, 20)
        unsubscribeTimer:start(ev.Loop.default)

        print ('Registering new RPC rpc.test2 instance 2')
        client2:register('rpc.test2', {
            rpc = function (data)
                print ('Invoked rpc.test2 instance 2')
                print ('RPC payload')
                printdump(data)
                return data
            end,
            onSuccess = function()
                print 'Got to register rpc rpc.test2 instance 2 onSuccess'
            end,
            onError = function(err)
                print ('Got to register rpc rpc.test2 instance 2 onError: ' .. err)
            end
        })

        local callTimer
        callTimer = ev.Timer.new(function()
            callTimer:stop(ev.Loop.default)
            print 'Calling rpc rpc.test1 from instance 2 with payload: string "string payload"'
            client2:call('rpc.test1', "string payload", {
                onSuccess = function(data)
                    print 'Got to rpc call rpc.test1 onSuccess'
                    print 'Call result'
                    printdump(data)
                end,
                onError = function(err)
                    print ('Got to rpc call rpc.test1 instance 2 onError: ' .. err)
                end

            })
        end, 10)
        callTimer:start(ev.Loop.default)

        local disconnectTimer
        disconnectTimer = ev.Timer.new(function()
            disconnectTimer:stop(ev.Loop.default)
            print ('Disconnecting from WAMP Server instance 2')
            client2:disconnect()
        end, 30)
        disconnectTimer:start(ev.Loop.default)

    end,
    onClose = function()
        print 'Got to WAMP Client instance 2 onClose callback'
    end,
    onError = function(err1)
        printdump(err1)
        print ('Got to WAMP Client instance 2 onError callback: ' .. err1)
    end,
    onReconnect = function()
        print 'Got to WAMP Client instance 2 onReconnect callback'
    end
})

ev.Loop.default:loop()
