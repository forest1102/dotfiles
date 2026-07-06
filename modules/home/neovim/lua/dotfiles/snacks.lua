local util = require("dotfiles.util")
local Snacks = require("snacks")

local function close_current_view()
	local win = vim.api.nvim_get_current_win()
	local ok, config = pcall(vim.api.nvim_win_get_config, win)
	if ok and config.relative ~= "" then
		vim.api.nvim_win_close(win, true)
		return
	end

	if #vim.api.nvim_tabpage_list_wins(0) > 1 then
		vim.cmd("quit")
		return
	end

	local force = vim.bo.buftype ~= ""
	vim.cmd(force and "bdelete!" or "bdelete")
end

local function git_diff_view_window()
	local fallback = nil

	for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
		local ok, is_diff_view = pcall(vim.api.nvim_win_get_var, win, "dotfiles_git_diff_view")
		local _, role = pcall(vim.api.nvim_win_get_var, win, "dotfiles_git_diff_role")
		if not ok or not is_diff_view then
			local buffer = vim.api.nvim_win_get_buf(win)
			ok, is_diff_view = pcall(vim.api.nvim_buf_get_var, buffer, "dotfiles_git_diff_view")
			_, role = pcall(vim.api.nvim_buf_get_var, buffer, "dotfiles_git_diff_role")
		end

		if ok and is_diff_view then
			if role == "worktree" then
				return win
			end
			fallback = fallback or win
		end
	end

	return fallback
end

local function focus_git_diff_view()
	local win = git_diff_view_window()
	if not win then
		return false
	end

	vim.api.nvim_set_current_win(win)
	return true
end

local function changed_files_explorer()
	for _, picker in ipairs(Snacks.picker.get({})) do
		if picker.opts.title == "Changed files" then
			return picker
		end
	end
end

local function picker_has_window(picker, target)
	for _, win in pairs(picker.layout.wins or {}) do
		if win.win == target then
			return true
		end
	end

	return false
end

local function focus_changed_files_explorer(picker)
	if not picker or picker.closed then
		return false
	end

	picker:focus("list", { show = true })
	return true
end

local function is_current_git_diff_view()
	local current = vim.api.nvim_get_current_win()
	local ok, is_diff_view = pcall(vim.api.nvim_win_get_var, current, "dotfiles_git_diff_view")
	if ok and is_diff_view then
		return true
	end

	local buffer = vim.api.nvim_win_get_buf(current)
	ok, is_diff_view = pcall(vim.api.nvim_buf_get_var, buffer, "dotfiles_git_diff_view")
	return ok and is_diff_view
end

local function is_file_explorer_focused()
	local current = vim.api.nvim_get_current_win()

	for _, picker in ipairs(Snacks.picker.get({ source = "explorer" })) do
		for _, win in pairs(picker.layout.wins or {}) do
			if win.win == current then
				return true
			end
		end
	end

	return false
end

local function is_window_in_picker(picker, target)
	if not picker then
		return false
	end

	for _, win in pairs(picker.layout.wins or {}) do
		if win.win == target then
			return true
		end
	end

	return false
end

local function is_explorer_window(win)
	local changed_files = changed_files_explorer()
	if is_window_in_picker(changed_files, win) then
		return true
	end

	for _, picker in ipairs(Snacks.picker.get({ source = "explorer" })) do
		if is_window_in_picker(picker, win) then
			return true
		end
	end

	return false
end

local function is_current_explorer_window()
	return is_explorer_window(vim.api.nvim_get_current_win())
end

local function close_file_explorer_if_open()
	for _, picker in ipairs(Snacks.picker.get({ source = "explorer" })) do
		if not picker.closed then
			picker:close()
			return true
		end
	end

	return false
end

local function close_changed_files_explorer_if_open()
	pcall(vim.cmd, "GitChangedFilesClose")
end

local function focus_folder_explorer()
	local explorer = Snacks.picker.get({ source = "explorer" })[1]
	if not explorer or explorer.closed then
		return false
	end

	explorer:focus("list", { show = true })
	return true
end

local function open_folder_explorer_only()
	close_changed_files_explorer_if_open()
	local explorer = Snacks.picker.get({ source = "explorer" })[1]
	if explorer and not explorer.closed then
		explorer:focus("list", { show = true })
	else
		Snacks.explorer()
	end
end

local function focus_file_window()
	if focus_git_diff_view() then
		return true
	end

	local current = vim.api.nvim_get_current_win()
	for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
		local ok, config = pcall(vim.api.nvim_win_get_config, win)
		local buffer = vim.api.nvim_win_get_buf(win)
		if ok and config.relative == "" and win ~= current and not is_explorer_window(win) and vim.bo[buffer].buftype == "" then
			vim.api.nvim_set_current_win(win)
			return true
		end
	end

	vim.cmd("wincmd p")
	return true
end

local function focus_current_explorer()
	local changed_files = changed_files_explorer()
	if changed_files then
		if is_current_git_diff_view() or picker_has_window(changed_files, vim.api.nvim_get_current_win()) then
			focus_changed_files_explorer(changed_files)
			return true
		end

		if not is_file_explorer_focused() then
			focus_changed_files_explorer(changed_files)
			return true
		end
	end

	open_folder_explorer_only()
	return true
end

local function toggle_focus_current_explorer()
	if is_current_explorer_window() then
		focus_file_window()
		return
	end

	focus_current_explorer()
end

vim.api.nvim_create_autocmd("FileType", {
	pattern = { "snacks_*", "trouble" },
	command = "setlocal nonumber norelativenumber signcolumn=no foldcolumn=0",
})
vim.api.nvim_create_autocmd("TermOpen", {
	command = "setlocal nonumber norelativenumber signcolumn=no foldcolumn=0",
})

Snacks.setup({
	explorer = { enabled = true, replace_netrw = true },
	input = { enabled = true },
	notifier = { enabled = true, timeout = 3000 },
	picker = {
		enabled = true,
		prompt = "> ",
		sources = {
			explorer = {
				hidden = true,
				ignored = true,
				layout = { preset = "sidebar", preview = false, layout = { position = "left", width = 32 } },
			},
			files = {
				hidden = true,
				ignored = true,
			},
		},
	},
	quickfile = { enabled = true },
	terminal = { win = { position = "bottom", height = 0.30 } },
})

util.map("n", "<leader>s", "<cmd>write<cr>", "Write buffer")
util.map("n", "<leader>q", "<cmd>quit<cr>", "Quit window")
util.map("n", "<leader>Q", "<cmd>qa<cr>", "Quit Neovim")
util.map({ "n", "t" }, "<C-q>", close_current_view, "Close current view")
util.map("n", "<leader>e", toggle_focus_current_explorer, "Toggle file/explorer focus")
util.map("n", "<leader>fe", open_folder_explorer_only, "Folder explorer")

local function open_initial_explorer()
	if #vim.api.nvim_list_uis() == 0 then
		return
	end

	local first_arg = vim.fn.argv(0)
	if type(first_arg) == "string" and vim.fn.isdirectory(first_arg) == 1 then
		local cwd = vim.fn.fnamemodify(first_arg, ":p"):gsub("/$", "")
		vim.fn.chdir(cwd)
		pcall(vim.api.nvim_buf_delete, vim.api.nvim_get_current_buf(), { force = true })
		Snacks.explorer({ cwd = cwd })
		return
	end

	local current_file = vim.api.nvim_buf_get_name(0)
	if current_file ~= "" and vim.fn.filereadable(current_file) == 1 then
		Snacks.explorer.reveal({ file = current_file })
	else
		Snacks.explorer()
	end
end

vim.api.nvim_create_autocmd("VimEnter", {
	callback = function()
		vim.schedule(open_initial_explorer)
	end,
})

util.map("n", "<leader>ff", function()
	Snacks.picker.files({ hidden = true, ignored = true })
end, "Find files")
util.map("n", "<leader>fg", function()
	Snacks.picker.grep()
end, "Grep")
util.map("n", "<leader>fb", function()
	Snacks.picker.buffers()
end, "Buffers")
util.map("n", "<leader>tt", function()
	Snacks.terminal.toggle()
end, "Toggle terminal")

util.map("t", "<C-]>", [[<C-\><C-n>]], "Terminal normal mode")
util.map("t", "<C-h>", [[<Cmd>wincmd h<CR>]], "Move left")
util.map("t", "<C-j>", [[<Cmd>wincmd j<CR>]], "Move down")
util.map("t", "<C-k>", [[<Cmd>wincmd k<CR>]], "Move up")
util.map("t", "<C-l>", [[<Cmd>wincmd l<CR>]], "Move right")
