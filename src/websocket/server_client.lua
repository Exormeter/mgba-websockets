local frame = require'websocket.frame'
local handshake = require'websocket.handshake'
local concat = table.concat
local insert = table.insert

--TODO absorb into client
local message_io = function(sock, on_message, on_error)
  local last
  local frames = {}
  local first_opcode

  local self = {}

  self.receive = function()

    local encoded, err, part = sock:receive(100000)

    if err then
      console:error('Error on receive of package occured ' .. err)
      on_error(err)
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
        insert(frames,decoded)
        encoded = rest
        if fin == true then
            on_message(concat(frames), first_opcode)
            frames = {}
            first_opcode = nil
        end
      end
    until not decoded
    if #encoded > 0 then
      last = encoded
    end

  end

  return self

end

local create_client = function(sock, opts)
  local handler = {
    _sock = sock,
    _receive_state = 'handshake',
    _state = 'OPEN',
    _message_io = nil,
    _callback_id = nil,
    _user_on_close = nil,
    _user_on_error = nil,
    _user_on_message = nil
  }

  handler._callback_id = handler._sock:add("received", function()
    if handler._receive_state == 'handshake' then
      handler:exchange_handshake()
      handler._receive_state = 'frame'
    elseif handler._receive_state == 'frame' then
      handler._message_io:receive()
    end
  end)

  function handler:set_on_close(on_close_arg)
    self._user_on_close = on_close_arg
  end

  function handler:set_on_error(on_error_arg)
    self._user_on_error = on_error_arg
  end

  function handler:set_on_message(on_message_arg)
    self._user_on_message = on_message_arg
  end

  local function on_error(s, err)
    if user_on_error then
      handler._user_on_error(err)
    else
      print('Websocket server error', err)
    end
  end

  local function on_close(was_clean, code, reason)
    handler._state = 'CLOSED'
    if handler._user_on_close then
      handler._user_on_close(was_clean, code, reason or '')
    end
    sock:close()
  end

  local function handle_sock_err(err)
    if err == 'closed' or err == 'disconnected' or err == 'unknown error' then
      if handler._state ~= 'CLOSED' then
        on_close(false, 1006, '')
      end
    else
      on_error(err)
    end
  end

  function handler:send(_,message,opcode)
    local encoded = frame.encode(message,opcode or frame.TEXT)
    return sock:send(encoded)
  end

  --FIXME
  function handler:broadcast(_,...)
  end

  function handler:close(_, code, reason, timeout)
    if self._state == 'OPEN' then
      self._state = 'CLOSING'
      timeout = timeout or 3
      local encoded = frame.encode_close(code or 1000, reason or '')
      encoded = frame.encode(encoded,frame.CLOSE)
      sock:send(encoded)
    end
    self._sock:remove(self._callback_id)
  end

  function handler:on_message(message, opcode)
    if opcode == frame.TEXT or opcode == frame.BINARY then
      self._user_on_message(self, message, opcode)
    elseif opcode == frame.CLOSE then
      if self._state ~= 'CLOSING' then
        self._state = 'CLOSING'
        local code,reason = frame.decode_close(message)
        local encoded = frame.encode_close(code)
        encoded = frame.encode(encoded,frame.CLOSE)
        sock:send(encoded)
        on_close(true, code or 1006, reason)
      else
        on_close(true,1006,'')
      end
    end
  end

  function handler:exchange_handshake()
    console:log("Handshake received")
    local request = {}

    local buffer = self._sock:receive(1024)

    repeat
      local line_end = buffer:find("\r\n", 1, true)
      local line = buffer:sub(1, line_end - 1)

      buffer = buffer:sub(line_end + 2)

      request[#request+1] = line
      console:log(line)

    until line == ''

    local upgrade_request = concat(request,'\r\n')
    local response, protocol = handshake.accept_upgrade(upgrade_request, opts.protocols)

    console:log(response)

    if not response then
      print('Handshake failed, Request:')
      print(upgrade_request)
      self._sock:close()
      return
    end

    self:accept_client(protocol)

    local index

    local len = #response
    local sent, err = self._sock:send(response, index)

    if not sent then
      print('Websocket client closed while handshake',err)
      self._sock:close()
    elseif sent ~= len then
      print('Message was to big to send in one go',err)
    end
  end

  function handler:accept_client(protocol)

    local protocol_handler

    if protocol and opts.protocols[protocol] then
      console:log("Using " .. protocol .. "protocol")
      protocol_handler = opts.protocols[protocol]
    elseif opts.default then
      console:log("Using default protocol")
      protocol_handler = opts.default
    else
      console:warn('No Protocol is matching and no default one has been assinged. Closing.')
      self._sock:close()
      return
    end

    protocol_handler(handler)
  end

  handler._message_io = message_io(
    sock,
    function(...)
      console:log("Recevied frame")
      handler:on_message(...) 
    end,
    handle_sock_err
  )

  return handler
end

return {
  create_client = create_client
}