R("99")

function foo() end

--- @param m _99.Mark
---@param count number
function done(m, count)
    local Logger = require("99.logger.logger")
    Logger:debug("done", "count", count)
    m:set_virtual_text({
        "deleting in " .. tostring(count)
    })
    if count <= 0 then
        m:delete()
        return
    end

    vim.defer_fn(function()
        done(m, count - 1)
    end, 500)
end

---@param m _99.Mark
--- @param lines string[]
---@param index number?
function write(m, lines, index)
    index = index or 1
    local Logger = require("99.logger.logger")
    Logger:debug("write", "index", index)

    if index > #lines then
        done(m, 5)
        return
    end

    vim.defer_fn(function()
        m:set_virtual_text({lines[index]})
        write(m, lines, index + 1)
    end, 500)
end

function create_mark()
    local Logger = require("99.logger.logger")
    local Level = require("99.logger.level")
    Logger:configure({
        level = Level.WARN,
        path = nil,
    })
    local buffer = vim.api.nvim_get_current_buf()
    local ts = require("99.editor.treesitter")
    local Mark = require("99.ops.marks")
    local Point = require("99.geo").Point

    Logger:info("getting containing function")
    local fn = ts.containing_function(buffer, Point:from_cursor())
    assert(fn, "could not find containing function")

    local _99 = require("99")
    local m = Mark.mark_func_body(_99.__get_state(), buffer, fn)

    write(m, {
        "hello, world",
        "",
        "this is the greatest text",
    })
end


create_mark()
