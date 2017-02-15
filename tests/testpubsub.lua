--
-- Project: Loowy
-- User: kostik
-- Date: 08.03.15
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
local client1

print('Connecting client to WAMP Server: ' ..  wsServer)
client1 = loowy.new(wsServer, { transportEncoding = 'json',
    debug = true,
    realm = config.realm,
    maxRetries = config.maxRetries,
    onConnect = function()
        print 'Got to WAMP Client instance onConnect callback'

        print ('Subscribing to topic.test1')
        client1:subscribe('topic.test1', {
            onSuccess = function()
                print 'Got to topic topic.test1 subscribe onSuccess'
            end,
            onError = function(err)
                print ('Got to topic topic.test1 subscribe onError: ' .. err)
            end,
            onEvent = function(evt)
                print 'Got to topic topic.test1 subscribe onEvent'
                print ('Event payload: ')
                var_dump(evt)
            end
        })

        local unsubscribeTimer
        unsubscribeTimer = ev.Timer.new(function()
            unsubscribeTimer:stop(ev.Loop.default)
            print ('Unsubscribing from topic.test1')
            client1:unsubscribe('topic.test1', {
                onSuccess = function()
                    print 'Got to unsubscribe from topic topic.test1 onSuccess'
                end,
                onError = function(err)
                    print ('Got to unsubscribe from topic topic.test1 onError: ' .. err)
                end
            })
        end, 5)
        unsubscribeTimer:start(ev.Loop.default)

        local disconnectTimer
        disconnectTimer = ev.Timer.new(function()
            disconnectTimer:stop(ev.Loop.default)
            print ('Disconnecting from WAMP Server')
            client1:disconnect()
        end, 10)
        disconnectTimer:start(ev.Loop.default)

    end,
    onClose = function()
        print 'Got to WAMP Client instance onClose callback'
    end,
    onError = function(err)
        print ('Got to WAMP Client instance onError callback: ' .. err)
    end,
    onReconnect = function()
        print 'Got to WAMP Client instance onReconnect callback'
    end
})

ev.Loop.default:loop()
