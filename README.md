# plamo-translate.nvim

A Neovim plugin that integrates [plamo-translate-cli](https://github.com/pfnet/plamo-translate-cli) with Neovim

## Features

- Translate selected text asynchronously
- Configure behavior via setup options
- Show results in a floating window
- Replace the selection with the translation

## Installation

```lua
{
  "mozumasu/plamo-translate.nvim",
  config = true,
  keys = {
    { "<leader>t", nil, desc = "PlamoTranslate" },
    { "<leader>tp", "<cmd>PlamoTranslate<cr>", desc = "Translate and show in floating window" },
    { "<leader>trp", "<cmd>PlamoTranslateReplace<cr>", desc = "Translate and replace selection" },
  },
}
