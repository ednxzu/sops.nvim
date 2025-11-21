-- sops.lua - SOPS transparent encryption/decryption plugin
-- Entry point that sets up user commands

local sops = require('sops')

-- Create user commands for manual encryption/decryption
vim.api.nvim_create_user_command('SopsDecrypt', function()
  sops.decrypt()
end, { desc = 'Manually decrypt current SOPS file' })

vim.api.nvim_create_user_command('SopsEncrypt', function()
  sops.encrypt()
end, { desc = 'Manually encrypt current SOPS file' })

