local TEST_TIMEOUT = 2
describe("http.stream_common", function()
	local h1_connection = require "http.h1_connection"
	local new_headers = require "http.headers".new
	local cqueues = require "cqueues"
	local cs = require "cqueues.socket"
	local function assert_loop(cq, timeout)
		local ok, err, _, thd = cq:loop(timeout)
		if not ok then
			if thd then
				err = debug.traceback(thd, err)
			end
			error(err, 2)
		end
	end
	local function new_pair(version)
		local s, c = cs.pair()
		s = h1_connection.new(s, "server", version)
		c = h1_connection.new(c, "client", version)
		return s, c
	end
	it("Can read a number of characters", function()
		local server, client = new_pair(1.1)
		local cq = cqueues.new()
		cq:wrap(function()
			local stream = client:new_stream()
			local headers = new_headers()
			headers:append(":method", "GET")
			headers:append(":path", "/")
			assert(stream:write_headers(headers, false))
			assert(stream:write_chunk("foo", false))
			assert(stream:write_chunk("\nb", false))
			assert(stream:write_chunk("ar\n", true))
		end)
		cq:wrap(function()
			local stream = server:get_next_incoming_stream()
			-- same size as next chunk
			assert.same("foo", stream:get_body_chars(3))
			-- less than chunk
			assert.same("\n", stream:get_body_chars(1))
			-- crossing chunks
			assert.same("bar", stream:get_body_chars(3))
			-- more than available
			assert.same("\n", stream:get_body_chars(8))
			-- when none available
			assert.same(nil, stream:get_body_chars(8))
		end)
		assert_loop(cq, TEST_TIMEOUT)
		assert.truthy(cq:empty())
	end)
	it("Can read a line", function()
		local server, client = new_pair(1.1)
		local cq = cqueues.new()
		cq:wrap(function()
			local stream = client:new_stream()
			local headers = new_headers()
			headers:append(":method", "GET")
			headers:append(":path", "/")
			assert(stream:write_headers(headers, false))
			assert(stream:write_chunk("foo", false))
			assert(stream:write_chunk("\nb", false))
			assert(stream:write_chunk("ar\n", true))
		end)
		cq:wrap(function()
			local stream = server:get_next_incoming_stream()
			assert.same("foo", stream:get_body_until("\n", true, false))
			assert.same("bar", stream:get_body_until("\n", true, false))
			assert.same(nil, stream:get_body_until("\n", true, false))
		end)
		assert_loop(cq, TEST_TIMEOUT)
		assert.truthy(cq:empty())
	end)
end)
