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
local firstDisconnect = true

print('Connecting client to WAMP Server: ' ..  wsServer)

client1 = loowy.new(wsServer, { transportEncoding = 'json',
    realm = config.realm,
    maxRetries = config.maxRetries,
    transportEncoding = config.transportEncoding,
    debug = config.debug,
    onConnect = function()
        print 'Got to WAMP Client instance onConnect callback'

        print ('Subscribing to topic.test1')
        client1:subscribe('topic.test1', {
            onSuccess = function()
                print 'Got to topic topic.test1 subscribe onSuccess'

                print ('Adding another subscription to topic.test1')
                client1:subscribe('topic.test1', {
                    onSuccess = function()
                        print 'Got to another topic topic.test1 subscribe onSuccess'
                    end,
                    onError = function(err)
                        print ('Got to another topic topic.test1 subscribe onError: ' .. err)
                    end,
                    onEvent = function(evt)
                        print 'Got to another topic topic.test1 subscribe onEvent'
                        print ('Event payload: ')
                        printdump(evt)
                    end
                })
            end,
            onError = function(err)
                print ('Got to topic topic.test1 subscribe onError: ' .. err)
            end,
            onEvent = function(evt)
                print 'Got to topic topic.test1 subscribe onEvent'
                print ('Event payload: ')
                printdump(evt)
            end
        })

        print ('Publishing to topic.test1 without payload')
        client1:publish('topic.test1', nil, {
            onSuccess = function()
                print 'Got to publish to topic topic.test1 onSuccess'
            end,
            onError = function(err)
                print ('Got to publish to topic topic.test1 onError: ' .. err)
            end
        }, { disclose_me = true, exclude_me = false })

        print ('Publishing to topic.test1 with payload: string "string payload"')
        client1:publish('topic.test1', "string payload", {
            onSuccess = function()
                print 'Got to publish to topic topic.test1 onSuccess'
            end,
            onError = function(err)
                print ('Got to publish to topic topic.test1 onError: ' .. err)
            end
        }, { disclose_me = true, exclude_me = false })

        print ('Publishing to topic.test1 with payload: integer 25')
        client1:publish('topic.test1', 25, {
            onSuccess = function()
                print 'Got to publish to topic topic.test1 onSuccess'
            end,
            onError = function(err)
                print ('Got to publish to topic topic.test1 onError: ' .. err)
            end
        }, { disclose_me = true, exclude_me = false })

        print ('Publishing to topic.test1 with payload: array { 1, 2, 3, 4, 5 }')
        client1:publish('topic.test1', { 1, 2, 3, 4, 5 }, {
            onSuccess = function()
                print 'Got to publish to topic topic.test1 onSuccess'
            end,
            onError = function(err)
                print ('Got to publish to topic topic.test1 onError: ' .. err)
            end
        }, { disclose_me = true, exclude_me = false })

        print ('Publishing to topic.test1 with payload: table { key1 = "string", key2 = 100, key3 = true }')
        client1:publish('topic.test1', { key1 = "string", key2 = 100, key3 = true }, {
            onSuccess = function()
                print 'Got to publish to topic topic.test1 onSuccess'
            end,
            onError = function(err)
                print ('Got to publish to topic topic.test1 onError: ' .. err)
            end
        }, { disclose_me = true, exclude_me = false })

        local unsubscribeTimer
        unsubscribeTimer = ev.Timer.new(function()
            unsubscribeTimer:stop(ev.Loop.default)
            print ('Unsubscribing from topic.test1')
            client1:unsubscribe('topic.test1', {
                onSuccess = function()
                    print 'Got to unsubscribe from topic topic.test1 onSuccess'

                    print ('Publishing to topic.test1 with string payload and settings: disclose_me = true, exclude_me = false')
                    print ('We should not receive this event')
                    client1:publish('topic.test1', "unsubscribed event string", {
                        onSuccess = function()
                            print 'Got to publish to unsubscribed topic topic.test1 onSuccess'
                        end,
                        onError = function(err)
                            print ('Got to publish to unsubscribed topic topic.test1 onError: ' .. err)
                        end
                    }, { disclose_me = true, exclude_me = false })

                end,
                onError = function(err)
                    print ('Got to unsubscribe from topic topic.test1 onError: ' .. err)
                end
            })
        end, 10)
        unsubscribeTimer:start(ev.Loop.default)

        print ('Registering new RPC rpc.test1')
        client1:register('rpc.test1', {
            rpc = function (dataList, dataDict, details)
                local result = {{}}
                print ('Invoked rpc.test1')
                print ('RPC payload')
                print ('List')
                printdump(dataList)
                print ('Dict')
                printdump(dataDict)
                print ('Details')
                printdump(details)

                if dataList and #dataList > 0 then
                    table.insert(result, dataList)
                end

                if dataDict then
                    print ('RPC result length: ' .. #result)
                    printdump(result)
                    if #result == 1 then
                        table.insert(result, {})
                    end
                    table.insert(result, dataDict)
                end

                print ('RPC returning result')
                printdump(result)
                return result
            end,
            onSuccess = function()
                print 'Got to register rpc rpc.test1 onSuccess'

                print 'Calling rpc rpc.test1 without data'
                client1:call('rpc.test1', nil, {
                    onSuccess = function(dataList, dataDict)
                        print 'Got to rpc call rpc.test1 onSuccess'
                        print 'Call result'
                        print ('List')
                        printdump(dataList)
                        print ('Dict')
                        printdump(dataDict)
                    end,
                    onError = function(err)
                        print ('Got to rpc call rpc.test1 onError: ' .. err)
                    end

                }, { disclose_me = true, exclude_me = false })

                print 'Calling rpc rpc.test1 with payload: string "string payload"'
                client1:call('rpc.test1', "string payload", {
                    onSuccess = function(data)
                        print 'Got to rpc call rpc.test1 onSuccess'
                        print 'Call result'
                        printdump(data)
                    end,
                    onError = function(err)
                        print ('Got to rpc call rpc.test1 onError: ' .. err)
                    end

                }, { disclose_me = true, exclude_me = false })

                print 'Calling rpc rpc.test1 with payload: integer 25'
                client1:call('rpc.test1', 25, {
                    onSuccess = function(data)
                        print 'Got to rpc call rpc.test1 onSuccess'
                        print 'Call result'
                        printdump(data)
                    end,
                    onError = function(err)
                        print ('Got to rpc call rpc.test1 onError: ' .. err)
                    end

                }, { disclose_me = true, exclude_me = false })

                print 'Calling rpc rpc.test1 with payload: array { 1, 2, 3, 4, 5 }'
                client1:call('rpc.test1', { 1, 2, 3, 4, 5 }, {
                    onSuccess = function(data)
                        print 'Got to rpc call rpc.test1 onSuccess'
                        print 'Call result'
                        printdump(data)
                    end,
                    onError = function(err)
                        print ('Got to rpc call rpc.test1 onError: ' .. err)
                    end

                }, { disclose_me = true, exclude_me = false })

                print 'Calling rpc rpc.test1 with payload: table { key1 = "string", key2 = 100, key3 = true }'
                client1:call('rpc.test1', { key1 = "string", key2 = 100, key3 = true }, {
                    onSuccess = function(data)
                        print 'Got to rpc call rpc.test1 onSuccess'
                        print 'Call result'
                        printdump(data)
                    end,
                    onError = function(err)
                        print ('Got to rpc call rpc.test1 onError: ' .. err)
                    end

                }, { disclose_me = true, exclude_me = false })

            end,
            onError = function(err)
                print ('Got to register rpc rpc.test1 onError: ' .. err)
            end
        })

        local disconnectTimer
        disconnectTimer = ev.Timer.new(function()
            disconnectTimer:stop(ev.Loop.default)
            print ('Disconnecting from WAMP Server')
            client1:disconnect()
        end, 30)
        disconnectTimer:start(ev.Loop.default)

    end,
    onClose = function()
        print 'Got to WAMP Client instance onClose callback'
        if firstDisconnect then
            client1.connect()
            firstDisconnect = false
        end
    end,
    onError = function(err)
        print ('Got to WAMP Client instance onError callback: ' .. err)
    end,
    onReconnect = function()
        print 'Got to WAMP Client instance onReconnect callback'
    end
})

ev.Loop.default:loop()
