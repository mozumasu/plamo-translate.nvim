local M = {}
local config = require("plamo-translate.config")
local util = require("plamo-translate.util")

-- State management
local state = {
  input_buf = nil,
  output_buf = nil,
  input_win = nil,
  output_win = nil,
}

---Create input and output windows
local function create_pane_windows()
  local cfg = config.window
  local positions = cfg.positions[cfg.position] or cfg.positions.center

  -- Get screen dimensions
  local vim_width = vim.o.columns
  local vim_height = vim.o.lines
  local total_width = math.floor(vim_width * positions.width)
  local total_height = math.floor(vim_height * positions.height)

  -- Calculate pane dimensions (split in half with gap)
  local gap = 2 -- Space between windows
  local pane_width = math.floor((total_width - gap) / 2)
  local pane_height = total_height

  -- Calculate base position (centered)
  local base_row = math.floor((vim_height - total_height) / 2)
  local base_col = math.floor((vim_width - total_width) / 2)

  -- Create input buffer and window (left side)
  state.input_buf = vim.api.nvim_create_buf(false, true)
  state.input_win = vim.api.nvim_open_win(state.input_buf, true, {
    relative = "editor",
    width = pane_width,
    height = pane_height,
    row = base_row,
    col = base_col,
    style = "minimal",
    border = cfg.border,
    title = " Input (Press <C-t> to translate) ",
    title_pos = "center",
  })

  -- Create output buffer and window (right side)
  state.output_buf = vim.api.nvim_create_buf(false, true)
  state.output_win = vim.api.nvim_open_win(state.output_buf, false, {
    relative = "editor",
    width = pane_width,
    height = pane_height,
    row = base_row,
    col = base_col + pane_width + gap, -- Position to the right with gap
    style = "minimal",
    border = cfg.border,
    title = " Translation ",
    title_pos = "center",
  })

  -- Set buffer options
  vim.bo[state.input_buf].buftype = "nofile"
  vim.bo[state.input_buf].bufhidden = "wipe"
  vim.bo[state.input_buf].filetype = "markdown"
  vim.bo[state.input_buf].modifiable = true

  vim.bo[state.output_buf].buftype = "nofile"
  vim.bo[state.output_buf].bufhidden = "wipe"
  vim.bo[state.output_buf].filetype = "markdown"
  vim.bo[state.output_buf].modifiable = true -- Keep modifiable for initial content

  -- Set window options for wrapping
  if cfg.wrap then
    vim.wo[state.input_win].wrap = true
    vim.wo[state.output_win].wrap = true
  end

  -- Start with empty buffers (no headers)
  -- Input buffer starts empty and editable
  vim.api.nvim_buf_set_lines(state.input_buf, 0, -1, false, { "" })

  -- Output buffer shows a subtle placeholder
  vim.api.nvim_buf_set_lines(state.output_buf, 0, -1, false, { "Waiting for input..." })
  vim.bo[state.output_buf].modifiable = false

  -- Position cursor at start of input buffer
  vim.api.nvim_win_set_cursor(state.input_win, { 1, 0 })
end

---Translate the content of input buffer
local function translate_input()
  if not state.input_buf or not vim.api.nvim_buf_is_valid(state.input_buf) then
    return
  end

  -- Dynamic require to avoid circular dependency
  local translate = require("plamo-translate.translate")

  -- Get all text from input buffer
  local lines = vim.api.nvim_buf_get_lines(state.input_buf, 0, -1, false)

  -- Remove empty lines from beginning and end, but preserve internal formatting
  while #lines > 0 and lines[1] == "" do
    table.remove(lines, 1)
  end
  while #lines > 0 and lines[#lines] == "" do
    table.remove(lines)
  end

  local text = table.concat(lines, "\n")

  if text == "" then
    util.warn("No text to translate")
    return
  end

  -- Show loading message
  vim.bo[state.output_buf].modifiable = true
  vim.api.nvim_buf_set_lines(state.output_buf, 0, -1, false, { "Translating..." })
  vim.bo[state.output_buf].modifiable = false

  -- Translate
  translate.translate(text, function(result, err)
    if not vim.api.nvim_buf_is_valid(state.output_buf) then
      return
    end

    vim.bo[state.output_buf].modifiable = true

    if err then
      vim.api.nvim_buf_set_lines(state.output_buf, 0, -1, false, { "Error: " .. tostring(err) })
    elseif result then
      -- Split result into lines
      local result_lines = vim.split(result, "\n")
      vim.api.nvim_buf_set_lines(state.output_buf, 0, -1, false, result_lines)
    else
      vim.api.nvim_buf_set_lines(state.output_buf, 0, -1, false, { "No translation result" })
    end

    vim.bo[state.output_buf].modifiable = false
  end)
end

---Set up key mappings for the translation window
local function setup_keymaps()
  -- Translate on Ctrl+T
  vim.api.nvim_buf_set_keymap(state.input_buf, "n", "<C-t>", "", {
    callback = translate_input,
    noremap = true,
    silent = true,
    desc = "Translate input text",
  })

  vim.api.nvim_buf_set_keymap(state.input_buf, "i", "<C-t>", "", {
    callback = translate_input,
    noremap = true,
    silent = true,
    desc = "Translate input text",
  })

  -- Close windows on Escape or q
  local close_callback = function()
    M.close()
  end

  for _, buf in ipairs({ state.input_buf, state.output_buf }) do
    if buf and vim.api.nvim_buf_is_valid(buf) then
      vim.api.nvim_buf_set_keymap(buf, "n", "<Esc>", "", {
        callback = close_callback,
        noremap = true,
        silent = true,
        desc = "Close translation window",
      })

      vim.api.nvim_buf_set_keymap(buf, "n", "q", "", {
        callback = close_callback,
        noremap = true,
        silent = true,
        desc = "Close translation window",
      })
    end
  end

  -- Switch between windows with Tab
  vim.api.nvim_buf_set_keymap(state.input_buf, "n", "<Tab>", "", {
    callback = function()
      if vim.api.nvim_win_is_valid(state.output_win) then
        vim.api.nvim_set_current_win(state.output_win)
      end
    end,
    noremap = true,
    silent = true,
    desc = "Switch to output window",
  })

  vim.api.nvim_buf_set_keymap(state.output_buf, "n", "<Tab>", "", {
    callback = function()
      if vim.api.nvim_win_is_valid(state.input_win) then
        vim.api.nvim_set_current_win(state.input_win)
      end
    end,
    noremap = true,
    silent = true,
    desc = "Switch to input window",
  })

  -- Copy text with y in both buffers
  vim.api.nvim_buf_set_keymap(state.input_buf, "n", "y", "", {
    callback = function()
      local lines = vim.api.nvim_buf_get_lines(state.input_buf, 0, -1, false) -- Get all text
      local result = table.concat(lines, "\n")
      vim.fn.setreg('"', result)
      vim.fn.setreg("+", result) -- Also copy to system clipboard
      util.info("Input text copied to clipboard")
    end,
    noremap = true,
    silent = true,
    desc = "Copy input text to clipboard",
  })

  vim.api.nvim_buf_set_keymap(state.output_buf, "n", "y", "", {
    callback = function()
      local lines = vim.api.nvim_buf_get_lines(state.output_buf, 0, -1, false) -- Get all text
      local result = table.concat(lines, "\n")
      vim.fn.setreg('"', result)
      vim.fn.setreg("+", result) -- Also copy to system clipboard
      util.info("Translation copied to clipboard")
    end,
    noremap = true,
    silent = true,
    desc = "Copy translation to clipboard",
  })
end

---Show the interactive translation window (for normal mode)
function M.show_interactive()
  -- Close existing windows if any
  M.close()

  -- Create windows and setup
  create_pane_windows()
  setup_keymaps()
end

---Show translation result directly (for visual mode)
---@param content string Content to display
---@param opts? table Optional display options (e.g., { position = "cursor" })
function M.show(content, opts)
  -- Close existing windows if any
  M.close()

  -- Merge options with config
  local cfg = vim.tbl_deep_extend("force", config.window, opts or {})
  local positions = cfg.positions[cfg.position] or cfg.positions.center

  -- Calculate window dimensions
  local vim_width = vim.o.columns
  local vim_height = vim.o.lines
  local width = math.floor(vim_width * positions.width * 0.6) -- Smaller for single pane
  local height = math.floor(vim_height * positions.height)

  -- Calculate position based on cfg.position
  local row, col
  if cfg.position == "cursor" then
    -- Position near cursor
    local screenrow = vim.fn.screenrow()
    local screencol = vim.fn.screencol()

    row = screenrow + 1
    col = screencol + 2

    -- Adjust if window would overflow
    if row + height > vim_height then
      row = math.max(0, screenrow - height - 1)
    end
    if col + width > vim_width then
      col = math.max(0, vim_width - width)
    end
  else
    -- Default to center
    row = math.floor((vim_height - height) / 2)
    col = math.floor((vim_width - width) / 2)
  end

  -- Create buffer
  local buf = vim.api.nvim_create_buf(false, true)
  state.output_buf = buf

  -- Set buffer options
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].filetype = "markdown"
  vim.bo[buf].modifiable = false

  -- Set content
  local lines = vim.split(content, "\n")
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false

  -- Create window
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = cfg.border,
    title = cfg.title or " Translation ",
    title_pos = cfg.title_pos or "center",
  })

  state.output_win = win

  -- Set window options
  vim.wo[win].wrap = cfg.wrap

  -- Set keymaps for closing
  vim.api.nvim_buf_set_keymap(buf, "n", "q", "", {
    callback = function()
      if vim.api.nvim_win_is_valid(win) then
        vim.api.nvim_win_close(win, true)
      end
      -- Clear state
      state.output_win = nil
      state.output_buf = nil
    end,
    noremap = true,
    silent = true,
    desc = "Close translation window",
  })

  vim.api.nvim_buf_set_keymap(buf, "n", "<Esc>", "", {
    callback = function()
      if vim.api.nvim_win_is_valid(win) then
        vim.api.nvim_win_close(win, true)
      end
      -- Clear state
      state.output_win = nil
      state.output_buf = nil
    end,
    noremap = true,
    silent = true,
    desc = "Close translation window",
  })

  -- Copy with y
  vim.api.nvim_buf_set_keymap(buf, "n", "y", "", {
    callback = function()
      local result_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
      local result = table.concat(result_lines, "\n")
      vim.fn.setreg('"', result)
      vim.fn.setreg("+", result) -- Also copy to system clipboard
      util.info("Translation copied to clipboard")
    end,
    noremap = true,
    silent = true,
    desc = "Copy translation to clipboard",
  })
end

---Close all translation windows
function M.close()
  for _, win in ipairs({ state.input_win, state.output_win }) do
    if win and vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end

  state.input_win = nil
  state.output_win = nil
  state.input_buf = nil
  state.output_buf = nil
end

---Check if window is open
---@return boolean
function M.is_open()
  return (state.input_win ~= nil and vim.api.nvim_win_is_valid(state.input_win))
    or (state.output_win ~= nil and vim.api.nvim_win_is_valid(state.output_win))
end

return M

