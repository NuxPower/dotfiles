-- ==========================================
-- 1. BASIC SETTINGS
-- ==========================================
vim.opt.clipboard = "unnamedplus" 
vim.g.mapleader = " "             
vim.opt.number = true             
vim.opt.relativenumber = true     
vim.opt.termguicolors = true      
vim.opt.shiftwidth = 4            
vim.opt.expandtab = true          -- Use spaces instead of tabs
vim.opt.smartindent = true

-- Fix transparency to match Kitty/Hyprland
vim.api.nvim_set_hl(0, "Normal", { bg = "none" })
vim.api.nvim_set_hl(0, "NormalFloat", { bg = "none" })
vim.api.nvim_set_hl(0, "NormalNC", { bg = "none" })
vim.api.nvim_set_hl(0, "NvimTreeNormal", { bg = "none" })
vim.api.nvim_set_hl(0, "NvimTreeNormalNC", { bg = "none" })
vim.api.nvim_set_hl(0, "DashboardHeader", { bg = "none" })
vim.api.nvim_set_hl(0, "DashboardCenter", { bg = "none" })

-- Register Laravel Blade files
vim.filetype.add({
  pattern = {
    ['.*%.blade%.php'] = 'blade',
  },
})

-- ==========================================
-- 2. BOOTSTRAP LAZY.NVIM
-- ==========================================
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  vim.fn.system({
    "git", "clone", "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git", "--branch=stable", lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- ==========================================
-- 3. PLUGIN LIST (ONLY ONE LAZY SETUP CALL)
-- ==========================================
require("lazy").setup({
  -- Colorscheme
    { 
        "folke/tokyonight.nvim", 
        lazy = false, 
        priority = 1000, 
        config = function() 
          vim.cmd.colorscheme("tokyonight-night") -- 'night' variant is the best indigo match
        end 
    },
  -- { "catppuccin/nvim", name = "catppuccin", priority = 1000, 
  --   config = function() vim.cmd.colorscheme("catppuccin-mocha") end 
  -- },

  -- Dashboard
  {
    'nvimdev/dashboard-nvim',
    event = 'VimEnter',
    config = function()
      require('dashboard').setup({ theme = 'hyper' })
    end,
    dependencies = { {'nvim-tree/nvim-web-devicons'}}
  },

  -- Telescope & Project Manager
  { 'nvim-telescope/telescope.nvim', dependencies = { 'nvim-lua/plenary.nvim' } },
  {
    "ahmedkhalf/project.nvim",
    config = function()
      require("project_nvim").setup({
        detection_methods = { "pattern" },
        patterns = { ".git", "_darcs", ".hg", ".bzr", ".svn", "Makefile", "package.json" },
      })
    end,
  },
  
  -- Comments
  {
    'numToStr/Comment.nvim',
    config = function() require('Comment').setup() end
  },

  -- Treesitter
  { 
    "nvim-treesitter/nvim-treesitter", 
    build = ":TSUpdate",
    config = function() 
      require("nvim-treesitter.parsers").blade = {
        install_info = {
          url = "https://github.com/EmranMR/tree-sitter-blade",
          files = {"src/parser.c"},
          branch = "main",
        },
        filetype = "blade",
      }

      local ok, configs = pcall(require, "nvim-treesitter.configs")
      if not ok then return end
      
      configs.setup({
        ensure_installed = { "lua", "php", "blade", "html", "javascript" },
        highlight = { enable = true },
        indent = { enable = true },
      })
    end
  },

  -- LSP Management
  { "neovim/nvim-lspconfig" },
  { "williamboman/mason.nvim", config = true },
  { "williamboman/mason-lspconfig.nvim", config = true },
  
  -- ==========================================
  -- AI AND AUTO-COMPLETION
  -- ==========================================
  {
    "Exafunction/codeium.nvim",
    dependencies = {
        "nvim-lua/plenary.nvim",
        "hrsh7th/nvim-cmp",
    },
    config = function()
        require("codeium").setup({})
    end
  },
  { 
    "hrsh7th/nvim-cmp", 
    dependencies = { "hrsh7th/cmp-nvim-lsp", "L3MON4D3/LuaSnip", "onsails/lspkind.nvim" },
    config = function()
        local cmp = require('cmp')
        local lspkind = require('lspkind')
        cmp.setup({
            window = {
                completion = cmp.config.window.bordered(),
                documentation = cmp.config.window.bordered(),
            },
            formatting = {
                format = lspkind.cmp_format({ mode = 'symbol_text', maxwidth = 50 })
            },
            snippet = { expand = function(args) require('luasnip').lsp_expand(args.body) end },
            mapping = cmp.mapping.preset.insert({
                ['<C-Space>'] = cmp.mapping.complete(),
                ['<CR>'] = cmp.mapping.confirm({ select = true }),
                ['<Tab>'] = cmp.mapping.select_next_item(),
                ['<S-Tab>'] = cmp.mapping.select_prev_item(),
            }),
            -- AI is injected into sources here!
            sources = cmp.config.sources({
                { name = 'nvim_lsp' },
                { name = 'codeium' }, 
            }, {
                { name = 'buffer' }
            })
        })
    end
  },

  -- Flutter
  { 'akinsho/flutter-tools.nvim', lazy = false, dependencies = { 'nvim-lua/plenary.nvim' }, config = true },

  -- Auto-formatting
  { "stevearc/conform.nvim",
    config = function()
      require("conform").setup({
        formatters_by_ft = {
          javascript = { "prettier" },
          typescript = { "prettier" },
          python = { "black" },
          c = { "clang-format" },
          cpp = { "clang-format" },
          php = { "php_cs_fixer" }, 
          blade = { "blade-formatter" }, 
        },        
        format_on_save = { timeout_ms = 3000, lsp_fallback = true },
      })
    end,
  },

-- Nvim Tree
  {
    "nvim-tree/nvim-tree.lua",
    version = "*",
    lazy = false,
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      require("nvim-tree").setup {
        -- This makes the tree follow your current file/project
        sync_root_with_cwd = true,
        respect_buf_cwd = true,
        update_focused_file = {
          enable = true,
          update_root = true,
        },
      }
      vim.keymap.set('n', '<leader>e', ':NvimTreeToggle<CR>', { silent = true })
    end,
  },

    -- Status Line
    {
        'nvim-lualine/lualine.nvim',
        dependencies = { 'nvim-tree/nvim-web-devicons' },
        config = function() 
          require('lualine').setup { 
            options = { 
              theme = 'tokyonight' -- Explicitly set to match the new theme
            } 
          } 
        end
    },
  -- {
  --   'nvim-lualine/lualine.nvim',
  --   dependencies = { 
  --     'nvim-tree/nvim-web-devicons',
  --     'catppuccin/nvim' -- Force catppuccin to be available
  --   },
  --   config = function() 
  --     require('lualine').setup { 
  --       options = { 
  --         -- Using 'auto' is safer; it will detect your Mocha theme automatically
  --         theme = 'auto' 
  --       } 
  --     } 
  --   end
  -- },
})

-- ==========================================
-- 4. NEOVIM 0.11+ LSP CONFIGURATION
-- ==========================================
local capabilities = require('cmp_nvim_lsp').default_capabilities()
local servers = { 'ts_ls', 'pyright', 'clangd', 'omnisharp', 'rust_analyzer', 'intelephense', 'html', 'emmet_language_server', 'tailwindcss' }

for _, server in ipairs(servers) do
    vim.lsp.config(server, { capabilities = capabilities })
    vim.lsp.enable(server)
end

-- LSP Keybinds
vim.api.nvim_create_autocmd('LspAttach', {
  callback = function(args)
    local opts = { buffer = args.buf }
    vim.keymap.set('n', 'gd', vim.lsp.buf.definition, opts)
    vim.keymap.set('n', 'K', vim.lsp.buf.hover, opts)
    vim.keymap.set('n', '<leader>rn', vim.lsp.buf.rename, opts)
    vim.keymap.set('n', '<leader>ca', vim.lsp.buf.code_action, opts)
  end,
})

-- ==========================================
-- 5. TELESCOPE & GENERAL KEYBINDS
-- ==========================================
local builtin = require('telescope.builtin')
local telescope = require('telescope')
telescope.load_extension('projects')
vim.keymap.set('n', '<leader>ff', builtin.find_files, {})
vim.keymap.set('n', '<leader>fg', builtin.live_grep, {})
vim.keymap.set('n', '<leader>p', function() telescope.extensions.projects.projects({}) end, {})

-- Dashboard
vim.keymap.set('n', '<leader>h', ':bd | Dashboard<CR>', { desc = 'Return to Home Dashboard', silent = true })

-- Visual Indent
vim.keymap.set("v", "<Tab>", ">gv")
vim.keymap.set("v", "<S-Tab>", "<gv")

-- Deleting words in insert mode
vim.keymap.set("i", "<C-BS>", "<C-w>", { noremap = true, silent = true })
vim.keymap.set("i", "<C-H>", "<C-w>", { noremap = true, silent = true })
vim.keymap.set("i", "<C-Delete>", "<C-o>dw", { noremap = true, silent = true })

-- Fix for Blade comments
vim.api.nvim_create_autocmd("FileType", {
  pattern = "blade",
  callback = function()
    vim.opt_local.commentstring = "{{-- %s --}}"
  end,
}) -- Added the missing }
