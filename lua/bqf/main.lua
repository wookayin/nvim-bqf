local M = {}
local api = vim.api
local fn = vim.fn
local cmd = vim.cmd

local qfs = require('bqf.qfwin.session')
local previewer = require('bqf.previewer.handler')
local layout = require('bqf.layout')
local magicwin = require('bqf.magicwin.handler')
local keymap = require('bqf.keymap')

function M.toggle()
    if vim.b.bqf_enabled then
        M.disable()
    else
        M.enable()
    end
end

function M.enable()
    -- need after vim-patch:8.1.0877
    if not layout.valid_qf_win() then
        return
    end

    local qwinid = api.nvim_get_current_win()

    local qs = qfs.new(qwinid)
    assert(qs, 'It is not a quickfix window')

    vim.wo.nu, vim.wo.rnu = true, false
    vim.wo.wrap = false
    vim.wo.foldenable, vim.wo.foldcolumn = false, '0'
    vim.wo.signcolumn = 'number'

    layout.initialize(qwinid)

    previewer.initialize(qwinid)
    keymap.initialize()

    local pwinid = qs:pwinid()
    cmd([[
        aug Bqf
            au! * <buffer>
            au WinEnter <buffer> ++nested lua require('bqf.main').kill_alone_qf()
            au WinClosed <buffer> ++nested lua require('bqf.main').close_qf()
        aug END
    ]])
    -- TODO
    -- After WinClosed callback in magic window, WinClosed in main can't be fired.
    -- WinClosed event in magic window must after in main
    magicwin.attach(qwinid, pwinid)
    vim.b.bqf_enabled = true
end

function M.disable()
    if vim.bo.buftype ~= 'quickfix' then
        return
    end
    local qwinid = api.nvim_get_current_win()
    previewer.close(qwinid)
    keymap.dispose()
    vim.b.bqf_enabled = false
    cmd('au! Bqf')
    cmd('sil! au! BqfPreview * <buffer>')
    cmd('sil! au! BqfFilterFzf * <buffer>')
    cmd('sil! au! BqfMagicWin')
    qfs.dispose()
end

local function close(winid)
    local ok, msg = pcall(api.nvim_win_close, winid, false)
    if not ok then
        -- Vim:E444: Cannot close last window
        if msg:match('^Vim:E444') then
            cmd('new')
            api.nvim_win_close(winid, true)
        end
    end
end

function M.kill_alone_qf()
    local winid = api.nvim_get_current_win()
    local qs = qfs.get(winid)
    if qs then
        if qs:pwinid() < 0 then
            close(winid)
        end
    end
end

function M.close_qf()
    local winid = tonumber(fn.expand('<afile>'))
    if winid and api.nvim_win_is_valid(winid) then
        qfs.dispose()
        previewer.close(winid)
    end
end

local function init()
    cmd([[
        aug Bqf
            au!
        aug END
    ]])
end

init()

return M
