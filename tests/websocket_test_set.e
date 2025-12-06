note
	description: "Test set for simple_websocket library"
	author: "Larry Rix"
	date: "$Date$"
	revision: "$Revision$"
	testing: "type/manual"

class
	WEBSOCKET_TEST_SET

inherit
	TEST_SET_BASE

feature -- WS_FRAME Tests: Creation

	test_make_text_frame
			-- Test creating text frame.
		note
			testing: "covers/{WS_FRAME}.make_text"
		local
			frame: WS_FRAME
		do
			create frame.make_text ("Hello", True)
			assert_true ("is_text", frame.is_text)
			assert_false ("not_binary", frame.is_binary)
			assert_true ("is_fin", frame.is_fin)
			assert_integers_equal ("opcode", {WS_FRAME}.Opcode_text, frame.opcode)
			assert_strings_equal ("payload", "Hello", frame.text_payload)
		end

	test_make_binary_frame
			-- Test creating binary frame.
		note
			testing: "covers/{WS_FRAME}.make_binary"
		local
			frame: WS_FRAME
			data: ARRAY [NATURAL_8]
		do
			data := <<1, 2, 3, 4, 5>>
			create frame.make_binary (data, True)
			assert_true ("is_binary", frame.is_binary)
			assert_false ("not_text", frame.is_text)
			assert_integers_equal ("length", 5, frame.payload_length)
		end

	test_make_close_frame
			-- Test creating close frame.
		note
			testing: "covers/{WS_FRAME}.make_close"
		local
			frame: WS_FRAME
		do
			create frame.make_close (1000, "Normal closure")
			assert_true ("is_close", frame.is_close)
			assert_true ("is_control", frame.is_control)
			assert_integers_equal ("close_code", 1000, frame.close_code)
			assert_strings_equal ("reason", "Normal closure", frame.close_reason)
		end

	test_make_ping_frame
			-- Test creating ping frame.
		note
			testing: "covers/{WS_FRAME}.make_ping"
		local
			frame: WS_FRAME
		do
			create frame.make_ping
			assert_true ("is_ping", frame.is_ping)
			assert_true ("is_control", frame.is_control)
			assert_integers_equal ("opcode", {WS_FRAME}.Opcode_ping, frame.opcode)
		end

	test_make_pong_frame
			-- Test creating pong frame.
		note
			testing: "covers/{WS_FRAME}.make_pong"
		local
			frame: WS_FRAME
		do
			create frame.make_pong
			assert_true ("is_pong", frame.is_pong)
			assert_true ("is_control", frame.is_control)
		end

feature -- WS_FRAME Tests: Encoding

	test_encode_small_unmasked_frame
			-- Test encoding small unmasked frame.
		note
			testing: "covers/{WS_FRAME}.to_bytes"
		local
			frame: WS_FRAME
			bytes: ARRAY [NATURAL_8]
		do
			create frame.make_text ("Hi", True)
			bytes := frame.to_bytes
			-- First byte: FIN(1) + RSV(0) + Opcode(1) = 0x81
			assert_integers_equal ("first_byte", 0x81, bytes [1].to_integer_32)
			-- Second byte: MASK(0) + Len(2) = 0x02
			assert_integers_equal ("second_byte", 0x02, bytes [2].to_integer_32)
			-- Payload: "Hi"
			assert_integers_equal ("H", 72, bytes [3].to_integer_32)
			assert_integers_equal ("i", 105, bytes [4].to_integer_32)
		end

	test_encode_masked_frame
			-- Test encoding masked frame.
		note
			testing: "covers/{WS_FRAME}.to_bytes"
		local
			frame: WS_FRAME
			bytes: ARRAY [NATURAL_8]
			mask: ARRAY [NATURAL_8]
		do
			create frame.make_text ("Hi", True)
			mask := <<0x12, 0x34, 0x56, 0x78>>
			frame.set_mask (mask)
			bytes := frame.to_bytes
			-- Second byte should have MASK bit set
			assert_true ("mask_bit", (bytes [2] & 0x80) /= 0)
			-- Mask key should be present
			assert_integers_equal ("mask1", 0x12, bytes [3].to_integer_32)
			assert_integers_equal ("mask2", 0x34, bytes [4].to_integer_32)
			assert_integers_equal ("mask3", 0x56, bytes [5].to_integer_32)
			assert_integers_equal ("mask4", 0x78, bytes [6].to_integer_32)
		end

	test_encode_medium_frame
			-- Test encoding frame with 126-byte payload.
		note
			testing: "covers/{WS_FRAME}.to_bytes"
		local
			frame: WS_FRAME
			data: ARRAY [NATURAL_8]
			bytes: ARRAY [NATURAL_8]
		do
			create data.make_filled (65, 1, 200) -- 200 'A' characters
			create frame.make_binary (data, True)
			bytes := frame.to_bytes
			-- Second byte should be 126 (extended 16-bit length)
			assert_integers_equal ("len_marker", 126, (bytes [2] & 0x7F).to_integer_32)
			-- Extended length in bytes 3-4 (big-endian)
			assert_integers_equal ("len_high", 0, bytes [3].to_integer_32)
			assert_integers_equal ("len_low", 200, bytes [4].to_integer_32)
		end

feature -- WS_FRAME Tests: Opcodes

	test_is_valid_opcode
			-- Test opcode validation.
		note
			testing: "covers/{WS_FRAME}.is_valid_opcode"
		local
			frame: WS_FRAME
		do
			create frame.make_ping
			assert_true ("continuation", frame.is_valid_opcode (0))
			assert_true ("text", frame.is_valid_opcode (1))
			assert_true ("binary", frame.is_valid_opcode (2))
			assert_false ("reserved_3", frame.is_valid_opcode (3))
			assert_false ("reserved_7", frame.is_valid_opcode (7))
			assert_true ("close", frame.is_valid_opcode (8))
			assert_true ("ping", frame.is_valid_opcode (9))
			assert_true ("pong", frame.is_valid_opcode (10))
			assert_false ("reserved_11", frame.is_valid_opcode (11))
		end

feature -- WS_FRAME_PARSER Tests

	test_parse_small_frame
			-- Test parsing small unmasked frame.
		note
			testing: "covers/{WS_FRAME_PARSER}.parse"
		local
			parser: WS_FRAME_PARSER
			bytes: ARRAY [NATURAL_8]
		do
			create parser.make
			-- FIN+TEXT, len=2, "Hi"
			bytes := <<0x81, 0x02, 72, 105>>
			parser.add_bytes (bytes)
			assert_true ("parsed", parser.parse)
			assert_true ("has_frame", parser.has_frame)
			if attached parser.last_frame as frame then
				assert_true ("is_fin", frame.is_fin)
				assert_true ("is_text", frame.is_text)
				assert_strings_equal ("payload", "Hi", frame.text_payload)
			else
				assert ("frame attached", False)
			end
		end

	test_parse_masked_frame
			-- Test parsing masked frame.
		note
			testing: "covers/{WS_FRAME_PARSER}.parse"
		local
			parser: WS_FRAME_PARSER
			bytes: ARRAY [NATURAL_8]
		do
			create parser.make
			-- FIN+TEXT, MASK+len=2, mask key, masked "Hi"
			-- 'H' XOR 0x12 = 72 XOR 18 = 90 (0x5A)
			-- 'i' XOR 0x34 = 105 XOR 52 = 93 (0x5D)
			bytes := <<0x81, 0x82, 0x12, 0x34, 0x56, 0x78, 90, 93>>
			parser.add_bytes (bytes)
			assert_true ("parsed", parser.parse)
			if attached parser.last_frame as frame then
				assert_strings_equal ("unmasked", "Hi", frame.text_payload)
			end
		end

	test_parse_incomplete_frame
			-- Test parsing with incomplete data.
		note
			testing: "covers/{WS_FRAME_PARSER}.parse"
		local
			parser: WS_FRAME_PARSER
			bytes: ARRAY [NATURAL_8]
		do
			create parser.make
			-- Only header, no payload
			bytes := <<0x81, 0x05>>
			parser.add_bytes (bytes)
			assert_false ("not_complete", parser.parse)
			assert_false ("no_frame", parser.has_frame)
		end

	test_parse_extended_length
			-- Test parsing frame with extended length.
		note
			testing: "covers/{WS_FRAME_PARSER}.parse"
		local
			parser: WS_FRAME_PARSER
			bytes: ARRAY [NATURAL_8]
			i: INTEGER
		do
			create parser.make
			-- FIN+BINARY, 126 (extended), length=200, then 200 bytes payload
			create bytes.make_filled (0, 1, 4 + 200)
			bytes [1] := 0x82  -- FIN + BINARY
			bytes [2] := 126   -- Extended length marker
			bytes [3] := 0     -- High byte
			bytes [4] := 200   -- Low byte
			from i := 5 until i > bytes.upper loop
				bytes [i] := 65  -- 'A'
				i := i + 1
			end
			parser.add_bytes (bytes)
			assert_true ("parsed", parser.parse)
			if attached parser.last_frame as frame then
				assert_integers_equal ("length", 200, frame.payload_length)
			end
		end

feature -- WS_MESSAGE Tests

	test_message_to_frame
			-- Test converting message to single frame.
		note
			testing: "covers/{WS_MESSAGE}.to_frame"
		local
			msg: WS_MESSAGE
			frame: WS_FRAME
		do
			create msg.make_text ("Hello")
			frame := msg.to_frame
			assert_true ("is_fin", frame.is_fin)
			assert_true ("is_text", frame.is_text)
			assert_strings_equal ("payload", "Hello", frame.text_payload)
		end

	test_message_to_frames_single
			-- Test splitting small message (fits in one frame).
		note
			testing: "covers/{WS_MESSAGE}.to_frames"
		local
			msg: WS_MESSAGE
			frames: ARRAYED_LIST [WS_FRAME]
		do
			create msg.make_text ("Hi")
			frames := msg.to_frames (100)
			assert_integers_equal ("one_frame", 1, frames.count)
			assert_true ("last_fin", frames.last.is_fin)
		end

	test_message_to_frames_multiple
			-- Test splitting large message.
		note
			testing: "covers/{WS_MESSAGE}.to_frames"
		local
			msg: WS_MESSAGE
			frames: ARRAYED_LIST [WS_FRAME]
		do
			create msg.make_text ("HelloWorld")  -- 10 bytes
			frames := msg.to_frames (4)  -- Max 4 bytes per frame
			assert_integers_equal ("three_frames", 3, frames.count)
			assert_false ("first_not_fin", frames.first.is_fin)
			assert_true ("last_fin", frames.last.is_fin)
			-- First should be TEXT, others CONTINUATION
			assert_integers_equal ("first_opcode", {WS_FRAME}.Opcode_text, frames [1].opcode)
			assert_integers_equal ("second_opcode", {WS_FRAME}.Opcode_continuation, frames [2].opcode)
		end

feature -- WS_HANDSHAKE Tests

	test_handshake_create_client_request
			-- Test creating client handshake request.
		note
			testing: "covers/{WS_HANDSHAKE}.create_client_request"
		local
			handshake: WS_HANDSHAKE
			request: STRING
		do
			create handshake.make
			request := handshake.create_client_request ("example.com", "/chat")
			assert_true ("has_get", request.has_substring ("GET /chat HTTP/1.1"))
			assert_true ("has_host", request.has_substring ("Host: example.com"))
			assert_true ("has_upgrade", request.has_substring ("Upgrade: websocket"))
			assert_true ("has_connection", request.has_substring ("Connection: Upgrade"))
			assert_true ("has_key", request.has_substring ("Sec-WebSocket-Key:"))
			assert_true ("has_version", request.has_substring ("Sec-WebSocket-Version: 13"))
			assert ("key_set", handshake.sec_websocket_key /= Void)
		end

	test_handshake_parse_client_request
			-- Test parsing client handshake request.
		note
			testing: "covers/{WS_HANDSHAKE}.parse_client_request"
		local
			handshake: WS_HANDSHAKE
			request: STRING
		do
			create handshake.make
			request := "GET /chat HTTP/1.1%R%N"
			request.append ("Host: example.com%R%N")
			request.append ("Upgrade: websocket%R%N")
			request.append ("Connection: Upgrade%R%N")
			request.append ("Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==%R%N")
			request.append ("Sec-WebSocket-Version: 13%R%N")
			request.append ("%R%N")

			assert_true ("parsed", handshake.parse_client_request (request))
			assert_true ("is_valid", handshake.is_valid)
			if attached handshake.requested_path as p then
				assert_strings_equal ("path", "/chat", p)
			else
				assert ("path_attached", False)
			end
			if attached handshake.sec_websocket_key as k then
				assert_strings_equal ("key", "dGhlIHNhbXBsZSBub25jZQ==", k)
			else
				assert ("key_attached", False)
			end
		end

	test_handshake_create_server_response
			-- Test creating server response.
		note
			testing: "covers/{WS_HANDSHAKE}.create_server_response"
		local
			handshake: WS_HANDSHAKE
			request, response: STRING
		do
			create handshake.make
			request := "GET / HTTP/1.1%R%N"
			request.append ("Upgrade: websocket%R%N")
			request.append ("Connection: Upgrade%R%N")
			request.append ("Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==%R%N")
			request.append ("Sec-WebSocket-Version: 13%R%N")

			if handshake.parse_client_request (request) then
				response := handshake.create_server_response
				assert_true ("has_101", response.has_substring ("101 Switching Protocols"))
				assert_true ("has_upgrade", response.has_substring ("Upgrade: websocket"))
				assert_true ("has_accept", response.has_substring ("Sec-WebSocket-Accept:"))
				-- RFC 6455 example: key "dGhlIHNhbXBsZSBub25jZQ==" should produce
				-- accept "s3pPLMBiTxaQ9kYGzzhZRbK+xOo="
				assert_true ("correct_accept", response.has_substring ("s3pPLMBiTxaQ9kYGzzhZRbK+xOo="))
			else
				assert ("parsed", False)
			end
		end

	test_handshake_invalid_upgrade
			-- Test rejecting request without proper Upgrade header.
		note
			testing: "covers/{WS_HANDSHAKE}.parse_client_request"
		local
			handshake: WS_HANDSHAKE
			request: STRING
		do
			create handshake.make
			request := "GET / HTTP/1.1%R%N"
			request.append ("Connection: keep-alive%R%N")  -- Missing Upgrade
			request.append ("Sec-WebSocket-Key: abc%R%N")
			request.append ("Sec-WebSocket-Version: 13%R%N")

			assert_false ("rejected", handshake.parse_client_request (request))
			assert_false ("not_valid", handshake.is_valid)
		end

end
