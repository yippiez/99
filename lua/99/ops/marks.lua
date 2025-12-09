local Logger = require("99.logger.logger")

local nsid = vim.api.nvim_create_namespace("99.marks")

--- @class _99.Mark.Text
--- @field text string
--- @field hlgroup string

--- @class _99.Mark
--- @field id any -- whatever extmark returns
--- @field buffer number
--- @field nsid any
local Mark = {}
Mark.__index = Mark

--- @param buffer number
--- @param func _99.treesitter.Function
function Mark.mark_func_body(buffer, func)
    local start = func.function_range.start
    local line, col = start:to_vim()
    local id = vim.api.nvim_buf_set_extmark(buffer, nsid, line, col, {})

    return setmetatable({
        id = id,
        buffer = buffer,
        nsid = nsid,
    }, Mark)
end

--- @param lines string[]
function Mark:set_virtual_text(lines)
    local pos =
        vim.api.nvim_buf_get_extmark_by_id(self.buffer, nsid, self.id, {})
    assert(#pos > 0, "extmark is broken.  it does not exist")
    local row, col = pos[1], pos[2]

    local formatted_lines = {}
    for _, line in ipairs(lines) do
        table.insert(formatted_lines, {
            { line, "Comment" },
        })
    end

    vim.api.nvim_buf_set_extmark(self.buffer, nsid, row, col, {
        id = self.id,
        virt_lines = formatted_lines,
    })
end

function Mark:delete()
    vim.api.nvim_buf_del_extmark(self.buffer, nsid, self.id)
end

return Mark
