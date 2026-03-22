console:log("Starting websocket server")
local server = require'websocket'.server.listen
{
  port = 8080,
  protocols = {
    echo = function(ws)
      ws:on_message(function(ws, message)
          ws:send(message)
        end)

      ws:on_close(function()
          ws:close()
        end)
    end
  }
}

