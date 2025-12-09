-- luacheck: globals describe it assert
local _99 = require("99")
local test_utils = require("99.test.test_utils")
local eq = assert.are.same
local test_content = require("99.test.test_content")

--- @param content string[]
--- @return _99.test.Provider, number
local function setup(content)
    local p = test_utils.TestProvider.new()
    _99.setup({
        provider = p,
    })

    local buffer = test_utils.create_file(content, "lua", 2)
    return p, buffer
end

--- @param buffer number
--- @return string[]
local function r(buffer)
    return vim.api.nvim_buf_get_lines(buffer, 0, -1, false)
end

local cases = {
    { "single line", test_content.empty_function_single_line },
    { "multiline", test_content.empty_function_2_lines },
}

describe("fill_in_function", function()
    for _, case in ipairs(cases) do
        it(case[1], function()
            local p, buffer = setup(case[2])
            _99.fill_in_function()
            eq(case[2], r(buffer))

            p:resolve(true, "function foo()\n    return 42\nend")
            test_utils.next_frame()

            local expected_state = {
                "",
                "function foo()",
                "    return 42",
                "end",
                "",
            }
            eq(expected_state, r(buffer))
        end)
    end
end)
