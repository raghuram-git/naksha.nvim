--[[
local sessionlist = {}
sessionlist.__index = sessionlist

local function create_floating_window(width, height)
	local ui = vim.api.nvim_list_uis()[1]
	local row = math.floor((ui.height - height) / 2)
	local col = math.floor((ui.width - width) / 2)

	local buf = vim.api.nvim_create_buf(false, true)

	local win = vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		width = width,
		height = height,
		row = row,
		col = col,
		style = "minimal",
		border = "rounded",
	})

	vim.wo[win].cursorline = true

	return buf, win
end

function sessionlist.new(sessionmanager, on_select)
	local self = setmetatable({}, sessionlist)
	self.sessionmanager = sessionmanager
	self.on_select = on_select
	self.buf, self.win = create_floating_window(60, 20)
	self:refresh()
	self:set_keymaps()
	return self
end

function sessionlist:refresh()
	local sessions = self.sessionmanager:list_sessions()
	self.session_items = {}
	local lines = { "Select a Session", "-----------------", "" }

	if not sessions or vim.tbl_isempty(sessions) then
		table.insert(lines, "No active sessions.")
	else
		local idx = 1
		for conn_name, conn_sessions in pairs(sessions) do
			for _, session_id in ipairs(conn_sessions) do
				local item = string.format("(%s) %s", conn_name, session_id)
				table.insert(self.session_items, { conn_name = conn_name, session_id = session_id })
				table.insert(lines, string.format("%d. %s", idx, item))
				idx = idx + 1
			end
		end
	end

	vim.bo[self.buf].modifiable = true
	vim.api.nvim_buf_set_lines(self.buf, 0, -1, false, lines)
	vim.bo[self.buf].modifiable = false
end

function sessionlist:close()
	if self.win and vim.api.nvim_win_is_valid(self.win) then
		vim.api.nvim_win_close(self.win, true)
	end
	if self.buf and vim.api.nvim_buf_is_valid(self.buf) then
		vim.api.nvim_buf_delete(self.buf, { force = true })
	end
	self.win = nil
	self.buf = nil
end

function sessionlist:set_keymaps()
	vim.keymap.set("n", "<Esc>", function()
		self:close()
	end, { buffer = self.buf, silent = true })

	vim.keymap.set("n", "<CR>", function()
		local row = vim.api.nvim_win_get_cursor(0)[1]
		local idx = row - 3
		if self.session_items and self.session_items[idx] then
			local selected = self.session_items[idx]
			self:close()
			if self.on_select then
				self.on_select(selected)
			end
		end
	end, { buffer = self.buf, silent = true })
end

return sessionlist
--]]

local sessionlist = {}
sessionlist.__index = sessionlist

function sessionlist.new(sessionmanager, on_select)
	local self = setmetatable({}, sessionlist)
	self.sessionmanager = sessionmanager
	self.on_select = on_select
	self:open()
	return self
end

function sessionlist:open()
	local sessions = self.sessionmanager:list_sessions()
	local items = {}

	if not sessions or vim.tbl_isempty(sessions) then
		vim.notify("No active sessions.", vim.log.levels.INFO)
		return
	end

	-- Flatten sessions into selectable items
	for conn_name, conn_sessions in pairs(sessions) do
		for _, session_id in ipairs(conn_sessions) do
			table.insert(items, {
				conn_name = conn_name,
				session_id = session_id,
				label = string.format("(%s) %s", conn_name, session_id),
			})
		end
	end

	vim.ui.select(items, {
		prompt = "Select a Session",
		format_item = function(item)
			return item.label
		end,
	}, function(choice)
		if not choice then
			return -- user cancelled
		end

		if self.on_select then
			self.on_select({
				conn_name = choice.conn_name,
				session_id = choice.session_id,
			})
		end
	end)
end

return sessionlist
