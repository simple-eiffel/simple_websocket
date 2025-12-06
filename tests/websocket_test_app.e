note
	description: "Test application for simple_websocket"
	author: "Larry Rix"

class
	WEBSOCKET_TEST_APP

create
	make

feature {NONE} -- Initialization

	make
			-- Run tests.
		local
			tests: WEBSOCKET_TEST_SET
		do
			create tests
			io.put_string ("simple_websocket test runner%N")
			io.put_string ("================================%N%N")

			passed := 0
			failed := 0

			-- WS_FRAME Creation tests
			io.put_string ("WS_FRAME Tests - Creation%N")
			io.put_string ("--------------------------%N")
			run_test (agent tests.test_make_text_frame, "test_make_text_frame")
			run_test (agent tests.test_make_binary_frame, "test_make_binary_frame")
			run_test (agent tests.test_make_close_frame, "test_make_close_frame")
			run_test (agent tests.test_make_ping_frame, "test_make_ping_frame")
			run_test (agent tests.test_make_pong_frame, "test_make_pong_frame")

			-- WS_FRAME Encoding tests
			io.put_string ("%NWS_FRAME Tests - Encoding%N")
			io.put_string ("---------------------------%N")
			run_test (agent tests.test_encode_small_unmasked_frame, "test_encode_small_unmasked_frame")
			run_test (agent tests.test_encode_masked_frame, "test_encode_masked_frame")
			run_test (agent tests.test_encode_medium_frame, "test_encode_medium_frame")

			-- WS_FRAME Opcode tests
			io.put_string ("%NWS_FRAME Tests - Opcodes%N")
			io.put_string ("--------------------------%N")
			run_test (agent tests.test_is_valid_opcode, "test_is_valid_opcode")

			-- WS_FRAME_PARSER tests
			io.put_string ("%NWS_FRAME_PARSER Tests%N")
			io.put_string ("-----------------------%N")
			run_test (agent tests.test_parse_small_frame, "test_parse_small_frame")
			run_test (agent tests.test_parse_masked_frame, "test_parse_masked_frame")
			run_test (agent tests.test_parse_incomplete_frame, "test_parse_incomplete_frame")
			run_test (agent tests.test_parse_extended_length, "test_parse_extended_length")

			-- WS_MESSAGE tests
			io.put_string ("%NWS_MESSAGE Tests%N")
			io.put_string ("------------------%N")
			run_test (agent tests.test_message_to_frame, "test_message_to_frame")
			run_test (agent tests.test_message_to_frames_single, "test_message_to_frames_single")
			run_test (agent tests.test_message_to_frames_multiple, "test_message_to_frames_multiple")

			-- WS_HANDSHAKE tests
			io.put_string ("%NWS_HANDSHAKE Tests%N")
			io.put_string ("--------------------%N")
			run_test (agent tests.test_handshake_create_client_request, "test_handshake_create_client_request")
			run_test (agent tests.test_handshake_parse_client_request, "test_handshake_parse_client_request")
			run_test (agent tests.test_handshake_create_server_response, "test_handshake_create_server_response")
			run_test (agent tests.test_handshake_invalid_upgrade, "test_handshake_invalid_upgrade")

			io.put_string ("%N================================%N")
			io.put_string ("Results: " + passed.out + " passed, " + failed.out + " failed%N")

			if failed > 0 then
				io.put_string ("TESTS FAILED%N")
			else
				io.put_string ("ALL TESTS PASSED%N")
			end
		end

feature {NONE} -- Implementation

	passed: INTEGER
	failed: INTEGER

	run_test (a_test: PROCEDURE; a_name: STRING)
			-- Run a single test and update counters.
		local
			l_retried: BOOLEAN
		do
			if not l_retried then
				a_test.call (Void)
				io.put_string ("  PASS: " + a_name + "%N")
				passed := passed + 1
			end
		rescue
			io.put_string ("  FAIL: " + a_name + "%N")
			failed := failed + 1
			l_retried := True
			retry
		end

end
