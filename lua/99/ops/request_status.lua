--- @class _99.RequestStatus
--- @field update_time number the milliseconds per update to the virtual text
--- @field status_line string
--- @field lines string[]
--- @field max_lines number
--- @field running boolean
--- @field mark _99.Mark?
local RequestStatus = {}
RequestStatus.__index = RequestStatus

--- @param update_time number
--- @param max_lines number
--- @param mark _99.Mark?
--- @return _99.RequestStatus
function RequestStatus.new(update_time, max_lines, mark)
    local self = setmetatable({}, RequestStatus)
    self.update_time = update_time
    self.max_lines = max_lines
    self.status_line = "⠋"
    self.lines = {}
    self.running = false
    self.mark = mark
    return self
end

--- @return string[]
function RequestStatus:get()
    local result = { self.status_line }
    for _, line in ipairs(self.lines) do
        table.insert(result, line)
    end
    return result
end

--- @param line string
function RequestStatus:push(line)
    table.insert(self.lines, line)
    if #self.lines > self.max_lines - 1 then
        table.remove(self.lines, 1)
    end
end

function RequestStatus:start()
    local braille_chars = {"⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"}
    local index = 0

    local function update_spinner()
        if not self.running then
            return
        end

        self.status_line = braille_chars[index % #braille_chars + 1]
        if self.mark then
            self.mark:set_virtual_text(self:get())
        end
        index = index + 1
        vim.defer_fn(update_spinner, self.update_time)
    end

    self.running = true
    update_spinner()
end

function RequestStatus:stop()
    self.running = false
end

return RequestStatus
