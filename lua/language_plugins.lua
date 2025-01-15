return {
  -- A plugin for managing LSP servers, DAP servers, linters, and formatters,
  -- simplifying their installation and configuration.
  {
    "williamboman/mason.nvim",
    build = ":MasonUpdate",
    config = function()
      require("mason").setup()
    end
  },

  -- This plugin simplifies the management and configuration of LSP servers
  -- by integrating 'Mason' with `nvim-lspconfig` for automatic setup.
  {
    "williamboman/mason-lspconfig.nvim",
    -- "neovim/nvim-lspconfig" is one of the most popular plugins and is enough to have it only as a dependency.
    dependencies = { "williamboman/mason.nvim", "neovim/nvim-lspconfig" },
    config = function()
      require("mason-lspconfig").setup({
        ensure_installed = { "lua_ls", "ts_ls" },
        automatic_installation = true
      })

      local lsp_config = require("lspconfig")

      -- Configure the Lua Language Server
      lsp_config.lua_ls.setup({
        settings = {
          Lua = {
            runtime = {
              -- Specifies the Lua runtime version (Neovim uses LuaJIT for better performance).
              version = "LuaJIT",
              -- Splits Lua's module search paths into a table for the language server,
              -- ensuring it can resolve required modules correctly.
              path = vim.split(package.path, ";")
            },
            -- It prevents 'undefined global' warnings for the Neovim `vim` global.
            diagnostics = {
              globals = { "vim" }
            },
            workspace = {
              -- Expand the workspace library by combining Neovim runtime files and external libraries
              -- to provide better API support for the Lua language server.
              library = vim.tbl_extend(
                "force",
                vim.api.nvim_get_runtime_file("", true),
                { "${3rd}/luv/library" }
              ),
              -- It turns off the automatic detection of third-party libraries or configurations
              -- to avoid unnecessary warnings or conflicts.
              checkThirdParty = false
            },
            -- It turns off telemetry to prevent the collection of usage and diagnostics data,
            -- ensuring better privacy and performance.
            telemetry = {
              enable = false
            }
          }
        }
      })

      -- Configure the JavaScript and TypeScript Language Server
      lsp_config.ts_ls.setup({
        on_attach = function(client, _)
          -- Disable ts_ls's formatting to use an external tool (e.g., Prettier)
          client.server_capabilities.documentFormattingProvider = false
        end
      })
    end
  },

  -- Plugin for code formatting using external formatters.
  {
    "stevearc/conform.nvim",
    config = function()
      local conform = require("conform")
      local prettier = { "prettier" }

      conform.setup({
        formatters_by_ft = {
          javascript = prettier,
          javascriptreact = prettier,
          json = prettier,
          yaml = prettier,
          markdown = prettier
        },
        format_on_save = {
          timeout_ms = 1000, -- Maximum wait time before formatting times out.
          lsp_fallback = false -- Prevents fallback to LSP formatting if no formatter is configured for the file type.
        }
      })

      -- Define `:Format` to manually trigger formatting.
      vim.api.nvim_create_user_command("Format", function()
        conform.format()
      end, {})
    end
  },

  -- TODO: make a detector for using "eslint_d" or "eslint"?
  -- TODO: check nvim_create_autocmd. And I created a PR so that using "eslint" instead of "eslint_d" is also possible.
  {
    "mfussenegger/nvim-lint",
    config = function()
      local lint = require("lint")
      local eslint = { "eslint_d" }

      lint.linters_by_ft = {
        javascript = eslint,
        typescriptreact = eslint
      }

      vim.api.nvim_create_autocmd({ "BufWritePost", "BufReadPost", "InsertLeave", "TextChanged" }, {
        callback = function()
          lint.try_lint()
        end
      })
    end
  },

  -- This plugin can work with eslint
  -- {
  --   "nvimtools/none-ls.nvim",
  --   dependencies = {
  --     "nvimtools/none-ls-extras.nvim",
  --   },
  --   config = function()
  --     require("null-ls").setup({
  --       sources = {
  --         null_ls.builtins.formatting.stylua,
  --         null_ls.builtins.formatting.prettier,
  --         require("none-ls.diagnostics.eslint")
  --       }
  --     })
  --     vim.keymap.set("n", "<leader>gf", vim.lsp.buf.format, {})
  --   end
  -- }

  -- This plugin provides better syntax highlighting, code folding,
  -- and multi-language support than standard regex using Tree-sitter parsing.
  -- config = function() is currently not needed
  {
    "nvim-treesitter/nvim-treesitter",
    -- After installing the plugin, it updates Tree-sitter parsers by running `:TSUpdate`.
    build = ":TSUpdate",
    opts = {
      ensure_installed = {
        "css", -- CSS syntax highlighting and parsing
        "diff", -- Highlights differences in files for better readability
        "html", -- HTML syntax highlighting and parsing
        "javascript", -- JavaScript syntax highlighting and parsing
        "lua", -- Lua syntax highlighting and parsing
        "luadoc", -- Lua documentation syntax highlighting
        "markdown", -- Markdown syntax highlighting and parsing
        "markdown_inline", -- Inline Markdown highlighting and parsing
        "query", -- Tree-sitter queries for advanced highlighting and parsing
        "vim", -- Vimscript syntax highlighting and parsing
        "vimdoc" -- Vim documentation highlighting
      },
      -- For languages like Ruby that use Vim's regex for indenting,
      -- add them to `additional_vim_regex_highlighting` and `disable indent`.
      highlight = {
        enable = true
        -- additional_vim_regex_highlighting = { "ruby" }
      },
      indent = {
        enable = true
        -- disable = { "ruby" }
      }
    }
  }
}
