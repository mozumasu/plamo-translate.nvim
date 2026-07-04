# plamo-translate.nvim

A Neovim plugin that integrates [plamo-translate-cli](https://github.com/pfnet/plamo-translate-cli) with Neovim

## Features

- **Interactive Translation Mode** (Normal mode)
- **Quick Translation** (Visual mode)
  - Select text and translate instantly
- **Replace selected text with translation**
- **Inline Comment Translation** (Virtual text)
  - Detect English comments via Treesitter and render translations next to / below each comment

## Installation

### Using lazy.nvim

```lua
{
  "mozumasu/plamo-translate.nvim",
  config = true,
  cmd = {
    "PlamoTranslate",
    "PlamoTranslateReplace",
    "PlamoTranslateLine",
    "PlamoTranslateWord",
    "PlamoTranslateComments",
    "PlamoTranslateCommentsClear",
    "PlamoTranslateCommentsToggle",
  },
  keys = {
    -- Normal mode: interactive window
    { "<leader>tt", "<cmd>PlamoTranslate<cr>", mode = "n", desc = "Translate text (interactive)" },
    -- Visual mode: translate selection (:'<,'> preserves selection)
    { "<leader>tt", ":'<,'>PlamoTranslate<cr>", mode = "v", desc = "Translate selected text" },
    { "<leader>tr", ":'<,'>PlamoTranslateReplace<cr>", mode = "v", desc = "Replace with translation" },
    -- Normal mode: line and word
    { "<leader>tl", "<cmd>PlamoTranslateLine<cr>", mode = "n", desc = "Translate current line" },
    { "<leader>tw", "<cmd>PlamoTranslateWord<cr>", mode = "n", desc = "Translate word under cursor" },
    -- Translate English comments in buffer as virtual text (toggle)
    { "<leader>tv", "<cmd>PlamoTranslateCommentsToggle<cr>", mode = "n", desc = "Toggle comment translations" },
  },
}
```

## Usage

### Interactive Translation Window

When you run `:PlamoTranslate` in normal mode, a split-pane window opens:

**Left pane (Input):**

- Type or paste text you want to translate
- Press `<C-t>` to trigger translation
- Press `y` to copy input text to clipboard
- Fully editable

**Right pane (Output):**

- Shows translation results
- Press `y` to copy translation to clipboard
- Read-only

**Navigation:**

- `<Tab>` - Switch between input and output panes
- `y` - Copy current pane's text to clipboard (works in both panes)
- `<Esc>` or `q` - Close the translation window
- `<C-t>` - Translate the input text

### Translate Comments as Virtual Text

Translate English comments in the current buffer and render the translation as virtual text without modifying the file:

- `:PlamoTranslateComments` - Translate all English comments via Treesitter and display each translation as virtual text. Single-line comments are appended at end-of-line, multi-line comments are rendered as virtual lines below the comment block.
- `:PlamoTranslateCommentsClear` - Remove all virtual text translations.
- `:PlamoTranslateCommentsToggle` - Toggle on/off (default keymap: `<leader>tv`).

Requires a working Treesitter parser for the buffer's filetype.

Virtual text uses the highlight group `PlamoTranslateVirtual` (defaults to `DiagnosticVirtualTextHint`). To customize the color:

```lua
vim.api.nvim_set_hl(0, "PlamoTranslateVirtual", { fg = "#7aa2f7", italic = true })
```

### Configuration

> [!NOTE]
> The window options are currently under development.

```lua
require("plamo-translate").setup({
  cli = {
    cmd = { "plamo-translate", "--no-stream" }, -- CLI command
    from = "Auto",  -- Source language ("Auto" = auto detect)
    to = "Auto",    -- Target language ("Auto" = auto detect)
  },
  window = {
    position = "center",  -- "center" | "cursor" | "right"
    border = "rounded",   -- "single" | "double" | "rounded" | "solid" | "shadow"
    wrap = true,          -- Wrap long lines
    title = " Translation ",
    title_pos = "center", -- "left" | "center" | "right"
    positions = {
      center = {
        width = 0.8,  -- 80% of screen width
        height = 0.6, -- 60% of screen height
      },
      cursor = {
        width = 0.5,  -- Smaller, less intrusive
        height = 0.4,
      },
      right = {
        width = 0.4,  -- Sidebar width
        height = 1.0, -- Full height
      },
    },
  },
})
```

## Requirements

- Neovim 0.10.0+
- [plamo-translate-cli](https://github.com/pfnet/plamo-translate-cli) installed and available in PATH
