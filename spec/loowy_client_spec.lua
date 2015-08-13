--
-- Project: Loowy
-- User: KSDaemon
-- Date: 29.03.15
--

local ev = require 'ev'
local loowy = require 'loowy.client'

describe('LUA WAMP client',
    function ()

        it('exposes the correct interface',
            function ()
                assert.is_table(loowy)
                assert.is_function(loowy.new)
            end
        )

--        it('returns the new instance',
--            function ()
--                local loowy_mock = mock(loowy, true)
--                client = loowy_mock.new()
--            end
--        )

    end
)

