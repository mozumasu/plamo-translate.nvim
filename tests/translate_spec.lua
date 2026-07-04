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
    local original_jobstart, original_chansend, original_chanclose
    local original_notify, original_schedule

    local job_callbacks, jobstart_cmds, stdin_data, notify_calls

    before_each(function()
      original_jobstart = vim.fn.jobstart
      original_chansend = vim.fn.chansend
      original_chanclose = vim.fn.chanclose
      original_notify = vim.notify
      original_schedule = vim.schedule

      job_callbacks = {}
      jobstart_cmds = {}
      stdin_data = {}
      notify_calls = {}

      ---@diagnostic disable-next-line: duplicate-set-field
      vim.fn.jobstart = function(cmd, opts)
        table.insert(jobstart_cmds, cmd)
        job_callbacks = opts
        return 123
      end
      ---@diagnostic disable-next-line: duplicate-set-field
      vim.fn.chansend = function(job_id, data)
        table.insert(stdin_data, { job_id = job_id, data = data })
        return true
      end
      ---@diagnostic disable-next-line: duplicate-set-field
      vim.fn.chanclose = function(_, _) end
      ---@diagnostic disable-next-line: duplicate-set-field
      vim.schedule = function(cb)
        cb()
      end
      ---@diagnostic disable-next-line: duplicate-set-field
      vim.notify = function(msg, level, opts)
        table.insert(notify_calls, { msg = msg, level = level, opts = opts })
      end
    end)

    after_each(function()
      vim.fn.jobstart = original_jobstart
      vim.fn.chansend = original_chansend
      vim.fn.chanclose = original_chanclose
      vim.notify = original_notify
      vim.schedule = original_schedule
    end)

    it("translates text using plamo-translate CLI", function()
      local callback_called = false
      local translation_result = nil

      local job_id = Translate.translate("Hello World", function(result)
        callback_called = true
        translation_result = result
      end)

      assert.are.equal(123, job_id)
      assert.are.same({ { job_id = 123, data = "Hello World" } }, stdin_data)

      -- Channel semantics: chunks carry partial lines, "" is a line boundary
      job_callbacks.on_stdout(123, { "こんにちは世界", "" }, "stdout")
      job_callbacks.on_exit(123, 0, "exit")

      assert.is_true(callback_called)
      assert.are.equal("こんにちは世界", translation_result)
    end)

    it("reassembles multi-chunk output and preserves internal empty lines", function()
      local translation_result = nil
      Translate.translate("input", function(result)
        translation_result = result
      end)

      -- "line1\n\nline2 continued\n" delivered in two chunks split mid-line
      job_callbacks.on_stdout(123, { "line1", "", "line2 " }, "stdout")
      job_callbacks.on_stdout(123, { "continued", "" }, "stdout")
      job_callbacks.on_exit(123, 0, "exit")

      assert.are.equal("line1\n\nline2 continued", translation_result)
    end)

    it("passes English->Japanese direction for English input", function()
      Translate.translate("Hello", function() end)
      local cmd = jobstart_cmds[1]
      local args = table.concat(cmd, " ")
      assert.truthy(args:find("--from English", 1, true))
      assert.truthy(args:find("--to Japanese", 1, true))
    end)

    it("passes Japanese->English direction for Japanese input", function()
      Translate.translate("こんにちは", function() end)
      local cmd = jobstart_cmds[1]
      local args = table.concat(cmd, " ")
      assert.truthy(args:find("--from Japanese", 1, true))
      assert.truthy(args:find("--to English", 1, true))
    end)

    it("reports errors with stderr content on non-zero exit", function()
      local err_result
      Translate.translate("input", function(_, err)
        err_result = err
      end)

      job_callbacks.on_stderr(123, { "boom", "" }, "stderr")
      job_callbacks.on_exit(123, 1, "exit")

      assert.truthy(err_result:find("exit code: 1", 1, true))
      assert.truthy(err_result:find("boom", 1, true))
      assert.are.equal(vim.log.levels.ERROR, notify_calls[1].level)
    end)

    it("reports cancelled jobs silently", function()
      local original_jobstop = vim.fn.jobstop
      ---@diagnostic disable-next-line: duplicate-set-field
      vim.fn.jobstop = function(_)
        return 1
      end

      local err_result
      local job_id = Translate.translate("input", function(_, err)
        err_result = err
      end)

      Translate.cancel(job_id)
      job_callbacks.on_exit(123, 143, "exit")

      assert.are.equal("cancelled", err_result)
      assert.are.same({}, notify_calls)

      vim.fn.jobstop = original_jobstop
    end)
  end)

  describe("split_into_paragraphs", function()
    it("splits on blank lines and preserves them", function()
      local paragraphs = Translate.split_into_paragraphs("one\ntwo\n\nthree")
      assert.are.same({ "one\ntwo", "", "three" }, paragraphs)
    end)

    it("treats whitespace-only lines as blank", function()
      local paragraphs = Translate.split_into_paragraphs("one\n  \ntwo")
      assert.are.same({ "one", "", "two" }, paragraphs)
    end)

    it("returns single paragraph for text without blank lines", function()
      assert.are.same({ "a\nb\nc" }, Translate.split_into_paragraphs("a\nb\nc"))
    end)
  end)
end)
