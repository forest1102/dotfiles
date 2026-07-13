local function run()
	local root = vim.fn.getcwd()
	local temp = vim.fn.resolve(vim.fn.tempname())
	local repo_a = temp .. "/repo-a"
	local repo_b = temp .. "/repo-b"
	vim.fn.mkdir(repo_a, "p")
	vim.fn.mkdir(repo_b, "p")
	assert(vim.fn.system({ "git", "init", "-q", repo_a }) == "")
	assert(vim.v.shell_error == 0)
	assert(vim.fn.system({ "git", "init", "-q", repo_b }) == "")
	assert(vim.v.shell_error == 0)

	vim.opt.runtimepath:prepend(root .. "/modules/home/neovim")
	package.path = root .. "/modules/home/neovim/lua/?.lua;" .. package.path
	package.loaded["dotfiles.util"] = { map = function() end }
	package.loaded["snacks"] = {
		explorer = function() end,
		terminal = function() end,
	}
	vim.notify = function() end

	local ensure_calls = {}
	vim.fn.NvwEnsure = function(cwd, branch, base)
		table.insert(ensure_calls, { cwd, branch, base })
		return cwd
	end

	local original_systemlist = vim.fn.systemlist
	local systemlist_args
	vim.fn.systemlist = function(args)
		systemlist_args = vim.deepcopy(args)
		return original_systemlist(args)
	end
	vim.ui.select = function() end

	require("dotfiles.worktree")

	vim.cmd("tabnew")
	vim.cmd("tcd " .. vim.fn.fnameescape(repo_a))
	vim.cmd("WorktreeCreate feature/repo-a")

	vim.cmd("tabnew")
	vim.cmd("tcd " .. vim.fn.fnameescape(repo_b))
	vim.cmd("WorktreeCreate feature/repo-b origin/main")

	assert(
		vim.deep_equal(ensure_calls, {
			{ repo_a, "feature/repo-a", "HEAD" },
			{ repo_b, "feature/repo-b", "origin/main" },
		}),
		vim.inspect(ensure_calls)
	)

	vim.cmd("tabnew")
	vim.cmd("tcd " .. vim.fn.fnameescape(repo_b))
	vim.cmd("WorktreeSelect")
	assert(
		vim.deep_equal(systemlist_args, {
			"git",
			"-C",
			repo_b,
			"worktree",
			"list",
			"--porcelain",
		}),
		vim.inspect(systemlist_args)
	)

	vim.fn.delete(temp, "rf")
end

local ok, error = xpcall(run, debug.traceback)
if not ok then
	vim.api.nvim_err_writeln(error)
	vim.cmd("cquit 1")
end
vim.cmd("qa!")
