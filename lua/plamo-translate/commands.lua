local M = {}

local translate = require("plamo-translate.translate")
local ui = require("plamo-translate.ui")
local util = require("plamo-translate.util")
local virtual_text = require("plamo-translate.virtual_text")

---Translate current buffer content with paragraph splitting
---@param on_complete function Callback with (result, err, buf_info)
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

  util.info("Translating buffer (0/" .. #paragraphs .. " paragraphs)...")

  translate.translate_paragraphs(
    paragraphs,
    function(current, total)
      util.info("Translating buffer (" .. current .. "/" .. total .. " paragraphs)...")
    end,
    function(result, err)
      on_complete(result, err, buf_info)
    end
  )

  return true
end

---Setup all plugin commands
function M.setup()
  -- PlamoTranslate: Interactive window (normal) or translate selection (visual)
  vim.api.nvim_create_user_command("PlamoTranslate", function(args)
    if args.range > 0 then
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
    desc = "Open translation window (normal) or translate selection (visual)",
  })

  -- PlamoTranslateReplace: Replace selected text with translation
  vim.api.nvim_create_user_command("PlamoTranslateReplace", function(args)
    -- Get the visual selection from the command range
    local start_line = args.line1
    local end_line = args.line2

    -- Get the actual text from the buffer using the range
    local lines = vim.api.nvim_buf_get_lines(0, start_line - 1, end_line, false)
    local text = table.concat(lines, "\n")

    if not text or text == "" then
      util.warn("No text selected")
      return
    end

    util.info("Translating and replacing...")
    translate.translate(text, function(result, err)
      if err then
        util.error("Translation failed: " .. err)
        return
      end

      if result then
        -- Replace the selected text with translation
        local result_lines = vim.split(result, "\n")
        vim.api.nvim_buf_set_lines(0, start_line - 1, end_line, false, result_lines)
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
    translate_buffer_content(function(result, err, buf_info)
      if err then
        util.error("Translation failed: " .. err)
        return
      end

      if result then
        ui.show_split(result, {
          filetype = buf_info.filetype,
          original_name = buf_info.bufname,
        })
        util.info("Buffer translated successfully")
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

    -- Save cursor position before translation
    local cursor = vim.api.nvim_win_get_cursor(0)

    translate_buffer_content(function(result, err, buf_info)
      if err then
        util.error("Translation failed: " .. err)
        return
      end

      if result then
        -- Replace buffer content (undo is automatically supported)
        local result_lines = vim.split(result, "\n")
        vim.api.nvim_buf_set_lines(buf_info.buf, 0, -1, false, result_lines)

        -- Restore cursor position (within bounds)
        local new_line_count = #result_lines
        local new_cursor = {
          math.min(cursor[1], new_line_count),
          cursor[2],
        }
        pcall(vim.api.nvim_win_set_cursor, 0, new_cursor)

        util.info("Buffer replaced with translation (undo available)")
      end
    end)
  end, {
    desc = "Replace entire buffer with translation",
  })

  -- PlamoTranslateComments: Translate English comments in current buffer and show as virtual text
  vim.api.nvim_create_user_command("PlamoTranslateComments", function()
    virtual_text.translate_comments()
  end, {
    desc = "Translate English comments in buffer as virtual text",
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

