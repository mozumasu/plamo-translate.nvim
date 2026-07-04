local M = {}

local translate = require("plamo-translate.translate")
local util = require("plamo-translate.util")

local ns = vim.api.nvim_create_namespace("plamo-translate-comments")
-- translate_range 由来の virtual text は自動更新の対象外なので namespace を分ける
local ns_range = vim.api.nvim_create_namespace("plamo-translate-range")

local HL_GROUP = "PlamoTranslateVirtual"

local uv = vim.uv or vim.loop

-- stripped text -> translation result
local cache = {}

---@type table<integer, { active: boolean, generation: integer, timer: uv_timer_t?, augroup: integer? }>
local state = {}

local REFRESH_DEBOUNCE_MS = 300

local function ensure_highlight()
  vim.api.nvim_set_hl(0, HL_GROUP, {
    link = "DiagnosticVirtualTextHint",
    default = true,
  })
end

ensure_highlight()
vim.api.nvim_create_autocmd("ColorScheme", {
  group = vim.api.nvim_create_augroup("PlamoTranslateVirtualText", { clear = true }),
  callback = ensure_highlight,
})

---Heuristic: text is "English" when it has no Japanese characters and contains alphabetic content
---@param text string
---@return boolean
local function is_english(text)
  if text == "" then
    return false
  end
  if util.contains_japanese(text) then
    return false
  end
  return text:find("[A-Za-z]") ~= nil
end

---Walk a syntax tree and collect comment nodes
---@param node TSNode
---@param buf integer
---@param results table
local function collect_comments(node, buf, results)
  local node_type = node:type() or ""
  if node_type:find("comment") then
    local sr, sc, er, ec = node:range()
    local ok, text = pcall(vim.treesitter.get_node_text, node, buf)
    if ok and text and text ~= "" then
      table.insert(results, {
        start_row = sr,
        start_col = sc,
        end_row = er,
        end_col = ec,
        text = text,
      })
    end
    return
  end
  for child in node:iter_children() do
    collect_comments(child, buf, results)
  end
end

---Find all comment ranges in the buffer via Treesitter
---@param buf integer
---@return table|nil ranges
---@return string|nil err
local function find_comment_ranges(buf)
  local ok, parser = pcall(vim.treesitter.get_parser, buf)
  if not ok or not parser then
    return nil, "Treesitter parser is not available for this buffer"
  end

  parser:parse()

  local results = {}
  parser:for_each_tree(function(tree)
    collect_comments(tree:root(), buf, results)
  end)

  return results, nil
end

---Render translation result as virtual text for one comment range
---@param buf integer
---@param namespace integer
---@param range table
---@param result string
local function render_translation(buf, namespace, range, result)
  if not vim.api.nvim_buf_is_valid(buf) then
    return
  end

  local win = vim.api.nvim_get_current_win()
  local win_width = vim.api.nvim_win_get_width(win)
  -- 行番号・サインカラム・フォールドカラム分を差し引いた実テキスト幅
  local info = vim.fn.getwininfo(win)
  local textoff = info and info[1] and info[1].textoff or 0
  -- prefix "» "(2文字) 分も引く
  local wrap_width = math.max(40, win_width - textoff - 2)

  local wrapped = util.wrap_text(result, wrap_width)

  local last_row = range.end_row
  if range.end_col == 0 and last_row > range.start_row then
    last_row = last_row - 1
  end
  local line_count = vim.api.nvim_buf_line_count(buf)
  if last_row >= line_count then
    last_row = line_count - 1
  end

  local virt_lines = {}
  for i, line in ipairs(wrapped) do
    local prefix = i == 1 and "» " or "  "
    table.insert(virt_lines, { { prefix .. line, HL_GROUP } })
  end
  vim.api.nvim_buf_set_extmark(buf, namespace, last_row, 0, {
    virt_lines = virt_lines,
  })
end

---Collect English comment groups (adjacent comment lines merged) in a buffer
---@param buf integer
---@return table|nil groups
---@return string|nil err
local function collect_english_groups(buf)
  local ranges, err = find_comment_ranges(buf)
  if err then
    return nil, err
  end

  table.sort(ranges, function(a, b)
    return a.start_row < b.start_row
  end)

  local groups = {}
  for _, range in ipairs(ranges) do
    local stripped = util.strip_comment_markers(range.text)
    if is_english(stripped) then
      local last = groups[#groups]
      if last and range.start_row <= last.end_row + 1 then
        last.end_row = math.max(last.end_row, range.end_row)
        last.end_col = range.end_col
        last.stripped = last.stripped .. "\n" .. stripped
      else
        table.insert(groups, {
          start_row = range.start_row,
          start_col = range.start_col,
          end_row = range.end_row,
          end_col = range.end_col,
          stripped = stripped,
        })
      end
    end
  end

  return groups, nil
end

---Render all groups: cached translations immediately, others via the CLI.
---Stale runs are cancelled through the per-buffer generation counter.
---@param buf integer
---@param groups table
---@param opts? { notify: boolean }
local function render_groups(buf, groups, opts)
  opts = opts or {}
  local st = state[buf]
  if not st then
    return
  end

  st.generation = st.generation + 1
  local gen = st.generation

  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)

  local pending = {}
  for _, group in ipairs(groups) do
    local cached = cache[group.stripped]
    if cached then
      render_translation(buf, ns, group, cached)
    else
      table.insert(pending, group)
    end
  end

  if #pending == 0 then
    if opts.notify then
      util.info("Comment translation complete")
    end
    return
  end

  if opts.notify then
    util.info(string.format("Translating %d comments...", #pending))
  end

  local index = 1

  local function is_stale()
    local current = state[buf]
    return not current or not current.active or current.generation ~= gen
  end

  local function translate_next()
    if is_stale() then
      return
    end
    if index > #pending then
      if opts.notify then
        util.info("Comment translation complete")
      end
      return
    end

    local group = pending[index]
    translate.translate(group.stripped, function(result, terr)
      vim.schedule(function()
        if is_stale() then
          return
        end
        if terr then
          util.warn("Skipped a comment due to error: " .. tostring(terr))
        elseif result and result ~= "" then
          cache[group.stripped] = result
          render_translation(buf, ns, group, result)
        end
        index = index + 1
        translate_next()
      end)
    end)
  end

  translate_next()
end

---Re-scan comments and re-render virtual text (deleted comments disappear,
---edited comments are re-translated, unchanged ones render from cache).
---@param buf integer
local function refresh(buf)
  local st = state[buf]
  if not st or not st.active or not vim.api.nvim_buf_is_valid(buf) then
    return
  end

  local groups = collect_english_groups(buf)
  if not groups then
    return
  end

  render_groups(buf, groups)
end

---Stop auto-refresh and drop per-buffer state
---@param buf integer
local function detach(buf)
  local st = state[buf]
  if not st then
    return
  end
  st.active = false
  if st.timer then
    st.timer:stop()
    if not st.timer:is_closing() then
      st.timer:close()
    end
  end
  if st.augroup then
    pcall(vim.api.nvim_del_augroup_by_id, st.augroup)
  end
  state[buf] = nil
end

---Start watching buffer edits to keep virtual text in sync
---@param buf integer
local function attach(buf)
  local st = state[buf]
  if st then
    st.active = true
    st.generation = st.generation + 1
    return
  end

  st = {
    active = true,
    generation = 0,
    timer = uv.new_timer(),
    augroup = vim.api.nvim_create_augroup("PlamoTranslateVirtualTextSync" .. buf, { clear = true }),
  }
  state[buf] = st

  vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
    group = st.augroup,
    buffer = buf,
    callback = function()
      local current = state[buf]
      if not current or not current.active then
        return
      end
      current.timer:stop()
      current.timer:start(
        REFRESH_DEBOUNCE_MS,
        0,
        vim.schedule_wrap(function()
          refresh(buf)
        end)
      )
    end,
  })

  vim.api.nvim_create_autocmd({ "BufDelete", "BufWipeout" }, {
    group = st.augroup,
    buffer = buf,
    callback = function()
      detach(buf)
    end,
  })
end

---Translate all English comments in a buffer and display results as virtual text.
---Keeps the virtual text in sync with later edits until M.clear() is called.
---@param buf? integer Defaults to current buffer
function M.translate_comments(buf)
  buf = buf or vim.api.nvim_get_current_buf()

  local groups, err = collect_english_groups(buf)
  if err then
    util.error(err)
    return
  end
  if not groups or #groups == 0 then
    util.info("No English comments found")
    return
  end

  attach(buf)
  render_groups(buf, groups, { notify = true })
end

---Translate the given line range and render the result as virtual text
---below the last selected line, using the same format as translate_comments.
---@param buf? integer Defaults to current buffer
---@param start_row integer 0-indexed start row (inclusive)
---@param end_row integer 0-indexed end row (inclusive)
function M.translate_range(buf, start_row, end_row)
  buf = buf or vim.api.nvim_get_current_buf()
  if not vim.api.nvim_buf_is_valid(buf) then
    return
  end

  local line_count = vim.api.nvim_buf_line_count(buf)
  if line_count == 0 then
    util.warn("Buffer is empty")
    return
  end
  if start_row < 0 then
    start_row = 0
  end
  if end_row >= line_count then
    end_row = line_count - 1
  end
  if end_row < start_row then
    util.warn("Invalid range")
    return
  end

  local lines = vim.api.nvim_buf_get_lines(buf, start_row, end_row + 1, false)
  local text = vim.trim(table.concat(lines, "\n"))
  if text == "" then
    util.warn("Selected lines are empty")
    return
  end

  vim.api.nvim_buf_clear_namespace(buf, ns_range, end_row, end_row + 1)

  util.info("Translating selection...")

  translate.translate(text, function(result, terr)
    vim.schedule(function()
      if terr then
        util.error("Translation failed: " .. tostring(terr))
      elseif result and result ~= "" then
        render_translation(buf, ns_range, {
          start_row = start_row,
          end_row = end_row,
          end_col = #(lines[#lines] or ""),
        }, result)
        util.info("Selection translation complete")
      end
    end)
  end)
end

---Clear all virtual text translations rendered by this module and stop
---the edit-sync for comment translations.
---@param buf? integer Defaults to current buffer
function M.clear(buf)
  buf = buf or vim.api.nvim_get_current_buf()
  if not vim.api.nvim_buf_is_valid(buf) then
    return
  end
  detach(buf)
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  vim.api.nvim_buf_clear_namespace(buf, ns_range, 0, -1)
  util.info("Cleared comment translations")
end

---Toggle: if extmarks exist clear them, otherwise translate.
---@param buf? integer Defaults to current buffer
function M.toggle(buf)
  buf = buf or vim.api.nvim_get_current_buf()
  if not vim.api.nvim_buf_is_valid(buf) then
    return
  end
  local st = state[buf]
  local existing = vim.api.nvim_buf_get_extmarks(buf, ns, 0, -1, {})
  local existing_range = vim.api.nvim_buf_get_extmarks(buf, ns_range, 0, -1, {})
  if (st and st.active) or #existing > 0 or #existing_range > 0 then
    M.clear(buf)
  else
    M.translate_comments(buf)
  end
end

return M
