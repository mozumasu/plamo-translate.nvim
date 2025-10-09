#!/usr/bin/env -S nvim -l

-- Test environment configuration
vim.env.LAZY_STDPATH = ".tests"
load(vim.fn.system("curl -s https://raw.githubusercontent.com/folke/lazy.nvim/main/bootstrap.lua"))()

-- Setting up plugins in lazy.nvim
require("lazy.minit").setup({
  spec = {
    {
      dir = vim.uv.cwd(), -- Current directory (plamo-translate.nvim)
      opts = {}, -- Options table
    },
    { "nvim-lua/plenary.nvim" }, -- Testing framework
  },
})

-- Add the plugin path to the runtimepath
vim.opt.rtp:append(vim.fn.stdpath("data") .. "/site")
