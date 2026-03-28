console:log("Starting websocket server")
local server = require'websocket'.server.listen
{
  port = 8080,
  protocols = {
    echo = function(ws)
      ws:set_on_message(function(ws, message, opcode)
          ws:send(message)
        end)

      ws:set_on_close(function()
          ws:close()
        end)
    end
  },
  default = function(ws)

    local number = 1
    ws:set_on_message(
      function(ws, message, opcode)
        console:log(tostring(number))
        number = number + 1
      end
    )

    ws:set_on_close(
      function()
        ws:close()
      end
    )
    end
}

