local ev = require'ev'

-- create a copas webserver and start listening
local server = require'websocket'.server.ev.listen
{
  port = 8080,
  protocols = {
    echo = function(ws)
      ws:on_message(function(ws,message)
          ws:send(message)
        end)

      ws:on_close(function()
          ws:close()
        end)
    end
  }
}

-- use the lua-ev loop
ev.Loop.default:loop()