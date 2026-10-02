local M = {}

local external_exts = {
	png = true,
	jpg = true,
	jpeg = true,
	gif = true,
	webp = true,
	svg = true,
	bmp = true,
	ico = true,
	pdf = true,
	mp4 = true,
	mov = true,
	mkv = true,
	webm = true,
	mp3 = true,
	wav = true,
}

local link_nodes = {
	inline_link = "link_destination",
	image = "link_destination",
	uri_autolink = true,
	email_autolink = true,
}

local function strip_angle(text)
	return (text:gsub("^<(.*)>$", "%1"))
end

local function markdown_target()
	local ok, node = pcall(function()
		local parser = vim.treesitter.get_parser(0, "markdown")
		parser:parse(true)
		return vim.treesitter.get_node({ ignore_injections = false })
	end)
	if not ok then
		return nil
	end
	while node do
		local kind = link_nodes[node.type and node:type()]
		if kind then
			local text
			if kind == true then
				text = strip_angle(vim.treesitter.get_node_text(node, 0))
				if node:type() == "email_autolink" then
					text = "mailto:" .. text
				end
			else
				for child in node:iter_children() do
					if child:type() == kind then
						text = strip_angle(vim.treesitter.get_node_text(child, 0))
						break
					end
				end
			end
			if text and text ~= "" then
				return text
			end
		end
		node = node:parent()
	end
	return nil
end

function M.get_target()
	local target
	if vim.bo.filetype == "markdown" then
		target = markdown_target()
	end
	if not target then
		target = vim.fn.expand("<cfile>")
	end
	if target == "" then
		return nil
	end
	return target
end

function M.has_scheme(target)
	return target:match("^%a[%w+.-]*:") ~= nil
end

function M.is_external_file(path)
	local ext = path:match("%.([^./]+)$")
	return ext ~= nil and external_exts[ext:lower()] == true
end

function M.resolve_path(target, base_dir, root)
	local path = target:gsub("#.*$", "")
	if root and path:sub(1, 1) == "/" then
		return M.absolute(root .. path, base_dir)
	end
	return M.absolute(path, base_dir)
end

-- Workspace root: git root (directory or worktree file) of base_dir, else cwd.
function M.workspace_root(base_dir)
	return vim.fs.root(base_dir, ".git") or vim.fn.getcwd()
end

function M.absolute(path, base_dir)
	path = vim.fs.normalize(path)
	if path:sub(1, 1) ~= "/" then
		path = vim.fs.normalize(base_dir .. "/" .. path)
	end
	return path
end

local function exists(path)
	return vim.uv.fs_stat(path) ~= nil
end

local function decode(text)
	local ok, decoded = pcall(vim.uri_decode, text)
	return ok and decoded or text
end

-- Returns the first existing path among raw / stripped-of-anchor, each
-- optionally URI-decoded. Returns nil if none exists.
function M.find_path(target, base_dir, root)
	local stripped = target:gsub("#.*$", "")
	local seen = {}
	for _, text in ipairs({ target, decode(target), stripped, decode(stripped) }) do
		if text ~= "" and not seen[text] then
			seen[text] = true
			if root and text:sub(1, 1) == "/" then
				local rooted = M.absolute(root .. text, base_dir)
				if exists(rooted) then
					return rooted
				end
			end
			local path = M.absolute(text, base_dir)
			if exists(path) then
				return path
			end
		end
	end
	return nil
end

local function slugify(text)
	text = text:lower():gsub("[%p]", function(c)
		return (c == "-" or c == "_") and c or ""
	end)
	return (text:gsub("%s", "-"))
end

local function goto_heading(anchor)
	anchor = slugify(decode(anchor))
	for lnum, line in ipairs(vim.api.nvim_buf_get_lines(0, 0, -1, false)) do
		local heading = line:match("^#+%s+(.-)%s*$")
		if heading and slugify(heading) == anchor then
			vim.api.nvim_win_set_cursor(0, { lnum, 0 })
			return true
		end
	end
	return false
end

local function external_open(target)
	local _, err = vim.ui.open(target)
	if err then
		vim.notify("Failed to open " .. target .. ": " .. err, vim.log.levels.ERROR)
	end
end

-- Show a directory in the snacks explorer without changing its root (cwd).
-- snacks' reveal only works for paths under the explorer cwd (for others it
-- neither shows the path nor moves the root), so fall back to re-rooting there.
local function open_directory(path)
	local snacks = require("snacks")
	local explorer = snacks.picker.get({ source = "explorer" })[1]
	local cwd = explorer and explorer:cwd() or vim.fn.getcwd()
	if path == cwd then
		-- reveal would treat the root itself as outside and move the root up
		if explorer then
			explorer:focus("list", { show = true })
		else
			snacks.explorer()
		end
		return
	end
	local prefix = cwd:gsub("/$", "") .. "/"
	if path:sub(1, #prefix) ~= prefix then
		return snacks.explorer({ cwd = path })
	end
	explorer = snacks.explorer.reveal({ file = path })
	if explorer then
		explorer:focus("list", { show = true })
	end
end

function M.open(target)
	if target:sub(1, 1) == "#" then
		if #target > 1 and not goto_heading(target:sub(2)) then
			vim.notify("Heading not found: " .. target, vim.log.levels.WARN)
		end
		return
	end
	local name = vim.api.nvim_buf_get_name(0)
	local base_dir = name ~= "" and vim.fs.dirname(name) or vim.fn.getcwd()
	local root = M.workspace_root(base_dir)
	local path = M.find_path(target, base_dir, root)
	if not path then
		if M.has_scheme(target) then
			return external_open(target)
		end
		vim.notify("Not found: " .. M.resolve_path(target, base_dir, root), vim.log.levels.WARN)
		return
	end
	if M.is_external_file(path) then
		return external_open(path)
	end
	if vim.fn.isdirectory(path) == 1 then
		return open_directory(path)
	end
	local ok, err = pcall(vim.cmd.edit, vim.fn.fnameescape(path))
	if not ok then
		vim.notify("Failed to open " .. path .. ": " .. tostring(err), vim.log.levels.ERROR)
	end
end

function M.open_under_cursor()
	local target = M.get_target()
	if not target then
		vim.notify("No link under cursor", vim.log.levels.WARN)
		return
	end
	M.open(target)
end

require("dotfiles.util").map("n", "gx", M.open_under_cursor, "Open link under cursor")

return M
