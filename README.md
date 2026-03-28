# mGBA-WebSockets

**mGBA-WebSockets** is a lightweight WebSocket server written in pure Lua, designed to run directly inside the mGBA emulator. It allows external clients—such as browsers or CLI tools—to connect to and interact with a running mGBA instance.

The project has **no external dependencies** and works out of the box with mGBA’s scripting environment.

---

## Features

- Pure Lua implementation (no dependencies)
- Runs inside the mGBA scripting environment
- Compatible with standard WebSocket clients (e.g. browsers, websocat)
- Easy to integrate into your own Lua scripts

---

## Credits

This project builds upon existing work:

- WebSocket implementation based on: https://github.com/lipp/lua-websockets  
- Refactored to use mGBA’s socket API  
- Base64 encoding: https://github.com/iskolbin/lbase64/blob/master/base64.lua  
- SHA1 implementation: https://gist.github.com/PedroAlvesV/872a108f187f57c2a5b7b5bc34398496  

---

## Installation

1. Clone this repository:
   ```bash
   git clone https://github.com/Exormeter/mgba-websockets.git
   
2.	Open mGBA
3.	Load any ROM
4.	Open the scripting window: Tools → Scripting...
5.	Load the sample: File → Load Script...

## Usage

Once the script is running, the WebSocket server will start inside mGBA.

You can connect using any WebSocket client.

**Example using websocat**
```bash
   websocat ws://localhost:PORT
```
Replace PORT with the port defined in your script.

**Example using a browser**
```js
const ws = new WebSocket("ws://localhost:PORT");

ws.onopen = () => {
  console.log("Connected");
  ws.send("Hello from browser");
};

ws.onmessage = (event) => {
  console.log("Received:", event.data);
};
```

## Integration

You can use this project as a starting point for your own scripts: 
-	Copy websocket.lua and the websocket/ folder into your project 
-	Import and use it within your Lua scripts running in mGBA

## Limitations
-	Broadcast to multiple clients is not implemented yet
- This is my first Lua project, so some parts may not follow typical Lua conventions
-	Depending on usage, socket handling may block if not integrated carefully with the emulator loop
