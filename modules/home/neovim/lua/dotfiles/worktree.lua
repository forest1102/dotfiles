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

local function sanitize_worktree_name(value)
	local sanitized = value:gsub("[/%s]+", "-"):gsub("[^%w%._%-]", "-"):gsub("%-+", "-")
	if sanitized == "" then
		return "worktree"
	end

	return sanitized
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

local function create_worktree(branch)
	local function run_worktree_init(main_root, worktree_path, branch_name, base)
		local init_script = main_root .. "/.worktree/init.sh"
		if vim.fn.filereadable(init_script) ~= 1 then
			return
		end

		local result = vim.system({ "sh", init_script }, {
			cwd = worktree_path,
			env = {
				WORKTREE_MAIN_ROOT = main_root,
				WORKTREE_PATH = worktree_path,
				WORKTREE_BRANCH = branch_name,
				WORKTREE_BASE = base,
			},
			text = true,
		}):wait()

		if result.code ~= 0 then
			local output = vim.trim(table.concat({ result.stdout or "", result.stderr or "" }, "\n"))
			local message = ".worktree/init.sh failed with exit status " .. result.code
			if output ~= "" then
				message = message .. "\n" .. output
			end
			vim.notify(message, vim.log.levels.WARN, { title = "Worktree" })
		end
	end

	local function run(input)
		input = input and vim.trim(input) or ""
		if input == "" then
			return
		end

		local main_root = get_main_worktree_root()
		if not main_root then
			return
		end

		local worktree_dir = main_root .. "/.worktree"
		local worktree_path = worktree_dir .. "/" .. sanitize_worktree_name(input)
		local base = "HEAD"

		if vim.fn.isdirectory(worktree_path) == 1 then
			open_worktree(worktree_path, input)
			return
		end

		vim.fn.mkdir(worktree_dir, "p")
		vim.fn.system({ "git", "show-ref", "--verify", "--quiet", "refs/heads/" .. input })

		local command
		if vim.v.shell_error == 0 then
			command = { "git", "worktree", "add", worktree_path, input }
		else
			command = { "git", "worktree", "add", "-b", input, worktree_path, base }
		end

		local output = vim.fn.systemlist(command)
		if vim.v.shell_error ~= 0 then
			vim.notify(table.concat(output, "\n"), vim.log.levels.ERROR, { title = "Worktree" })
			return
		end

		run_worktree_init(main_root, worktree_path, input, base)
		open_worktree(worktree_path, input)
	end

	if branch and branch ~= "" then
		run(branch)
		return
	end

	vim.ui.input({ prompt = "Worktree branch: " }, run)
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

vim.api.nvim_create_user_command("WorktreeCreate", function(command)
	create_worktree(command.args)
end, { nargs = "?", desc = "Create and move to worktree" })
vim.api.nvim_create_user_command("WorktreeDeleteCurrent", delete_current_worktree, { desc = "Delete current worktree" })
vim.api.nvim_create_user_command("WorktreeSelect", select_worktree, { desc = "Select and move to worktree" })
vim.api.nvim_create_user_command("GithubIssueList", list_github_issues, { desc = "List GitHub issues" })
util.map("n", "<leader>wc", create_worktree, "Create worktree")
util.map("n", "<leader>wd", delete_current_worktree, "Delete current worktree")
util.map("n", "<leader>ww", select_worktree, "Select worktree")
util.map("n", "<leader>gi", list_github_issues, "GitHub issues")
