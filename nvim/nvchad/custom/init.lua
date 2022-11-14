--vim.cmd [[ autocmd BufWritePre * vim.lsp.buf.format({ bufnr = bufnr }) ]]

local opt = vim.opt

opt.relativenumber = true
opt.noswapfile = true
