local util = require("dotfiles.util")
local Snacks = require("snacks")

require("gitsigns").setup({
	numhl = true,
})

local function close_file_explorer()
	local explorer = Snacks.picker.get({ source = "explorer" })[1]
	if explorer and not explorer.closed then
		explorer:close()
	end
end

local function get_git_root()
	local lines = vim.fn.systemlist({ "git", "rev-parse", "--show-toplevel" })
	if vim.v.shell_error ~= 0 or not lines[1] or lines[1] == "" then
		vim.notify(table.concat(lines, "\n"), vim.log.levels.ERROR, { title = "Git" })
		return nil
	end

	return lines[1]
end

local function read_git_file(cwd, file)
	local lines = vim.fn.systemlist({ "git", "-C", cwd, "show", "HEAD:" .. file })
	if vim.v.shell_error ~= 0 then
		return {}
	end

	return lines
end

local function read_worktree_file(cwd, file)
	local ok, lines = pcall(vim.fn.readfile, cwd .. "/" .. file)
	if not ok then
		return {}
	end

	return lines
end

local function changed_filetype(file)
	local ok, filetype = pcall(vim.filetype.match, { filename = file })
	if ok and filetype then
		return filetype
	end

	return ""
end

local function set_scratch_diff_buffer(name, lines, filetype)
	local buffer = vim.api.nvim_get_current_buf()
	local unique_name = name
	if vim.fn.bufexists(unique_name) == 1 then
		unique_name = unique_name .. "#" .. tostring(vim.uv.hrtime())
	end

	vim.bo[buffer].buftype = "nofile"
	vim.bo[buffer].bufhidden = "wipe"
	vim.bo[buffer].swapfile = false
	vim.bo[buffer].modifiable = true
	pcall(vim.api.nvim_buf_set_name, buffer, unique_name)
	vim.api.nvim_buf_set_lines(buffer, 0, -1, false, #lines > 0 and lines or { "" })
	vim.bo[buffer].filetype = filetype
	vim.bo[buffer].readonly = true
	vim.bo[buffer].modifiable = false
end

local function open_changed_file_diff(picker, item)
	item = item or picker:current()
	if not item or not item.file then
		return
	end

	local cwd = item.cwd or get_git_root()
	if not cwd then
		return
	end

	local file = item.file
	local old_file = item.rename or file
	local filetype = changed_filetype(file)
	local old_lines = read_git_file(cwd, old_file)
	local worktree_lines = read_worktree_file(cwd, file)

	picker:close()

	vim.cmd("enew")
	set_scratch_diff_buffer("WORKTREE:" .. file, worktree_lines, filetype)

	local worktree_win = vim.api.nvim_get_current_win()
	vim.cmd("leftabove vertical new")
	set_scratch_diff_buffer("HEAD:" .. old_file, old_lines, filetype)

	vim.cmd("diffthis")
	vim.api.nvim_set_current_win(worktree_win)
	vim.cmd("diffthis")
	vim.cmd("normal! gg")
end

local function open_changed_files_explorer()
	close_file_explorer()
	Snacks.picker.git_status({
		title = "Changed files",
		show_empty = true,
		actions = {
			confirm = open_changed_file_diff,
		},
		layout = {
			preset = "sidebar",
			preview = false,
			layout = {
				position = "left",
				width = 42,
			},
		},
	})
end

util.map("n", "<leader>gs", function()
	Snacks.picker.git_status({ show_empty = true })
end, "Git status")
util.map("n", "<leader>gd", function()
	Snacks.picker.git_diff({ show_empty = true })
end, "Git diff")
vim.api.nvim_create_user_command("GitChangedFiles", open_changed_files_explorer, { desc = "Show changed files diff" })
util.map("n", "<leader>ge", open_changed_files_explorer, "Changed files diff")
util.map("n", "<leader>gg", function()
	vim.fn.mkdir(vim.fn.stdpath("cache"), "p")
	vim.cmd("silent! wall")
	Snacks.lazygit({
		config = {
			gui = {
				mainPanelSplitMode = "flexible",
				portraitMode = "never",
				sidePanelWidth = 0.28,
			},
		},
		win = {
			position = "right",
			width = 0.50,
		},
	})
end, "LazyGit")
