{ config, lib, pkgs, ... }:
let
  inherit (lib) mkIf;
  cfg = config.cli;
  primaryUsername = config.primaryUser.name;
in
{
  config = mkIf cfg.enable {
    # Make neovim available system-wide (root, etc.)
    environment.systemPackages = [ pkgs.neovim ];

    home-manager.users.${primaryUsername}.catppuccin.nvim.enable = true;

    home-manager.users.${primaryUsername}.programs.neovim = {
      enable = true;
      defaultEditor = true;

      extraLuaConfig = ''
        -- ============================================================
        -- mcedit-like neovim configuration (catppuccin theme)
        -- ============================================================

        -- Visual
        vim.opt.number        = true      -- absolute line numbers
        vim.opt.mouse         = 'a'       -- mouse support
        vim.opt.wrap          = false     -- no word wrap (mcedit default)
        vim.opt.showmode      = false     -- mode shown in statusline
        vim.opt.laststatus    = 2
        vim.opt.cursorline    = false
        vim.opt.signcolumn    = 'no'

        -- Show tabs and trailing spaces (mcedit editor_visible_tabs/spaces)
        vim.opt.list      = true
        vim.opt.listchars = { tab = '» ', trail = '·', nbsp = '␣' }

        -- Status line: filename + flags on left, line/col on right
        vim.opt.statusline = '  %f %m%r%h  %=%l/%L  Col:%-3c  '

        -- Function-key hint bar (tabline, mimicking mcedit's bottom keybar)
        vim.opt.showtabline = 2
        vim.opt.tabline = '%#TabLine#  F2:Save  F3:Mark  F4:Replace  F7:Search  F8:Delete  F9:Cmd  F10:Quit  %#TabLineFill#'

        -- Editing (mirrors mc editor settings: tab=2, fill with spaces)
        vim.opt.tabstop     = 2
        vim.opt.shiftwidth  = 2
        vim.opt.expandtab   = true   -- editor_fill_tabs_with_spaces = true
        vim.opt.autoindent  = true
        vim.opt.backspace   = { 'indent', 'eol', 'start' }

        -- Search
        vim.opt.ignorecase = true
        vim.opt.smartcase  = true
        vim.opt.hlsearch   = true
        vim.opt.incsearch  = true

        -- Start regular files in insert mode (mcedit opens directly for editing)
        vim.api.nvim_create_autocmd({ 'BufRead', 'BufNewFile' }, {
          pattern = '*',
          callback = function()
            if vim.bo.buftype == "" and not vim.bo.readonly then
              vim.schedule(function() vim.cmd('startinsert') end)
            end
          end,
        })

        -- ============================================================
        -- Key bindings  (mcedit function-key layout)
        -- ============================================================
        local opts = { noremap = true, silent = true }

        -- F1: Help
        vim.keymap.set({ 'n', 'i', 'v' }, '<F1>', function()
          vim.cmd('stopinsert')
          vim.cmd('help')
        end, opts)

        -- F2: Save
        vim.keymap.set({ 'n', 'i', 'v' }, '<F2>', '<Cmd>w<CR>', opts)

        -- Shift-F2: Save as
        vim.keymap.set({ 'n', 'i' }, '<S-F2>', function()
          vim.cmd('stopinsert')
          local name = vim.fn.input('Save as: ', vim.fn.expand('%'), 'file')
          if name ~= "" then vim.cmd('saveas ' .. name) end
          vim.cmd('startinsert')
        end, opts)

        -- F3: Toggle block marking (visual mode on / off)
        vim.keymap.set('i', '<F3>', '<Esc>v',  opts)
        vim.keymap.set('n', '<F3>', 'v',       opts)
        vim.keymap.set('v', '<F3>', '<Esc>i',  opts)

        -- Shift-F3: Column (block) selection
        vim.keymap.set('i', '<S-F3>', '<Esc><C-v>', opts)
        vim.keymap.set('n', '<S-F3>', '<C-v>',      opts)

        -- F4: Find and replace (interactive, like mcedit's Replace dialog)
        vim.keymap.set({ 'n', 'i' }, '<F4>', function()
          vim.cmd('stopinsert')
          local search = vim.fn.input('Search: ')
          if search == "" then vim.cmd('startinsert') return end
          local replace = vim.fn.input('Replace with: ')
          local esc_s = vim.fn.escape(search,  '/\\')
          local esc_r = vim.fn.escape(replace, '/\\')
          pcall(function() vim.cmd(string.format('%%s/%s/%s/gc', esc_s, esc_r)) end)
          vim.cmd('startinsert')
        end, opts)

        -- F5: Copy selection to system clipboard
        vim.keymap.set('v', '<F5>', '"+y',                   opts)
        vim.keymap.set('n', '<F5>', '<Cmd>normal! yy<CR>',   opts)

        -- F6: Move / cut selection
        vim.keymap.set('v', '<F6>', '"+d', opts)

        -- F7: Find (search)
        vim.keymap.set({ 'n', 'i' }, '<F7>', function()
          vim.cmd('stopinsert')
          vim.fn.feedkeys('/', 'n')
        end, opts)

        -- Shift-F7: Find next
        vim.keymap.set({ 'n', 'i' }, '<S-F7>', '<Cmd>normal! n<CR>', opts)

        -- F8: Delete line or selection
        vim.keymap.set('n', '<F8>', '<Cmd>normal! dd<CR>', opts)
        vim.keymap.set('i', '<F8>', '<Cmd>normal! dd<CR>', opts)
        vim.keymap.set('v', '<F8>', 'd',                   opts)

        -- F9: Open command line (mcedit menu equivalent)
        vim.keymap.set({ 'n', 'i' }, '<F9>', function()
          vim.cmd('stopinsert')
          vim.fn.feedkeys(':', 'n')
        end, opts)

        -- F10: Quit with unsaved-changes prompt
        vim.keymap.set({ 'n', 'i', 'v' }, '<F10>', function()
          vim.cmd('stopinsert')
          if vim.bo.modified then
            local choice = vim.fn.confirm('File modified. Save before quitting?', '&Yes\n&No\n&Cancel', 1)
            if     choice == 1 then vim.cmd('wq')
            elseif choice == 2 then vim.cmd('q!') end
          else
            vim.cmd('q')
          end
        end, opts)

        -- Ctrl+S: Save
        vim.keymap.set({ 'n', 'i', 'v' }, '<C-s>', '<Cmd>w<CR>', opts)

        -- Ctrl+Z: Undo (mcedit)
        vim.keymap.set('n', '<C-z>', 'u',      opts)
        vim.keymap.set('i', '<C-z>', '<C-o>u', opts)

        -- Ctrl+Y: Delete current line (mcedit)
        vim.keymap.set('n', '<C-y>', '<Cmd>normal! dd<CR>', opts)
        vim.keymap.set('i', '<C-y>', '<Cmd>normal! dd<CR>', opts)

        -- Ctrl+K: Cut to end of line (mcedit)
        vim.keymap.set('n', '<C-k>', 'D',      opts)
        vim.keymap.set('i', '<C-k>', '<Esc>D', opts)

        -- Ctrl+A / Ctrl+E: Line start / end
        vim.keymap.set('i', '<C-a>', '<Home>', opts)
        vim.keymap.set('i', '<C-e>', '<End>',  opts)
      '';
    };
  };
}
