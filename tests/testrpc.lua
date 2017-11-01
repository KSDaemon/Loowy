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
    transportEncoding = 'json',
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

        print('Registering new RPC rpc.test1')
        client1:register('rpc.test1', {
            rpc = function(data)
                print('Invoked rpc.test1')
                print('RPC payload')
                printdump(data)

                return { argsList = data.argsList, argsDict = data.argsDict }
            end,
            onSuccess = function()
                print('Got to register rpc rpc.test1 onSuccess')
            end,
            onError = function(err)
                print('Got to register rpc rpc.test1 onError: ' .. err.error)
            end
        })
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
