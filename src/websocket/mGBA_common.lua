local frame = require'websocket.frame'
local tinsert = table.insert
local tconcat = table.concat

-- this is no longer async, so don't write to bigger request 
local function async_send(sock)

  local function send_async(data, on_sent, on_err)
    local index = 1
    local len = #data

    while index <= len do
      local sent, err, last = sock:send(data, index)

      if sent then
        index = sent + 1

      elseif err == "timeout" then
        index = last + 1

      else
        if on_err then
          on_err(err)
        end
        return nil, err
      end
    end

    if on_sent then
      on_sent(data)
    end

    return true
  end

  local function stop()
    -- nothing needed in blocking version
  end

  return send_async, stop
end

local message_io = function(sock,on_message,on_error)
    local last
    local frames = {}
    local first_opcode

    sock:add("received", function()

        local encoded,err,part = sock:receive(100000)

        if err then
            on_error(err)
            console:error('Error on receive of package occured'..err)
            sock:close()
            return
        end

        if last then
            encoded = last..(encoded or part)
            last = nil
        else
            encoded = encoded or part
        end

        repeat
            local decoded, fin, opcode, rest = frame.decode(encoded)
            if decoded then
            if not first_opcode then
                first_opcode = opcode
            end
            tinsert(frames,decoded)
            encoded = rest
            if fin == true then
                on_message(tconcat(frames),first_opcode)
                frames = {}
                first_opcode = nil
            end
            end
        until not decoded
        if #encoded > 0 then
            last = encoded
        end

    end)

end

return {
  async_send = async_send,
  message_io = message_io
}
