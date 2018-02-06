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

local printdump = require("loowy.vardump").printdump
local ev = require 'ev'
local loowy = require 'loowy.client'
local client1

print('Connecting client to WAMP Server: ' .. wsServer)
client1 = loowy.new(wsServer, {
    realm = config.realm,
    maxRetries = config.maxRetries,
    transportEncoding = config.transportEncoding,
    debug = config.debug,
    onConnect = function()
        print('Got to WAMP Client instance onConnect callback')

        print('Subscribing to topic.test1')
        client1:subscribe('topic.test1', {
            onSuccess = function()
                print('Got to topic topic.test1 subscribe onSuccess')
            end,
            onError = function(err)
                print('Got to topic topic.test1 subscribe onError: ' .. err.error)
            end,
            onEvent = function(evt)
                print('Got to topic topic.test1 subscribe onEvent')
                print('Event payload: ')
                printdump(evt)
            end
        })

        local unsubscribeTimer
        unsubscribeTimer = ev.Timer.new(function()
            unsubscribeTimer:stop(ev.Loop.default)
            print('Unsubscribing from topic.test1')
            client1:unsubscribe('topic.test1', {
                onSuccess = function()
                    print('Got to unsubscribe from topic topic.test1 onSuccess')
                    print('Disconnecting from WAMP Server')
                    client1:disconnect()
                end,
                onError = function(err)
                    print('Got to unsubscribe from topic topic.test1 onError: ' .. err.error)
                end
            })
        end, 5)
        unsubscribeTimer:start(ev.Loop.default)
    end,
    onClose = function()
        print('Got to WAMP Client instance onClose callback')
    end,
    onError = function(err)
        print('Got to WAMP Client instance onError callback: ' .. err.error)
    end,
    onReconnect = function()
        print('Got to WAMP Client instance onReconnect callback')
    end
})

ev.Loop.default:loop()
