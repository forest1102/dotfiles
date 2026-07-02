vim.g.mapleader = " "
vim.g.maplocalleader = " "

vim.opt.autowrite = true
vim.opt.breakindent = true
vim.opt.clipboard = "unnamedplus"
vim.opt.completeopt = { "menu", "menuone", "noselect" }
vim.opt.confirm = true
vim.opt.cursorline = true
vim.opt.expandtab = true
vim.opt.ignorecase = true
vim.opt.inccommand = "split"
vim.opt.number = true
vim.opt.relativenumber = false
vim.opt.scrolloff = 8
vim.opt.shiftwidth = 2
vim.opt.signcolumn = "yes"
vim.opt.smartcase = true
vim.opt.splitbelow = true
vim.opt.splitright = true
vim.opt.tabstop = 2
vim.opt.termguicolors = true
vim.opt.updatetime = 250
vim.opt.fillchars = {
  eob = " ",
  fold = " ",
  foldclose = "+",
  foldopen = "-",
  foldsep = " ",
}

local keymap = vim.keymap.set
local opts = { noremap = true, silent = true }
local Snacks = require("snacks")
local ascii_border = { "+", "-", "+", "|", "+", "-", "+", "|" }

local function close_current_view()
  local win = vim.api.nvim_get_current_win()
  local ok, config = pcall(vim.api.nvim_win_get_config, win)
  if ok and config.relative ~= "" then
    vim.api.nvim_win_close(win, true)
    return
  end

  if #vim.api.nvim_tabpage_list_wins(0) > 1 then
    vim.cmd("quit")
    return
  end

  local force = vim.bo.buftype ~= ""
  vim.cmd(force and "bdelete!" or "bdelete")
end

local function toggle_focus_explorer()
  local explorer = Snacks.picker.get({ source = "explorer" })[1]
  if not explorer or explorer.closed then
    Snacks.explorer()
    return
  end

  if vim.bo.filetype:match("^snacks_") then
    vim.cmd("wincmd p")
  else
    explorer:focus("list", { show = true })
  end
end

keymap("n", "<leader>s", "<cmd>write<cr>", vim.tbl_extend("force", opts, { desc = "Write buffer" }))
keymap("n", "<leader>q", "<cmd>quit<cr>", vim.tbl_extend("force", opts, { desc = "Quit window" }))
keymap("n", "<leader>Q", "<cmd>qa<cr>", vim.tbl_extend("force", opts, { desc = "Quit Neovim" }))
keymap({ "n", "t" }, "<C-q>", close_current_view, vim.tbl_extend("force", opts, { desc = "Close current view" }))

vim.api.nvim_create_autocmd("FileType", {
  pattern = { "snacks_*", "trouble" },
  command = "setlocal nonumber norelativenumber signcolumn=no foldcolumn=0",
})
vim.api.nvim_create_autocmd("TermOpen", {
  command = "setlocal nonumber norelativenumber signcolumn=no foldcolumn=0",
})

Snacks.setup({
  explorer = { enabled = true, replace_netrw = true },
  input = { enabled = true },
  notifier = { enabled = true, timeout = 3000 },
  picker = {
    enabled = true,
    prompt = "> ",
    sources = {
      explorer = {
        hidden = true,
        ignored = true,
        layout = { preset = "sidebar", preview = false, layout = { position = "left", width = 32 } },
      },
      files = {
        hidden = true,
        ignored = true,
      },
    },
  },
  quickfile = { enabled = true },
  terminal = { win = { position = "bottom", height = 0.30 } },
})

local which_key = require("which-key")
which_key.setup({})
which_key.add({
  { "<leader>f", group = "Find" },
  { "<leader>fb", desc = "Buffers" },
  { "<leader>ff", desc = "Find files" },
  { "<leader>fg", desc = "Grep" },
  { "<leader>g", group = "Git" },
  { "<leader>gd", desc = "Git diff" },
  { "<leader>ge", desc = "Changed files explorer" },
  { "<leader>gi", desc = "GitHub issues" },
  { "<leader>gg", desc = "LazyGit" },
  { "<leader>gs", desc = "Git status" },
  { "<leader>l", group = "LSP" },
  { "<leader>la", desc = "Code action" },
  { "<leader>lf", desc = "Format" },
  { "<leader>lr", desc = "Rename" },
  { "<leader>m", group = "Markdown" },
  { "<leader>t", group = "Terminal" },
  { "<leader>tt", desc = "Toggle terminal" },
  { "<leader>w", group = "Worktree" },
  { "<leader>wc", desc = "Create worktree" },
  { "<leader>wd", desc = "Delete current worktree" },
  { "<leader>ww", desc = "Select worktree" },
  { "<leader>x", group = "Diagnostics" },
  { "<leader>xx", desc = "Diagnostics" },
  { "<leader>xX", desc = "Buffer diagnostics" },
  { "<leader>c", desc = "Focus Claude" },
  { "<leader>C", group = "Claude" },
  { "<leader>CA", desc = "Continue Claude" },
  { "<leader>Ca", desc = "Accept Claude diff" },
  { "<leader>Cb", desc = "Add current buffer" },
  { "<leader>Cd", desc = "Deny Claude diff" },
  { "<leader>Cf", desc = "Focus Claude" },
  { "<leader>Cm", desc = "Select Claude model" },
  { "<leader>Cr", desc = "Resume Claude" },
})
which_key.add({
  { "<leader>C", group = "Claude", mode = "v" },
  { "<leader>Cs", desc = "Send selection to Claude", mode = "v" },
})

keymap("n", "<leader>e", function()
  toggle_focus_explorer()
end, vim.tbl_extend("force", opts, { desc = "Toggle Focus Explorer" }))

local function open_initial_explorer()
  if #vim.api.nvim_list_uis() == 0 then
    return
  end

  local first_arg = vim.fn.argv(0)
  if type(first_arg) == "string" and vim.fn.isdirectory(first_arg) == 1 then
    local cwd = vim.fn.fnamemodify(first_arg, ":p"):gsub("/$", "")
    vim.fn.chdir(cwd)
    pcall(vim.api.nvim_buf_delete, vim.api.nvim_get_current_buf(), { force = true })
    Snacks.explorer({ cwd = cwd })
    return
  end

  local current_file = vim.api.nvim_buf_get_name(0)
  if current_file ~= "" and vim.fn.filereadable(current_file) == 1 then
    Snacks.explorer.reveal({ file = current_file })
  else
    Snacks.explorer()
  end
end

vim.api.nvim_create_autocmd("VimEnter", {
  callback = function()
    vim.schedule(open_initial_explorer)
  end,
})
keymap("n", "<leader>ff", function()
  Snacks.picker.files({ hidden = true, ignored = true })
end, vim.tbl_extend("force", opts, { desc = "Find files" }))
keymap("n", "<leader>fg", function()
  Snacks.picker.grep()
end, vim.tbl_extend("force", opts, { desc = "Grep" }))
keymap("n", "<leader>fb", function()
  Snacks.picker.buffers()
end, vim.tbl_extend("force", opts, { desc = "Buffers" }))
keymap("n", "<leader>tt", function()
  Snacks.terminal.toggle()
end, vim.tbl_extend("force", opts, { desc = "Toggle terminal" }))

keymap("t", "<C-]>", [[<C-\><C-n>]], vim.tbl_extend("force", opts, { desc = "Terminal normal mode" }))
keymap("t", "<C-h>", [[<Cmd>wincmd h<CR>]], vim.tbl_extend("force", opts, { desc = "Move left" }))
keymap("t", "<C-j>", [[<Cmd>wincmd j<CR>]], vim.tbl_extend("force", opts, { desc = "Move down" }))
keymap("t", "<C-k>", [[<Cmd>wincmd k<CR>]], vim.tbl_extend("force", opts, { desc = "Move up" }))
keymap("t", "<C-l>", [[<Cmd>wincmd l<CR>]], vim.tbl_extend("force", opts, { desc = "Move right" }))

require("gitsigns").setup({
  numhl = true,
})
local function open_changed_files_explorer()
  Snacks.picker.git_status({
    title = "Changed files",
    show_empty = true,
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

keymap("n", "<leader>gs", function()
  Snacks.picker.git_status({ show_empty = true })
end, vim.tbl_extend("force", opts, { desc = "Git status" }))
keymap("n", "<leader>gd", function()
  Snacks.picker.git_diff({ show_empty = true })
end, vim.tbl_extend("force", opts, { desc = "Git diff" }))
vim.api.nvim_create_user_command("GitChangedFiles", open_changed_files_explorer, { desc = "Show changed files" })
keymap("n", "<leader>ge", open_changed_files_explorer, vim.tbl_extend("force", opts, { desc = "Changed files explorer" }))
keymap("n", "<leader>gg", function()
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
end, vim.tbl_extend("force", opts, { desc = "LazyGit" }))

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
keymap("n", "<leader>wc", create_worktree, vim.tbl_extend("force", opts, { desc = "Create worktree" }))
keymap("n", "<leader>wd", delete_current_worktree, vim.tbl_extend("force", opts, { desc = "Delete current worktree" }))
keymap("n", "<leader>ww", select_worktree, vim.tbl_extend("force", opts, { desc = "Select worktree" }))
keymap("n", "<leader>gi", list_github_issues, vim.tbl_extend("force", opts, { desc = "GitHub issues" }))

require("lualine").setup({
  options = {
    globalstatus = true,
  },
})

require("todo-comments").setup({})
require("trouble").setup({})
keymap("n", "<leader>xx", "<cmd>Trouble diagnostics toggle<cr>", vim.tbl_extend("force", opts, { desc = "Diagnostics" }))
keymap("n", "<leader>xX", "<cmd>Trouble diagnostics toggle filter.buf=0<cr>", vim.tbl_extend("force", opts, { desc = "Buffer diagnostics" }))

require("markview").setup({
  preview = {
    enable = false,
    enable_hybrid_mode = false,
    filetypes = { "markdown" },
    condition = function(buffer)
      return vim.bo[buffer].filetype == "markdown"
    end,
    icon_provider = "devicons",
    map_gx = false,
  },
})

local function toggle_markview_preview()
  if vim.bo.filetype ~= "markdown" then
    return
  end

  local actions = require("markview.actions")
  local state = require("markview.state")
  local buffer = vim.api.nvim_get_current_buf()

  if not state.buf_attached(buffer) then
    actions.attach(buffer)
    actions.enable(buffer)
    return
  end

  actions.toggle(buffer)
end

keymap("n", "<leader>mr", toggle_markview_preview, vim.tbl_extend("force", opts, { desc = "Markdown preview" }))
keymap("n", "<leader>ms", "<cmd>Markview splitToggle<cr>", vim.tbl_extend("force", opts, { desc = "Markdown split preview" }))

vim.api.nvim_create_autocmd("FileType", {
  pattern = {
    "bash",
    "css",
    "html",
    "javascript",
    "javascriptreact",
    "json",
    "lua",
    "markdown",
    "nix",
    "toml",
    "typescript",
    "typescriptreact",
    "vim",
    "yaml",
  },
  callback = function()
    pcall(vim.treesitter.start)
    vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
  end,
})

vim.diagnostic.config({
  severity_sort = true,
  virtual_text = {
    spacing = 2,
    source = "if_many",
  },
  float = {
    border = ascii_border,
    source = true,
  },
})

local lsp_capabilities = require("blink.cmp").get_lsp_capabilities()
require("blink.cmp").setup({
  keymap = {
    preset = "default",
  },
  completion = {
    documentation = {
      auto_show = true,
      auto_show_delay_ms = 300,
    },
    menu = {
      draw = {
        columns = {
          { "label", "label_description", gap = 1 },
          { "kind" },
        },
        components = {
          label = {
            ellipsis = false,
          },
          label_description = {
            ellipsis = false,
          },
        },
      },
    },
  },
  sources = {
    default = { "lsp", "path", "snippets", "buffer" },
  },
})

local servers = {
  bashls = {},
  cssls = {},
  eslint = {},
  html = {},
  jsonls = {},
  lua_ls = {
    settings = {
      Lua = {
        diagnostics = {
          globals = { "vim" },
        },
        runtime = {
          version = "LuaJIT",
        },
        telemetry = {
          enable = false,
        },
        workspace = {
          checkThirdParty = false,
        },
      },
    },
  },
  marksman = {},
  nixd = {
    settings = {
      nixd = {
        formatting = {
          command = { "nixfmt" },
        },
      },
    },
  },
  tailwindcss = {},
  ts_ls = {},
}

for name, config in pairs(servers) do
  config.capabilities = lsp_capabilities
  vim.lsp.config(name, config)
  vim.lsp.enable(name)
end

vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(event)
    local map = function(lhs, rhs, desc)
      keymap("n", lhs, rhs, { buffer = event.buf, desc = desc, silent = true })
    end

    map("gd", vim.lsp.buf.definition, "Go to definition")
    map("gD", vim.lsp.buf.declaration, "Go to declaration")
    map("gi", vim.lsp.buf.implementation, "Go to implementation")
    map("gr", vim.lsp.buf.references, "References")
    map("K", vim.lsp.buf.hover, "Hover")
    map("<leader>la", vim.lsp.buf.code_action, "Code action")
    map("<leader>lr", vim.lsp.buf.rename, "Rename")
  end,
})

require("conform").setup({
  formatters_by_ft = {
    bash = { "shfmt" },
    css = { "prettierd" },
    html = { "prettierd" },
    javascript = { "prettierd" },
    javascriptreact = { "prettierd" },
    json = { "prettierd" },
    lua = { "stylua" },
    markdown = { "prettierd" },
    nix = { "nixfmt" },
    sh = { "shfmt" },
    typescript = { "prettierd" },
    typescriptreact = { "prettierd" },
    yaml = { "prettierd" },
  },
})
keymap({ "n", "v" }, "<leader>lf", function()
  require("conform").format({ async = true, lsp_format = "fallback" })
end, vim.tbl_extend("force", opts, { desc = "Format" }))

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

keymap({ "n", "i", "t" }, "<C-g>", "<cmd>ClaudeCode<cr>", vim.tbl_extend("force", opts, { desc = "Toggle Claude Code" }))
keymap("n", "<leader>c", "<cmd>ClaudeCodeFocus<cr>", vim.tbl_extend("force", opts, { desc = "Focus Claude" }))
keymap("n", "<leader>Cf", "<cmd>ClaudeCodeFocus<cr>", vim.tbl_extend("force", opts, { desc = "Focus Claude" }))
keymap("n", "<leader>Cr", "<cmd>ClaudeCode --resume<cr>", vim.tbl_extend("force", opts, { desc = "Resume Claude" }))
keymap("n", "<leader>CA", "<cmd>ClaudeCode --continue<cr>", vim.tbl_extend("force", opts, { desc = "Continue Claude" }))
keymap("n", "<leader>Cm", "<cmd>ClaudeCodeSelectModel<cr>", vim.tbl_extend("force", opts, { desc = "Select Claude model" }))
keymap("n", "<leader>Cb", "<cmd>ClaudeCodeAdd %<cr>", vim.tbl_extend("force", opts, { desc = "Add current buffer" }))
keymap("v", "<leader>Cs", "<cmd>ClaudeCodeSend<cr>", vim.tbl_extend("force", opts, { desc = "Send selection to Claude" }))
keymap("n", "<leader>Ca", "<cmd>ClaudeCodeDiffAccept<cr>", vim.tbl_extend("force", opts, { desc = "Accept Claude diff" }))
keymap("n", "<leader>Cd", "<cmd>ClaudeCodeDiffDeny<cr>", vim.tbl_extend("force", opts, { desc = "Deny Claude diff" }))
