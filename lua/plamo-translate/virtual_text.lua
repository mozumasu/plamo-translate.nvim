local M = {}

local translate = require("plamo-translate.translate")
local util = require("plamo-translate.util")

local ns = vim.api.nvim_create_namespace("plamo-translate-comments")

local HL_GROUP = "PlamoTranslateVirtual"

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

---Strip common comment markers (//, /*, #, --, ;, <!-- -->, """ etc.) from text
---@param text string
---@return string
local function strip_comment_markers(text)
  text = text:gsub("^/%*+", ""):gsub("%*+/$", "")
  text = text:gsub("^<!%-%-", ""):gsub("%-%->$", "")
  text = text:gsub('^"""', ""):gsub('"""$', "")
  text = text:gsub("^'''", ""):gsub("'''$", "")

  local lines = vim.split(text, "\n")
  for i, line in ipairs(lines) do
    lines[i] = line:gsub("^%s*([/#;%-%*]+)%s*", "")
  end

  while #lines > 0 and lines[1]:match("^%s*$") do
    table.remove(lines, 1)
  end
  while #lines > 0 and lines[#lines]:match("^%s*$") do
    table.remove(lines)
  end

  return vim.trim(table.concat(lines, "\n"))
end

---Heuristic: text is "English" when it has no Japanese characters and contains alphabetic content
---@param text string
---@return boolean
local function is_english(text)
  if text == "" then
    return false
  end
  local has_japanese = text:find("[\228-\233][\128-\191][\128-\191]") ~= nil
    or text:find("[\227][\129-\130][\128-\191]") ~= nil
    or text:find("[\227][\131][\128-\191]") ~= nil
  if has_japanese then
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

---Append chars from src into result lines, breaking when width exceeds max_width
---@param result string[]
---@param src string
---@param max_width integer
local function break_by_char(result, src, max_width)
  local current = ""
  -- iterate over UTF-8 characters
  for char in src:gmatch("[%z\1-\127\194-\253][\128-\191]*") do
    local candidate = current .. char
    if vim.fn.strdisplaywidth(candidate) <= max_width then
      current = candidate
    else
      if current ~= "" then
        table.insert(result, current)
      end
      current = char
    end
  end
  if current ~= "" then
    table.insert(result, current)
  end
end

---Wrap a string to fit within max_width, breaking at spaces then by character
---@param text string
---@param max_width integer
---@return string[]
local function wrap_text(text, max_width)
  local result = {}
  for _, line in ipairs(vim.split(text, "\n")) do
    if vim.fn.strdisplaywidth(line) <= max_width then
      table.insert(result, line)
    else
      local current = ""
      for _, word in ipairs(vim.split(line, " ")) do
        -- word itself is wider than max_width: break it by character
        if vim.fn.strdisplaywidth(word) > max_width then
          if current ~= "" then
            table.insert(result, current)
            current = ""
          end
          break_by_char(result, word, max_width)
        else
          local candidate = current == "" and word or (current .. " " .. word)
          if vim.fn.strdisplaywidth(candidate) <= max_width then
            current = candidate
          else
            if current ~= "" then
              table.insert(result, current)
            end
            current = word
          end
        end
      end
      if current ~= "" then
        table.insert(result, current)
      end
    end
  end
  return result
end

---Render translation result as virtual text for one comment range
---@param buf integer
---@param range table
---@param result string
local function render_translation(buf, range, result)
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

  local wrapped = wrap_text(result, wrap_width)

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
  vim.api.nvim_buf_set_extmark(buf, ns, last_row, 0, {
    virt_lines = virt_lines,
  })
end

---Translate all English comments in a buffer and display results as virtual text.
---@param buf? integer Defaults to current buffer
function M.translate_comments(buf)
  buf = buf or vim.api.nvim_get_current_buf()

  local ranges, err = find_comment_ranges(buf)
  if err then
    util.error(err)
    return
  end
  if not ranges or #ranges == 0 then
    util.info("No comments found in buffer")
    return
  end

  -- 隣接する行のコメントをグループにまとめる
  table.sort(ranges, function(a, b)
    return a.start_row < b.start_row
  end)

  local groups = {}
  for _, range in ipairs(ranges) do
    local stripped = strip_comment_markers(range.text)
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

  local targets = groups

  if #targets == 0 then
    util.info("No English comments found")
    return
  end

  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)

  util.info(string.format("Translating %d comments...", #targets))

  local index = 1

  local function translate_next()
    if index > #targets then
      util.info("Comment translation complete")
      return
    end

    local range = targets[index]
    translate.translate(range.stripped, function(result, terr)
      vim.schedule(function()
        if terr then
          util.warn("Skipped a comment due to error: " .. tostring(terr))
        elseif result and result ~= "" then
          render_translation(buf, range, result)
        end
        index = index + 1
        translate_next()
      end)
    end)
  end

  translate_next()
end

---Clear all virtual text translations rendered by this module.
---@param buf? integer Defaults to current buffer
function M.clear(buf)
  buf = buf or vim.api.nvim_get_current_buf()
  if not vim.api.nvim_buf_is_valid(buf) then
    return
  end
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  util.info("Cleared comment translations")
end

---Toggle: if extmarks exist clear them, otherwise translate.
---@param buf? integer Defaults to current buffer
function M.toggle(buf)
  buf = buf or vim.api.nvim_get_current_buf()
  if not vim.api.nvim_buf_is_valid(buf) then
    return
  end
  local existing = vim.api.nvim_buf_get_extmarks(buf, ns, 0, -1, {})
  if #existing > 0 then
    M.clear(buf)
  else
    M.translate_comments(buf)
  end
end

return M
