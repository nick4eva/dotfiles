-- First read our docs (completely) then check the example_config repo

local M = {}
local override = require("custom.override")

M.ui = {
  theme = "tokyonight",
}

M.plugins = {
  override = {
    ["kyazdani42/nvim-tree.lua"] = override.nvimtree,
  },
}

return M
