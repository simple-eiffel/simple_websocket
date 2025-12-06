note
	description: "Complete WebSocket message (may span multiple frames)"
	author: "Larry Rix"
	date: "$Date$"
	revision: "$Revision$"

class
	WS_MESSAGE

create
	make_text,
	make_binary

feature {NONE} -- Initialization

	make_text (a_text: STRING)
			-- Create text message.
		require
			text_not_void: a_text /= Void
		local
			i: INTEGER
		do
			is_text := True
			is_binary := False
			text := a_text
			create data.make_filled (0, 1, a_text.count)
			from i := 1 until i > a_text.count loop
				data [i] := a_text.item (i).code.to_natural_8
				i := i + 1
			end
		ensure
			is_text: is_text
			not_binary: not is_binary
			text_set: text.same_string (a_text)
		end

	make_binary (a_data: ARRAY [NATURAL_8])
			-- Create binary message.
		require
			data_not_void: a_data /= Void
		do
			is_text := False
			is_binary := True
			data := a_data
			create text.make_empty
		ensure
			not_text: not is_text
			is_binary: is_binary
			data_set: data = a_data
		end

feature -- Access

	is_text: BOOLEAN
			-- Is this a text message?

	is_binary: BOOLEAN
			-- Is this a binary message?

	text: STRING
			-- Message as text (for text messages).

	data: ARRAY [NATURAL_8]
			-- Message as binary data.

	size: INTEGER
			-- Size of message in bytes.
		do
			Result := data.count
		ensure
			non_negative: Result >= 0
		end

feature -- Conversion

	to_frame: WS_FRAME
			-- Convert message to single frame.
		do
			if is_text then
				create Result.make_text (text, True)
			else
				create Result.make_binary (data, True)
			end
		ensure
			result_not_void: Result /= Void
			is_fin: Result.is_fin
		end

	to_frames (a_max_size: INTEGER): ARRAYED_LIST [WS_FRAME]
			-- Split message into frames of max size.
		require
			positive_size: a_max_size > 0
		local
			i, chunk_start, chunk_end: INTEGER
			chunk: ARRAY [NATURAL_8]
			is_first, is_last: BOOLEAN
			opcode: INTEGER
		do
			create Result.make (data.count // a_max_size + 1)

			if is_text then
				opcode := {WS_FRAME}.Opcode_text
			else
				opcode := {WS_FRAME}.Opcode_binary
			end

			from
				i := 1
				chunk_start := 1
			until
				chunk_start > data.count
			loop
				is_first := i = 1
				chunk_end := (chunk_start + a_max_size - 1).min (data.count)
				is_last := chunk_end >= data.count

				chunk := data.subarray (chunk_start, chunk_end)

				if is_first then
					Result.extend (create {WS_FRAME}.make (opcode, chunk, is_last))
				else
					Result.extend (create {WS_FRAME}.make ({WS_FRAME}.Opcode_continuation, chunk, is_last))
				end

				chunk_start := chunk_end + 1
				i := i + 1
			end

			if Result.is_empty then
				-- Empty message, create single empty frame
				create chunk.make_empty
				Result.extend (create {WS_FRAME}.make (opcode, chunk, True))
			end
		ensure
			result_not_void: Result /= Void
			has_frames: Result.count > 0
			last_is_fin: Result.last.is_fin
		end

invariant
	exclusive_type: is_text xor is_binary
	text_not_void: text /= Void
	data_not_void: data /= Void

end
