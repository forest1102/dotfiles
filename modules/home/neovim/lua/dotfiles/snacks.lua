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

local function toggle_focus_explorer()
	local explorer = Snacks.picker.get({ source = "explorer" })[1]
	if not explorer or explorer.closed then
		Snacks.explorer()
		return
	end

	if vim.bo.filetype:match("^snacks_") then
		vim.cmd("wincmd p")
	else
		explorer:focus("list", { show = true })
	end
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
util.map("n", "<leader>e", toggle_focus_explorer, "Toggle Focus Explorer")

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
