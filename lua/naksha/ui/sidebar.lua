local connectionform = require("naksha.ui.connectionform")

local sidebar = {}
sidebar.__index = sidebar

function sidebar.new(sessionmanager, connectionmanager)
	local self = setmetatable({}, sidebar)
	self.buf = vim.api.nvim_create_buf(false, true)
	self.sessionmanager = sessionmanager
	self.connectionmanager = connectionmanager
	if self.buf and vim.api.nvim_buf_is_valid(self.buf) then
		self:refresh()
		self:set_keymaps()
		return self
	end
end

function sidebar:refresh()
	local conns = self.connectionmanager:load_connections()
	local lines = {}

	if #conns == 0 then
		table.insert(lines, "No saved connections found.")
	else
		table.insert(lines, "Saved JDBC Connections:")
		table.insert(lines, "-----------------------")
		for i, c in ipairs(conns) do
			table.insert(lines, string.format("*. %s", c.name or ""))
		end
	end

	vim.bo[self.buf].modifiable = true
	vim.api.nvim_buf_set_lines(self.buf, 0, -1, false, lines)
	vim.bo[self.buf].modifiable = false
end

function sidebar:set_keymaps()
	vim.keymap.set("n", "<CR>", function()
		local row = vim.api.nvim_win_get_cursor(0)[1]
		local idx = row - 2
		local conns = self.connectionmanager:load_connections()
		local conn = conns[idx]
		if not conn then
			return
		end
		self.sessionmanager:create_session(conn.name, function(response)
			vim.notify("Connected: " .. response.session_id, vim.log.levels.INFO)
		end)
	end, { buffer = self.buf, silent = true })

	vim.keymap.set("n", "e", function()
		local row = vim.api.nvim_win_get_cursor(0)[1]
		local idx = row - 2
		local conns = self.connectionmanager:load_connections()
		local conn = conns[idx]
		if not conn then
			return
		end
		connectionform.new(self.connectionmanager, conn, idx, function()
			self:refresh()
		end)
	end, { buffer = self.buf, silent = true })

	vim.keymap.set("n", "dd", function()
		local row = vim.api.nvim_win_get_cursor(0)[1]
		local idx = row - 2
		local conns = self.connectionmanager:load_connections()
		local conn = conns[idx]
		if not conn then
			return
		end
		local ok = self.connectionmanager:delete_connection(idx)
		if ok then
			vim.notify("Connection deleted", vim.log.levels.INFO)
			self:refresh()
		else
			vim.notify("Failed to delete connection", vim.log.levels.ERROR)
		end
	end, { buffer = self.buf, silent = true })
end

return sidebar
