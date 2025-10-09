---@module 'luassert'

local Util = require("plamo-translate.util")

describe("util module", function()
  it("can be required", function()
    assert.truthy(Util)
  end)

  describe("error", function()
    it("shows error notification", function()
      local original_notify = vim.notify
      local original_schedule = vim.schedule

      -- Variable to log the call
      local called = {}

      -- Replace with mock function
      ---@diagnostic disable-next-line: duplicate-set-field -- Mock vim.notify for testing
      vim.notify = function(msg, level, opts)
        table.insert(called, { msg = msg, level = level, opts = opts })
      end

      ---@diagnostic disable-next-line: duplicate-set-field -- Mock vim.schedule for testing
      vim.schedule = function(cb)
        cb() -- Execute immediately (converts asynchronous to synchronous)
      end

      Util.error("test error message")
      assert.are.same({
        {
          msg = "test error message",
          level = vim.log.levels.ERROR,
          opts = { title = "PlamoTranslate" },
        },
      }, called)

      vim.notify = original_notify
      vim.schedule = original_schedule
    end)
  end)

  describe("warn", function()
    it("shows warning notification", function()
      local original_notify = vim.notify
      local original_schedule = vim.schedule

      local called = {}

      -- Replace with mock function
      ---@diagnostic disable-next-line: duplicate-set-field -- Mock vim.notify for testing
      vim.notify = function(msg, level, opts)
        table.insert(called, { msg = msg, level = level, opts = opts })
      end

      ---@diagnostic disable-next-line: duplicate-set-field -- Mock vim.schedule for testing
      vim.schedule = function(cb)
        cb()
      end

      Util.warn("test warn message")
      assert.are.same({
        {
          msg = "test warn message",
          level = vim.log.levels.WARN,
          opts = { title = "PlamoTranslate" },
        },
      }, called)

      vim.notify = original_notify
      vim.schedule = original_schedule
    end)
  end)

  describe("info", function()
    it("shows info notification", function()
      local original_notify = vim.notify
      local original_schedule = vim.schedule

      local called = {}

      -- Replace with mock function
      ---@diagnostic disable-next-line: duplicate-set-field -- Mock vim.notify for testing
      vim.notify = function(msg, level, opts)
        table.insert(called, { msg = msg, level = level, opts = opts })
      end

      ---@diagnostic disable-next-line: duplicate-set-field -- Mock vim.schedule for testing
      vim.schedule = function(cb)
        cb()
      end

      Util.info("test info message")
      assert.are.same({
        {
          msg = "test info message",
          level = vim.log.levels.INFO,
          opts = { title = "PlamoTranslate" },
        },
      }, called)

      vim.notify = original_notify
      vim.schedule = original_schedule
    end)
  end)
end)
