<p align="center">
  <img src="https://raw.githubusercontent.com/ljr1981/claude_eiffel_op_docs/main/artwork/LOGO.png" alt="simple_ library logo" width="400">
</p>

# simple_websocket

**[Documentation](https://simple-eiffel.github.io/simple_websocket/)**

RFC 6455 WebSocket protocol implementation for Eiffel. Handles frame encoding/decoding, message fragmentation, and WebSocket handshake.

## Features

- **RFC 6455 Compliant** - Full WebSocket protocol support
- **Frame Types** - Text, Binary, Close, Ping, Pong, Continuation
- **Masking** - Client-side XOR masking per spec
- **Fragmentation** - Split large messages into multiple frames
- **Handshake** - Complete client/server handshake handling
- **Streaming Parser** - Process frames from byte streams
- **Design by Contract** - Full preconditions/postconditions

## Installation

Add to your ECF:

```xml
<library name="simple_websocket" location="$SIMPLE_WEBSOCKET\simple_websocket.ecf"/>
```

Set environment variables:
```
SIMPLE_WEBSOCKET=D:\prod\simple_websocket
SIMPLE_FOUNDATION_API=D:\prod\simple_foundation_api
```

Note: simple_websocket uses simple_foundation_api for Base64 encoding and SHA-1 hashing in the handshake.

## Usage

### Creating Frames

```eiffel
local
    frame: WS_FRAME
    bytes: ARRAY [NATURAL_8]
do
    -- Text frame
    create frame.make_text ("Hello, WebSocket!", True)
    bytes := frame.to_bytes

    -- Binary frame
    create frame.make_binary (<<0x01, 0x02, 0x03>>, True)

    -- Control frames
    create frame.make_ping
    create frame.make_pong
    create frame.make_close (1000, "Normal closure")
end
```

### Client Handshake

```eiffel
local
    handshake: WS_HANDSHAKE
    request: STRING
do
    create handshake.make

    -- Generate client handshake request
    request := handshake.create_client_request ("example.com", "/chat")
    -- Send request to server...

    -- Validate server response
    if handshake.validate_server_response (server_response) then
        io.put_string ("WebSocket connection established!%N")
    else
        io.put_string ("Handshake failed: " + handshake.last_error + "%N")
    end
end
```

### Server Handshake

```eiffel
local
    handshake: WS_HANDSHAKE
    response: STRING
do
    create handshake.make

    -- Parse incoming client request
    if handshake.parse_client_request (client_request) then
        -- Generate server response
        response := handshake.create_server_response
        -- Send response to client...
    else
        -- Reject connection
        io.put_string ("Invalid request: " + handshake.last_error + "%N")
    end
end
```

### Parsing Frames

```eiffel
local
    parser: WS_FRAME_PARSER
    bytes: ARRAY [NATURAL_8]
do
    create parser.make

    -- Add received bytes
    parser.add_bytes (bytes)

    -- Try to parse a complete frame
    if parser.parse and parser.has_frame then
        if attached parser.last_frame as frame then
            if frame.is_text then
                io.put_string ("Received: " + frame.text_payload + "%N")
            elseif frame.is_close then
                io.put_string ("Close code: " + frame.close_code.out + "%N")
            end
        end
    end
end
```

### Message Fragmentation

```eiffel
local
    msg: WS_MESSAGE
    frames: ARRAYED_LIST [WS_FRAME]
do
    -- Create a large message
    create msg.make_text ("Very long message content...")

    -- Split into 1024-byte frames
    frames := msg.to_frames (1024)

    -- First frame has original opcode, rest are CONTINUATION
    -- Last frame has FIN bit set
end
```

## API Reference

### WS_FRAME

| Method | Description |
|--------|-------------|
| `make_text (text, is_fin)` | Create text frame |
| `make_binary (data, is_fin)` | Create binary frame |
| `make_close (code, reason)` | Create close frame |
| `make_ping` | Create ping frame |
| `make_pong` | Create pong frame |
| `set_mask (key)` | Set 4-byte mask key |
| `to_bytes` | Encode to wire format |
| `text_payload` | Get payload as string |
| `close_code` | Get close status code |
| `close_reason` | Get close reason |

### WS_FRAME_PARSER

| Method | Description |
|--------|-------------|
| `add_bytes (bytes)` | Add data to buffer |
| `parse` | Attempt to parse frame |
| `has_frame` | Is frame available? |
| `last_frame` | Get parsed frame |
| `reset` | Clear parser state |

### WS_HANDSHAKE

| Method | Description |
|--------|-------------|
| `create_client_request (host, path)` | Generate client handshake |
| `validate_server_response (response)` | Validate server response |
| `parse_client_request (request)` | Parse client handshake |
| `create_server_response` | Generate server response |
| `is_valid` | Was handshake successful? |
| `last_error` | Error message |

### WS_MESSAGE

| Method | Description |
|--------|-------------|
| `make_text (text)` | Create text message |
| `make_binary (data)` | Create binary message |
| `to_frame` | Convert to single frame |
| `to_frames (max_size)` | Split into multiple frames |

## Frame Opcodes (RFC 6455)

| Opcode | Type | Description |
|--------|------|-------------|
| 0x0 | Continuation | Fragment continuation |
| 0x1 | Text | UTF-8 text data |
| 0x2 | Binary | Binary data |
| 0x8 | Close | Connection close |
| 0x9 | Ping | Heartbeat request |
| 0xA | Pong | Heartbeat response |

## Close Codes (RFC 6455)

| Code | Name | Description |
|------|------|-------------|
| 1000 | Normal | Clean close |
| 1001 | Going Away | Server shutting down |
| 1002 | Protocol Error | Protocol violation |
| 1003 | Unsupported | Unsupported data type |
| 1007 | Invalid Payload | Malformed data |
| 1008 | Policy Violation | Generic policy error |
| 1009 | Message Too Big | Message exceeds limit |
| 1011 | Server Error | Unexpected server error |

## Dependencies

- EiffelBase
- EiffelNet
- simple_foundation_api (for Base64 encoding and SHA-1 hashing in handshake)

## References

- [RFC 6455 - The WebSocket Protocol](https://tools.ietf.org/html/rfc6455)

## License

MIT License - Copyright (c) 2024-2025, Larry Rix
