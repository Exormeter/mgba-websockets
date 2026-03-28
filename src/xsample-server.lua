console:log("Starting websocket server")
local server = require'websocket'.server.listen
{
  port = 8080,
  protocols = {
    echo = function(ws)
      ws:set_on_message(function(ws, message, opcode)
          ws:send(message)
        end)

      --optional
      ws:set_on_close(function(ws, was_clean, code, reason) end)

      --optional
      ws:set_on_error(function(handler, err) end)
    end
  },

  -- add as many protocls here as you like, server will
  -- accept the first matching on. Default is when no protocl matches

  --optional
  default = function(ws)

    local number = 1
    ws:set_on_message(
      function(ws, message, opcode)
        console:log(message)
        console:log(tostring(number))
        number = number + 1
      end
    )

    --optional
    ws:set_on_close(function(ws, was_clean, code, reason) end)

    --optional
    ws:set_on_error(function(handler, err) end)
  end
}