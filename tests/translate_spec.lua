---@module 'luassert'

local Translate = require("plamo-translate.translate")

describe("translate module", function()
  it("can be required", function()
    assert.truthy(Translate)
  end)

  describe("get_visual_selection", function()
    it("returns selected text from visual mode", function()
      local original_getregion = vim.fn.getregion

      ---@diagnostic disable-next-line: duplicate-set-field
      vim.fn.getregion = function(_, _, _)
        return { "Hello", "World" }
      end

      local result = Translate.get_visual_selection()
      assert.are.equal("Hello\nWorld", result)

      vim.fn.getregion = original_getregion
    end)
  end)

  describe("translate", function()
    it("translates text using plamo-translate CLI", function()
      -- Test translation using plamo-translate CLI
      local original_jobstart = vim.fn.jobstart
      local original_chansend = vim.fn.chansend
      local original_chanclose = vim.fn.chanclose
      local original_notify = vim.notify
      local original_schedule = vim.schedule

      local job_callbacks = {}
      local notify_calls = {}
      local stdin_data = {}

      -- Mock vim.fn.jobstart (simulate async processing)
      ---@diagnostic disable-next-line: duplicate-set-field
      vim.fn.jobstart = function(_, opts)
        job_callbacks = opts
        return 123 -- job ID
      end

      -- Mock vim.fn.chansend and vim.fn.chanclose
      ---@diagnostic disable-next-line: duplicate-set-field
      vim.fn.chansend = function(job_id, data)
        table.insert(stdin_data, { job_id = job_id, data = data })
        return true
      end

      ---@diagnostic disable-next-line: duplicate-set-field
      vim.fn.chanclose = function(_, _)
        -- Do nothing (mock)
      end

      -- Mock vim.notify and vim.schedule
      ---@diagnostic disable-next-line: duplicate-set-field
      vim.schedule = function(cb)
        cb()
      end
      ---@diagnostic disable-next-line: duplicate-set-field
      vim.notify = function(msg, level, opts)
        table.insert(notify_calls, { msg = msg, level = level, opts = opts })
      end

      -- Execute translation
      local callback_called = false
      local translation_result = nil

      Translate.translate("Hello World", function(result)
        callback_called = true
        translation_result = result
      end)

      -- Verify stdin data was sent
      assert.are.same({ { job_id = 123, data = "Hello World" } }, stdin_data)

      -- Simulate output from CLI
      job_callbacks.on_stdout(123, { "こんにちは世界" }, "stdout")
      job_callbacks.on_exit(123, 0, "exit")

      -- Verify results
      assert.is_true(callback_called)
      assert.are.equal("こんにちは世界", translation_result)

      -- Restore mocks
      vim.fn.jobstart = original_jobstart
      vim.fn.chansend = original_chansend
      vim.fn.chanclose = original_chanclose
      vim.notify = original_notify
      vim.schedule = original_schedule
    end)
  end)
end)
