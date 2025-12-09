local project_row = 100000000

--- @param point_or_row _99.Point | number
--- @param col number | nil
--- @return number
local function project(point_or_row, col)
    if type(point_or_row) == "number" then
        return point_or_row * project_row + col
    end
    return point_or_row.row * project_row + point_or_row.col
end

--- stores all values as 1 based
--- @class _99.Point
--- @field row number
--- @field col number
local Point = {}
Point.__index = Point

function Point:to_string()
    return string.format("point(%d,%d)", self.row, self.col)
end

--- @param buffer number
--- @return string
function Point:get_text_line(buffer)
    local r, _ = self:to_vim()
    return vim.api.nvim_buf_get_lines(buffer, r, r + 1, true)[1]
end

--- @param buffer number
--- @param text string
function Point:set_text_line(buffer, text)
    local r, _ = self:to_vim()
    vim.api.nvim_buf_set_lines(buffer, r, r + 1, false, { text })
end

function Point:update_to_end_of_line()
    self.col = vim.fn.col("$") + 1
    local r, c = self:to_one_zero_index()
    vim.api.nvim_win_set_cursor(0, { r, c })
end

--- @param buffer number
function Point:insert_new_line_below(buffer)
    vim.api.nvim_input("<esc>o")
end

--- 1 based point
--- @param row number
--- @param col number
--- @return _99.Point
function Point:new(row, col)
    assert(type(row) == "number", "expected row to be a number")
    assert(type(col) == "number", "expected col to be a number")
    return setmetatable({
        row = row,
        col = col,
    }, self)
end

function Point:from_cursor()
    local point = setmetatable({
        row = 0,
        col = 0,
    }, self)

    --- NOTE: win_get_cursor 1, 0 based return
    local cursor = vim.api.nvim_win_get_cursor(0)
    local cursor_row, cursor_col = cursor[1], cursor[2]
    point.row = cursor_row
    point.col = cursor_col + 1
    return point
end

--- @param ns_id string
---@param buffer number
---@param mark_id string
function Point.from_extmark(ns_id, buffer, mark_id)
    --- NOTE: get_extmark_by_id returns 0 based
    local row, col = vim.api.nvim_buf_get_extmark_by_id(buffer, ns_id, mark_id)
    return setmetatable({
        row = row + 1,
        col = col + 1,
    }, Point)
end

--- @param row number
---@param col number
--- @return _99.Point
function Point:from_ts_point(row, col)
    return setmetatable({
        row = row + 1,
        col = col + 1,
    }, self)
end

--- stores all 2 points
--- @param range _99.Range
--- @return boolean
function Point:in_ts_range(range)
    return range:contains(self)
end

--- vim.api.nvim_buf_get_text uses 0 based row and col
--- @return number, number
function Point:to_lua()
    return self.row, self.col
end

--- @return number, number
function Point:to_lsp()
    return self.row - 1, self.col - 1
end

--- vim.api.nvim_buf_get_text uses 0 based row and col
--- @return number, number
function Point:to_vim()
    return self.row - 1, self.col - 1
end

function Point:to_one_zero_index()
    return self.row, self.col - 1
end

--- treesitter uses 0 based row and col
--- @return number, number
function Point:to_ts()
    return self.row - 1, self.col - 1
end

--- @param point _99.Point
--- @return boolean
function Point:gt(point)
    return project(self) > project(point)
end

--- @param point _99.Point
--- @return boolean
function Point:lt(point)
    return project(self) < project(point)
end

--- @param point _99.Point
--- @return boolean
function Point:lte(point)
    return project(self) <= project(point)
end

--- @param point _99.Point
--- @return boolean
function Point:gte(point)
    return project(self) >= project(point)
end

--- @param point _99.Point
--- @return boolean
function Point:eq(point)
    return project(self) == project(point)
end

--- @param mark _99.Mark
--- @return _99.Point
function Point.from_mark(mark)
    --- buf extmark by id is a 0 based api
    local pos =
        vim.api.nvim_buf_get_extmark_by_id(mark.buffer, mark.nsid, mark.id, {})

    return setmetatable({
        row = pos[1] + 1,
        col = pos[2] + 1,
    }, Point)
end

--- @class _99.Range
--- @field start _99.Point
--- @field end_ _99.Point
--- @field buffer number
local Range = {}
Range.__index = Range

---@param buffer number
--- @param start _99.Point
---@param end_ _99.Point
function Range:new(buffer, start, end_)
    return setmetatable({
        start = start,
        end_ = end_,
        buffer = buffer,
    }, self)
end

---@param node _99.treesitter.TSNode
---@param buffer number
---@return _99.Range
function Range:from_ts_node(node, buffer)
    -- ts is zero based
    local start_row, start_col, _ = node:start()
    local end_row, end_col, _ = node:end_()
    local range = {
        start = Point:from_ts_point(start_row, start_col),
        end_ = Point:from_ts_point(end_row, end_col),
        buffer = buffer,
    }

    return setmetatable(range, self)
end

--- @param point _99.Point
--- @return boolean
function Range:contains(point)
    local start = project(self.start)
    local stop = project(self.end_)
    local p = project(point)
    return start <= p and p <= stop
end

--- @return string
function Range:to_text()
    local sr, sc = self.start:to_vim()
    local er, ec = self.end_:to_vim()

    -- note
    -- this api is 0 index end exclusive for _only_ column
    if ec == 0 then
        ec = -1
        er = er - 1
    end

    local text = vim.api.nvim_buf_get_text(self.buffer, sr, sc, er, ec, {})
    return table.concat(text, "\n")
end

--- @param range _99.Range
--- @return boolean
function Range:contains_range(range)
    return self.start:lte(range.start) and self.end_:gte(range.end_)
end

function Range:area()
    local start = project(self.start)
    local end_ = project(self.end_)
    return end_ - start
end

function Range:to_string()
    return string.format(
        "range(%s,%s)",
        self.start:to_string(),
        self.end_:to_string()
    )
end

return {
    Point = Point,
    Range = Range,
}
