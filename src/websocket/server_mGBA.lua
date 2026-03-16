
local socket = require("socket")

local frame = require'websocket.frame'
local handshake = require'websocket.handshake'
local tconcat = table.concat
local tinsert = table.insert
local ev
local loop

local listener = {}
local clients = {}
clients[true] = {}

local client = function(sock,protocol)
  assert(sock)
  sock:setoption('tcp-nodelay',true)
  local fd = sock:getfd()
  local message_io
  local close_timer
  local async_send = require'websocket.ev_common'.async_send(sock,loop)
  local self = {}
  self.state = 'OPEN'
  self.sock = sock
  local user_on_error
  local on_error = function(s,err)
    if clients[protocol] ~= nil and clients[protocol][self] ~= nil then
      clients[protocol][self] = nil
    end
    if user_on_error then
      user_on_error(self,err)
    else
      print('Websocket server error',err)
    end
  end
  local user_on_close
  local on_close = function(was_clean,code,reason)
    if clients[protocol] ~= nil and clients[protocol][self] ~= nil then
      clients[protocol][self] = nil
    end
    if close_timer then
      close_timer:stop(loop)
      close_timer = nil
    end
    message_io:stop(loop)
    self.state = 'CLOSED'
    if user_on_close then
      user_on_close(self,was_clean,code,reason or '')
    end
    sock:shutdown()
    sock:close()
  end
  
  local handle_sock_err = function(err)
    if err == 'closed' then
      if self.state ~= 'CLOSED' then
        on_close(false,1006,'')
      end
    else
      on_error(err)
    end
  end
  local user_on_message = function() end
  local TEXT = frame.TEXT
  local BINARY = frame.BINARY
  local on_message = function(message,opcode)
    if opcode == TEXT or opcode == BINARY then
      user_on_message(self,message,opcode)
    elseif opcode == frame.CLOSE then
      if self.state ~= 'CLOSING' then
        self.state = 'CLOSING'
        local code,reason = frame.decode_close(message)
        local encoded = frame.encode_close(code)
        encoded = frame.encode(encoded,frame.CLOSE)
        async_send(encoded,
          function()
            on_close(true,code or 1006,reason)
          end,handle_sock_err)
      else
        on_close(true,1006,'')
      end
    end
  end
  
  self.send = function(_,message,opcode)
    local encoded = frame.encode(message,opcode or frame.TEXT)
    return async_send(encoded)
  end
  
  self.on_close = function(_,on_close_arg)
    user_on_close = on_close_arg
  end
  
  self.on_error = function(_,on_error_arg)
    user_on_error = on_error_arg
  end
  
  self.on_message = function(_,on_message_arg)
    user_on_message = on_message_arg
  end
  
  self.broadcast = function(_,...)
    for client in pairs(clients[protocol]) do
      if client.state == 'OPEN' then
        client:send(...)
      end
    end
  end
  
  self.close = function(_,code,reason,timeout)
    if clients[protocol] ~= nil and clients[protocol][self] ~= nil then
      clients[protocol][self] = nil
    end
    if not message_io then
      self:start()
    end
    if self.state == 'OPEN' then
      self.state = 'CLOSING'
      assert(message_io)
      timeout = timeout or 3
      local encoded = frame.encode_close(code or 1000,reason or '')
      encoded = frame.encode(encoded,frame.CLOSE)
      async_send(encoded)
      close_timer = ev.Timer.new(function()
          close_timer = nil
          on_close(false,1006,'timeout')
        end,timeout)
      close_timer:start(loop)
    end
  end
  
  self.start = function()
    message_io = require'websocket.ev_common'.message_io(
      sock,loop,
      on_message,
    handle_sock_err)
  end
  
  
  return self
end

--////////////////////////////////////////////////////////////////////////////////////////////////////////--

local listen = function(opts)

  assert(opts and (opts.protocols or opts.default))
  local protocols = {}

  if opts.protocols then
    for protocol in pairs(opts.protocols) do
      clients[protocol] = {}
      tinsert(protocols, protocol)
    end
  end

  local self = {}

  self.on_error = function(self,on_error)
    user_on_error = on_error
  end

  listener, err = socket.bind(opts.interface or '*',opts.port or 80)

  if not listener then
    error(err)
  end
  
  listener:add("received", function() self.socket_accept(listener) end)

  self.sock = function()
    return listener
  end
    
  self.close = function(keep_clients)
    listen_io:stop(loop)
    listener:close()
    listener = nil
    if not keep_clients then
      for protocol,clients in pairs(clients) do
        for client in pairs(clients) do
          client:close()
        end
      end
    end
  end

  --////////////////////////////////////////////////////////////////////////////////////////////////////////--

  self.exchange_handshake = function(client_sock)

    local request = {}
    local last
   
    --TODO
    repeat
      local line,err,part = client_sock:receive('*l')
      if line then
        if last then
          line = last..line
          last = nil
        end
        request[#request+1] = line
      elseif err ~= 'timeout' then
        console:error('Websocket Handshake failed due to socket err:'..err)
        client_sock:close()
        return
      else
        last = part
        return
      end
    until line == ''

    local upgrade_request = tconcat(request,'\r\n')
    local response, protocol = handshake.accept_upgrade(upgrade_request, protocols)

    if not response then
      print('Handshake failed, Request:')
      print(upgrade_request)
      client_sock:close()
      return
    end
    
    local index

    local len = #response
    local sent, err = client_sock:send(response,index)

    if not sent then
      print('Websocket client closed while handshake',err)
      client_sock:close()
    elseif sent ~= len then
      print('Message was to big to send in one go',err)
    end

    self.accept_client(client_sock, protocol)
  end

  --////////////////////////////////////////////////////////////////////////////////////////////////////////--

  self.socket_accept = function(listener)
    local client_sock = listener:accept()
    client_sock:add("received", self.exchange_handshake)
  end
            
  --////////////////////////////////////////////////////////////////////////////////////////////////////////--
              
  self.accept_client = function(client_sock, protocol)

      local protocol_handler
      local new_client
      local protocol_index

      if protocol and opts.protocols[protocol] then

        protocol_index = protocol
        protocol_handler = opts.protocols[protocol]

      elseif opts.default then

        -- true is the 'magic' index for the default handler
        protocol_index = true
        protocol_handler = opts.default

      else

        client_sock:close()
        print('Wrong Protocol',err)
        return

      end
      new_client = client(client_sock,protocol_index)
      clients[protocol_index][new_client] = true
      protocol_handler(new_client)
  end
              
  --////////////////////////////////////////////////////////////////////////////////////////////////////////--

  return self
end

--////////////////////////////////////////////////////////////////////////////////////////////////////////--

return {
  listen = listen
}

--////////////////////////////////////////////////////////////////////////////////////////////////////////--
