return setmetatable({},{__index = function(self, name)
  local backend = require("websocket.server_mGBA")
  self["mGBA"] = backend
  return backend
end})
