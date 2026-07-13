local function run()
	local root = vim.fn.getcwd()
	local temp = vim.fn.resolve(vim.fn.tempname())
	local repo_a = temp .. "/repo-a"
	local repo_b = temp .. "/repo-b"
	local selected_worktree = repo_a .. "/.worktree/selected"
	vim.fn.mkdir(repo_a, "p")
	vim.fn.mkdir(repo_b, "p")
	vim.fn.mkdir(selected_worktree, "p")
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

	local systemlist_args
	vim.fn.systemlist = function(args)
		systemlist_args = vim.deepcopy(args)
		if args[2] == "-C" then
			return {
				"worktree " .. selected_worktree,
				"HEAD 0123456789abcdef0123456789abcdef01234567",
				"branch refs/heads/feature/selected",
				"",
			}
		end
		return {}
	end
	local input_callback
	vim.ui.input = function(_, callback)
		input_callback = callback
	end
	local select_items
	local select_callback
	vim.ui.select = function(items, _, callback)
		select_items = items
		select_callback = callback
	end

	require("dotfiles.worktree")

	vim.cmd("tabnew")
	vim.cmd("tcd " .. vim.fn.fnameescape(repo_a))
	vim.cmd("WorktreeCreate")
	assert(type(input_callback) == "function")

	vim.cmd("tabnew")
	vim.cmd("tcd " .. vim.fn.fnameescape(repo_b))
	input_callback("feature/repo-a")
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
	vim.cmd("tcd " .. vim.fn.fnameescape(repo_a))
	vim.cmd("WorktreeSelect")
	assert(
		vim.deep_equal(systemlist_args, {
			"git",
			"-C",
			repo_a,
			"worktree",
			"list",
			"--porcelain",
		}),
		vim.inspect(systemlist_args)
	)
	assert(type(select_callback) == "function")
	assert(select_items[1].path == selected_worktree, vim.inspect(select_items))

	vim.cmd("tabnew")
	vim.cmd("tcd " .. vim.fn.fnameescape(repo_b))
	select_callback(select_items[1])
	assert(vim.fn.getcwd(-1, 0) == selected_worktree, vim.fn.getcwd(-1, 0))

	vim.fn.delete(temp, "rf")
end

local ok, error = xpcall(run, debug.traceback)
if not ok then
	vim.api.nvim_err_writeln(error)
	vim.cmd("cquit 1")
end
vim.cmd("qa!")
