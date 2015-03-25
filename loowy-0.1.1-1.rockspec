package = "Loowy"
version = "0.1.1-1"

source = {
    url = "git://github.com/KSDaemon/Loowy.git",
    tag = "v0.1.1"
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
    "luajson",
    "lua-messagepack",
    "busted"
}

build = {
    type = 'none',
    install = {
        lua = {
            ['loowy.client'] = 'src/loowy/client.lua'
        }
    }
}
