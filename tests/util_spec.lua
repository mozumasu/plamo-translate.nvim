---@module 'luassert'

local Util = require("plamo-translate.util")

describe("util module", function()
  it("can be required", function()
    assert.truthy(Util)
  end)

  describe("notifications", function()
    local original_notify, original_schedule
    local called

    before_each(function()
      original_notify = vim.notify
      original_schedule = vim.schedule
      called = {}

      ---@diagnostic disable-next-line: duplicate-set-field
      vim.notify = function(msg, level, opts)
        table.insert(called, { msg = msg, level = level, opts = opts })
      end
      ---@diagnostic disable-next-line: duplicate-set-field
      vim.schedule = function(cb)
        cb()
      end
    end)

    after_each(function()
      vim.notify = original_notify
      vim.schedule = original_schedule
    end)

    it("shows error notification", function()
      Util.error("test error message")
      assert.are.same({
        {
          msg = "test error message",
          level = vim.log.levels.ERROR,
          opts = { title = "PlamoTranslate" },
        },
      }, called)
    end)

    it("shows warning notification", function()
      Util.warn("test warn message")
      assert.are.same({
        {
          msg = "test warn message",
          level = vim.log.levels.WARN,
          opts = { title = "PlamoTranslate" },
        },
      }, called)
    end)

    it("shows info notification", function()
      Util.info("test info message")
      assert.are.same({
        {
          msg = "test info message",
          level = vim.log.levels.INFO,
          opts = { title = "PlamoTranslate" },
        },
      }, called)
    end)
  end)

  describe("contains_japanese", function()
    it("detects hiragana", function()
      assert.is_true(Util.contains_japanese("これはテストです"))
      assert.is_true(Util.contains_japanese("mixed こんにちは text"))
    end)

    it("detects katakana", function()
      assert.is_true(Util.contains_japanese("カタカナ"))
    end)

    it("detects kanji", function()
      assert.is_true(Util.contains_japanese("翻訳"))
    end)

    it("returns false for pure ASCII", function()
      assert.is_false(Util.contains_japanese("Hello, World! 123"))
      assert.is_false(Util.contains_japanese(""))
    end)
  end)

  describe("strip_comment_markers", function()
    it("strips line comment markers", function()
      assert.are.equal("hello", Util.strip_comment_markers("// hello"))
      assert.are.equal("hello", Util.strip_comment_markers("# hello"))
      assert.are.equal("hello", Util.strip_comment_markers("-- hello"))
      assert.are.equal("hello", Util.strip_comment_markers("; hello"))
    end)

    it("strips block comment markers", function()
      assert.are.equal("hello", Util.strip_comment_markers("/* hello */"))
      assert.are.equal("hello", Util.strip_comment_markers("<!-- hello -->"))
    end)

    it("strips markers on each line of multiline comments", function()
      assert.are.equal("first\nsecond", Util.strip_comment_markers("-- first\n-- second"))
    end)

    it("removes leading and trailing blank lines", function()
      assert.are.equal("body", Util.strip_comment_markers("/*\n * body\n */"))
    end)
  end)

  describe("wrap_text", function()
    it("keeps short lines as is", function()
      assert.are.same({ "short line" }, Util.wrap_text("short line", 20))
    end)

    it("breaks at spaces", function()
      assert.are.same({ "aaa bbb", "ccc" }, Util.wrap_text("aaa bbb ccc", 8))
    end)

    it("breaks overlong words by character", function()
      assert.are.same({ "abcde", "fghij" }, Util.wrap_text("abcdefghij", 5))
    end)

    it("counts display width for multibyte characters", function()
      -- each character is 2 cells wide
      assert.are.same({ "ああ", "いい" }, Util.wrap_text("ああいい", 4))
    end)

    it("preserves existing newlines", function()
      assert.are.same({ "one", "two" }, Util.wrap_text("one\ntwo", 10))
    end)
  end)
end)
