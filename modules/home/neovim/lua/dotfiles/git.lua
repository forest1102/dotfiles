local util = require("dotfiles.util")
local Snacks = require("snacks")

require("gitsigns").setup({
	numhl = true,
})

local diff_windows = {
	head = nil,
	worktree = nil,
}
local diff_layout_snapshot = nil

local function save_diff_layout_snapshot()
	if diff_layout_snapshot then
		return
	end

	local tabpage = vim.api.nvim_get_current_tabpage()
	local snapshot = {
		tabpage = tabpage,
		current_win = vim.api.nvim_get_current_win(),
		restore_cmd = vim.fn.winrestcmd(),
		views = {},
	}

	for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tabpage)) do
		local ok, config = pcall(vim.api.nvim_win_get_config, win)
		if ok and config.relative == "" then
			local view = nil
			vim.api.nvim_win_call(win, function()
				view = vim.fn.winsaveview()
			end)
			snapshot.views[win] = {
				buffer = vim.api.nvim_win_get_buf(win),
				view = view,
			}
		end
	end

	diff_layout_snapshot = snapshot
end

local function restore_diff_layout_snapshot()
	local snapshot = diff_layout_snapshot
	diff_layout_snapshot = nil
	if not snapshot or not vim.api.nvim_tabpage_is_valid(snapshot.tabpage) then
		return
	end

	if vim.api.nvim_get_current_tabpage() ~= snapshot.tabpage then
		return
	end

	for win, state in pairs(snapshot.views) do
		if vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win) == state.buffer then
			vim.api.nvim_win_call(win, function()
				pcall(vim.fn.winrestview, state.view)
			end)
		end
	end

	if snapshot.restore_cmd and snapshot.restore_cmd ~= "" then
		pcall(vim.cmd, snapshot.restore_cmd)
	end

	if vim.api.nvim_win_is_valid(snapshot.current_win) then
		vim.api.nvim_set_current_win(snapshot.current_win)
	end
end

local function close_file_explorer()
	local explorer = Snacks.picker.get({ source = "explorer" })[1]
	if explorer and not explorer.closed then
		explorer:close()
	end
end

local function find_changed_files_explorer()
	for _, picker in ipairs(Snacks.picker.get({})) do
		if picker.opts.title == "Changed files" then
			return picker
		end
	end
end

local function changed_files_tree_finder(opts, ctx)
	local git_status = require("snacks.picker.source.git").status(opts, ctx)
	local root = {
		internal = true,
		dir = true,
		open = true,
		sort = "",
	}
	local dirs = {}
	local last = {}

	local function add_tree_item(item, cb)
		local dirname, basename = item.file:match("(.*)/(.*)")
		dirname, basename = dirname or "", basename or item.file
		local parent = dirs[dirname] or root
		local prefix = item.dir and "!" or "#"

		item.parent = parent
		item.sort = parent.sort .. prefix .. basename .. " "
		if not last[parent] or last[parent].sort < item.sort then
			if last[parent] then
				last[parent].last = false
			end
			item.last = true
			last[parent] = item
		end

		cb(item)
	end

	local function ensure_dir(path, cwd, cb)
		if path == "" then
			return root
		end

		if dirs[path] then
			return dirs[path]
		end

		local parent_path, basename = path:match("(.*)/(.*)")
		parent_path, basename = parent_path or "", basename or path
		local parent = ensure_dir(parent_path, cwd, cb)
		local item = {
			cwd = cwd,
			file = path,
			text = path,
			dir = true,
			open = true,
			internal = true,
			parent = parent,
		}
		dirs[path] = item
		add_tree_item(item, cb)
		return item
	end

	return function(cb)
		git_status(function(item)
			local dirname = item.file:match("(.*)/.*") or ""
			ensure_dir(dirname, item.cwd, cb)
			add_tree_item(item, cb)
		end)
	end
end

local function keep_changed_files_open() end

local function get_git_root()
	local lines = vim.fn.systemlist({ "git", "rev-parse", "--show-toplevel" })
	if vim.v.shell_error ~= 0 or not lines[1] or lines[1] == "" then
		vim.notify(table.concat(lines, "\n"), vim.log.levels.ERROR, { title = "Git" })
		return nil
	end

	return lines[1]
end

local function read_git_file(cwd, file)
	local lines = vim.fn.systemlist({ "git", "-C", cwd, "show", "HEAD:" .. file })
	if vim.v.shell_error ~= 0 then
		return {}
	end

	return lines
end

local function changed_filetype(file)
	local ok, filetype = pcall(vim.filetype.match, { filename = file })
	if ok and filetype then
		return filetype
	end

	return ""
end

local function is_valid_window(win)
	return win ~= nil and vim.api.nvim_win_is_valid(win)
end

local function close_diff_windows()
	for _, win in pairs(diff_windows) do
		if is_valid_window(win) then
			pcall(vim.api.nvim_win_close, win, true)
		end
	end

	diff_windows.head = nil
	diff_windows.worktree = nil
end

local function clear_diff_window_state()
	pcall(vim.api.nvim_win_del_var, 0, "dotfiles_git_diff_view")
	pcall(vim.api.nvim_win_del_var, 0, "dotfiles_git_diff_role")
	pcall(vim.api.nvim_buf_del_var, 0, "dotfiles_git_diff_view")
	pcall(vim.api.nvim_buf_del_var, 0, "dotfiles_git_diff_role")
	vim.wo.foldmethod = "manual"
	vim.wo.foldenable = false
end

local function changed_file_path_from_item(picker)
	local item = picker and picker:current()
	if not item or not item.file or item.dir or item.internal then
		return nil
	end

	local cwd = item.cwd or get_git_root()
	if not cwd then
		return nil
	end

	return cwd .. "/" .. item.file
end

local function current_worktree_file()
	if not is_valid_window(diff_windows.worktree) then
		return nil
	end

	local buffer = vim.api.nvim_win_get_buf(diff_windows.worktree)
	local path = vim.api.nvim_buf_get_name(buffer)
	if path == "" or vim.fn.filereadable(path) ~= 1 then
		return nil
	end

	return path
end

local function open_real_file_after_diff(path)
	if is_valid_window(diff_windows.worktree) then
		vim.api.nvim_set_current_win(diff_windows.worktree)
	else
		vim.cmd("edit " .. vim.fn.fnameescape(path))
	end

	if vim.bo.modified and vim.bo.buftype == "" then
		vim.cmd("write")
	end

	if path and vim.api.nvim_buf_get_name(0) ~= path then
		vim.cmd.edit(vim.fn.fnameescape(path))
	end

	pcall(vim.cmd, "diffoff")
	clear_diff_window_state()
	vim.cmd("normal! zR")
end

local function close_changed_files_view(picker)
	local path = changed_file_path_from_item(picker) or current_worktree_file()

	if picker and not picker.closed then
		picker:close()
	end

	if is_valid_window(diff_windows.head) then
		pcall(vim.api.nvim_win_close, diff_windows.head, true)
	end

	if path then
		open_real_file_after_diff(path)
	elseif is_valid_window(diff_windows.worktree) then
		vim.api.nvim_set_current_win(diff_windows.worktree)
		pcall(vim.cmd, "diffoff")
		clear_diff_window_state()
	end

	diff_windows.head = nil
	diff_windows.worktree = nil
	restore_diff_layout_snapshot()
end

local function set_scratch_diff_buffer(name, lines, filetype)
	local buffer = vim.api.nvim_get_current_buf()
	local unique_name = name
	if vim.fn.bufexists(unique_name) == 1 then
		unique_name = unique_name .. "#" .. tostring(vim.uv.hrtime())
	end

	vim.bo[buffer].buftype = "nofile"
	vim.bo[buffer].bufhidden = "wipe"
	vim.bo[buffer].swapfile = false
	vim.bo[buffer].modifiable = true
	pcall(vim.api.nvim_buf_set_name, buffer, unique_name)
	vim.api.nvim_buf_set_lines(buffer, 0, -1, false, #lines > 0 and lines or { "" })
	vim.bo[buffer].filetype = filetype
	vim.bo[buffer].readonly = true
	vim.bo[buffer].modifiable = false
end

local function set_worktree_diff_buffer(cwd, file, filetype)
	local path = cwd .. "/" .. file

	vim.cmd.edit(vim.fn.fnameescape(path))
	vim.bo.filetype = filetype
end

local function configure_diff_window(kind)
	local buffer = vim.api.nvim_get_current_buf()

	vim.w.dotfiles_git_diff_view = true
	vim.w.dotfiles_git_diff_role = kind
	vim.b[buffer].dotfiles_git_diff_view = true
	vim.b[buffer].dotfiles_git_diff_role = kind
	vim.wo.foldmethod = "diff"
	vim.wo.foldenable = true
	vim.wo.foldlevel = 0

	pcall(vim.keymap.set, "n", "zR", "zR", { buffer = buffer, desc = "Expand diff file" })
	pcall(vim.keymap.set, "n", "zM", "zM", { buffer = buffer, desc = "Collapse diff file" })
	pcall(vim.api.nvim_buf_create_user_command, buffer, "GitDiffExpandFile", function()
		vim.cmd("normal! zR")
	end, { desc = "Expand diff file" })
	pcall(vim.api.nvim_buf_create_user_command, buffer, "GitDiffCollapseFile", function()
		vim.cmd("normal! zM")
	end, { desc = "Collapse diff file" })
end

local function reset_diff_window(win)
	vim.api.nvim_win_call(win, function()
		if vim.bo.modified and vim.bo.buftype == "" then
			vim.cmd("write")
		end

		pcall(vim.cmd, "diffoff")
		vim.cmd("enew")
	end)
end

local function ensure_diff_windows(picker)
	if is_valid_window(diff_windows.head) and is_valid_window(diff_windows.worktree) then
		return true
	end

	close_diff_windows()

	local main_win = picker and picker.main
	if not is_valid_window(main_win) then
		main_win = vim.api.nvim_get_current_win()
	end

	if not is_valid_window(main_win) then
		return false
	end

	vim.api.nvim_set_current_win(main_win)
	vim.cmd("enew")
	diff_windows.worktree = vim.api.nvim_get_current_win()
	vim.cmd("leftabove vertical new")
	diff_windows.head = vim.api.nvim_get_current_win()

	return true
end

local function render_diff_windows(cwd, file, head_name, head_lines, filetype)
	reset_diff_window(diff_windows.head)
	vim.api.nvim_win_call(diff_windows.head, function()
		set_scratch_diff_buffer(head_name, head_lines, filetype)
		vim.cmd("diffthis")
		configure_diff_window("head")
		vim.cmd("normal! zM")
		vim.cmd("normal! gg")
	end)

	reset_diff_window(diff_windows.worktree)
	vim.api.nvim_win_call(diff_windows.worktree, function()
		set_worktree_diff_buffer(cwd, file, filetype)
		vim.cmd("diffthis")
		configure_diff_window("worktree")
		vim.cmd("normal! zM")
		vim.cmd("normal! gg")
	end)
end

local function open_changed_file_diff(picker, item)
	item = item or picker:current()
	if not item or not item.file or item.dir or item.internal then
		return
	end

	local cwd = item.cwd or get_git_root()
	if not cwd then
		return
	end

	local file = item.file
	local old_file = item.rename or file
	local filetype = changed_filetype(file)
	local old_lines = read_git_file(cwd, old_file)

	if not ensure_diff_windows(picker) then
		return
	end

	render_diff_windows(cwd, file, "HEAD:" .. old_file, old_lines, filetype)
	pcall(function()
		picker:focus("list", { show = true })
	end)
end

local function toggle_changed_files_explorer()
	local explorer = find_changed_files_explorer()
	if explorer and not explorer.closed then
		close_changed_files_view(explorer)
		return
	end

	save_diff_layout_snapshot()
	close_file_explorer()
	Snacks.picker.git_status({
		title = "Changed files",
		finder = changed_files_tree_finder,
		format = "file",
		auto_close = false,
		show_empty = true,
		sort = { fields = { "sort" } },
		formatters = {
			file = {
				filename_only = true,
			},
		},
		actions = {
			confirm = open_changed_file_diff,
		},
		win = {
			input = {
				keys = {
					["<Esc>"] = keep_changed_files_open,
				},
			},
			list = {
				keys = {
					["<Esc>"] = keep_changed_files_open,
				},
			},
			preview = {
				keys = {
					["<Esc>"] = keep_changed_files_open,
				},
			},
		},
		layout = {
			preset = "sidebar",
			preview = false,
			layout = {
				position = "left",
				width = 42,
			},
		},
	})
end

util.map("n", "<leader>gs", function()
	Snacks.picker.git_status({ show_empty = true })
end, "Git status")
util.map("n", "<leader>gd", function()
	Snacks.picker.git_diff({ show_empty = true })
end, "Git diff")
vim.api.nvim_create_user_command(
	"GitChangedFiles",
	toggle_changed_files_explorer,
	{ desc = "Toggle changed files diff" }
)
vim.api.nvim_create_user_command("GitChangedFilesClose", function()
	local explorer = find_changed_files_explorer()
	if explorer or is_valid_window(diff_windows.head) or is_valid_window(diff_windows.worktree) then
		close_changed_files_view(explorer)
	end
end, { desc = "Close changed files diff" })
util.map("n", "<leader>ge", toggle_changed_files_explorer, "Toggle changed files diff")
util.map("n", "<leader>gg", function()
	vim.fn.mkdir(vim.fn.stdpath("cache"), "p")
	vim.cmd("silent! wall")
	Snacks.lazygit({
		config = {
			gui = {
				mainPanelSplitMode = "flexible",
				portraitMode = "never",
				sidePanelWidth = 0.28,
			},
		},
		win = {
			position = "right",
			width = 0.50,
		},
	})
end, "LazyGit")
