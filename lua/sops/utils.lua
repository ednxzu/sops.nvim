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

--- Execute a sops command interactively in a terminal, for operations that
--- may need to prompt on a TTY (e.g. age-plugin-yubikey asking for a PIN).
--- vim.fn.system() has no PTY, so such prompts can't be shown or answered.
---@param args table Command arguments for sops
---@param input string Input content to pass to sops
---@param callback function Called as callback(success, output) once the job exits
function M.execute_sops_interactive(args, input, callback)
	local tmpfile_in = vim.fn.tempname()
	local tmpfile_out = vim.fn.tempname()

	local f = io.open(tmpfile_in, "w")
	if not f then
		callback(false, "Failed to create temporary file")
		return
	end
	f:write(input)
	f:close()

	-- --output must be inserted before the positional filename argument:
	-- cobra (sops' CLI) only accepts flags before the first positional arg.
	local cmd = { "sops" }
	for _, arg in ipairs(args) do
		if arg == "/dev/stdin" then
			table.insert(cmd, "--output")
			table.insert(cmd, tmpfile_out)
			table.insert(cmd, tmpfile_in)
		else
			table.insert(cmd, arg)
		end
	end

	-- Link to DiagnosticInfo so the border matches the colorscheme's info/blue
	-- color, same as :messages info highlighting. `default = true` lets a user
	-- override it by setting SopsFloatBorder themselves.
	vim.api.nvim_set_hl(0, "SopsFloatBorder", { link = "DiagnosticInfo", default = true })

	local width = math.min(50, math.floor(vim.o.columns * 0.4))
	local height = 3
	local term_buf = vim.api.nvim_create_buf(false, true)
	local term_win = vim.api.nvim_open_win(term_buf, true, {
		relative = "editor",
		width = width,
		height = height,
		row = math.floor((vim.o.lines - height) / 2),
		col = math.floor((vim.o.columns - width) / 2),
		style = "minimal",
		border = "rounded",
		title = " 🔒 sops ",
		title_pos = "center",
	})
	vim.wo[term_win].winhighlight = "FloatBorder:SopsFloatBorder,FloatTitle:SopsFloatBorder"

	vim.fn.termopen(cmd, {
		on_exit = function(_, exit_code)
			local success = exit_code == 0
			local output = ""

			if success then
				local out = io.open(tmpfile_out, "r")
				if out then
					output = out:read("*a")
					out:close()
				else
					success = false
					output = "Failed to read sops output"
				end
			else
				local out = io.open(tmpfile_out, "r")
				if out then
					output = out:read("*a")
					out:close()
				end
				if output == "" then
					output = "sops exited with code " .. tostring(exit_code)
				end
			end

			os.remove(tmpfile_in)
			os.remove(tmpfile_out)

			vim.schedule(function()
				if vim.api.nvim_win_is_valid(term_win) then
					pcall(vim.api.nvim_win_close, term_win, true)
				end
				if vim.api.nvim_buf_is_valid(term_buf) then
					pcall(vim.api.nvim_buf_delete, term_buf, { force = true })
				end
				callback(success, output)
			end)
		end,
	})

	vim.cmd("startinsert")
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
