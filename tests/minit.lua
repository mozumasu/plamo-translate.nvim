#!/usr/bin/env -S nvim -l

-- Test environment configuration
vim.env.LAZY_STDPATH = ".tests"

-- Cache the lazy.nvim bootstrap locally so tests run offline after the first fetch
local bootstrap_path = ".tests/bootstrap.lua"
local stat = (vim.uv or vim.loop).fs_stat(bootstrap_path)
if not stat or stat.size == 0 then
  vim.fn.mkdir(".tests", "p")
  vim.fn.system({
    "curl",
    "-s",
    "-o",
    bootstrap_path,
    "https://raw.githubusercontent.com/folke/lazy.nvim/main/bootstrap.lua",
  })
  stat = (vim.uv or vim.loop).fs_stat(bootstrap_path)
  if not stat or stat.size == 0 then
    error("Failed to download lazy.nvim bootstrap (network unavailable?)")
  end
end
dofile(bootstrap_path)

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
