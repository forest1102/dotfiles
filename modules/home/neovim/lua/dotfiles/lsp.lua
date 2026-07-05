local util = require("dotfiles.util")

vim.diagnostic.config({
	severity_sort = true,
	virtual_text = {
		spacing = 2,
		source = "if_many",
	},
	float = {
		border = util.ascii_border,
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
			vim.keymap.set("n", lhs, rhs, { buffer = event.buf, desc = desc, silent = true })
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
util.map({ "n", "v" }, "<leader>lf", function()
	require("conform").format({ async = true, lsp_format = "fallback" })
end, "Format")
