local util = require("dotfiles.util")

require("claudecode").setup({
	git_repo_cwd = true,
	terminal = {
		provider = "snacks",
		split_side = "right",
		split_width_percentage = 0.30,
		diff_split_width_percentage = 0.20,
		auto_close = true,
		snacks_win_opts = {
			keys = {
				term_normal = {
					"<Esc>",
					function()
						local channel = vim.b.terminal_job_id
						if not channel or channel == 0 then
							channel = vim.bo.channel
						end
						if channel and channel ~= 0 then
							vim.fn.chansend(channel, "\27")
						end
						return ""
					end,
					mode = "t",
					expr = true,
					desc = "Pass escape to Claude",
				},
			},
		},
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
