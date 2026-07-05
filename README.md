# plamo-translate.nvim

A Neovim plugin that integrates [plamo-translate-cli](https://github.com/pfnet/plamo-translate-cli) with Neovim

## Features

- **Interactive Translation Mode** (Normal mode)
- **Quick Translation** (Visual mode)
  - Select text and translate instantly, shown in a popup or as virtual text
- **Replace selected text with translation**
- **Inline Comment Translation** (Virtual text)
  - Detect English comments via Treesitter and render translations below each comment
  - Stays in sync while you edit: deleted comments lose their virtual text, edited comments are re-translated, unchanged ones re-render instantly from cache

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

### Translate Selection

With a visual selection, `:PlamoTranslate` translates the selected text and shows the result in a popup window. Pass `virtual` to render the result as virtual text below the selection instead:

```vim
:'<,'>PlamoTranslate virtual
```

The default display mode is configurable via `window.default_display` (`"popup"` or `"virtual"`).

### Translate Comments as Virtual Text

Translate English comments in the current buffer and render the translation as virtual text without modifying the file:

- `:PlamoTranslateComments` - Translate all English comments via Treesitter and render each translation as virtual lines below the comment. Consecutive comment lines are grouped and translated together.
- `:PlamoTranslateCommentsClear` - Remove all virtual text translations and stop the edit-sync.
- `:PlamoTranslateCommentsToggle` - Toggle on/off (default keymap: `<leader>tv`).

After `:PlamoTranslateComments`, the virtual text follows your edits automatically: deleting a comment removes its translation, editing a comment re-translates it, and unchanged comments re-render instantly from a translation cache without calling the CLI again.

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
    default_display = "popup", -- Visual-selection result: "popup" | "virtual"
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
