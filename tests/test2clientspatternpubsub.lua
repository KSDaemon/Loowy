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

print('Connecting clients to WAMP Server: ' .. wsServer)

client1 = loowy.new(wsServer, {
    realm = config.realm,
    maxRetries = config.maxRetries,
    transportEncoding = config.transportEncoding,
    debug = config.debug,
    onConnect = function()
        print('Got to WAMP Client instance 1 onConnect callback')

        print('Subscribing client1 to aaa.bbb.ccc exactly')
        client1:subscribe('aaa.bbb.ccc', {
            onSuccess = function()
                print('Got to topic aaa.bbb.ccc exactly instance 1 subscribe onSuccess')
            end,
            onError = function(err)
                print('Got to topic aaa.bbb.ccc exactly instance 1 subscribe onError: ' .. err.error)
            end,
            onEvent = function(evt)
                print('Got to topic aaa.bbb.ccc exactly instance 1 subscribe onEvent')
                print('Event payload: ')
                printdump(evt)
            end
        })

        print('Subscribing client1 to aaa.bbb.ccc.ddd exactly')
        client1:subscribe('aaa.bbb.ccc.ddd', {
            onSuccess = function()
                print('Got to topic aaa.bbb.ccc.ddd exactly instance 1 subscribe onSuccess')
            end,
            onError = function(err)
                print('Got to topic aaa.bbb.ccc.ddd exactly instance 1 subscribe onError: ' .. err.error)
            end,
            onEvent = function(evt)
                print('Got to topic aaa.bbb.ccc.ddd exactly instance 1 subscribe onEvent')
                print('Event payload: ')
                printdump(evt)
            end
        })

        print('Subscribing client1 to aaa.bbb prefixly')
        client1:subscribe('aaa.bbb', {
            onSuccess = function()
                print('Got to topic aaa.bbb prefixly instance 1 subscribe onSuccess')
            end,
            onError = function(err)
                print('Got to topic aaa.bbb prefixly instance 1 subscribe onError: ' .. err.error)
            end,
            onEvent = function(evt)
                print('Got to topic aaa.bbb prefixly instance 1 subscribe onEvent')
                print('Event payload: ')
                printdump(evt)
            end
        },
        {
            match = "prefix"
        })

        print('Subscribing client1 to aaa..ccc wildcardly')
        client1:subscribe('aaa..ccc', {
            onSuccess = function()
                print('Got to topic aaa..ccc wildcardly instance 1 subscribe onSuccess')
            end,
            onError = function(err)
                print('Got to topic aaa..ccc wildcardly instance 1 subscribe onError: ' .. err.error)
            end,
            onEvent = function(evt)
                print('Got to topic aaa..ccc wildcardly instance 1 subscribe onEvent')
                print('Event payload: ')
                printdump(evt)
            end
        },
        {
            match = "wildcard"
        })

        local unsubscribeTimer
        unsubscribeTimer = ev.Timer.new(function()
            unsubscribeTimer:stop(ev.Loop.default)
            print('Unsubscribing from topic.test1 instance 1')
            client1:unsubscribe('aaa.bbb.ccc', {
                onSuccess = function()
                    print('Got to unsubscribe from topic aaa.bbb.ccc exactly instance 1 onSuccess')
                end,
                onError = function(err)
                    print('Got to unsubscribe from topic aaa.bbb.ccc exactly instance 1 onError: ' .. err.error)
                end
            })
            client1:unsubscribe('aaa.bbb.ccc.ddd', {
                onSuccess = function()
                    print('Got to unsubscribe from topic aaa.bbb.ccc.ddd exactly instance 1 onSuccess')
                end,
                onError = function(err)
                    print('Got to unsubscribe from topic aaa.bbb.ccc.ddd exactly instance 1 onError: ' .. err.error)
                end
            })
            client1:unsubscribe('aaa.bbb', {
                onSuccess = function()
                    print('Got to unsubscribe from topic aaa.bbb prefixly instance 1 onSuccess')
                end,
                onError = function(err)
                    print('Got to unsubscribe from topic aaa.bbb prefixly instance 1 onError: ' .. err.error)
                end
            })
            client1:unsubscribe('aaa..ccc', {
                onSuccess = function()
                    print('Got to unsubscribe from topic aaa..ccc instance 1 onSuccess')
                end,
                onError = function(err)
                    print('Got to unsubscribe from topic aaa..ccc instance 1 onError: ' .. err.error)
                end
            })
        end, 100)
        unsubscribeTimer:start(ev.Loop.default)

        local disconnectTimer
        disconnectTimer = ev.Timer.new(function()
            disconnectTimer:stop(ev.Loop.default)
            print('Disconnecting from WAMP Server instance 1')
            client1:disconnect()
        end, 130)
        disconnectTimer:start(ev.Loop.default)
    end,
    onClose = function()
        print('Got to WAMP Client instance 1 onClose callback')
    end,
    onError = function(err)
        print('Got to WAMP Client instance 1 onError callback: ' .. err.error)
    end,
    onReconnect = function()
        print('Got to WAMP Client instance 1 onReconnect callback')
    end
})

client2 = loowy.new(wsServer, {
    transportEncoding = 'json',
    realm = config.realm,
    maxRetries = config.maxRetries,
    transportEncoding = config.transportEncoding,
    debug = config.debug,
    onConnect = function()
        print('Got to WAMP Client instance 2 onConnect callback')

        local publishTimer
        publishTimer = ev.Timer.new(function()
            publishTimer:stop(ev.Loop.default)
            print('Publishing to aaa.bbb instance 2 without payload')
            client2:publish('aaa.bbb', nil, {
                onSuccess = function()
                    print('Got to publish to topic aaa.bbb instance 2 onSuccess')
                end,
                onError = function(err)
                    print('Got to publish to topic aaa.bbb instance 2 onError: ' .. err.error)
                end
            })
            client2:publish('aaa.bbb.ccc', nil, {
                onSuccess = function()
                    print('Got to publish to topic aaa.bbb.ccc instance 2 onSuccess')
                end,
                onError = function(err)
                    print('Got to publish to topic aaa.bbb.ccc instance 2 onError: ' .. err.error)
                end
            })
        end, 10)
        publishTimer:start(ev.Loop.default)

        local disconnectTimer
        disconnectTimer = ev.Timer.new(function()
            disconnectTimer:stop(ev.Loop.default)
            print('Disconnecting from WAMP Server instance 2')
            client2:disconnect()
        end, 130)
        disconnectTimer:start(ev.Loop.default)
    end,
    onClose = function()
        print('Got to WAMP Client instance 2 onClose callback')
    end,
    onError = function(err)
        printdump(err)
        print('Got to WAMP Client instance 2 onError callback: ' .. err.error)
    end,
    onReconnect = function()
        print('Got to WAMP Client instance 2 onReconnect callback')
    end
})

ev.Loop.default:loop()
