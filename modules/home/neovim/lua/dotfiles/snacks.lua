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

local function changed_files_explorer()
	for _, picker in ipairs(Snacks.picker.get({})) do
		if picker.opts.title == "Changed files" then
			return picker
		end
	end
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
	local changed_files = changed_files_explorer()
	if not changed_files or changed_files.closed then
		return false
	end

	pcall(vim.cmd, "GitChangedFilesClose")
	return true
end

local function open_folder_explorer()
	local explorer = Snacks.picker.get({ source = "explorer" })[1]
	if explorer and not explorer.closed then
		explorer:focus("list", { show = true })
	else
		Snacks.explorer()
	end
end

local function open_folder_explorer_only()
	if close_changed_files_explorer_if_open() then
		vim.schedule(open_folder_explorer)
		return
	end

	open_folder_explorer()
end

local function close_explorer()
	if close_changed_files_explorer_if_open() then
		return true
	end

	return close_file_explorer_if_open()
end

local function is_window_in_picker(picker, win)
	if not picker or picker.closed then
		return false
	end

	for _, w in pairs(picker.layout.wins or {}) do
		if w.win == win then
			return true
		end
	end

	return false
end

local function current_window_picker()
	local win = vim.api.nvim_get_current_win()
	local changed_files = changed_files_explorer()
	if is_window_in_picker(changed_files, win) then
		return changed_files
	end

	local explorer = Snacks.picker.get({ source = "explorer" })[1]
	if is_window_in_picker(explorer, win) then
		return explorer
	end

	return nil
end

local function toggle_explorer_visibility()
	if close_explorer() then
		return
	end

	open_folder_explorer()
end

local function toggle_explorer()
	local picker = current_window_picker()
	if picker then
		if picker.opts.title == "Changed files" then
			close_changed_files_explorer_if_open()
		else
			picker:close()
		end
		return
	end

	local changed_files = changed_files_explorer()
	if changed_files and not changed_files.closed then
		changed_files:focus("list", { show = true })
		return
	end

	open_folder_explorer()
end

vim.api.nvim_create_autocmd("FileType", {
	pattern = { "snacks_*", "trouble" },
	command = "setlocal nonumber norelativenumber signcolumn=no foldcolumn=0",
})
vim.api.nvim_create_autocmd("TermOpen", {
	command = "setlocal nonumber norelativenumber signcolumn=no foldcolumn=0",
})

-- herdr hides the outer terminal (TERM_PROGRAM=herdr) but still passes kitty
-- graphics protocol placeholders through, so register it explicitly since
-- snacks.image doesn't recognize herdr on its own.
table.insert(require("snacks.image.terminal").envs(), {
	name = "herdr",
	env = { TERM_PROGRAM = "herdr" },
	supported = true,
	placeholders = true,
})

Snacks.setup({
	explorer = { enabled = true, replace_netrw = true },
	image = { enabled = true },
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
				win = {
					list = {
						keys = {
							["<c-n>"] = "close",
						},
					},
				},
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
util.map("n", "<C-n>", toggle_explorer_visibility, "Toggle explorer")
util.map("n", "<leader>e", toggle_explorer, "Open/focus or close explorer")
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
		return
	end

	Snacks.explorer()
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
