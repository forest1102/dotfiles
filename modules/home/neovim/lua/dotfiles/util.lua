local M = {}

M.ascii_border = { "+", "-", "+", "|", "+", "-", "+", "|" }
M.keymap_opts = { noremap = true, silent = true }

function M.map(mode, lhs, rhs, desc, extra)
	local opts = vim.tbl_extend("force", M.keymap_opts, extra or {})
	if desc then
		opts.desc = desc
	end

	vim.keymap.set(mode, lhs, rhs, opts)
end

return M
