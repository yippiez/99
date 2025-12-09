local geo = require("99.geo")
local Point = geo.Point
local Logger = require("99.logger.logger")
local Request = require("99.request")
local Mark = require("99.ops.marks")
local Context = require("99.ops.context")
local editor = require("99.editor")
local RequestStatus = require("99.ops.request_status")

--- @param res string
--- @param location _99.Location
local function update_file_with_changes(res, location)
    local buffer = location.buffer
    local mark = location.marks.function_location

    assert(
        mark and buffer,
        "mark and buffer have to be set on the location object"
    )

    local func_start = Point.from_mark(mark)
    local ts = editor.treesitter
    local func = ts.containing_function(buffer, func_start)

    mark:delete()
    if not func then
        Logger:error(
            "update_file_with_changes: unable to find function at mark location"
        )
        error(
            "update_file_with_changes: funable to find function at mark location"
        )
        return
    end

    local range = func.function_range
    local function_start_row, _ = range.start:to_vim()
    local function_end_row, _ = range.end_:to_vim()

    local lines = vim.split(res, "\n")
    vim.api.nvim_buf_set_lines(
        buffer,
        function_start_row,
        function_end_row + 1,
        false,
        lines
    )
end

--- @param _99 _99.State
local function fill_in_function(_99)
    local ts = editor.treesitter
    local buffer = vim.api.nvim_get_current_buf()
    local cursor = Point:from_cursor()
    local func = ts.containing_function(buffer, cursor)

    if not func then
        Logger:fatal("fill_in_function: unable to find any containing function")
        return
    end

    local location =
        editor.Location.from_ts_node(func.function_node, func.function_range)
    local virt_line_count = _99.ai_stdout_rows
    if virt_line_count >= 0 then
        location.marks.function_location =
            Mark.mark_func_body(buffer, func)
    end

    local context = Context.new(_99):finalize(_99, location)
    local request = Request.new({
        provider = _99.provider_override,
        model = _99.model,
        context = context,
    })

    context:add_to_request(request)
    request:add_prompt_content(_99.prompts.prompts.fill_in_function)

    local request_status = RequestStatus.new(
        250,
        _99.ai_stdout_rows,
        location.marks.function_location
    )
    request_status:start()

    request:start({
        on_stdout = function(line)
            request_status:push(line)
        end,
        on_complete = function(ok, response)
            request_status:stop()
            if not ok then
                Logger:fatal(
                    "unable to fill in function, enable and check logger for more details"
                )
            end
            update_file_with_changes(response, location)
        end,
        on_stderr = function(line) end,
    })
end

return fill_in_function
