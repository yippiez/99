-- luacheck: globals describe it assert
local eq = assert.are.same
local RequestStatus = require("99.ops.request_status")

describe("request_status", function()
    it("setting lines and status line", function()
        local status = RequestStatus.new(250, 3)
        eq({"⠋"}, status:get())

        status:push("foo")
        status:push("bar")

        eq({"⠋", "foo", "bar"}, status:get())

        status:push("baz")

        eq({"⠋", "bar", "baz"}, status:get())
    end)
end)
