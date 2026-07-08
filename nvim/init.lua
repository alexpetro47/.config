-- ~/.local/share/nvim/lazy/
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '
vim.o.syntax = 'on'
vim.o.mouse = ''
vim.o.hlsearch = true
vim.o.incsearch = true
vim.o.backup = false
vim.o.swapfile = false
vim.o.undofile = true
vim.o.timeoutlen = 1000
vim.o.updatetime = 50
vim.wo.signcolumn = 'no'
-- vim.wo.signcolumn = 'yes:1'
vim.wo.number = true
vim.o.scrolloff = 6
vim.o.wrap = true
vim.o.ignorecase = true
vim.o.smartcase = true
vim.o.shiftwidth = 4
vim.o.softtabstop = 4
vim.o.tabstop = 4
vim.opt.iskeyword:remove('_')  -- treat _ as word separator
vim.opt.iskeyword:remove('-')  -- treat - as word separator

-- Skip over _ and - separators (like spaces) for w/b/e motions
local function skip_sep(motion)
  return function()
    for _ = 1, vim.v.count1 do
      vim.cmd('normal! ' .. motion)
      local char = vim.fn.getline('.'):sub(vim.fn.col('.'), vim.fn.col('.'))
      while char == '_' or char == '-' do
        vim.cmd('normal! ' .. motion)
        char = vim.fn.getline('.'):sub(vim.fn.col('.'), vim.fn.col('.'))
      end
    end
  end
end
vim.keymap.set({'n', 'v'}, 'w', skip_sep('w'), {noremap = true})
vim.keymap.set({'n', 'v'}, 'b', skip_sep('b'), {noremap = true})
vim.keymap.set({'n', 'v'}, 'e', skip_sep('e'), {noremap = true})
vim.opt.termguicolors = true
-- vim.o.smartindent = true
-- vim.o.smarttab = true
-- vim.o.expandtab = true
-- vim.g.loaded_netrw = 0 --use nvim-tree
-- vim.g.loaded_netrwPlugin = 0 --use nvim-tree
-- vim.o.grepprg = 'rg --vimgrep --no-heading --smart-case'


--Removals 
vim.keymap.set({'n', 'v'}, 'U', '<Nop>', {silent = true})
vim.keymap.set({'n', 'v'}, 'Y', '<Nop>', {silent = true})
vim.keymap.set({'n', 'v'}, 'H', '<Nop>', {silent = true})
vim.keymap.set({'n', 'v'}, 'J', '<Nop>', {silent = true})
vim.keymap.set({'n', 'v'}, 'K', '<Nop>', {silent = true})
vim.keymap.set({'n', 'v'}, 'L', '<Nop>', {silent = true})
vim.keymap.set({'n', 'v'}, 'M', '<Nop>', {silent = true})
vim.keymap.set({'n', 'v'}, 'gl', '<Nop>', {silent = true})
vim.keymap.set({'n', 'v'}, 'gn', '<Nop>', {silent = true})
vim.keymap.set({'n'     }, 's', '<Nop>', {silent = true})

--Pre Remaps
vim.keymap.set({'n'}, '<C-p>', '<C-i>', {noremap = true, silent = true}) -- remap for jumplist forward before any tab remaps, tab == C-i

--Keybinds
vim.keymap.set('i', 'jj', '<Esc>', { noremap = true, silent = true })
vim.keymap.set('n', 's', 'J_', {noremap = true, silent = true})
vim.keymap.set('n', '<leader>R', ':! rm %<CR><Esc>:q!<CR>:echo "file removed"<CR>', { noremap = true, silent = true, desc = 'remove file' })
vim.keymap.set('n', 'D', 'dd', {noremap=true, silent=true})
vim.keymap.set('v', 'D', '"+ygvd', {noremap=true, silent=true})
vim.keymap.set('n', '>', '>>', {noremap=true, silent=true})
vim.keymap.set('n', '<', '<<', {noremap=true, silent=true})
vim.keymap.set("v", "J", ":m '>+1<CR>gv=gv", { noremap = true, silent = true })
vim.keymap.set("v", "K", ":m '<-2<CR>gv=gv", { noremap = true, silent = true })
vim.keymap.set("v", "Y", '"+y')
vim.keymap.set("n", "Y", '"+y')
vim.keymap.set('n', 'y`', '"+yi`', {desc = 'yank in backticks'})
vim.keymap.set('v', 'S', 'g_')
vim.keymap.set('n', 'S', '0vg_')
vim.keymap.set('n', 'U', '<C-r>', { noremap = true, silent = true })
vim.keymap.set({"n", 'v'}, "x", '"_x', {noremap = true, silent = true})
vim.keymap.set('n', '<leader>.', 'I <Esc>', {noremap=true, silent=true, desc="add space to start of line"})
-- vim.keymap.set('v', '`', 'c``<Esc>hp0', {noremap=true, silent=true, desc="wrap visual selection in ``` "})
vim.keymap.set('n', 'P', '"+p', {desc="paste from clipboard", noremap = true, silent = true})
vim.keymap.set('n', '<leader>w', ':w<CR>', {desc="write buffer", noremap = true, silent = true})
vim.keymap.set('n', 'Q', ':q!<CR>', {desc="quit buffer without write", noremap = true, silent = true})
vim.keymap.set("n", "<leader>x", "$x", { silent = true, desc = 'x at end of line'})
vim.keymap.set("n", "<leader>X", "_x", { silent = true, desc = 'x at end of line'})
vim.keymap.set('n', '<leader>y', ':%y+<CR>', {desc = 'copy all to sys clipboard'})
-- <leader>I: move clipboard path to .media/, insert markdown image
vim.keymap.set('n', '<leader>I', function()
  local path = vim.fn.getreg('+'):gsub('%s+$', '')
  if path == '' or vim.fn.filereadable(path) ~= 1 then
    print('No valid file path in clipboard')
    return
  end
  local fname = vim.fn.fnamemodify(path, ':t')
  local result = vim.fn.system('mkdir -p .media && mv ' .. vim.fn.shellescape(path) .. ' .media/')
  if vim.v.shell_error ~= 0 then
    print('Failed to move file: ' .. result)
    return
  end
  local abs_path = vim.fn.getcwd() .. '/.media/' .. fname
  vim.api.nvim_put({'![](' .. abs_path .. ')'}, 'c', true, true)
end, {desc = 'move clipboard image to .media/ and insert'})
-- <leader>i: toggle inline image rendering (mermaid diagrams + PNGs via image.nvim, LaTeX via mdmath)
vim.g.inline_images_on = true
vim.keymap.set('n', '<leader>i', function()
  vim.g.inline_images_on = not vim.g.inline_images_on
  local on = vim.g.inline_images_on
  -- image.nvim is the master switch: enable/disable is global and its per-image
  -- render() bails on state.enabled, so diagram.nvim's re-renders stay suppressed
  pcall(function() require('image')[on and 'enable' or 'disable']() end)
  -- mdmath is per-buffer; apply to every loaded markdown buffer so it stays in sync
  pcall(function()
    local mdmath = require('mdmath')
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].filetype == 'markdown' then
        mdmath[on and 'enable' or 'disable'](buf)
      end
    end
  end)
  vim.notify('inline images ' .. (on and 'on' or 'off'))
end, { desc = 'toggle inline image rendering' })
vim.keymap.set('n', '<leader>=', ':set shiftwidth=2<CR>', {noremap=true, silent=true, desc="reset shiftwidth 2"})
vim.keymap.set('n', '<leader><', ':cd ..<CR>:pwd<CR>', {noremap=true, silent=true, desc="cd back 1 dir"})
vim.keymap.set('n', '<leader>r', ':e!<CR>', {desc = 'reload buffer'})
vim.keymap.set('n', '<leader>8', 'I* <Esc>', {desc = 'insert bullet point *'})
vim.keymap.set('v', '<leader>8', ":'<,'>normal! I* <CR>", { silent = true, desc = 'Insert bullet point * on visual selection' })
vim.keymap.set('n', '<leader>-', 'I- <Esc>', {desc = 'insert bullet point *'})
vim.keymap.set('n', '<leader>l', 'I1. <Esc>', {desc = 'insert list'})
vim.keymap.set('v', '<leader>l', ":'<,'>normal! I1. <CR>gvojg<c-a>", { silent = true, desc = 'insert list on visual selection' })
vim.keymap.set('v', '<leader>*', ":s/[0-9]. /* /<CR>", { silent = true, desc = 'list -> bullets' })
vim.keymap.set('n', '<leader>#', '0i#<Esc>0', {desc = 'insert header'})
vim.keymap.set('n', '<leader>@', 'I@<Esc>', {desc = 'insert @'})
vim.keymap.set('n', '<leader>1', '0i# <Esc>0VgU', {desc = 'insert header'})
vim.keymap.set('n', '<leader>2', '0i## <Esc>0VgU', {desc = 'insert header'})
vim.keymap.set('n', '<leader>3', '0i### <Esc>0VgU', {desc = 'insert header'})
vim.keymap.set('n', '<leader>4', '0i#### <Esc>0VgU', {desc = 'insert header'})
vim.keymap.set('n', '<leader>5', '0i##### <Esc>0VgU', {desc = 'insert header'})
vim.keymap.set('n', '<leader>,', [[i* <Esc>V:s/,\s*/\r* /g<CR>]], {desc = 'comma list -> bullet list'})
vim.keymap.set('n', '<leader>o', '2o<Esc>', {desc = 'insert blank line below cursor'})
vim.keymap.set('v', '<leader>r', [[:g/^\s*$/d<CR>]], {desc = 'remove blank lines in selection'})
vim.keymap.set('v', '<leader>}', ":g/^\\s*$/s/^/ /<CR>", { desc = 'Add two spaces to start of each blank line in selection' })
vim.keymap.set('n', '<leader>t', '<Esc>gg0:r !basename %<CR>/\\.<CR>"_d$VgUI# <Esc>V:s/[_-]/ /g<CR>2o<Esc>', {desc = 'insert filename as title'})
vim.keymap.set('n', '<leader>*', 'I* <Esc>:s/\\s*,\\s*/\\r* /g<CR>', {desc = 'comma separted list to bullets'})
vim.keymap.set('n', '<leader>d', ':! cp %:p ~/Downloads/<CR>', { noremap = true, silent = true, desc = 'copy file to Downloads' })

--Window Management
vim.keymap.set('n', '<Tab>', '<C-w>', { noremap = true })
vim.keymap.set('n', '<Tab>[', '<C-w>20<', { noremap = true })
vim.keymap.set('n', '<Tab>]', '<C-w>20>', { noremap = true })

--centered navigation
vim.keymap.set("n", "<C-d>", "<C-d>zz", {noremap = true, silent = true})
vim.keymap.set("n", "<C-u>", "<C-u>zz", {noremap = true, silent = true})
vim.keymap.set("n", "N", "Nzzzv", {noremap = true, silent = true})
vim.keymap.set("n", "n", "nzzzv", {noremap = true, silent = true})
vim.keymap.set("n", "g;", "g;zz", {noremap = true, silent = true})
vim.keymap.set('n', '*', '*zzzv', { noremap = true, silent = true })
vim.keymap.set('n', '}', '}zz', { noremap = true })
vim.keymap.set('n', '{', '{zz', { noremap = true })

vim.keymap.set('n', '<leader>e', ':NvimTreeToggle<CR>')

vim.keymap.set('n', '<leader>h', ':cd %:p:h<CR>:pwd<CR>', {desc = 'cd here'})


vim.keymap.set('v', 'L', '<Esc>:let @+ = "@" . expand("%:p") . ":" . line("\'<") . "-" . line("\'>")<CR>', { noremap = true, silent = true, desc = 'get absolute path with line range'})
vim.keymap.set('n', '<leader>p', ':let @+ = "@" . expand("%:p") . " " <CR>', { noremap = true, silent = true, desc = 'get absolute path to current file'})
vim.keymap.set('v', '<leader>p', '<Esc>:let @+ = "@" . expand("%:p") . ":" . line("\'<") . "-" . line("\'>")<CR>', { noremap = true, silent = true, desc = 'get absolute path with line range'})
vim.keymap.set('n', '<leader>P', ':let @+ = expand("%:p")<CR>', { noremap = true, silent = true, desc = 'get absolute path to current file'})
vim.keymap.set('n', '<leader>E', ':! xdg-open %:p:h &<CR>', {desc = 'open current buffer directory in file manager'})

--sneak
vim.g["sneak#label"] = 1 --label mode for vim-sneak
vim.g["sneak#use_ic_scs"] = 1 --case insensitive


-- sets text wrapping in markdown files
vim.cmd([[
" autocmd FileType markdown setlocal textwidth=100
autocmd FileType markdown setlocal textwidth=80
]])


vim.keymap.set('n', 'H', ':lua require("harpoon.ui").toggle_quick_menu()<CR>' , { desc = 'harpoon menu' })
vim.keymap.set('n', 'M', ':lua require("harpoon.mark").add_file()<CR>', { desc = 'harpoon mark' })
vim.keymap.set('n', 'J', ':lua require("harpoon.ui").nav_file(1)<CR>' , { desc = 'harpoon 1' })
vim.keymap.set('n', 'K', ':lua require("harpoon.ui").nav_file(2)<CR>' , { desc = 'harpoon 2' })
vim.keymap.set('n', 'L', ':lua require("harpoon.ui").nav_file(3)<CR>' , { desc = 'harpoon 3' })
vim.keymap.set('n', '<M-J>', ':lua require("harpoon.ui").nav_file(4)<CR>' , { desc = 'harpoon 4' })
vim.keymap.set('n', '<M-K>', ':lua require("harpoon.ui").nav_file(5)<CR>' , { desc = 'harpoon 5' })
vim.keymap.set('n', '<M-L>', ':lua require("harpoon.ui").nav_file(6)<CR>' , { desc = 'harpoon 6' })
--open files with absolute path
vim.api.nvim_create_autocmd("FileType", { pattern = "NvimTree", callback =
  function(args) vim.keymap.set("n", "gx", function() local node =
    require("nvim-tree.api").tree.get_node_under_cursor() if node and
      node.absolute_path then vim.fn.jobstart({"xdg-open", node.absolute_path}, {detach = true})
    end end, { buffer = args.buf, noremap = true, silent = true }) end, })
--gx for regular buffers (detached to avoid timeout)
vim.keymap.set('n', 'gx', function()
  local line = vim.fn.getline('.')
  local col = vim.fn.col('.')
  local target
  -- check for markdown link: [text](path) or ![text](path)
  for start_pos, path in line:gmatch('()!?%[.-%]%((.-)%)') do
    local end_pos = start_pos + #line:match('!?%[.-%]%(.-%)', start_pos) - 1
    if col >= start_pos and col <= end_pos then
      target = path
      break
    end
  end
  target = target or vim.fn.expand('<cfile>')
  if target and target ~= '' then
    -- resolve relative paths from buffer directory
    if not target:match('^[a-z]+://') and not target:match('^/') then
      target = vim.fn.expand('%:p:h') .. '/' .. target
    end
    vim.fn.jobstart({"xdg-open", target}, {detach = true})
  end
end, { desc = 'open file/URL under cursor' })

--Distant / SSH
vim.keymap.set('n', '<leader>Sl', ':DistantLaunch ssh://root@<UP>' , { desc = 'Distant Launch' })
vim.keymap.set('n', '<leader>Si', ':Distant<CR>' , { desc = 'Distant Info' })
vim.keymap.set('n', '<leader>Se', ':vs<CR><C-w>40< :DistantOpen<CR>' , { desc = 'Distant Explorer' })
vim.keymap.set('n', '<leader>St', ':vs<CR><C-w>l :DistantShell<CR>a' , { desc = 'Distant Term' })

--file conversions
vim.keymap.set('n', '<leader>c9', ':!pandoc % -o %:r.pdf -d /home/alexpetro/.config/pandoc/defaults.yaml<CR>:! xdg-open %:r.pdf &<CR>', { desc = 'md -> pdf' })
vim.keymap.set('n', '<leader>c8', ":!markmap % --offline <CR>", {desc = 'md -> mind-map (html)'})
vim.keymap.set('n', '<leader>c7', ':silent !markserv % > /dev/null 2>&1 &<CR>', { desc = 'md -> browser live preview' })

--Nvim Management
vim.keymap.set('n', '<leader>m', ':messages<CR>:horizontal resize 25<CR>', { desc = 'nvim messages'})
vim.keymap.set('n', '<leader>L', ':Lazy<CR>', { desc = 'lazy package manager'})

-- Git (minimal - use lazygit via C-w g for full git TUI)
vim.keymap.set('n', '<leader>gB', ':GBrowse<CR>', { desc = 'open git repo in browser' })
       
vim.keymap.set('n', '<leader>F', function()
 require('telescope.pickers').new({}, {
   prompt_title = "Downloads (from most recent)",
   finder = require('telescope.finders').new_oneshot_job(
     { 'sh', '-c', 'ls -1t ~/Downloads | head -10' },
     {}
   ),
   sorter = require('telescope.sorters').empty(),
   previewer = require('telescope.config').values.file_previewer({}),
   initial_mode = "normal",
   attach_mappings = function(_, map)
     map('n', '<tab><tab>', function() end)
     map('n', '<tab>', function(bufnr)
       require('telescope.actions').toggle_selection(bufnr)
     end)
     map('n', '<cr>', function(bufnr)
       local actions = require('telescope.actions')
       local picker = require('telescope.actions.state').get_current_picker(bufnr)
       local multi = picker:get_multi_selection()

       if #multi == 0 then
         actions.add_selection(bufnr)
         multi = picker:get_multi_selection()
       end

       actions.close(bufnr)

       -- Open directory picker to choose destination
       local cwd = vim.fn.getcwd()
       local fd_results = vim.fn.systemlist({ "fd", "--type", "d", "--hidden", "--no-ignore" })
       local dir_list = { cwd }  -- Current directory first
       for _, dir in ipairs(fd_results) do
         table.insert(dir_list, dir)
       end

       require('telescope.pickers').new({}, {
         prompt_title = "Choose Destination Directory",
         finder = require('telescope.finders').new_table({
           results = dir_list,
           entry_maker = function(entry)
             local display = entry == cwd and ". (current dir)" or entry
             return {
               value = entry,
               display = display,
               ordinal = entry,
               path = entry,
             }
           end,
         }),
         sorter = require('telescope.config').values.generic_sorter({}),
         attach_mappings = function(_, dir_map)
           local action_state = require('telescope.actions.state')

           dir_map('i', '<CR>', function(dir_bufnr)
             local selection = action_state.get_selected_entry()
             actions.close(dir_bufnr)

             local dest_dir = selection.path
             local paths = {}
             for _, entry in ipairs(multi) do
               local src = vim.fn.expand('~/Downloads/') .. entry.value
               vim.fn.system('cp ' .. vim.fn.shellescape(src) .. ' ' .. vim.fn.shellescape(dest_dir))
               table.insert(paths, src)
             end
             vim.fn.setreg('+', table.concat(paths, '\n'))
             vim.notify('Copied ' .. #multi .. ' files to ' .. dest_dir .. ' and paths to clipboard')
           end)

           dir_map('n', '<CR>', function(dir_bufnr)
             local selection = action_state.get_selected_entry()
             actions.close(dir_bufnr)

             local dest_dir = selection.path
             local paths = {}
             for _, entry in ipairs(multi) do
               local src = vim.fn.expand('~/Downloads/') .. entry.value
               vim.fn.system('cp ' .. vim.fn.shellescape(src) .. ' ' .. vim.fn.shellescape(dest_dir))
               table.insert(paths, src)
             end
             vim.fn.setreg('+', table.concat(paths, '\n'))
             vim.notify('Copied ' .. #multi .. ' files to ' .. dest_dir .. ' and paths to clipboard')
           end)

           return true
         end,
       }):find()
     end)
     return true
   end
 }):find()
end)

--Search
vim.keymap.set('n', '<leader><leader>', ":lua require'telescope.builtin'.oldfiles()<CR>", { desc = '[ ] recent files' })
vim.keymap.set('n', '<leader>sh', ":lua require'telescope.builtin'.help_tags()<CR>" , { desc = 'search help'})
vim.keymap.set('n', '<leader>sg', ":lua require'telescope.builtin'.live_grep({ additional_args = { '--hidden' } })<CR>" , { desc = 'search grep' })
vim.keymap.set('n', '<leader>sf', ":lua require'telescope.builtin'.fd({ hidden = true })<CR>" , { desc = 'search files' })
vim.keymap.set('n', '<leader>ss', ":lua require'telescope.builtin'.lsp_dynamic_workspace_symbols()<CR>" , { desc = 'search workspace symbols' })
vim.keymap.set('n', '<leader>sd', ":lua require'telescope.builtin'.lsp_document_symbols()<CR>" , { desc = 'search document symbols' })
vim.keymap.set('n', 'gr', ":lua require'telescope.builtin'.lsp_references()<CR>" , { desc = 'search references' })
vim.keymap.set('n', '<leader>sd', function()
  require('telescope.builtin').find_files({
    prompt_title = "Find Directories",
    find_command = { "fd", "--type", "d", "--hidden", "--no-ignore" },
    attach_mappings = function(_, map)
      local actions = require('telescope.actions')
      local action_state = require('telescope.actions.state')

      -- Override default <CR> action
      map('i', '<CR>', function(bufnr)
        local selection = action_state.get_selected_entry()
        actions.close(bufnr)

        -- Open nvim-tree at selected directory (without changing cwd)
        require('nvim-tree.api').tree.open()
        require('nvim-tree.api').tree.change_root(selection.path)
      end)

      map('n', '<CR>', function(bufnr)
        local selection = action_state.get_selected_entry()
        actions.close(bufnr)

        -- Open nvim-tree at selected directory (without changing cwd)
        require('nvim-tree.api').tree.open()
        require('nvim-tree.api').tree.change_root(selection.path)
      end)

      return true
    end,
  })
end, { desc = 'search dirs -> open in nvim-tree' })




-- package manager
local lazypath = vim.fn.stdpath 'data' .. '/lazy/lazy.nvim'
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system {
    'git',
    'clone',
    '--filter=blob:none',
    'https://github.com/folke/lazy.nvim.git',
    '--branch=stable',
    lazypath,
  }
end
vim.opt.rtp:prepend(lazypath)

require('lazy').setup({
--ALL PLUGINS ARE LOCATED at ~/.local/share/nvim/
  auto_update = false,

  --MY ADDITIONS---------------------------------

  --Editing enclosing characters
  -- 'tpope/vim-surround', -- deprecated, using nvim-surround instead
  {
    'kylechui/nvim-surround',
    version = "*",
    event = "VeryLazy",
    config = function()
      require("nvim-surround").setup({
        aliases = {
          -- Disable default 'b' = ) alias so we can use 'b' for bold
          ["b"] = false,
        },
        surrounds = {
          -- 'c' wraps with triple backticks on isolated lines
          ["c"] = {
            add = { "```\n", "\n```" },
          },
          -- 'i' wraps with italic (single *)
          ["i"] = {
            add = { "*", "*" },
            find = "%*.-%*",
            delete = "^(%*)().-(%*)()$",
          },
          -- 'b' wraps with bold (double **) - overrides default 'b' = )
          ["b"] = {
            add = { "**", "**" },
            find = "%*%*.-%*%*",
            delete = "^(%*%*)().-(%*%*)()$",
          },
        },
      })
    end
  },

  --preview substitutions
  'markonm/traces.vim',

  --colorscheme
  {
    'sainnhe/gruvbox-material',
    config = function()
      vim.o.background = 'dark'
      vim.g.gruvbox_material_transparent_background = 2
      -- vim.o.background = 'light'
      -- vim.g.gruvbox_material_transparent_background = 0
      vim.cmd.colorscheme 'gruvbox-material'
    end,
  },

  -- use . to repeat commands
  'tpope/vim-repeat',

  --faster searches
  {
  'justinmk/vim-sneak',
    --two character searches
    vim.keymap.set('n', 'f', '<Plug>Sneak_s', { noremap = true }),
    vim.keymap.set('n', 'F', '<Plug>Sneak_S', { noremap = true }),
    vim.keymap.set('v', 'f', '<Plug>Sneak_s', { noremap = true }),
    vim.keymap.set('v', 'F', '<Plug>Sneak_S', { noremap = true }),
    --one character searches are 'til mode
    vim.keymap.set('n', 't', '<Plug>Sneak_t', { noremap = true }),
    vim.keymap.set('n', 'T', '<Plug>Sneak_T', { noremap = true }),
  },

  --harpoon
  {
    'ThePrimeagen/harpoon',
    config = function()
      require('harpoon').setup{
        save_on_ui_close = true,
      }
    end
  },

  -- nice icons, requires nerd fonts probably
  "nvim-tree/nvim-web-devicons",

  --better indenting
  -- 'lukas-reineke/format.nvim',

  {
  --undotree
  'mbbill/undotree',
  vim.keymap.set('n', '<leader>u', ':UndotreeToggle<CR>', { desc = 'undotree toggle' }),
  },

  --telescope upgrades
  'BurntSushi/ripgrep',
  'sharkdp/fd',

  --markdown highlighting
  {
    'MeanderingProgrammer/render-markdown.nvim',
    -- dependencies = { 'nvim-treesitter/nvim-treesitter', 'echasnovski/mini.nvim' }, -- if you use the mini.nvim suite
    dependencies = { 'nvim-treesitter/nvim-treesitter', 'echasnovski/mini.icons' }, -- if you use standalone mini plugins
    dependencies = { 'nvim-treesitter/nvim-treesitter', 'nvim-tree/nvim-web-devicons' }, -- if you prefer nvim-web-devicons
    ---@module 'render-markdown'
    ---@type render.md.UserConfig
    opts = {},
  },

  -- DISABLED: noice.nvim has treesitter query incompatibility with @operator capture
  -- {
  --   "folke/noice.nvim",
  --   event = "VeryLazy",
  --   opts = {
  --     cmdline = {
  --       enabled = true,
  --       view = "cmdline_popup",
  --     },
  --   },
  --   dependencies = {
  --     "MunifTanjim/nui.nvim",
  --   }
  -- },

  -- {
  --   'windwp/nvim-autopairs',
  --   enabled = false,
  --   event = "InsertEnter",
  --   config = function()
  --     require('nvim-autopairs').setup({})
  --   end
  -- },

  {
    'nvim-tree/nvim-tree.lua',
    config = function()
      local function nvim_tree_on_attach(bufnr)
        local api = require("nvim-tree.api")
        local function opts(desc)
          return { desc = "nvim-tree: " .. desc, buffer = bufnr, noremap = true, silent = true, nowait = true }
        end
        api.config.mappings.default_on_attach(bufnr)
        vim.keymap.del("n", "<Tab>", { buffer = bufnr })
        vim.keymap.set("n", "l", api.node.open.edit, opts("Open"))
        vim.keymap.set("n", "h", api.node.navigate.parent_close, opts("Close Directory"))
        vim.keymap.set("n", "d", api.fs.trash, opts("Trash"))
        vim.keymap.set("n", "m", api.marks.toggle, opts("Toggle Mark"))
        vim.keymap.set("n", "p", api.fs.paste, opts("Paste"))
        vim.keymap.set("n", "D", api.marks.bulk.trash, opts("Trash marks"))
        vim.keymap.set("n", "y", api.fs.copy.relative_path, opts("Copy Relative Path"))
        vim.keymap.set("n", "Y", api.fs.copy.absolute_path, opts("Copy Relative Path"))
        vim.keymap.set("n", "v", api.node.open.vertical, opts("open vertical split"))
        vim.keymap.set("n", "H", api.tree.change_root_to_node, opts("change root to node"))
        vim.keymap.set("n", "<leader>h", function()
          local node = api.tree.get_node_under_cursor()
          local path = node.type == "directory" and node.absolute_path or vim.fn.fnamemodify(node.absolute_path, ":h")
          vim.cmd("cd " .. vim.fn.fnameescape(path))
          vim.notify("cwd: " .. path)
        end, opts("cd to node directory"))
        vim.keymap.set("n", "<leader>E", function()
          local node = api.tree.get_node_under_cursor()
          local path = node.type == "directory" and node.absolute_path or vim.fn.fnamemodify(node.absolute_path, ":h")
          vim.fn.jobstart({"xdg-open", path}, {detach = true})
        end, opts("open directory in file manager"))
        vim.keymap.set("n", "z", function()
          local node = api.tree.get_node_under_cursor()
          if not node or node.type == "directory" then return end
          local filepath = node.absolute_path
          if not filepath:match("%.zip$") then
            vim.notify("Not a .zip file", vim.log.levels.WARN)
            return
          end
          local dir = vim.fn.fnamemodify(filepath, ":h")
          vim.fn.jobstart({"unzip", "-o", filepath, "-d", dir}, {
            detach = false,
            on_exit = function(_, code)
              if code == 0 then
                vim.schedule(function()
                  api.tree.reload()
                  vim.notify("Unzipped: " .. vim.fn.fnamemodify(filepath, ":t"))
                end)
              else
                vim.schedule(function()
                  vim.notify("Unzip failed (code " .. code .. ")", vim.log.levels.ERROR)
                end)
              end
            end,
          })
        end, opts("unzip file in place"))
        vim.keymap.set("n", "i", function()
          local node = api.tree.get_node_under_cursor()
          if not node then return end
          vim.fn.system('cp -r ' .. vim.fn.shellescape(node.absolute_path) .. ' ~/Downloads/')
          if vim.v.shell_error == 0 then
            vim.notify("Copied to ~/Downloads: " .. vim.fn.fnamemodify(node.absolute_path, ":t"))
          else
            vim.notify("Copy failed", vim.log.levels.ERROR)
          end
        end, opts("copy to Downloads"))
        vim.keymap.set("n", "<leader>d", function()
          local node = api.tree.get_node_under_cursor()
          if not node then return end
          vim.fn.system('cp -r ' .. vim.fn.shellescape(node.absolute_path) .. ' ~/Downloads/')
          if vim.v.shell_error == 0 then
            vim.notify("Copied to ~/Downloads: " .. vim.fn.fnamemodify(node.absolute_path, ":t"))
          else
            vim.notify("Copy failed", vim.log.levels.ERROR)
          end
        end, opts("copy to Downloads"))
      end

      require("nvim-tree").setup({
        on_attach = nvim_tree_on_attach,
        hijack_cursor = true,
        sync_root_with_cwd = false,
        reload_on_bufenter = true,
        respect_buf_cwd = false,
        update_focused_file = {
          enable = true,
          update_root = {
            enable = true,
            ignore_list = {},
          },
        },
        actions = {
          change_dir = {
            enable = false,
          },
          remove_file = {
            close_window = true,
          },
        },
        trash = {
          cmd = "trash-put",
          require_confirm = true,
        },
        filesystem_watchers = {
          enable = true,
        },
        sort = {
          sorter = "case_sensitive",
        },
        view = {
          width = 20,
        },
        renderer = {
          group_empty = true,
        },
        filters = {
          enable = false,
        },
      })
    end
  },

  'romainl/vim-cool',

  {
    'neovim/nvim-lspconfig',
    config = function()
      vim.diagnostic.enable(false)

      vim.keymap.set('n', 'gd', vim.lsp.buf.definition)
      vim.keymap.set('n', 'gi', vim.lsp.buf.hover)
      vim.keymap.set('n', 'cd', vim.lsp.buf.rename)

      vim.lsp.config('lua_ls', {
        settings = {
          Lua = {
            diagnostics = { globals = { 'vim' } }
          }
        }
      })
      vim.lsp.enable('lua_ls')

      vim.lsp.config('pyright', {})
      vim.lsp.enable('pyright')

      -- ctags-lsp: lexical (ctags-backed) symbol search, no runtime/deps needed.
      -- Pin root to ~/Documents/ALIDA so one index spans all sibling repos
      -- (cross-repo workspace symbols); other projects fall back to per-repo .git.
      local alida = vim.fn.expand('~/Documents/ALIDA')
      vim.lsp.config('ctags_lsp', {
        cmd = { 'ctags-lsp' },
        filetypes = { 'python', 'javascript', 'typescript', 'typescriptreact', 'sql' },
        root_dir = function(bufnr, on_dir)
          local fname = vim.api.nvim_buf_get_name(bufnr)
          if fname:sub(1, #alida) == alida then
            on_dir(alida)
          else
            on_dir(vim.fs.root(bufnr, '.git') or vim.fn.getcwd())
          end
        end,
      })
      vim.lsp.enable('ctags_lsp')
    end
  },

  {
    'chipsenkbeil/distant.nvim',
    branch = 'v0.3',
    config = function()
        require('distant'):setup({
        network = {
            private = true
        },
        manager = {
          log_file = '/var/log/distant.log',
          log_level = 'trace',
        }
      })
    end
  },

  -- building distant from source locally
  -- `curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh`
  -- `source "$HOME/.cargo/env"`
  -- `cd && mkdir my-temp && cd my-temp`
  -- `git clone https://github.com/chipsenkbeil/distant.git`
  -- `cd distant`
  -- `cargo build --release`
  -- `sudo cp target/release/distant /usr/local/bin/`
  -- `rm -rf ~/my-temp`

  -- Git related plugins
  'tpope/vim-fugitive',
  'tpope/vim-rhubarb',

  -- Detect tabstop and shiftwidth automatically
  'tpope/vim-sleuth',

  {
    -- Adds git related signs to the gutter, as well as utilities for managing changes
    'lewis6991/gitsigns.nvim',
    opts = {
      signs = {
        add = { text = '+' },
        change = { text = '~' },
        delete = { text = '_' },
        topdelete = { text = '‾' },
        changedelete = { text = '/' },
      },
      on_attach = function(bufnr)
        signs_staged_enabled = true,
        vim.keymap.set('n', 'ghp', require('gitsigns').preview_hunk, { buffer = bufnr, desc = 'git hunk preview' })
        vim.keymap.set({ 'n', 'v' }, 'ghs', require("gitsigns").stage_hunk, {buffer = bufnr, desc = 'git hunk toggle staged' })
        vim.keymap.set({ 'n', 'v' }, 'ghr', require("gitsigns").reset_hunk, {buffer = bufnr, desc = 'git hunk reset' })
        -- don't override the built-in and fugitive keymaps
        local gs = package.loaded.gitsigns
        vim.keymap.set({ 'n', 'v' }, 'gn', function()
          if vim.wo.diff then
            return ']c'
          end
          vim.schedule(function()
            gs.next_hunk()
          end)
          return '<Ignore>'
        end, { expr = true, buffer = bufnr, desc = 'git next hunk' })
        vim.keymap.set({ 'n', 'v' }, 'gl', function()
          if vim.wo.diff then
            return '[c'
          end
          vim.schedule(function()
            gs.prev_hunk()
          end)
          return '<Ignore>'
        end, { expr = true, buffer = bufnr, desc = 'git last hunk' })
      end,
    },
  },

  {
    -- Set lualine as statusline
    'nvim-lualine/lualine.nvim',
    opts = {
      options = {
        icons_enabled = true,
        theme = 'gruvbox',
        component_separators = '',
        section_separators = '',
      },
      sections = {
        lualine_a = {},
        lualine_b = {{'filename', path = 2}},
        lualine_c = {},
        lualine_x = {},
        lualine_y = {'diff', 'branch'},
        lualine_z = {}
      },
    },
  },

  {
    -- Add indentation guides even on blank lines
    'lukas-reineke/indent-blankline.nvim',
    main = 'ibl',
    opts = {},
  },

  -- keybind comments, gcc for lines gb for blocks (visual mode helps)
  { 'numToStr/Comment.nvim', opts = {} },

  -- Fuzzy Finder (files, lsp, etc)
  {
    'nvim-telescope/telescope.nvim',
    branch = 'master',
    dependencies = {
      'nvim-lua/plenary.nvim',
      {
        'nvim-telescope/telescope-fzf-native.nvim',
        build = 'make',
        cond = function()
          return vim.fn.executable 'make' == 1
        end,
      },
    },
    config = function()
      require('telescope').setup {
        defaults = {
          layout_config = {
            width = 0.95,
            height = 0.95,
          },
          file_ignore_patterns = {
            "node_modules",
            "venv",
            ".venv",
            "__pycache__",
            ".pytest_cache",
            ".git/",
            "%.git/",
            "build/",
            "dist/",
            "target/",
            ".next/",
            ".cache/",
            "vendor/",
            "%.egg%-info/",
            "coverage/",
            ".coverage",
            "%.min%.js$",
            "%.map$",
          }
        },
      }
      -- Enable telescope fzf native, if installed
      pcall(require('telescope').load_extension, 'fzf')
    end
  },

  {
    -- Highlight, edit, and navigate code
    'nvim-treesitter/nvim-treesitter',
    dependencies = {
      { 'nvim-treesitter/nvim-treesitter-textobjects', branch = 'main' },
    },
    build = ':TSUpdate',
    config = function()
      -- Add nvim-treesitter runtime to runtimepath (required for queries in 1.0)
      vim.opt.rtp:prepend(vim.fn.stdpath('data') .. '/lazy/nvim-treesitter/runtime')

      -- Install only missing parsers
      local parsers = { 'c', 'cpp', 'go', 'lua', 'python', 'rust', 'tsx', 'javascript', 'typescript', 'vimdoc', 'vim', 'bash', 'sql', 'markdown', 'markdown_inline' }
      require("nvim-treesitter").setup({})
      local parser_dir = vim.fn.stdpath('data') .. '/lazy/nvim-treesitter/parser/'
      local to_install = vim.tbl_filter(function(p)
        return vim.fn.filereadable(parser_dir .. p .. '.so') == 0
      end, parsers)
      if #to_install > 0 then
        require("nvim-treesitter").install(to_install)
      end

      -- Enable treesitter highlighting for all buffers
      vim.api.nvim_create_autocmd('FileType', {
        callback = function(args)
          local buf = args.buf
          local ft = vim.bo[buf].filetype
          if ft == '' then return end
          -- Map filetype to language and try to start treesitter
          local lang = vim.treesitter.language.get_lang(ft) or ft
          local ok = pcall(vim.treesitter.start, buf, lang)
          if ok then
            vim.bo[buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
          end
        end,
      })

      -- Textobjects configuration
      require("nvim-treesitter-textobjects").setup({
        select = { lookahead = true },
        move = { set_jumps = true },
      })

      -- Textobjects select keymaps
      local ts_select = require("nvim-treesitter-textobjects.select")
      vim.keymap.set({ "x", "o" }, "af", function() ts_select.select_textobject("@function.outer", "textobjects") end, { desc = "around function" })
      vim.keymap.set({ "x", "o" }, "if", function() ts_select.select_textobject("@function.inner", "textobjects") end, { desc = "inside function" })
      vim.keymap.set({ "x", "o" }, "aC", function() ts_select.select_textobject("@class.outer", "textobjects") end, { desc = "around class" })
      vim.keymap.set({ "x", "o" }, "iC", function() ts_select.select_textobject("@class.inner", "textobjects") end, { desc = "inside class" })
      vim.keymap.set({ "x", "o" }, "ac", function() ts_select.select_textobject("@code_block.outer", "textobjects") end, { desc = "around code block" })
      vim.keymap.set({ "x", "o" }, "ic", function() ts_select.select_textobject("@code_block.inner", "textobjects") end, { desc = "inside code block" })

      -- Textobjects move keymaps
      local ts_move = require("nvim-treesitter-textobjects.move")
      vim.keymap.set({ "n", "x", "o" }, "]f", function() ts_move.goto_next_start("@function.outer", "textobjects") end, { desc = "Next function start" })
      vim.keymap.set({ "n", "x", "o" }, "]c", function() ts_move.goto_next_start("@class.outer", "textobjects") end, { desc = "Next class start" })
      vim.keymap.set({ "n", "x", "o" }, "]b", function() ts_move.goto_next_start("@block.outer", "textobjects") end, { desc = "Next block start" })
      vim.keymap.set({ "n", "x", "o" }, "[f", function() ts_move.goto_previous_start("@function.outer", "textobjects") end, { desc = "Previous function start" })
      vim.keymap.set({ "n", "x", "o" }, "[c", function() ts_move.goto_previous_start("@class.outer", "textobjects") end, { desc = "Previous class start" })
      vim.keymap.set({ "n", "x", "o" }, "[b", function() ts_move.goto_previous_start("@block.outer", "textobjects") end, { desc = "Previous block start" })

      -- Define custom markdown code block queries for treesitter textobjects
      vim.treesitter.query.set("markdown", "textobjects", [[
        (fenced_code_block) @code_block.outer
        (fenced_code_block
          (code_fence_content) @code_block.inner)
      ]])

      -- Make % jump between opening/closing ``` using matchup pairs
      vim.api.nvim_create_autocmd("FileType", {
        pattern = "markdown",
        callback = function()
          vim.b.match_words = vim.b.match_words or ""
          if vim.b.match_words ~= "" then
            vim.b.match_words = vim.b.match_words .. ","
          end
          vim.b.match_words = vim.b.match_words .. "^```.*$:^```$"
        end
      })
    end
  },

  -- LaTeX math rendering (requires Kitty graphics protocol)
  {
    "Thiago4532/mdmath.nvim",
    ft = "markdown",
    build = function() require("mdmath").build() end,
    opts = {
      anticonceal = true,  -- reveal source when cursor is on equation
    },
  },

  -- Mermaid diagram rendering inline in markdown (requires Kitty graphics protocol + mmdc)
  {
    '3rd/diagram.nvim',
    ft = 'markdown',
    dependencies = {
      {
        '3rd/image.nvim',
        build = false,
        opts = {
          processor = 'magick_cli',
          -- clear/hide images on tmux pane, window, and session switches
          tmux_show_only_in_active_window = true,
          editor_only_render_when_focused = true,
          window_overlap_clear_enabled = true,
          kitty_tmux_write_delay = 10, -- more reliable rendering with Kitty+Tmux
        },
      },
    },
    opts = {
      events = {
        -- re-rendering shells out to Chromium (~1s); skip TextChanged so
        -- typing in a file with diagrams doesn't re-render on every edit
        render_buffer = { 'InsertLeave', 'BufWinEnter' },
        clear_buffer = { 'BufLeave' },
      },
      renderer_options = {
        mermaid = {
          theme = 'dark',
          background = 'transparent',
          scale = 2,
          -- sandboxed chromium fails to launch under this machine's AppArmor
          -- userns restrictions; -p points mmdc at a puppeteer config with --no-sandbox
          cli_args = { '-p', '/home/alexpetro/.config/nvim/mermaid-puppeteer.json' },
        },
      },
    },
  },

  -- -- Image rendering in terminal (requires Kitty terminal + ImageMagick)
  -- {
  --   "3rd/image.nvim",
  --   build = false, -- don't build the rock
  --   opts = {
  --     backend = "kitty",
  --     processor = "magick_cli", -- uses ImageMagick CLI
  --     integrations = {
  --       markdown = {
  --         enabled = true,
  --         clear_in_insert_mode = false,
  --         download_remote_images = true,
  --         only_render_image_at_cursor = false, -- render all visible images
  --         filetypes = { "markdown", "vimwiki" },
  --       },
  --       neorg = {
  --         enabled = false,
  --       },
  --       typst = {
  --         enabled = false,
  --       },
  --       html = {
  --         enabled = false,
  --       },
  --       css = {
  --         enabled = false,
  --       },
  --     },
  --     max_width = nil,
  --     max_height = nil,
  --     max_width_window_percentage = nil,
  --     max_height_window_percentage = 60,
  --     window_overlap_clear_enabled = true,
  --     window_overlap_clear_ft_ignore = { "cmp_menu", "cmp_docs", "snacks_notif", "scrollview", "scrollview_sign" },
  --     editor_only_render_when_focused = false,
  --     tmux_show_only_in_active_window = true,
  --     kitty_tmux_write_delay = 10,  -- more reliable rendering with Kitty+Tmux
  --     hijack_file_patterns = { "*.png", "*.jpg", "*.jpeg", "*.gif", "*.webp", "*.avif" },
  --   },
  -- },

}, {})

-- Highlight on yank
local highlight_group = vim.api.nvim_create_augroup('YankHighlight', { clear = true })
vim.api.nvim_create_autocmd('TextYankPost', {
  callback = function()
    vim.highlight.on_yank()
  end,
  group = highlight_group,
  pattern = '*',
})

-- JSON: decode the string under the cursor into a rendered markdown scratch split
local function json_string_preview()
  local node = vim.treesitter.get_node()
  while node and node:type() ~= "string" do node = node:parent() end
  if not node then return vim.notify("no JSON string under cursor", vim.log.levels.WARN) end
  local ok, decoded = pcall(vim.json.decode, vim.treesitter.get_node_text(node, 0))
  if not ok then return vim.notify("could not decode string", vim.log.levels.ERROR) end
  vim.cmd("botright vnew")
  local buf = vim.api.nvim_get_current_buf()
  vim.bo[buf].buftype, vim.bo[buf].bufhidden, vim.bo[buf].filetype = "nofile", "wipe", "markdown"
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(decoded, "\n", { plain = true }))
  vim.bo[buf].modifiable = false
end
-- JSON: toggle folding of the entry under the cursor. Multi-line objects/arrays
-- use real treesitter folds; single-line string values (which can't span
-- multiple lines) are collapsed by concealing their text behind an ellipsis.
local json_collapse_ns = vim.api.nvim_create_namespace("json_collapse_string")
local function json_toggle_fold()
  local node = vim.treesitter.get_node()
  local outer = node
  while outer and outer:type() ~= "pair" and outer:type() ~= "object" and outer:type() ~= "array" do
    outer = outer:parent()
  end
  if outer then
    local srow, _, erow, _ = outer:range()
    if srow ~= erow then return vim.cmd("normal! za") end
  end

  while node and node:type() ~= "string" do node = node:parent() end
  if not node then return vim.notify("no JSON entry under cursor", vim.log.levels.WARN) end
  local buf = vim.api.nvim_get_current_buf()
  local srow, scol, erow, ecol = node:range()
  local existing = vim.api.nvim_buf_get_extmarks(buf, json_collapse_ns, { srow, scol }, { erow, ecol }, {})
  if #existing > 0 then
    for _, mark in ipairs(existing) do vim.api.nvim_buf_del_extmark(buf, json_collapse_ns, mark[1]) end
    return
  end
  vim.api.nvim_buf_set_extmark(buf, json_collapse_ns, srow, scol + 1, {
    end_row = erow,
    end_col = ecol - 1,
    conceal = "",
    virt_text = { { "…", "Comment" } },
    virt_text_pos = "inline",
  })
end

vim.api.nvim_create_autocmd("FileType", {
  pattern = "json",
  callback = function(args)
    vim.keymap.set("n", "<leader>jp", json_string_preview,
      { buffer = args.buf, desc = "preview JSON string as markdown" })

    vim.wo.foldmethod = "expr"
    vim.wo.foldexpr = "v:lua.vim.treesitter.foldexpr()"
    vim.wo.foldlevel = 99
    vim.wo.conceallevel = 2
    vim.wo.concealcursor = "nc"
    vim.keymap.set("n", "<leader>f", json_toggle_fold, { buffer = args.buf, desc = "toggle JSON fold" })
  end,
})

