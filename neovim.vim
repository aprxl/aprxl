" Vim plug configuration/initialization
call plug#begin()
Plug 'neovim/nvim-lspconfig'
Plug 'jose-elias-alvarez/null-ls.nvim'
Plug 'jose-elias-alvarez/nvim-lsp-ts-utils'
Plug 'nvim-lua/plenary.nvim'
Plug 'neoclide/coc.nvim', {'branch': 'release'}
Plug 'echasnovski/mini.nvim', { 'branch': 'stable' }
Plug 'nvim-treesitter/nvim-treesitter', {'do': ':TSUpdate'}
Plug 'kyazdani42/nvim-web-devicons' 
Plug 'kyazdani42/nvim-tree.lua'
Plug 'nvim-lualine/lualine.nvim'
Plug 'kyazdani42/nvim-web-devicons'
Plug 'kassio/neoterm'
Plug 'dracula/vim', { 'as': 'dracula' }
Plug 'akinsho/bufferline.nvim', { 'tag': 'v2.*' }
Plug 'nvim-telescope/telescope.nvim'
Plug 'kdheepak/lazygit.nvim'
call plug#end()

" Neovide configuration
if exists('g:neovide')
  let g:neovide_refresh_rate=144
  let g:neovide_cursor_animation_length=0.05
  let g:neovide_cursor_trail_length=0.2
en

" Color scheme
let g:dracula_colorterm = 0
colorscheme dracula

" Tab size
:set tabstop=2
:set shiftwidth=2
:set expandtab
:set smarttab

" Line numbers
:set number

" Clipboard
:set clipboard^=unnamed,unnamedplus

" Allow mouse
:set mouse=a

" Custom keybindings
nmap <C-e> :e .<CR>
nmap <C-n> :NvimTreeToggle<CR>

nmap <Space>bi :ls<CR>
nmap <Space>bk :bw!<CR>
nmap <Space>bn :bn<CR>
nmap <Space>bp :bp<CR>
nmap <Space>qq :qa!<CR>
nmap <Space>qw :wqa<CR>
nmap <Space>fP :e $MYVIMRC<CR>
nmap <Space>gg :LazyGit<CR>
nmap <Space>nt :NvimTreeToggle<CR>
nmap <Space>tf :Telescope find_files<CR>
nmap <Space>tg :Telescope live_grep<CR>
nmap <Space>tb :Telescope buffers<CR>

inoremap <silent><expr> <TAB>
      \ pumvisible() ? "\<C-n>" :
      \   "\<TAB>" 
inoremap <expr><S-TAB> pumvisible() ? "\<C-p>" : "\<C-h>"

" Bufferline configuration
set termguicolors
lua << EOF
require("bufferline").setup{}
EOF

" Lua line configuration
lua << EOF
require('lualine').setup()
EOF

" Auto-pairs configuration
lua << EOF
require('mini.pairs').setup()
EOF

" Tree configuration
au BufEnter * :NvimTreeResize 25
lua << EOF
require('nvim-tree').setup()
EOF

" LSP configuration
lua << EOF
local lspconfig = require("lspconfig")
local null_ls = require("null-ls")
local buf_map = function(bufnr, mode, lhs, rhs, opts)
    vim.api.nvim_buf_set_keymap(bufnr, mode, lhs, rhs, opts or {
        silent = true,
    })
end
local on_attach = function(client, bufnr)
    vim.cmd("command! LspDef lua vim.lsp.buf.definition()")
    vim.cmd("command! LspFormatting lua vim.lsp.buf.formatting()")
    vim.cmd("command! LspCodeAction lua vim.lsp.buf.code_action()")
    vim.cmd("command! LspHover lua vim.lsp.buf.hover()")
    vim.cmd("command! LspRename lua vim.lsp.buf.rename()")
    vim.cmd("command! LspRefs lua vim.lsp.buf.references()")
    vim.cmd("command! LspTypeDef lua vim.lsp.buf.type_definition()")
    vim.cmd("command! LspImplementation lua vim.lsp.buf.implementation()")
    vim.cmd("command! LspDiagPrev lua vim.diagnostic.goto_prev()")
    vim.cmd("command! LspDiagNext lua vim.diagnostic.goto_next()")
    vim.cmd("command! LspDiagLine lua vim.diagnostic.open_float()")
    vim.cmd("command! LspSignatureHelp lua vim.lsp.buf.signature_help()")
    buf_map(bufnr, "n", "gd", ":LspDef<CR>")
    buf_map(bufnr, "n", "gr", ":LspRename<CR>")
    buf_map(bufnr, "n", "gy", ":LspTypeDef<CR>")
    buf_map(bufnr, "n", "K", ":LspHover<CR>")
    buf_map(bufnr, "n", "[a", ":LspDiagPrev<CR>")
    buf_map(bufnr, "n", "]a", ":LspDiagNext<CR>")
    buf_map(bufnr, "n", "ga", ":LspCodeAction<CR>")
    buf_map(bufnr, "n", "<Leader>a", ":LspDiagLine<CR>")
    buf_map(bufnr, "i", "<C-x><C-x>", "<cmd> LspSignatureHelp<CR>")
    if client.resolved_capabilities.document_formatting then
        vim.cmd("autocmd BufWritePre <buffer> lua vim.lsp.buf.formatting_sync()")
    end
end
lspconfig.tsserver.setup({
    on_attach = function(client, bufnr)
        client.resolved_capabilities.document_formatting = false
        client.resolved_capabilities.document_range_formatting = false
        local ts_utils = require("nvim-lsp-ts-utils")
        ts_utils.setup({})
        ts_utils.setup_client(client)
        buf_map(bufnr, "n", "gs", ":TSLspOrganize<CR>")
        buf_map(bufnr, "n", "gi", ":TSLspRenameFile<CR>")
        buf_map(bufnr, "n", "go", ":TSLspImportAll<CR>")
        on_attach(client, bufnr)
    end,
})
null_ls.setup({
    sources = {
        null_ls.builtins.diagnostics.eslint,
        null_ls.builtins.code_actions.eslint,
        null_ls.builtins.formatting.prettier,
    },
    on_attach = on_attach,
})
EOF
