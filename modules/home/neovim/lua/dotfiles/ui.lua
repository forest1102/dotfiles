local util = require("dotfiles.util")
local Snacks = require("snacks")

-- Transparent background: let Ghostty's background show through normal
-- windows AND floating windows (pickers, notifier, which-key, snacks
-- explorer sidebar, ...), except the completion menu.
--
-- snacks.nvim/which-key.nvim/trouble.nvim/blink-cmp's own highlight groups
-- (`SnacksPickerList`, `SnacksNormal`, `WhichKeyNormal`, `TroubleNormal`,
-- `BlinkCmpMenu`, ...) are, in the versions installed here, all
-- `default = true` *links* -- never groups with their own `bg` -- that
-- chain down to one of the plain builtin groups below (mostly by way of
-- `NormalFloat`; `SnacksInput*`/`SnacksNotifier*` link straight to `Normal`,
-- verified by reading `snacks.nvim`'s `win.lua`/`input.lua`/`notifier.lua`
-- and `which-key.nvim`'s `colors.lua`). So clearing the small set of
-- builtin roots below cascades through every one of those link chains,
-- without needing to enumerate each plugin's alias groups individually or
-- hook any picker/window lifecycle event: a plain highlight link is
-- resolved at render time, so clearing the roots once (and again on
-- `ColorScheme`) is enough.
local transparent_groups = {
	"Normal",
	"NormalNC",
	"SignColumn",
	"LineNr",
	"CursorLineNr",
	"EndOfBuffer",
	"FoldColumn",
	"NormalFloat",
	"FloatBorder",
	"FloatTitle",
	"FloatFooter",
}

-- blink-cmp's completion menu (`BlinkCmpMenu*`) links to `Pmenu`, which
-- this file never touches, so it keeps its background automatically. Its
-- documentation and signature-help popups (`BlinkCmpDoc*`,
-- `BlinkCmpSignatureHelp`/`BlinkCmpSignatureHelpBorder` -- every group in
-- `blink/cmp/highlights.lua` that links to `NormalFloat`;
-- `BlinkCmpSignatureHelpActiveParameter` links to `LspSignatureActiveParameter`
-- instead, so it's unaffected) link to `NormalFloat` though, which the
-- sidebar above just went transparent -- give them their own bg-preserving
-- copy of `NormalFloat` so these stay readable, being part of the same
-- completion UI as the (bg-preserved) menu. blink.cmp defines all of these
-- itself with `default = true` (on setup and again on every `ColorScheme`),
-- so our hard (non-default) override here, applied on `ColorScheme`
-- alongside `apply_transparency()`, always wins regardless of
-- load/registration order.
local blink_doc_groups = {
	"BlinkCmpDoc",
	"BlinkCmpDocBorder",
	"BlinkCmpDocSeparator",
	"BlinkCmpSignatureHelp",
	"BlinkCmpSignatureHelpBorder",
}

---@param ns integer
---@param group string
local function clear_bg(ns, group)
	local ok, hl = pcall(vim.api.nvim_get_hl, ns, { name = group, link = false })
	if not ok then
		return
	end
	hl.bg = nil
	hl.ctermbg = nil
	vim.api.nvim_set_hl(ns, group, hl)
end

local function apply_transparency()
	-- Snapshot NormalFloat's current (colorscheme-provided) bg before
	-- clearing it, to preserve it on the blink-cmp doc popup below.
	local ok, normal_float = pcall(vim.api.nvim_get_hl, 0, { name = "NormalFloat", link = false })

	for _, group in ipairs(transparent_groups) do
		clear_bg(0, group)
	end

	if ok then
		for _, group in ipairs(blink_doc_groups) do
			vim.api.nvim_set_hl(0, group, normal_float)
		end
	end
end

vim.api.nvim_create_autocmd("ColorScheme", {
	callback = apply_transparency,
})

apply_transparency()

vim.o.background = "dark"
vim.cmd.colorscheme("solarized8")

require("lualine").setup({
	options = {
		globalstatus = true,
	},
})

require("todo-comments").setup({})
require("trouble").setup({})
util.map("n", "<leader>xx", "<cmd>Trouble diagnostics toggle<cr>", "Diagnostics")
util.map("n", "<leader>xX", "<cmd>Trouble diagnostics toggle filter.buf=0<cr>", "Buffer diagnostics")

require("render-markdown").setup({
	file_types = { "markdown" },
})

util.map("n", "<leader>mr", "<cmd>RenderMarkdown buf_toggle<cr>", "Markdown render")
util.map("n", "<leader>ms", "<cmd>RenderMarkdown preview<cr>", "Markdown side preview")

local function leaf_preview()
	if vim.bo.filetype ~= "markdown" then
		return
	end

	local file = vim.api.nvim_buf_get_name(0)
	if file == "" then
		return
	end

	Snacks.terminal.toggle({ "leaf", "-w", file }, { win = { position = "right" } })
end

util.map("n", "<leader>ml", leaf_preview, "Markdown leaf preview")

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
