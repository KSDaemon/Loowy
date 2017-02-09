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

require "debug.var_dump"
local ev = require 'ev'
local loowy = require 'loowy.client'

local client1, client2

print('Connecting clients to WAMP Server: ' ..  wsServer)

client1 = loowy.new(wsServer, { transportEncoding = 'json',
    realm = config.realm,
    maxRetries = config.maxRetries,
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
                var_dump(evt)
            end
        })

        print ('Publishing to topic.test1 instance 1 without payload')
        client1:publish('topic.test1', nil, {
            onSuccess = function()
                print 'Got to publish to topic topic.test1 instance 1 onSuccess'
            end,
            onError = function(err)
                print ('Got to publish to topic topic.test1 instance 1 onError: ' .. err)
            end
        })

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
                var_dump(data)
                return data
            end,
            onSuccess = function()
                print 'Got to register rpc rpc.test1 instance 1 onSuccess'
            end,
            onError = function(err)
                print ('Got to register rpc rpc.test1 instance 1 onError: ' .. err)
            end
        })

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

client1 = loowy.new(wsServer, { transportEncoding = 'json',
    realm = config.realm,
    maxRetries = config.maxRetries,
    onConnect = function()
        print 'Got to WAMP Client instance 2 onConnect callback'

        print ('Subscribing to topic.test1')
        client1:subscribe('topic.test1', {
            onSuccess = function()
                print 'Got to topic topic.test1 instance 2 subscribe onSuccess'
            end,
            onError = function(err)
                print ('Got to topic topic.test1 instance 2 subscribe onError: ' .. err)
            end,
            onEvent = function(evt)
                print 'Got to topic topic.test1 instance 2 subscribe onEvent'
                print ('Event payload: ')
                var_dump(evt)
            end
        })

        print ('Publishing to topic.test1 instance 2 without payload')
        client1:publish('topic.test1', nil, {
            onSuccess = function()
                print 'Got to publish to topic topic.test1 instance 2 onSuccess'
            end,
            onError = function(err)
                print ('Got to publish to topic topic.test1 instance 2 onError: ' .. err)
            end
        })

        local unsubscribeTimer
        unsubscribeTimer = ev.Timer.new(function()
            unsubscribeTimer:stop(ev.Loop.default)
            print ('Unsubscribing from topic.test1 instance 2')
            client1:unsubscribe('topic.test1', {
                onSuccess = function()
                    print 'Got to unsubscribe from topic topic.test1 instance 2 onSuccess'
                end,
                onError = function(err)
                    print ('Got to unsubscribe from topic topic.test1 instance 2 onError: ' .. err)
                end
            })
        end, 10)
        unsubscribeTimer:start(ev.Loop.default)

        print ('Registering new RPC rpc.test2 instance 2')
        client1:register('rpc.test2', {
            rpc = function (data)
                print ('Invoked rpc.test2 instance 2')
                print ('RPC payload')
                var_dump(data)
                return data
            end,
            onSuccess = function()
                print 'Got to register rpc rpc.test1 instance 2 onSuccess'
            end,
            onError = function(err)
                print ('Got to register rpc rpc.test1 instance 2 onError: ' .. err)
            end
        })

        local disconnectTimer
        disconnectTimer = ev.Timer.new(function()
            disconnectTimer:stop(ev.Loop.default)
            print ('Disconnecting from WAMP Server instance 2')
            client1:disconnect()
        end, 30)
        disconnectTimer:start(ev.Loop.default)

    end,
    onClose = function()
        print 'Got to WAMP Client instance 2 onClose callback'
    end,
    onError = function(err)
        print ('Got to WAMP Client instance 2 onError callback: ' .. err)
    end,
    onReconnect = function()
        print 'Got to WAMP Client instance 2 onReconnect callback'
    end
})

ev.Loop.default:loop()
