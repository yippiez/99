---@module "plenary.busted"

-- luacheck: globals describe it assert
local _99 = require("99")
local test_utils = require("99.test.test_utils")
local Levels = require("99.logger.level")
local eq = assert.are.same

--- @param content string[]
--- @param row number
--- @param col number
--- @param lang string?
--- @return _99.test.Provider, number
local function setup(content, row, col, lang)
  assert(lang, "lang must be provided")
  local provider = test_utils.TestProvider.new()
  _99.setup({
    provider = provider,
    logger = {
      error_cache_level = Levels.ERROR,
      type = "print",
    },
  })

  local buffer = test_utils.create_file(content, lang, row, col)
  return provider, buffer
end

--- @param buffer number
--- @return string[]
local function read(buffer)
  return vim.api.nvim_buf_get_lines(buffer, 0, -1, false)
end

describe("fill_in_function", function()
  it("fill in haskell function", function()
    local haskell_content = {
      "",
      "factorial :: Int -> Int",
      "factorial n = undefined",
    }
    local provider, buffer = setup(haskell_content, 2, 0, "haskell")
    local state = _99.__get_state()

    _99.fill_in_function()

    eq(1, state:active_request_count())
    eq(haskell_content, read(buffer))

    provider:resolve("success", "factorial :: Int -> Int\nfactorial n = if n <= 1 then 1 else n * factorial (n - 1)")
    test_utils.next_frame()

    local expected_state = {
      "",
      "factorial :: Int -> Int",
      "factorial n = if n <= 1 then 1 else n * factorial (n - 1)",
    }
    eq(expected_state, read(buffer))
    eq(0, state:active_request_count())
  end)

  it("fill in haskell function with pattern matching", function()
    local haskell_content = {
      "",
      "fib :: Int -> Int",
      "fib 0 = undefined",
      "fib 1 = undefined",
      "fib n = undefined",
    }
    local provider, buffer = setup(haskell_content, 2, 0, "haskell")
    local state = _99.__get_state()

    _99.fill_in_function()

    eq(1, state:active_request_count())
    eq(haskell_content, read(buffer))

    provider:resolve("success", "fib :: Int -> Int\nfib 0 = 0\nfib 1 = 1\nfib n = fib (n - 1) + fib (n - 2)")
    test_utils.next_frame()

    local expected_state = {
      "",
      "fib :: Int -> Int",
      "fib 0 = 0",
      "fib 1 = 1",
      "fib n = fib (n - 1) + fib (n - 2)",
    }
    eq(expected_state, read(buffer))
    eq(0, state:active_request_count())
  end)
end)
