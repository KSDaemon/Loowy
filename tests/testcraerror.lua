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
    authid = 'user1',
    authmethods = { 'wampcra' },
    onChallenge = function (method, info)
        print('Requested challenge with ' .. method)
        printdump(info)

        error('Error in challenge processing')
    end,
    maxRetries = config.maxRetries,
    transportEncoding = config.transportEncoding,
    debug = config.debug,
    onConnect = function()
        print('Got to WAMP Client instance onConnect callback')

        local disconnectTimer
        disconnectTimer = ev.Timer.new(function()
            disconnectTimer:stop(ev.Loop.default)
            print('Disconnecting from WAMP Server')
            client1:disconnect()
        end, 10)
        disconnectTimer:start(ev.Loop.default)
    end,
    onClose = function()
        print('Got to WAMP Client instance onClose callback')
    end,
    onError = function(err)
        print('Got to WAMP Client instance onError callback: ' .. err.error)
    end,
    onReconnect = function()
        print 'Got to WAMP Client instance onReconnect callback'
    end
})

ev.Loop.default:loop()
