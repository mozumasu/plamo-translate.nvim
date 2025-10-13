local M = {}

---Setup all plugin commands
function M.setup()
  local translate = require("plamo-translate.translate")
  local ui = require("plamo-translate.ui")
  local util = require("plamo-translate.util")

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
end

return M

