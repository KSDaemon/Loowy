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

        print('Publishing to topic.test1 with payload: string "string payload"')
        client1:publish('topic.test1', "string payload", {
            onSuccess = function()
                print('Got to publish to topic topic.test1 onSuccess')
            end,
            onError = function(err)
                print('Got to publish to topic topic.test1 onError: ' .. err.error)
            end
        }, { disclose_me = true, exclude_me = false })

        print('Calling rpc rpc.test1 without data')
        client1:call('rpc.test1', nil, {
            onSuccess = function(data)
                print('Got to rpc call rpc.test1 onSuccess')
                print('Call result')
                printdump(data)
            end,
            onError = function(err)
                print('Got to rpc call rpc.test1 onError: ' .. err.error)
            end
        }, { disclose_me = true, exclude_me = false })

        print('Calling rpc rpc.test1 with payload: string "string payload"')
        client1:call('rpc.test1', "string payload", {
            onSuccess = function(data)
                print('Got to rpc call rpc.test1 onSuccess')
                print('Call result')
                printdump(data)
            end,
            onError = function(err)
                print('Got to rpc call rpc.test1 onError: ' .. err.error)
            end
        }, { disclose_me = true, exclude_me = false })
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
