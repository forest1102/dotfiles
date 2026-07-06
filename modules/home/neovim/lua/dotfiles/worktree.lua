local util = require("dotfiles.util")
local Snacks = require("snacks")

local function parse_worktree_list(lines)
	local worktrees = {}
	local current = nil

	local function push_current()
		if current and current.path then
			current.label = current.branch or current.head or vim.fn.fnamemodify(current.path, ":t")
			table.insert(worktrees, current)
		end
	end

	for _, line in ipairs(lines) do
		if line:sub(1, 9) == "worktree " then
			push_current()
			current = { path = line:sub(10) }
		elseif current and line:sub(1, 5) == "HEAD " then
			current.head = line:sub(6, 17)
		elseif current and line:sub(1, 18) == "branch refs/heads/" then
			current.branch = line:sub(19)
		elseif current and line == "detached" then
			current.branch = "detached"
		end
	end

	push_current()
	return worktrees
end

local function get_git_root()
	local lines = vim.fn.systemlist({ "git", "rev-parse", "--show-toplevel" })
	if vim.v.shell_error ~= 0 or not lines[1] or lines[1] == "" then
		vim.notify(table.concat(lines, "\n"), vim.log.levels.ERROR, { title = "Git" })
		return nil
	end

	return lines[1]
end

local function get_main_worktree_root()
	local lines = vim.fn.systemlist({ "git", "rev-parse", "--path-format=absolute", "--git-common-dir" })
	if vim.v.shell_error ~= 0 or not lines[1] or lines[1] == "" then
		vim.notify(table.concat(lines, "\n"), vim.log.levels.ERROR, { title = "Git" })
		return nil
	end

	return vim.fn.fnamemodify(lines[1], ":h")
end

local function open_worktree(path, label)
	if vim.fn.isdirectory(path) ~= 1 then
		vim.notify("Directory not found: " .. path, vim.log.levels.ERROR, { title = "Worktree" })
		return
	end

	local escaped_path = vim.fn.fnameescape(path)
	vim.cmd("tabnew")
	vim.cmd("tcd " .. escaped_path)
	Snacks.explorer({ cwd = path })
	vim.notify("Moved to " .. label, vim.log.levels.INFO, { title = "Worktree" })
end

local function select_worktree()
	local lines = vim.fn.systemlist({ "git", "worktree", "list", "--porcelain" })
	if vim.v.shell_error ~= 0 then
		vim.notify(table.concat(lines, "\n"), vim.log.levels.ERROR, { title = "Worktree" })
		return
	end

	local worktrees = parse_worktree_list(lines)
	if #worktrees == 0 then
		vim.notify("No worktrees found", vim.log.levels.WARN, { title = "Worktree" })
		return
	end

	vim.ui.select(worktrees, {
		prompt = "Worktree",
		format_item = function(item)
			return string.format("%s  %s", item.label, item.path)
		end,
	}, function(item)
		if not item then
			return
		end

		open_worktree(item.path, item.label)
	end)
end

local function create_worktree(args)
	local branch
	local base = "HEAD"
	if type(args) == "table" then
		branch = args[1]
		base = args[2] or base
	else
		branch = args
	end

	local function run(input, input_base)
		input = input and vim.trim(input) or ""
		input_base = input_base and vim.trim(input_base) or "HEAD"
		if input == "" then
			return
		end

		local ok, result = pcall(vim.fn.NvwEnsure, input, input_base)
		if not ok then
			vim.notify(tostring(result), vim.log.levels.ERROR, { title = "Worktree" })
			return
		end

		if type(result) ~= "string" or result == "" then
			vim.notify("NvwEnsure returned no worktree path", vim.log.levels.ERROR, { title = "Worktree" })
			return
		end

		open_worktree(result, input)
	end

	if branch and branch ~= "" then
		run(branch, base)
		return
	end

	vim.ui.input({ prompt = "Worktree branch: " }, function(input)
		run(input, base)
	end)
end

local function delete_current_worktree()
	local root = get_git_root()
	if not root then
		return
	end

	if not root:find("/%.worktree/") then
		vim.notify("Refusing to remove main worktree: " .. root, vim.log.levels.WARN, { title = "Worktree" })
		return
	end

	local main_root = get_main_worktree_root()
	if not main_root or main_root == root then
		vim.notify("Could not determine main worktree", vim.log.levels.ERROR, { title = "Worktree" })
		return
	end

	local label = vim.fn.fnamemodify(root, ":t")
	vim.ui.select({ "Remove", "Cancel" }, {
		prompt = "Remove current worktree " .. label .. "?",
	}, function(choice)
		if choice ~= "Remove" then
			return
		end

		vim.cmd("tcd " .. vim.fn.fnameescape(main_root))
		Snacks.explorer({ cwd = main_root })

		local output = vim.fn.systemlist({ "git", "worktree", "remove", root })
		if vim.v.shell_error ~= 0 then
			vim.notify(table.concat(output, "\n"), vim.log.levels.ERROR, { title = "Worktree" })
			return
		end

		vim.notify("Removed worktree " .. root, vim.log.levels.INFO, { title = "Worktree" })
	end)
end

local function list_github_issues()
	if vim.fn.executable("gh") ~= 1 then
		vim.notify("gh command is not installed", vim.log.levels.ERROR, { title = "GitHub Issues" })
		return
	end

	local lines = vim.fn.systemlist({
		"gh",
		"issue",
		"list",
		"--limit",
		"50",
		"--json",
		"number,title,state,author,updatedAt,url",
	})
	if vim.v.shell_error ~= 0 then
		vim.notify(table.concat(lines, "\n"), vim.log.levels.ERROR, { title = "GitHub Issues" })
		return
	end

	local ok, issues = pcall(vim.json.decode, table.concat(lines, "\n"))
	if not ok or type(issues) ~= "table" then
		vim.notify("Failed to parse gh issue list output", vim.log.levels.ERROR, { title = "GitHub Issues" })
		return
	end

	if #issues == 0 then
		vim.notify("No GitHub issues found", vim.log.levels.INFO, { title = "GitHub Issues" })
		return
	end

	vim.ui.select(issues, {
		prompt = "GitHub Issues",
		format_item = function(issue)
			local author = issue.author and issue.author.login or "unknown"
			return string.format("#%s [%s] %s (%s)", issue.number, issue.state, issue.title, author)
		end,
	}, function(issue)
		if not issue then
			return
		end

		Snacks.terminal({ "gh", "issue", "view", tostring(issue.number), "--comments" }, {
			win = {
				position = "right",
				width = 0.50,
			},
		})
	end)
end

vim.api.nvim_create_user_command("Nvw", function(command)
	create_worktree(command.fargs)
end, { nargs = "*", desc = "Create and move to worktree" })
vim.api.nvim_create_user_command("WorktreeCreate", function(command)
	create_worktree(command.fargs)
end, { nargs = "*", desc = "Create and move to worktree" })
vim.api.nvim_create_user_command("WorktreeDeleteCurrent", delete_current_worktree, { desc = "Delete current worktree" })
vim.api.nvim_create_user_command("WorktreeSelect", select_worktree, { desc = "Select and move to worktree" })
vim.api.nvim_create_user_command("GithubIssueList", list_github_issues, { desc = "List GitHub issues" })
util.map("n", "<leader>wc", create_worktree, "Create worktree")
util.map("n", "<leader>wd", delete_current_worktree, "Delete current worktree")
util.map("n", "<leader>ww", select_worktree, "Select worktree")
util.map("n", "<leader>gi", list_github_issues, "GitHub issues")
