# plamo-translate.nvim

A Neovim plugin that integrates [plamo-translate-cli](https://github.com/pfnet/plamo-translate-cli) with Neovim

## Features

- **Interactive Translation Mode** (Normal mode)
- **Quick Translation** (Visual mode)
  - Select text and translate instantly
- **Replace selected text with translation**

## Installation

### Using lazy.nvim

```lua
{
  "mozumasu/plamo-translate.nvim",
  config = true,
  cmd = { "PlamoTranslate", "PlamoTranslateReplace", "PlamoTranslateLine", "PlamoTranslateWord" },
  keys = {
    -- Normal mode: interactive window
    { "<leader>tt", "<cmd>PlamoTranslate<cr>", mode = "n", desc = "Translate text (interactive)" },
    -- Visual mode: translate selection (:'<,'> preserves selection)
    { "<leader>tt", ":'<,'>PlamoTranslate<cr>", mode = "v", desc = "Translate selected text" },
    { "<leader>tr", ":'<,'>PlamoTranslateReplace<cr>", mode = "v", desc = "Replace with translation" },
    -- Normal mode: line and word
    { "<leader>tl", "<cmd>PlamoTranslateLine<cr>", mode = "n", desc = "Translate current line" },
    { "<leader>tw", "<cmd>PlamoTranslateWord<cr>", mode = "n", desc = "Translate word under cursor" },
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

- Neovim 0.8.0+
- [plamo-translate-cli](https://github.com/pfnet/plamo-translate-cli) installed and available in PATH
