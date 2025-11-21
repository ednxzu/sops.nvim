-- nvim_sops.lua - SOPS transparent encryption/decryption plugin
-- Entry point that sets up autocommands for YAML/JSON files

local nvim_sops = require('nvim_sops')

-- Create autocommand group for SOPS operations
local group = vim.api.nvim_create_augroup('NvimSops', { clear = true })

-- Decrypt SOPS files after reading
vim.api.nvim_create_autocmd('BufReadPost', {
  group = group,
  pattern = { '*.yaml', '*.yml', '*.json' },
  callback = function(args)
    nvim_sops.decrypt_buffer(args.buf)
  end,
  desc = 'Decrypt SOPS files on open',
})

-- Encrypt SOPS files before writing
vim.api.nvim_create_autocmd('BufWritePre', {
  group = group,
  pattern = { '*.yaml', '*.yml', '*.json' },
  callback = function(args)
    nvim_sops.encrypt_buffer(args.buf)
  end,
  desc = 'Encrypt SOPS files before save',
})

