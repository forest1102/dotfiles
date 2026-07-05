local util = require("dotfiles.util")

require("lualine").setup({
	options = {
		globalstatus = true,
	},
})

require("todo-comments").setup({})
require("trouble").setup({})
util.map("n", "<leader>xx", "<cmd>Trouble diagnostics toggle<cr>", "Diagnostics")
util.map("n", "<leader>xX", "<cmd>Trouble diagnostics toggle filter.buf=0<cr>", "Buffer diagnostics")

require("markview").setup({
	preview = {
		enable = false,
		enable_hybrid_mode = false,
		filetypes = { "markdown" },
		condition = function(buffer)
			return vim.bo[buffer].filetype == "markdown"
		end,
		icon_provider = "devicons",
		map_gx = false,
	},
})

local function toggle_markview_preview()
	if vim.bo.filetype ~= "markdown" then
		return
	end

	local actions = require("markview.actions")
	local state = require("markview.state")
	local buffer = vim.api.nvim_get_current_buf()

	if not state.buf_attached(buffer) then
		actions.attach(buffer)
		actions.enable(buffer)
		return
	end

	actions.toggle(buffer)
end

util.map("n", "<leader>mr", toggle_markview_preview, "Markdown preview")
util.map("n", "<leader>ms", "<cmd>Markview splitToggle<cr>", "Markdown split preview")

vim.api.nvim_create_autocmd("FileType", {
	pattern = {
		"bash",
		"css",
		"html",
		"javascript",
		"javascriptreact",
		"json",
		"lua",
		"markdown",
		"nix",
		"toml",
		"typescript",
		"typescriptreact",
		"vim",
		"yaml",
	},
	callback = function()
		pcall(vim.treesitter.start)
		vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
	end,
})
