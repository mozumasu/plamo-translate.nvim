local M = {}

local config = require("plamo-translate.config")
local translate = require("plamo-translate.translate")
local ui = require("plamo-translate.ui")
local util = require("plamo-translate.util")
local virtual_text = require("plamo-translate.virtual_text")

---Translate current buffer content with paragraph splitting.
---Progress is reported through a single self-replacing notification; the
---handle is passed to on_complete so callers can reuse it for the final
---message.
---@param on_complete function Callback with (result, err, buf_info, progress)
---@return boolean success False if buffer is empty
local function translate_buffer_content(on_complete)
  local buf = vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local text = table.concat(lines, "\n")

  if text == "" then
    util.warn("Buffer is empty")
    return false
  end

  local buf_info = {
    buf = buf,
    filetype = vim.bo[buf].filetype,
    bufname = vim.fn.bufname(buf),
  }

  local paragraphs = translate.split_into_paragraphs(text)
  local progress = util.progress("plamo-translate-buffer")

  progress.update("Translating buffer...")

  translate.translate_paragraphs(paragraphs, function(current, total)
    progress.update(string.format("Translating buffer (%d/%d paragraphs)...", current, total))
  end, function(result, err)
    on_complete(result, err, buf_info, progress)
  end)

  return true
end

---Setup all plugin commands
function M.setup()
  -- PlamoTranslate: Interactive window (normal) or translate selection (visual).
  -- Optional argument "virtual" renders the result as virtual text below the
  -- selection, matching the PlamoTranslateComments format.
  vim.api.nvim_create_user_command("PlamoTranslate", function(args)
    local mode = (args.fargs[1] or ""):lower()
    if mode == "" then
      mode = (config.window.default_display or "popup"):lower()
    end

    if args.range > 0 then
      if mode == "virtual" then
        virtual_text.translate_range(nil, args.line1 - 1, args.line2 - 1)
        return
      end

      -- Visual mode: translate selection and show result
      local text = translate.get_visual_selection()
      if not text or text == "" then
        util.warn("No text selected")
        return
      end

      util.info("Translating...")
      translate.translate(text, function(result, err)
        if err then
          util.error("Translation failed: " .. err)
        elseif result then
          ui.show(result)
        end
      end)
    else
      -- Normal mode: open interactive window
      ui.show_interactive()
    end
  end, {
    range = true,
    nargs = "?",
    complete = function()
      return { "virtual", "popup" }
    end,
    desc = "Open translation window (normal) or translate selection (visual). Pass 'virtual' for virtual text format.",
  })

  -- PlamoTranslateReplace: Replace selected text with translation
  vim.api.nvim_create_user_command("PlamoTranslateReplace", function(args)
    -- Get the visual selection from the command range
    local buf = vim.api.nvim_get_current_buf()
    local start_line = args.line1
    local end_line = args.line2

    -- Get the actual text from the buffer using the range
    local lines = vim.api.nvim_buf_get_lines(buf, start_line - 1, end_line, false)
    local text = table.concat(lines, "\n")

    if not text or text == "" then
      util.warn("No text selected")
      return
    end

    local tick = vim.api.nvim_buf_get_changedtick(buf)

    util.info("Translating and replacing...")
    translate.translate(text, function(result, err)
      if err then
        util.error("Translation failed: " .. err)
        return
      end

      if result then
        if not vim.api.nvim_buf_is_valid(buf) then
          util.warn("Buffer was closed before translation finished")
          return
        end
        if vim.api.nvim_buf_get_changedtick(buf) ~= tick then
          util.warn("Buffer was modified during translation; replace aborted")
          return
        end
        -- Replace the selected text with translation
        local result_lines = vim.split(result, "\n")
        vim.api.nvim_buf_set_lines(buf, start_line - 1, end_line, false, result_lines)
        util.info("Text replaced with translation")
      end
    end)
  end, {
    range = true,
    desc = "Replace selected text with translation",
  })

  -- PlamoTranslateLine: Translate current line
  vim.api.nvim_create_user_command("PlamoTranslateLine", function()
    local line = vim.api.nvim_get_current_line()
    if not line or line == "" then
      util.warn("Current line is empty")
      return
    end

    util.info("Translating line...")
    translate.translate(line, function(result, err)
      if err then
        util.error("Translation failed: " .. err)
      elseif result then
        -- Show at cursor position
        ui.show(result, { position = "cursor" })
      end
    end)
  end, {
    desc = "Translate current line",
  })

  -- PlamoTranslateWord: Translate word under cursor
  vim.api.nvim_create_user_command("PlamoTranslateWord", function()
    -- Get word under cursor
    local word = vim.fn.expand("<cword>")
    if not word or word == "" then
      util.warn("No word under cursor")
      return
    end

    util.info("Translating word: " .. word)
    translate.translate(word, function(result, err)
      if err then
        util.error("Translation failed: " .. err)
      elseif result then
        -- Also show at cursor position
        ui.show(result, { position = "cursor" })
      end
    end)
  end, {
    desc = "Translate word under cursor",
  })

  -- PlamoTranslateClose: Close translation window
  vim.api.nvim_create_user_command("PlamoTranslateClose", function()
    ui.close()
  end, {
    desc = "Close translation window",
  })

  -- PlamoTranslateBuffer: Translate entire buffer and show in split window
  vim.api.nvim_create_user_command("PlamoTranslateBuffer", function()
    translate_buffer_content(function(result, err, buf_info, progress)
      if err then
        progress.update("Translation failed: " .. err, vim.log.levels.ERROR)
        return
      end

      if result then
        ui.show_split(result, {
          filetype = buf_info.filetype,
          original_name = buf_info.bufname,
        })
        progress.update("Buffer translated successfully")
      end
    end)
  end, {
    desc = "Translate entire buffer and show in split window",
  })

  -- PlamoTranslateBufferReplace: Replace entire buffer with translation
  vim.api.nvim_create_user_command("PlamoTranslateBufferReplace", function()
    local buf = vim.api.nvim_get_current_buf()

    -- Check if buffer is read-only
    if vim.bo[buf].readonly then
      util.error("Cannot replace: buffer is read-only")
      return
    end

    -- Save cursor position and change state before translation
    local cursor = vim.api.nvim_win_get_cursor(0)
    local tick = vim.api.nvim_buf_get_changedtick(buf)

    translate_buffer_content(function(result, err, buf_info, progress)
      if err then
        progress.update("Translation failed: " .. err, vim.log.levels.ERROR)
        return
      end

      if result then
        if not vim.api.nvim_buf_is_valid(buf_info.buf) then
          progress.update("Buffer was closed before translation finished", vim.log.levels.WARN)
          return
        end
        if vim.api.nvim_buf_get_changedtick(buf_info.buf) ~= tick then
          progress.update("Buffer was modified during translation; replace aborted", vim.log.levels.WARN)
          return
        end
        -- Replace buffer content (undo is automatically supported)
        local result_lines = vim.split(result, "\n")
        vim.api.nvim_buf_set_lines(buf_info.buf, 0, -1, false, result_lines)

        -- Restore cursor position (within bounds) in a window showing the buffer
        local win = vim.fn.bufwinid(buf_info.buf)
        if win ~= -1 then
          local new_cursor = {
            math.min(cursor[1], #result_lines),
            cursor[2],
          }
          pcall(vim.api.nvim_win_set_cursor, win, new_cursor)
        end

        progress.update("Buffer replaced with translation (undo available)")
      end
    end)
  end, {
    desc = "Replace entire buffer with translation",
  })

  -- PlamoTranslateComments: Translate English comments in current buffer and show as virtual text.
  -- With a visual selection, translate the selected lines and render the result
  -- as virtual text in the same format.
  vim.api.nvim_create_user_command("PlamoTranslateComments", function(args)
    if args.range > 0 then
      virtual_text.translate_range(nil, args.line1 - 1, args.line2 - 1)
    else
      virtual_text.translate_comments()
    end
  end, {
    range = true,
    desc = "Translate English comments (normal) or selected lines (visual) as virtual text",
  })

  -- PlamoTranslateCommentsClear: Clear virtual text translations
  vim.api.nvim_create_user_command("PlamoTranslateCommentsClear", function()
    virtual_text.clear()
  end, {
    desc = "Clear comment virtual text translations",
  })

  -- PlamoTranslateCommentsToggle: Toggle comment virtual text translations
  vim.api.nvim_create_user_command("PlamoTranslateCommentsToggle", function()
    virtual_text.toggle()
  end, {
    desc = "Toggle comment virtual text translations",
  })
end

return M
