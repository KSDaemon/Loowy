Loowy
=====

LUA WAMP (WebSocket Application Messaging Protocol) client implementation on top of lua-websockets and lib-ev. 

Table of Contents
=================

* [Description](#description)
* [Usage example](#usage-example)
* [Installation](#installation)
* [Dependencies](#dependencies)
* [Loowy client instance methods](#loowy-client-instance-methods)
    * [options](#optionsopts)
    * [getOpStatus](#getopstatus)
    * [getSessionId](#getsessionid)
    * [connect](#connecturl)
    * [disconnect](#disconnect)
    * [abort](#abort)
    * [subscribe](#subscribetopicuri-callbacks)
    * [unsubscribe](#unsubscribetopicuri-callbacks)
    * [publish](#publishtopicuri-payload-callbacks-advancedoptions)
    * [call](#calltopicuri-payload-callbacks-advancedoptions)
    * [register](#registertopicuri-callbacks)
    * [unregister](#unregistertopicuri-callbacks)
* [Copyright and License](#copyright-and-license)
* [See Also](#see-also)

Description
===========

Loowy implements [WAMP](http://wamp.ws) v2 client specification.

Loowy supports next WAMP roles and features:

* publisher: advanced profile with features:
    * subscriber blackwhite listing
    * publisher exclusion
    * publisher identification
* subscriber: basic profile.
* caller: advanced profile with features:
    * callee blackwhite listing.
    * caller exclusion.
    * caller identification.
    * progressive call results.
* callee: basic profile.

Loowy supports JSON and msgpack serializers.

[Back to TOC](#table-of-contents)

Usage example
=============

For example usage, please see [test.lua](tests/test.lua) file.

[Back to TOC](#table-of-contents)

Installation
============

You can install Loowy via luarocks

```bash
> luarocks install loowy 

```

or simply put loowy/client.lua somewhere accessible by lua package.path. 
But in this case you also need to install dependencies.

[Back to TOC](#table-of-contents)

Dependencies
=============

Loowy depends on:

* [lua-websockets](https://github.com/lipp/lua-websockets)
* [lua-ev](https://github.com/brimworks/lua-ev)
* [luajson](https://github.com/harningt/luajson)
* [lua-messagepack](http://fperrad.github.io/lua-MessagePack/)

also it uses [busted](http://olivinelabs.com/busted/) for testing.

[Back to TOC](#table-of-contents)

Loowy client instance methods
=============================

options([opts])
------------------------------------------

options() method can be called in two forms:

* without parameters it will return table with current options
* with one parameter as table it will set new options

Options keys description:

* **autoReconnect**. Default value: true. Enable autoreconnecting. In case of connection failure, 
Loowy will try to reconnect to WAMP server, and if you were subscribed to any topics,
or had registered some procedures, Loowy will resubscribe to that topics and reregister procedures.
* **reconnectInterval**. Default value: 2(s). Reconnection Interval in seconds.
* **maxRetries**. Default value: 25. Max reconnection attempts. After reaching this value [disconnect()](#disconnect)
will be called
* **transportEncoding**. Default value: json. Transport serializer to use. Supported 2 values: json|msgpack.
* **realm**. Default value: nil. WAMP Realm to join on server. See WAMP spec for additional info.
* **onConnect**. Default value: undefined. Callback function. Fired when connection to wamp server is established.
* **onClose**. Default value: undefined. Callback function. Fired on closing connection to wamp server.
* **onError**. Default value: undefined. Callback function. Fired on error in websocket communication.
* **onReconnect**. Default value: undefined. Callback function. Fired every time on reconnection attempt.

[Back to TOC](#table-of-contents)

getOpStatus()
------------------------------------------

Get the status of last operation.

returns table: `{code, description}` where:

* code: 0 - if operation was successful,
* code > 0 - if error occurred,
* description contains details about error

[Back to TOC](#table-of-contents)

getSessionId()
------------------------------------------

Get the WAMP Session ID.

[Back to TOC](#table-of-contents)

connect([url])
------------------------------------------

Connect to server. 

Parameters:

* url - WAMP Server url (optional). Should be specified as URI. For example: ws://my-server/wamp

[Back to TOC](#table-of-contents)

disconnect()
------------------------------------------

Disconnect from server.

[Back to TOC](#table-of-contents)

abort()
------------------------------------------

Abort WAMP session establishment. Works only if websocket connection is established, 
but WAMP session establishment is in progress.

[Back to TOC](#table-of-contents)

subscribe(topicURI, callbacks)
------------------------------------------

Subscribe to a topic on a broker.

Parameters:

* topicURI - topic to subscribe
* callbacks - if it is a function - it will be treated as published event callback 
or it can be hash table of callbacks:

        { onSuccess: will be called when subscribe would be confirmed
          onError: will be called if subscribe would be aborted
          onEvent: will be called on receiving published event }

[Back to TOC](#table-of-contents)

unsubscribe(topicURI, callbacks)
------------------------------------------

Unsubscribe from topic.

Parameters:

* topicURI - topic to unsubscribe
* callbacks - if it is a function - it will be treated as published event callback to remove or it can be hash table of callbacks:

        { onSuccess: will be called when unsubscribe would be confirmed
          onError: will be called if unsubscribe would be aborted
          onEvent: published event callback to remove }

[Back to TOC](#table-of-contents)

publish(topicURI, payload, callbacks, advancedOptions)
------------------------------------------

Publish a event to topic.

Parameters:

* topicURI - topic to publish
* payload - optional parameter, can be any value
* callbacks - optional table of callbacks:

        { onSuccess: will be called when publishing would be confirmed 
          onError: will be called if publishing would be aborted }

* advancedOptions - optional parameter. Must include any or all of the options:

        { exclude: integer|array WAMP session id(s) that won't receive a published
                   event, even though they may be subscribed
          eligible: integer|array WAMP session id(s) that are allowed 
                   to receive a published event
          exclude_me: bool flag of receiving publishing event by initiator
          disclose_me: bool flag of disclosure of publisher identity 
                   (its WAMP session ID) to receivers of a published event }

[Back to TOC](#table-of-contents)

call(topicURI, payload, callbacks, advancedOptions)
------------------------------------------

Remote Procedure Call.

Parameters:

* topicURI - topic to call
* payload - can be either a value of any type or null
* callbacks - if it is a function - it will be treated as result callback function or it can be hash table of callbacks:

        { onSuccess: will be called with result on successful call
          onError: will be called if invocation would be aborted }

* advancedOptions - optional parameter. Must include any or all of the options:

        { exclude: integer|array WAMP session id(s) providing an explicit list of
                   (potential) Callees that a call won't be forwarded to, 
                   even though they might be registered
          eligible: integer|array WAMP session id(s) providing an explicit list of
                   (potential) Callees that are (potentially) forwarded the call issued
          exclude_me: bool flag of potentially forwarding call to caller 
                   if he is registered as callee
          disclose_me: bool flag of disclosure of Caller identity 
                   (WAMP session ID) to endpoints of a routed call }

[Back to TOC](#table-of-contents)

register(topicURI, callbacks)
------------------------------------------

RPC registration for invocation.

Parameters:

* topicURI - topic to register
* callbacks - if it is a function - it will be treated as rpc itself or it can be hash table of callbacks:

        { rpc: registered procedure
          onSuccess: will be called on successful registration
          onError: will be called if registration would be aborted }

[Back to TOC](#table-of-contents)

unregister(topicURI, callbacks)
------------------------------------------

RPC unregistration for invocation.

Parameters:

* topicURI - topic to unregister
* callbacks - if it is a function, it will be called on successful unregistration or it can be hash table of callbacks:

        { onSuccess: will be called on successful unregistration
          onError: will be called if unregistration would be aborted }

[Back to TOC](#table-of-contents)

Copyright and License
=====================

Loowy is licensed under the MIT license.

Copyright (c) 2014, Konstantin Burkalev

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.


[Back to TOC](#table-of-contents)

See Also
========

* [WAMP specification](http://wamp.ws)
* [Wampy.js](https://github.com/KSDaemon/wampy.js). WAMP Javascript client-side implementation.
* [Wiola](https://github.com/KSDaemon/wiola). WAMP router powered by LUA Nginx module, Lua WebSocket addon, and Redis as cache store.

[Back to TOC](#table-of-contents)
