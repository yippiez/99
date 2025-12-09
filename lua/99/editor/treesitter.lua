local geo = require("99.geo")
local Logger = require("99.logger.logger")
local Range = geo.Range
local Mark = require("99.ops.marks")

--- @class _99.treesitter.TSNode
--- @field start fun(): number
--- @field end_ fun(): number

--- @class _99.treesitter.Node
--- @field start fun(self: _99.treesitter.Node): number, number, number
--- @field end_ fun(self: _99.treesitter.Node): number, number, number
--- @field named fun(self: _99.treesitter.Node): boolean
--- @field type fun(self: _99.treesitter.Node): string
--- @field range fun(self: _99.treesitter.Node): number, number, number, number

local M = {}

local function_query = "99-function"
local imports_query = "99-imports"
local identifier_query = "99-identifier"

--- @param buffer number
---@param lang string
local function tree_root(buffer, lang)
    -- Load the parser and the query.
    local ok, parser = pcall(vim.treesitter.get_parser, buffer, lang)
    if not ok then
        return nil
    end

    local tree = parser:parse()[1]
    return tree:root()
end

--- @param buffer number
--- @param cursor _99.Point
--- @return _99.treesitter.Node | nil
function M.identifier(buffer, cursor)
    local lang = vim.bo[buffer].ft
    local root = tree_root(buffer, lang)
    if not root then
        Logger:error(
            "unable to find treeroot, this should never happen",
            "buffer",
            buffer,
            "lang",
            lang
        )
        return nil
    end

    local ok, query = pcall(vim.treesitter.query.get, lang, identifier_query)
    if not ok or query == nil then
        Logger:error(
            "unable to get the identifier_query",
            "lang",
            lang,
            "buffer",
            buffer,
            "ok",
            type(ok),
            "query",
            type(query)
        )
        return nil
    end

    --- likely something that needs to be done with treesitter#get_node
    local found = nil
    for _, match, _ in query:iter_matches(root, buffer, 0, -1, { all = true }) do
        for _, nodes in pairs(match) do
            for _, node in ipairs(nodes) do
                local range = Range:from_ts_node(node, buffer)
                if range:contains(cursor) then
                    found = node
                    goto end_of_loops
                end
            end
        end
    end
    ::end_of_loops::

    Logger:debug("treesitter#identifier", "found", found)

    return found
end

--- @class _99.treesitter.Function
--- @field function_range _99.Range
--- @field function_node _99.treesitter.Node
--- @field body_range _99.Range
--- @field body_node _99.treesitter.Node
local Function = {}
Function.__index = Function

--- @param ts_node _99.treesitter.TSNode
---@param lang string
---@param buffer number
---@param cursor _99.Point
---@return _99.treesitter.Function
function Function.from_ts_node(ts_node, lang, buffer, cursor)
    local ok, query = pcall(vim.treesitter.query.get, lang, function_query)
    if not ok or query == nil then
        Logger:fatal("not query or not ok")
        error("failed")
    end

    local func = {}
    for id, node, _ in
        query:iter_captures(ts_node, buffer, 0, -1, { all = true })
    do
        local range = Range:from_ts_node(node, buffer)
        local name = query.captures[id]
        if range:contains(cursor) then
            if name == "context.function" then
                func.function_node = node
                func.function_range = range
            elseif name == "context.body" then
                func.body_node = node
                func.body_range = range
            end
        end
    end

    -- Not all functions have bodies, example: function foo() end
    assert(func.function_node ~= nil, "function_node not found")
    assert(func.function_range ~= nil, "function_range not found")

    return setmetatable(func, Function)
end

--- @class _99.Scope
--- @field scope _99.treesitter.TSNode[]
--- @field range _99.Range[]
--- @field buffer number
--- @field cursor _99.Point
local Scope = {}
Scope.__index = Scope

--- @param cursor _99.Point
--- @param buffer number
--- @return _99.Scope
function Scope:new(cursor, buffer)
    return setmetatable({
        scope = {},
        range = {},
        buffer = buffer,
        cursor = cursor,
    }, self)
end

--- @return boolean
function Scope:has_scope()
    return #self.range > 0
end

--- @return _99.treesitter.TSNode | nil
function Scope:get_inner_scope()
    return self.scope[#self.scope]
end

--- @return _99.Range | nil
function Scope:get_inner_range()
    return self.range[#self.range]
end

--- @param node _99.treesitter.TSNode
function Scope:push(node)
    local range = Range:from_ts_node(node, self.buffer)
    if not range:contains(self.cursor) then
        return
    end

    table.insert(self.range, range)
    table.insert(self.scope, node)
end

function Scope:finalize()
    assert(#self.range == #self.scope, "range scope mismatch")
    table.sort(self.range, function(a, b)
        return a:contains_range(b)
    end)
end

--- @param buffer number
--- @param cursor _99.Point
--- @return _99.treesitter.Function?
function M.containing_function(buffer, cursor)
    local lang = vim.bo[buffer].ft
    local root = tree_root(buffer, lang)
    if not root then
        Logger:debug("LSP: could not find tree root")
        return nil
    end

    local ok, query = pcall(vim.treesitter.query.get, lang, function_query)
    if not ok or query == nil then
        Logger:debug(
            "LSP: not ok or query",
            "query",
            vim.inspect(query),
            "lang",
            lang,
            "ok",
            vim.inspect(ok)
        )
        return nil
    end

    --- @type _99.Range
    local found_range = nil
    local found_node = nil
    for id, node, _ in query:iter_captures(root, buffer, 0, -1, { all = true }) do
        local range = Range:from_ts_node(node, buffer)
        local name = query.captures[id]
        Logger:debug(
            "containing_function#capture",
            "range",
            range:to_string(),
            "name",
            name
        )
        if name == "context.function" and range:contains(cursor) then
            Logger:debug(
                "    containing_function#capture#found",
                "cursor",
                cursor:to_string(),
                "range",
                range:to_string()
            )
            if not found_range then
                found_range = range
                found_node = node
            elseif found_range:area() > range:area() then
                found_range = range
                found_node = node
            end
        end
        Logger:debug(
            "containing_function#capture finished loop",
            "found_range",
            found_range and found_range:to_string() or "found_range is nil"
        )
    end

    if not found_range then
        return nil
    end
    assert(found_node, "INVARIANT: found_range is not nil but found node is")

    ok, query = pcall(vim.treesitter.query.get, lang, function_query)
    if not ok or query == nil then
        Logger:fatal("INVARIANT: found_range ", "range", found_range:to_text())
        return
    end

    --- TODO: learn the diagnostics
    --- @type _99.treesitter.Function
    return Function.from_ts_node(found_node, lang, buffer, cursor)
end

--- @param cursor _99.Point
--- @param buffer number?
--- @return _99.Scope
function M.scopes(cursor, buffer)
    Logger:fatal("M.scopes not implemented")
    buffer = buffer or vim.api.nvim_get_current_buf()
    local scope = Scope:new(cursor, buffer)

    local lang = vim.bo[buffer].ft
    local root = tree_root(buffer, lang)
    if not root then
        Logger:debug("LSP: could not find tree root")
        return scope
    end

    local ok, query = pcall(vim.treesitter.query.get, lang, function_query)
    if not ok or query == nil then
        Logger:debug(
            "LSP: not ok or query",
            "query",
            vim.inspect(query),
            "lang",
            lang,
            "ok",
            vim.inspect(ok)
        )
        return scope
    end

    for id, node, _ in query:iter_captures(root, buffer, 0, -1, { all = true }) do
        local name = query.captures[id]
        if name == "context.scope" then
            scope:push(node)
        elseif name == "context.body" then
            -- scope:push(node)
        end
    end

    scope:finalize()

    return scope
end

--- @return _99.treesitter.Node[]
function M.imports()
    assert(false, "not implemented")
    local root = tree_root()
    if not root then
        return {}
    end

    local buffer = vim.api.nvim_get_current_buf()
    local ok, query = pcall(vim.treesitter.query.get, vim.bo.ft, imports_query)

    if not ok or query == nil then
        return {}
    end

    local imports = {}
    for _, match, _ in query:iter_matches(root, buffer, 0, -1, { all = true }) do
        for id, nodes in pairs(match) do
            local name = query.captures[id]
            if name == "import.name" then
                for _, node in ipairs(nodes) do
                    table.insert(imports, node)
                end
            end
        end
    end

    return imports
end

return M
