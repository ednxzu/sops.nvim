-- utils.lua - Helper functions for SOPS operations

local M = {}

--- Check if the sops command is available
---@return boolean
function M.has_sops()
	return vim.fn.executable("sops") == 1
end

--- Check if a buffer contains SOPS metadata
---@param bufnr number Buffer number
---@return boolean
function M.is_sops_file(bufnr)
	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	local content = table.concat(lines, "\n")

	-- Check for SOPS metadata in YAML or JSON format
	-- YAML: look for 'sops:' key
	-- JSON: look for '"sops":' key
	return content:match("sops:") ~= nil or content:match('"sops"%s*:') ~= nil
end

--- Execute a sops command with input
---@param args table Command arguments for sops
---@param input string Input content to pass to sops
---@return boolean success Whether the command succeeded
---@return string output The command output or error message
function M.execute_sops(args, input)
	-- Write input to a temporary file to avoid /dev/stdin issues with Neovim on Linux
	-- (Neovim does not provide /dev/stdin to subprocesses, see https://github.com/neovim/neovim/issues/14049)
	local tmpfile = vim.fn.tempname()
	local f = io.open(tmpfile, "w")
	if not f then
		return false, "Failed to create temporary file"
	end
	f:write(input)
	f:close()

	-- Build the command, replacing /dev/stdin with the temp file
	local cmd = { "sops" }
	for _, arg in ipairs(args) do
		if arg == "/dev/stdin" then
			table.insert(cmd, tmpfile)
		else
			table.insert(cmd, arg)
		end
	end

	local result = vim.fn.system(cmd)
	local success = vim.v.shell_error == 0

	os.remove(tmpfile)

	return success, result
end

--- Get the file extension to determine format
---@param bufnr number Buffer number
---@return string format Either 'yaml' or 'json'
function M.get_file_format(bufnr)
	local filename = vim.api.nvim_buf_get_name(bufnr)
	local ext = filename:match("%.([^.]+)$")

	if ext == "json" then
		return "json"
	else
		return "yaml"
	end
end

return M
