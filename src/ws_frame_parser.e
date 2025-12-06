note
	description: "WebSocket frame parser for reading frames from byte stream"
	author: "Larry Rix"
	date: "$Date$"
	revision: "$Revision$"

class
	WS_FRAME_PARSER

create
	make

feature {NONE} -- Initialization

	make
			-- Initialize parser.
		do
			create buffer.make (0)
			create last_error.make_empty
			reset
		ensure
			empty_buffer: buffer.is_empty
		end

feature -- Access

	has_frame: BOOLEAN
			-- Is a complete frame available?

	last_frame: detachable WS_FRAME
			-- Last parsed frame.

	last_error: STRING
			-- Last error message.

	has_error: BOOLEAN
			-- Did an error occur?

feature -- Operations

	add_bytes (a_bytes: ARRAY [NATURAL_8])
			-- Add bytes to parse buffer.
		require
			bytes_not_void: a_bytes /= Void
		local
			i: INTEGER
		do
			from i := a_bytes.lower until i > a_bytes.upper loop
				buffer.extend (a_bytes [i])
				i := i + 1
			end
		ensure
			bytes_added: buffer.count >= old buffer.count
		end

	parse: BOOLEAN
			-- Attempt to parse a frame from buffer.
			-- Return True if successful.
		local
			first_byte, second_byte: NATURAL_8
			opcode: INTEGER
			is_fin, is_masked: BOOLEAN
			payload_len: INTEGER_64
			header_size: INTEGER
			mask_key: ARRAY [NATURAL_8]
			payload: ARRAY [NATURAL_8]
			i, j: INTEGER
			total_size: INTEGER
		do
			has_frame := False
			last_frame := Void
			has_error := False
			create last_error.make_empty

			if buffer.count < 2 then
				-- Not enough data for header
				Result := False
			else
				first_byte := buffer [1]
				second_byte := buffer [2]

				-- Parse first byte: FIN + RSV + Opcode
				is_fin := (first_byte & 0x80) /= 0
				opcode := (first_byte & 0x0F).to_integer_32

				-- Check RSV bits (must be 0 for base protocol)
				if (first_byte & 0x70) /= 0 then
					has_error := True
					last_error := "Reserved bits must be 0"
					Result := False
				else
					-- Parse second byte: MASK + Payload length
					is_masked := (second_byte & 0x80) /= 0
					payload_len := (second_byte & 0x7F).to_integer_64

					header_size := 2

					if payload_len = 126 then
						-- 16-bit extended length
						if buffer.count < 4 then
							Result := False
						else
							payload_len := (buffer [3].to_integer_64 |<< 8) | buffer [4].to_integer_64
							header_size := 4
						end
					elseif payload_len = 127 then
						-- 64-bit extended length
						if buffer.count < 10 then
							Result := False
						else
							payload_len := 0
							from i := 3 until i > 10 loop
								payload_len := (payload_len |<< 8) | buffer [i].to_integer_64
								i := i + 1
							end
							header_size := 10
						end
					end

					if not has_error and payload_len >= 0 then
						if is_masked then
							header_size := header_size + 4
						end

						total_size := header_size + payload_len.to_integer_32

						if buffer.count < total_size then
							-- Not enough data yet
							Result := False
						else
							-- Parse mask key if present
							if is_masked then
								create mask_key.make_filled (0, 1, 4)
								mask_key [1] := buffer [header_size - 3]
								mask_key [2] := buffer [header_size - 2]
								mask_key [3] := buffer [header_size - 1]
								mask_key [4] := buffer [header_size]
							else
								create mask_key.make_filled (0, 1, 4)
							end

							-- Extract payload
							create payload.make_filled (0, 1, payload_len.to_integer_32)
							from i := 1 until i > payload_len.to_integer_32 loop
								payload [i] := buffer [header_size + i]
								i := i + 1
							end

							-- Unmask if needed
							if is_masked then
								from i := 1 until i > payload.count loop
									j := ((i - 1) \\ 4) + 1
									payload [i] := payload [i].bit_xor (mask_key [j])
									i := i + 1
								end
							end

							-- Create frame
							create last_frame.make (opcode, payload, is_fin)
							if is_masked and attached last_frame as lf then
								lf.set_mask (mask_key)
							end

							has_frame := True
							Result := True

							-- Remove parsed bytes from buffer
							remove_bytes (total_size)
						end
					end
				end
			end
		end

	reset
			-- Reset parser state.
		do
			buffer.wipe_out
			has_frame := False
			last_frame := Void
			has_error := False
			create last_error.make_empty
		ensure
			empty_buffer: buffer.is_empty
			no_frame: not has_frame
			no_error: not has_error
		end

feature {NONE} -- Implementation

	buffer: ARRAYED_LIST [NATURAL_8]
			-- Byte buffer.

	remove_bytes (count: INTEGER)
			-- Remove first `count` bytes from buffer.
		require
			valid_count: count >= 0 and count <= buffer.count
		local
			i: INTEGER
		do
			from i := 1 until i > count loop
				buffer.start
				buffer.remove
				i := i + 1
			end
		ensure
			size_reduced: buffer.count = old buffer.count - count
		end

invariant
	buffer_not_void: buffer /= Void
	last_error_not_void: last_error /= Void

end
