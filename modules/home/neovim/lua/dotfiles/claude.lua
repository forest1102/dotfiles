local util = require("dotfiles.util")

require("claudecode").setup({
	git_repo_cwd = true,
	terminal = {
		provider = "snacks",
		split_side = "right",
		split_width_percentage = 0.30,
		diff_split_width_percentage = 0.20,
		auto_close = true,
	},
	diff_opts = {
		layout = "vertical",
		auto_resize_terminal = true,
	},
})

util.map({ "n", "i", "t" }, "<C-g>", "<cmd>ClaudeCode<cr>", "Toggle Claude Code")
util.map("n", "<leader>c", "<cmd>ClaudeCodeFocus<cr>", "Focus Claude")
util.map("n", "<leader>Cf", "<cmd>ClaudeCodeFocus<cr>", "Focus Claude")
util.map("n", "<leader>Cr", "<cmd>ClaudeCode --resume<cr>", "Resume Claude")
util.map("n", "<leader>CA", "<cmd>ClaudeCode --continue<cr>", "Continue Claude")
util.map("n", "<leader>Cm", "<cmd>ClaudeCodeSelectModel<cr>", "Select Claude model")
util.map("n", "<leader>Cb", "<cmd>ClaudeCodeAdd %<cr>", "Add current buffer")
util.map("v", "<leader>Cs", "<cmd>ClaudeCodeSend<cr>", "Send selection to Claude")
util.map("n", "<leader>Ca", "<cmd>ClaudeCodeDiffAccept<cr>", "Accept Claude diff")
util.map("n", "<leader>Cd", "<cmd>ClaudeCodeDiffDeny<cr>", "Deny Claude diff")
