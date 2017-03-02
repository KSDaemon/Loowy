package = "Loowy"
version = "0.2.0-2"

source = {
    url = "git://github.com/KSDaemon/Loowy.git",
    tag = "v0.2.0"
}

description = {
    summary = "LUA WAMP client",
    detailed = "Async WAMP client based on lua-websockets, luasocket and lib-ev",
    homepage = "https://github.com/KSDaemon/Loowy",
    license = "MIT/X11",
    maintainer = "Konstantin Burkalev <KSDaemon@ya.ru>"
}

dependencies = {
    "lua >= 5.1",
    "luasocket",
    "lua-websockets",
    "lua-ev",
    "rapidjson >= 0.5",
    "lua-messagepack",
    "busted"
}

build = {
    type = 'none',
    install = {
        lua = {
            ['loowy.client'] = 'src/loowy/client.lua',
            ['loowy.vardump'] = 'src/loowy/vardump.lua'

        }
    }
}
