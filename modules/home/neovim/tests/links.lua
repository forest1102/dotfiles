local explorer_root

local function run()
	local root = vim.fn.getcwd()
	vim.opt.runtimepath:prepend(root .. "/modules/home/neovim")
	package.path = root .. "/modules/home/neovim/lua/?.lua;" .. package.path
	package.loaded["dotfiles.util"] = { map = function() end }
	local links = require("dotfiles.links")

	local function target_at(lines, ft, row, col)
		vim.cmd("enew!")
		vim.bo.filetype = ft
		vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
		if ft == "markdown" then
			vim.treesitter.start(0, "markdown")
		end
		vim.api.nvim_win_set_cursor(0, { row, col })
		return links.get_target()
	end

	local function eq(actual, expected, label)
		assert(actual == expected, label .. ": expected " .. vim.inspect(expected) .. ", got " .. vim.inspect(actual))
	end

	-- inline link: text and destination
	local line = "see [text](./a.md) now"
	eq(target_at({ line }, "markdown", 1, 6), "./a.md", "link text")
	eq(target_at({ line }, "markdown", 1, 13), "./a.md", "link destination")
	-- angle-bracket destination with spaces
	eq(target_at({ "[x](<path with space.md>)" }, "markdown", 1, 1), "path with space.md", "angle dest")
	-- autolink
	eq(target_at({ "<https://example.com>" }, "markdown", 1, 5), "https://example.com", "autolink")
	-- image
	eq(target_at({ "![alt](img.png)" }, "markdown", 1, 3), "img.png", "image alt")
	eq(target_at({ "![alt](img.png)" }, "markdown", 1, 10), "img.png", "image dest")
	-- fallback to <cfile> in non-markdown buffers
	eq(target_at({ "foo /tmp/bar.txt baz" }, "text", 1, 6), "/tmp/bar.txt", "cfile fallback")
	-- markdown buffer outside any link falls back to <cfile>
	eq(target_at({ "plain words here" }, "markdown", 1, 1), "plain", "markdown no link")

	-- multibyte text before and inside the link
	local mb = "日本語 [テキスト](./a.md) 後"
	eq(target_at({ mb }, "markdown", 1, mb:find("./a.md", 1, true) - 1), "./a.md", "multibyte dest")
	eq(target_at({ mb }, "markdown", 1, mb:find("テ", 1, true)), "./a.md", "multibyte text")
	-- email autolink
	eq(target_at({ "<me@example.com>" }, "markdown", 1, 3), "mailto:me@example.com", "email autolink")

	-- scheme detection
	assert(links.has_scheme("https://example.com"))
	assert(links.has_scheme("mailto:a@b.c"))
	assert(not links.has_scheme("./a.md"))
	assert(not links.has_scheme("docs/a.md"))
	assert(not links.has_scheme("/abs/a.md"))

	-- path resolution
	eq(links.resolve_path("./a.md#sec", "/base/dir"), "/base/dir/a.md", "relative + anchor")
	eq(links.resolve_path("../b.md", "/base/dir"), "/base/b.md", "parent")
	eq(links.resolve_path("/abs/c.md", "/base/dir"), "/abs/c.md", "absolute")
	eq(links.resolve_path("~/x.md", "/base/dir"), vim.fn.expand("~") .. "/x.md", "tilde")

	-- external classification
	assert(links.is_external_file("a/b.PNG"))
	assert(links.is_external_file("doc.pdf"))
	assert(not links.is_external_file("a.md"))

	-- open(): dispatch
	local opened, notified = {}, {}
	vim.ui.open = function(t)
		table.insert(opened, t)
		return { wait = function() end }, nil
	end
	vim.notify = function(msg, level)
		table.insert(notified, { msg, level })
	end
	local temp = vim.fn.resolve(vim.fn.tempname())
	vim.fn.mkdir(temp, "p")
	vim.fn.writefile({ "hi" }, temp .. "/note.md")
	vim.fn.writefile({ "x" }, temp .. "/pic.png")
	vim.cmd("enew!")
	vim.api.nvim_buf_set_name(0, temp .. "/cur.md")

	links.open("https://example.com")
	eq(opened[1], "https://example.com", "open url")
	links.open("pic.png")
	eq(opened[2], temp .. "/pic.png", "open image externally")
	links.open("missing.md")
	eq(#opened, 2, "missing not opened")
	eq(notified[1][2], vim.log.levels.WARN, "missing warns")
	links.open("note.md#top")
	eq(vim.fn.resolve(vim.api.nvim_buf_get_name(0)), temp .. "/note.md", "edit text file")
	eq(#opened, 2, "text not opened externally")

	-- URI-encoded path
	vim.fn.writefile({ "x" }, temp .. "/my file.md")
	eq(links.find_path("my%20file.md", temp), temp .. "/my file.md", "uri decode")
	-- '#' in a real filename wins over anchor stripping
	vim.fn.writefile({ "x" }, temp .. "/a#b.md")
	eq(links.find_path("a#b.md", temp), temp .. "/a#b.md", "raw hash filename")
	eq(links.find_path("note.md#top", temp), temp .. "/note.md", "anchor stripped fallback")
	-- scheme-like name that exists as a file
	vim.fn.writefile({ "x" }, temp .. "/note:1.md")
	vim.cmd("enew!")
	vim.api.nvim_buf_set_name(0, temp .. "/cur2.md")
	local before = #opened
	links.open("note:1.md")
	eq(#opened, before, "scheme-like file not opened externally")
	eq(vim.fn.resolve(vim.api.nvim_buf_get_name(0)), temp .. "/note:1.md", "scheme-like file edited")

	-- same-file anchor: no directory open, jumps to heading
	vim.cmd("enew!")
	vim.api.nvim_buf_set_name(0, temp .. "/cur3.md")
	vim.api.nvim_buf_set_lines(0, 0, -1, false, { "intro", "", "## My Section", "body" })
	links.open("#my-section")
	eq(vim.api.nvim_win_get_cursor(0)[1], 3, "heading jump")
	eq(vim.api.nvim_buf_get_name(0), temp .. "/cur3.md", "anchor keeps buffer")
	local n = #notified
	links.open("#")
	eq(#notified, n, "bare # is no-op")

	-- edit failure (E37: modified buffer) is reported as ERROR
	vim.bo.modified = true
	vim.bo.bufhidden = ""
	vim.o.hidden = false
	links.open("note.md")
	eq(notified[#notified][2], vim.log.levels.ERROR, "edit failure notifies")
	vim.bo.modified = false

	-- workspace-root-relative paths, directories -> explorer
	local explorer_cwd, revealed, focused, set_cwd_to, explorer_open, default_opened
	explorer_open = true
	local fake_explorer = {
		cwd = function()
			return explorer_root
		end,
		set_cwd = function(_, dir)
			set_cwd_to = dir
		end,
		focus = function(_, win)
			focused = win
		end,
	}
	package.loaded["snacks"] = {
		picker = {
			get = function()
				return explorer_open and { fake_explorer } or {}
			end,
		},
		explorer = setmetatable({
			reveal = function(opts)
				revealed = opts.file
				return fake_explorer
			end,
		}, {
			__call = function(_, opts)
				if opts then
					explorer_cwd = opts.cwd
				else
					default_opened = true
				end
			end,
		}),
	}
	local repo = temp .. "/repo"
	vim.fn.mkdir(repo .. "/.git", "p")
	vim.fn.mkdir(repo .. "/docs", "p")
	vim.fn.mkdir(repo .. "/sub", "p")
	vim.fn.writefile({ "x" }, repo .. "/docs/a.md")
	local function enter(dir)
		vim.cmd("enew!")
		vim.api.nvim_buf_set_name(0, dir .. "/cur" .. vim.uv.hrtime() .. ".md")
	end
	enter(repo .. "/sub")
	eq(links.workspace_root(repo .. "/sub"), repo, "git root")
	explorer_root = repo
	links.open("/docs")
	eq(revealed, repo .. "/docs", "dir inside root is revealed")
	eq(explorer_cwd, nil, "dir inside root keeps explorer root")
	eq(focused, "list", "explorer focused")
	eq(set_cwd_to, nil, "set_cwd not called")
	-- link to the root itself: focus only, no reveal / re-root
	revealed, focused = nil, nil
	links.open("/")
	eq(revealed, nil, "root not revealed")
	eq(set_cwd_to, nil, "root keeps explorer root")
	eq(focused, "list", "root focuses explorer")
	-- root itself while explorer is closed: open with default root
	explorer_open = false
	links.open(vim.fn.getcwd())
	eq(default_opened, true, "closed explorer opens at default root")
	eq(explorer_cwd, nil, "closed explorer keeps root")
	explorer_open, default_opened = true, nil
	-- explorer root "/" : everything below is inside
	explorer_root = "/"
	revealed = nil
	links.open("/docs")
	eq(revealed, repo .. "/docs", "cwd / detects children")
	explorer_root = repo
	-- directory outside the explorer root falls back to re-rooting
	revealed = nil
	explorer_root = repo .. "/sub"
	links.open("/docs")
	eq(revealed, nil, "dir outside root not revealed")
	eq(explorer_cwd, repo .. "/docs", "dir outside root re-roots explorer")
	links.open("/docs/a.md")
	eq(vim.fn.resolve(vim.api.nvim_buf_get_name(0)), repo .. "/docs/a.md", "root-relative file edits")
	-- worktree-style .git file
	local wt = temp .. "/wt"
	vim.fn.mkdir(wt .. "/docs", "p")
	vim.fn.writefile({ "gitdir: x" }, wt .. "/.git")
	eq(links.workspace_root(wt .. "/docs"), wt, "git file root")
	-- real absolute path fallback
	enter(repo .. "/sub")
	links.open(temp .. "/note.md")
	eq(vim.fn.resolve(vim.api.nvim_buf_get_name(0)), temp .. "/note.md", "absolute fallback")
	-- missing root-relative path warns with root-resolved path
	enter(repo .. "/sub")
	links.open("/nope.md")
	local last = notified[#notified]
	eq(last[2], vim.log.levels.WARN, "missing warns")
	assert(last[1]:find(repo .. "/nope.md", 1, true), last[1])
	-- no git root: cwd fallback
	local plain = temp .. "/plain"
	vim.fn.mkdir(plain, "p")
	eq(links.workspace_root(plain), vim.fn.getcwd(), "cwd fallback")

	-- vim.ui.open error is notified
	vim.ui.open = function()
		return nil, "boom"
	end
	links.open("https://example.com")
	eq(notified[#notified][2], vim.log.levels.ERROR, "ui.open error notifies")

	vim.fn.delete(temp, "rf")
end

local ok, error = xpcall(run, debug.traceback)
if not ok then
	vim.api.nvim_err_writeln(error)
	vim.cmd("cquit 1")
end
vim.cmd("qa!")
