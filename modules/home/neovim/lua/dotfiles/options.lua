vim.g.mapleader = " "
vim.g.maplocalleader = " "

vim.opt.autowrite = true
vim.opt.breakindent = true
vim.opt.clipboard = "unnamedplus"
vim.opt.completeopt = { "menu", "menuone", "noselect" }
vim.opt.confirm = true
vim.opt.cursorline = true
vim.opt.expandtab = true
vim.opt.ignorecase = true
vim.opt.inccommand = "split"
vim.opt.number = true
vim.opt.relativenumber = false
vim.opt.scrolloff = 8
vim.opt.shiftwidth = 2
vim.opt.signcolumn = "yes"
vim.opt.smartcase = true
vim.opt.splitbelow = true
vim.opt.splitright = true
vim.opt.tabstop = 2
vim.opt.termguicolors = true
vim.opt.title = true
vim.opt.updatetime = 250
vim.opt.fillchars = {
	eob = " ",
	fold = " ",
	foldclose = "+",
	foldopen = "-",
	foldsep = " ",
}

local function terminal_title_value(value)
	return value:gsub("%%", "%%%%"):gsub("[\r\n]", " ")
end

local function current_git_branch()
	local lines = vim.fn.systemlist({ "git", "-C", vim.fn.getcwd(), "branch", "--show-current" })
	if vim.v.shell_error ~= 0 or not lines[1] or lines[1] == "" then
		return nil
	end

	return lines[1]
end

local function update_terminal_title()
	local branch = current_git_branch()
	local title = branch or vim.fn.fnamemodify(vim.fn.getcwd(), ":t")
	vim.opt.titlestring = "nvim " .. terminal_title_value(title)
end

vim.api.nvim_create_autocmd({ "VimEnter", "DirChanged", "FocusGained", "TermClose" }, {
	callback = update_terminal_title,
})
