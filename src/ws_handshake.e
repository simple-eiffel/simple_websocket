note
	description: "WebSocket handshake per RFC 6455 Section 4"
	author: "Larry Rix"
	date: "$Date$"
	revision: "$Revision$"

class
	WS_HANDSHAKE

create
	make

feature {NONE} -- Initialization

	make
			-- Initialize handshake handler.
		do
			create last_error.make_empty
			is_valid := False
		ensure
			not_valid: not is_valid
		end

feature -- Access

	is_valid: BOOLEAN
			-- Was last handshake operation successful?

	last_error: STRING
			-- Last error message.

	sec_websocket_key: detachable STRING
			-- Client's Sec-WebSocket-Key header value.

	sec_websocket_accept: detachable STRING
			-- Server's Sec-WebSocket-Accept response value.

	requested_path: detachable STRING
			-- Requested WebSocket path.

	subprotocol: detachable STRING
			-- Negotiated subprotocol.

feature -- Client Operations

	create_client_request (a_host: STRING; a_path: STRING): STRING
			-- Generate client handshake request.
		require
			host_not_void: a_host /= Void
			host_not_empty: not a_host.is_empty
			path_not_void: a_path /= Void
		local
			key: STRING
		do
			key := generate_key
			sec_websocket_key := key

			create Result.make (200)
			Result.append ("GET ")
			if a_path.is_empty then
				Result.append ("/")
			else
				Result.append (a_path)
			end
			Result.append (" HTTP/1.1%R%N")
			Result.append ("Host: " + a_host + "%R%N")
			Result.append ("Upgrade: websocket%R%N")
			Result.append ("Connection: Upgrade%R%N")
			Result.append ("Sec-WebSocket-Key: " + key + "%R%N")
			Result.append ("Sec-WebSocket-Version: 13%R%N")
			Result.append ("%R%N")
		ensure
			key_set: sec_websocket_key /= Void
		end

	validate_server_response (a_response: STRING): BOOLEAN
			-- Validate server handshake response.
		require
			response_not_void: a_response /= Void
			key_set: sec_websocket_key /= Void
		local
			lines: LIST [STRING]
			line: STRING
			expected_accept: STRING
		do
			is_valid := False
			create last_error.make_empty

			lines := a_response.split ('%N')

			-- Check status line
			if lines.count > 0 then
				line := lines.first
				line.right_adjust
				if not line.has_substring ("101") then
					last_error := "Invalid status code (expected 101 Switching Protocols)"
					Result := False
				else
					-- Check required headers
					if not has_header (a_response, "Upgrade", "websocket") then
						last_error := "Missing or invalid Upgrade header"
					elseif not has_header (a_response, "Connection", "Upgrade") then
						last_error := "Missing or invalid Connection header"
					else
						-- Validate Sec-WebSocket-Accept
						if attached get_header_value (a_response, "Sec-WebSocket-Accept") as accept_value then
							sec_websocket_accept := accept_value
							if attached sec_websocket_key as key then
								expected_accept := compute_accept_key (key)
								if accept_value.same_string (expected_accept) then
									is_valid := True
									Result := True
								else
									last_error := "Sec-WebSocket-Accept mismatch"
								end
							end
						else
							last_error := "Missing Sec-WebSocket-Accept header"
						end
					end
				end
			else
				last_error := "Empty response"
			end
		end

feature -- Server Operations

	parse_client_request (a_request: STRING): BOOLEAN
			-- Parse client handshake request.
		require
			request_not_void: a_request /= Void
		local
			lines: LIST [STRING]
			first_line: STRING
			parts: LIST [STRING]
		do
			is_valid := False
			create last_error.make_empty

			lines := a_request.split ('%N')

			if lines.count > 0 then
				first_line := lines.first
				first_line.right_adjust

				-- Parse request line: GET /path HTTP/1.1
				parts := first_line.split (' ')
				if parts.count >= 2 then
					if parts.first.same_string ("GET") then
						requested_path := parts.i_th (2)

						-- Check required headers
						if not has_header (a_request, "Upgrade", "websocket") then
							last_error := "Missing or invalid Upgrade header"
						elseif not has_header (a_request, "Connection", "Upgrade") then
							last_error := "Missing or invalid Connection header"
						elseif not has_header_key (a_request, "Sec-WebSocket-Key") then
							last_error := "Missing Sec-WebSocket-Key header"
						elseif not has_header (a_request, "Sec-WebSocket-Version", "13") then
							last_error := "Missing or invalid Sec-WebSocket-Version header"
						else
							sec_websocket_key := get_header_value (a_request, "Sec-WebSocket-Key")
							is_valid := True
							Result := True
						end
					else
						last_error := "Invalid method (expected GET)"
					end
				else
					last_error := "Invalid request line"
				end
			else
				last_error := "Empty request"
			end
		end

	create_server_response: STRING
			-- Generate server handshake response.
		require
			valid_request: is_valid
			key_set: sec_websocket_key /= Void
		local
			accept_key: STRING
		do
			if attached sec_websocket_key as key then
				accept_key := compute_accept_key (key)
				sec_websocket_accept := accept_key

				create Result.make (200)
				Result.append ("HTTP/1.1 101 Switching Protocols%R%N")
				Result.append ("Upgrade: websocket%R%N")
				Result.append ("Connection: Upgrade%R%N")
				Result.append ("Sec-WebSocket-Accept: " + accept_key + "%R%N")
				if attached subprotocol as proto then
					Result.append ("Sec-WebSocket-Protocol: " + proto + "%R%N")
				end
				Result.append ("%R%N")
			else
				create Result.make_empty
			end
		ensure
			accept_set: sec_websocket_accept /= Void
		end

feature {NONE} -- Implementation

	Guid: STRING = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
			-- WebSocket GUID per RFC 6455.

	generate_key: STRING
			-- Generate random 16-byte Base64-encoded key.
		local
			random: RANDOM
			bytes: ARRAY [NATURAL_8]
			i: INTEGER
			foundation: FOUNDATION
		do
			create random.make
			random.start
			create bytes.make_filled (0, 1, 16)
			from i := 1 until i > 16 loop
				random.forth
				bytes [i] := (random.item \\ 256).to_natural_8
				i := i + 1
			end
			create foundation.make
			Result := foundation.base64_encode_bytes (bytes)
		end

	compute_accept_key (a_key: STRING): STRING
			-- Compute Sec-WebSocket-Accept from client key.
		require
			key_not_void: a_key /= Void
		local
			foundation: FOUNDATION
			sha1_bytes: ARRAY [NATURAL_8]
			combined: STRING
		do
			combined := a_key + Guid
			create foundation.make
			sha1_bytes := foundation.sha1_bytes (combined)
			Result := foundation.base64_encode_bytes (sha1_bytes)
		end

	has_header (a_text: STRING; a_header: STRING; a_value: STRING): BOOLEAN
			-- Does text contain header with value (case-insensitive)?
		require
			text_not_void: a_text /= Void
			header_not_void: a_header /= Void
			value_not_void: a_value /= Void
		local
			header_value: detachable STRING
		do
			header_value := get_header_value (a_text, a_header)
			if header_value /= Void then
				Result := header_value.as_lower.same_string (a_value.as_lower)
			end
		end

	has_header_key (a_text: STRING; a_header: STRING): BOOLEAN
			-- Does text contain header key?
		require
			text_not_void: a_text /= Void
			header_not_void: a_header /= Void
		do
			Result := get_header_value (a_text, a_header) /= Void
		end

	get_header_value (a_text: STRING; a_header: STRING): detachable STRING
			-- Get header value from HTTP headers.
		require
			text_not_void: a_text /= Void
			header_not_void: a_header /= Void
		local
			lines: LIST [STRING]
			line: STRING
			colon_pos: INTEGER
			header_name: STRING
		do
			lines := a_text.split ('%N')
			across lines as l loop
				line := l.twin
				line.left_adjust
				line.right_adjust
				colon_pos := line.index_of (':', 1)
				if colon_pos > 0 then
					header_name := line.substring (1, colon_pos - 1)
					header_name.left_adjust
					header_name.right_adjust
					if header_name.as_lower.same_string (a_header.as_lower) then
						Result := line.substring (colon_pos + 1, line.count)
						Result.left_adjust
						Result.right_adjust
					end
				end
			end
		end

invariant
	last_error_not_void: last_error /= Void

end
