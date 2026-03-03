local sidebar = require("naksha.ui.sidebar")
local editor = require("naksha.ui.editor")

local layout = {}
layout.__index = layout

local function set_win_size(win, width, height)
	vim.api.nvim_set_current_win(win)
	if width then
		vim.cmd("vertical resize " .. width)
	end
	if height then
		vim.cmd("resize " .. height)
	end
end

function layout.new(sessionmanager, connectionmanager)
	local self = setmetatable({}, layout)

	self.sessionmanager = sessionmanager
	self.connectionmanager = connectionmanager
	self.sidebar = sidebar.new(sessionmanager, connectionmanager)
	self.sidebar_buf = self.sidebar.buf
	vim.cmd("tabnew")
	vim.opt_local.bufhidden = "wipe"
	vim.cmd("vsplit")

	self.naksha_tab = vim.api.nvim_get_current_tabpage()
	vim.api.nvim_tabpage_set_var(self.naksha_tab, "tabname", "Naksha")

	local windows = vim.api.nvim_tabpage_list_wins(0)
	self.sidebar_window = windows[1]
	self.editor_window = windows[2]
	vim.api.nvim_set_current_win(self.editor_window)
	vim.cmd("split")
	windows = vim.api.nvim_tabpage_list_wins(0)
	self.results_window = windows[#windows]

	self.sidebar_width = 30
	self.editor_height = 15
	self.results_height = 15
	set_win_size(self.sidebar_window, self.sidebar_width, nil)
	set_win_size(self.editor_window, nil, self.editor_height)
	set_win_size(self.results_window, nil, self.results_height)

	vim.api.nvim_set_option_value("number", false, { win = self.sidebar_window })
	vim.api.nvim_set_option_value("number", false, { win = self.results_window })
	vim.api.nvim_set_option_value("relativenumber", false, { win = self.sidebar_window })
	vim.api.nvim_set_option_value("relativenumber", false, { win = self.results_window })

	vim.api.nvim_win_set_buf(self.sidebar_window, self.sidebar_buf)

	self.editor = editor.new(sessionmanager, connectionmanager, self.editor_window, self.results_window)
	self.editor:add_buffer()

	self.resize_autocmd = vim.api.nvim_create_autocmd("VimResized", {
		callback = function()
			if vim.api.nvim_win_is_valid(self.sidebar_window) then
				set_win_size(self.sidebar_window, self.sidebar_width, nil)
			end
			if vim.api.nvim_win_is_valid(self.editor_window) then
				set_win_size(self.editor_window, nil, self.editor_height)
			end
			if vim.api.nvim_win_is_valid(self.results_window) then
				set_win_size(self.results_window, nil, self.results_height)
			end
		end,
	})

	return self
end

--TODO: Close Layout to kill the editor and result buffers
function layout:close_layout()
	if self.resize_autocmd then
		vim.api.nvim_del_autocmd(self.resize_autocmd)
	end

	local naksha_tab = vim.api.nvim_get_current_tabpage()
	local windows = vim.api.nvim_tabpage_list_wins(naksha_tab)

	local bufs_to_delete = {}
	for _, win in ipairs(windows) do
		local buf = vim.api.nvim_win_get_buf(win)
		bufs_to_delete[buf] = true
	end

	vim.cmd("tabclose")

	for buf, _ in pairs(bufs_to_delete) do
		if vim.api.nvim_buf_is_valid(buf) then
			vim.api.nvim_buf_delete(buf, { force = true })
		end
	end
end

function layout:go_to_previous_tab()
	vim.cmd("tabprevious")
end

return layout
