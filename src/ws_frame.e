note
	description: "WebSocket frame per RFC 6455 Section 5"
	author: "Larry Rix"
	date: "$Date$"
	revision: "$Revision$"

class
	WS_FRAME

create
	make,
	make_text,
	make_binary,
	make_close,
	make_ping,
	make_pong

feature {NONE} -- Initialization

	make (a_opcode: INTEGER; a_payload: ARRAY [NATURAL_8]; a_fin: BOOLEAN)
			-- Create frame with given opcode, payload and FIN flag.
		require
			valid_opcode: is_valid_opcode (a_opcode)
			payload_not_void: a_payload /= Void
		do
			opcode := a_opcode
			payload := a_payload
			is_fin := a_fin
			is_masked := False
			create mask_key.make_filled (0, 1, 4)
		ensure
			opcode_set: opcode = a_opcode
			payload_set: payload = a_payload
			fin_set: is_fin = a_fin
		end

	make_text (a_text: STRING; a_fin: BOOLEAN)
			-- Create text frame.
		require
			text_not_void: a_text /= Void
		local
			bytes: ARRAY [NATURAL_8]
			i: INTEGER
		do
			create bytes.make_filled (0, 1, a_text.count)
			from i := 1 until i > a_text.count loop
				bytes [i] := a_text.item (i).code.to_natural_8
				i := i + 1
			end
			make (Opcode_text, bytes, a_fin)
		end

	make_binary (a_data: ARRAY [NATURAL_8]; a_fin: BOOLEAN)
			-- Create binary frame.
		require
			data_not_void: a_data /= Void
		do
			make (Opcode_binary, a_data, a_fin)
		end

	make_close (a_code: INTEGER; a_reason: STRING)
			-- Create close frame with status code and reason.
		require
			valid_code: a_code >= 1000 and a_code <= 4999
		local
			bytes: ARRAY [NATURAL_8]
			i, offset: INTEGER
		do
			create bytes.make_filled (0, 1, 2 + a_reason.count)
			-- Status code in network byte order (big-endian)
			bytes [1] := ((a_code |>> 8) & 0xFF).to_natural_8
			bytes [2] := (a_code & 0xFF).to_natural_8
			-- Reason string
			from
				i := 1
				offset := 2
			until
				i > a_reason.count
			loop
				bytes [offset + i] := a_reason.item (i).code.to_natural_8
				i := i + 1
			end
			make (Opcode_close, bytes, True)
		end

	make_ping
			-- Create ping frame.
		do
			make (Opcode_ping, create {ARRAY [NATURAL_8]}.make_empty, True)
		end

	make_pong
			-- Create pong frame.
		do
			make (Opcode_pong, create {ARRAY [NATURAL_8]}.make_empty, True)
		end

feature -- Access

	opcode: INTEGER
			-- Frame opcode (0x0-0xF).

	payload: ARRAY [NATURAL_8]
			-- Frame payload data.

	is_fin: BOOLEAN
			-- Is this the final fragment?

	is_masked: BOOLEAN
			-- Is payload masked?

	mask_key: ARRAY [NATURAL_8]
			-- 4-byte masking key.

feature -- Derived Access

	payload_length: INTEGER
			-- Length of payload.
		do
			Result := payload.count
		ensure
			non_negative: Result >= 0
		end

	text_payload: STRING
			-- Payload as text (for text frames).
		require
			is_text: opcode = Opcode_text or opcode = Opcode_continuation
		local
			i: INTEGER
		do
			create Result.make (payload.count)
			from i := payload.lower until i > payload.upper loop
				Result.append_character (payload [i].to_character_8)
				i := i + 1
			end
		end

	close_code: INTEGER
			-- Close status code (for close frames).
		require
			is_close: opcode = Opcode_close
			has_code: payload.count >= 2
		do
			Result := (payload [1].to_integer_32 |<< 8) | payload [2].to_integer_32
		end

	close_reason: STRING
			-- Close reason (for close frames).
		require
			is_close: opcode = Opcode_close
		local
			i: INTEGER
		do
			create Result.make (payload.count - 2)
			from i := 3 until i > payload.count loop
				Result.append_character (payload [i].to_character_8)
				i := i + 1
			end
		end

feature -- Status

	is_control: BOOLEAN
			-- Is this a control frame?
		do
			Result := opcode >= 0x8
		end

	is_text: BOOLEAN
			-- Is this a text data frame?
		do
			Result := opcode = Opcode_text
		end

	is_binary: BOOLEAN
			-- Is this a binary data frame?
		do
			Result := opcode = Opcode_binary
		end

	is_close: BOOLEAN
			-- Is this a close frame?
		do
			Result := opcode = Opcode_close
		end

	is_ping: BOOLEAN
			-- Is this a ping frame?
		do
			Result := opcode = Opcode_ping
		end

	is_pong: BOOLEAN
			-- Is this a pong frame?
		do
			Result := opcode = Opcode_pong
		end

	is_continuation: BOOLEAN
			-- Is this a continuation frame?
		do
			Result := opcode = Opcode_continuation
		end

feature -- Modification

	set_mask (a_key: ARRAY [NATURAL_8])
			-- Set masking key and enable masking.
		require
			key_not_void: a_key /= Void
			key_length: a_key.count = 4
		do
			mask_key := a_key
			is_masked := True
		ensure
			masked: is_masked
			key_set: mask_key = a_key
		end

feature -- Encoding

	to_bytes: ARRAY [NATURAL_8]
			-- Encode frame to wire format.
		local
			result_list: ARRAYED_LIST [NATURAL_8]
			first_byte, second_byte: NATURAL_8
			len: INTEGER
			i: INTEGER
			masked_payload: ARRAY [NATURAL_8]
		do
			create result_list.make (10 + payload.count)

			-- First byte: FIN + RSV + Opcode
			first_byte := opcode.to_natural_8
			if is_fin then
				first_byte := first_byte | 0x80
			end
			result_list.extend (first_byte)

			-- Second byte: MASK + Payload length
			len := payload.count
			if is_masked then
				second_byte := 0x80
			else
				second_byte := 0
			end

			if len <= 125 then
				second_byte := second_byte | len.to_natural_8
				result_list.extend (second_byte)
			elseif len <= 65535 then
				second_byte := second_byte | 126
				result_list.extend (second_byte)
				result_list.extend (((len |>> 8) & 0xFF).to_natural_8)
				result_list.extend ((len & 0xFF).to_natural_8)
			else
				second_byte := second_byte | 127
				result_list.extend (second_byte)
				-- 8 bytes for extended length
				result_list.extend (0)
				result_list.extend (0)
				result_list.extend (0)
				result_list.extend (0)
				result_list.extend (((len |>> 24) & 0xFF).to_natural_8)
				result_list.extend (((len |>> 16) & 0xFF).to_natural_8)
				result_list.extend (((len |>> 8) & 0xFF).to_natural_8)
				result_list.extend ((len & 0xFF).to_natural_8)
			end

			-- Masking key (if masked)
			if is_masked then
				result_list.extend (mask_key [1])
				result_list.extend (mask_key [2])
				result_list.extend (mask_key [3])
				result_list.extend (mask_key [4])
			end

			-- Payload (masked if needed)
			if is_masked then
				masked_payload := apply_mask (payload, mask_key)
				from i := masked_payload.lower until i > masked_payload.upper loop
					result_list.extend (masked_payload [i])
					i := i + 1
				end
			else
				from i := payload.lower until i > payload.upper loop
					result_list.extend (payload [i])
					i := i + 1
				end
			end

			create Result.make_filled (0, 1, result_list.count)
			from i := 1 until i > result_list.count loop
				Result [i] := result_list [i]
				i := i + 1
			end
		end

feature -- Validation

	is_valid_opcode (a_opcode: INTEGER): BOOLEAN
			-- Is opcode valid per RFC 6455?
		do
			Result := (a_opcode >= 0 and a_opcode <= 2) or
			          (a_opcode >= 8 and a_opcode <= 10)
		end

feature {NONE} -- Implementation

	apply_mask (data: ARRAY [NATURAL_8]; key: ARRAY [NATURAL_8]): ARRAY [NATURAL_8]
			-- Apply XOR mask to data.
		require
			data_not_void: data /= Void
			key_not_void: key /= Void
			key_length: key.count = 4
		local
			i, j: INTEGER
		do
			create Result.make_filled (0, data.lower, data.upper)
			from
				i := data.lower
			until
				i > data.upper
			loop
				j := ((i - data.lower) \\ 4) + 1
				Result [i] := data [i].bit_xor (key [j])
				i := i + 1
			end
		ensure
			same_size: Result.count = data.count
		end

feature -- Opcodes (RFC 6455 Section 5.2)

	Opcode_continuation: INTEGER = 0x0
	Opcode_text: INTEGER = 0x1
	Opcode_binary: INTEGER = 0x2
	Opcode_close: INTEGER = 0x8
	Opcode_ping: INTEGER = 0x9
	Opcode_pong: INTEGER = 0xA

feature -- Close Codes (RFC 6455 Section 7.4.1)

	Close_normal: INTEGER = 1000
	Close_going_away: INTEGER = 1001
	Close_protocol_error: INTEGER = 1002
	Close_unsupported_data: INTEGER = 1003
	Close_invalid_payload: INTEGER = 1007
	Close_policy_violation: INTEGER = 1008
	Close_message_too_big: INTEGER = 1009
	Close_server_error: INTEGER = 1011

invariant
	payload_not_void: payload /= Void
	mask_key_not_void: mask_key /= Void
	mask_key_length: mask_key.count = 4

end
