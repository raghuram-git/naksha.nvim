local connectionform = {}
connectionform.__index = connectionform

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

	return buf, win
end

function connectionform.new(connectionmanager, conn, edit_index, on_success)
	local self = setmetatable({}, connectionform)
	if conn then
		self.conn = conn
	end
	if edit_index then
		self.edit_index = edit_index
	end
	self.connectionmanager = connectionmanager
	self.on_success = on_success
	self.buf, self.win = create_floating_window(50, 12)
	self.lines = {
		"JDBC Confiuration",
		"------------------",
		"",
		"name:" .. (conn and conn.name or ""),
		"host:" .. (conn and conn.host or ""),
		"port:" .. (conn and conn.port or ""),
		"database:" .. (conn and conn.database or ""),
		"username:" .. (conn and conn.username or ""),
		"password:" .. (conn and conn.password or ""),
		"clusterType:" .. (conn and conn.clusterType or ""),
	}
	vim.api.nvim_buf_set_lines(self.buf, 0, -1, false, self.lines)
	vim.bo[self.buf].modifiable = true
	vim.bo[self.buf].buftype = "nofile"
	vim.bo[self.buf].bufhidden = "wipe"
	vim.bo[self.buf].swapfile = false
	vim.api.nvim_win_set_cursor(self.win, { 4, 6 })

	self:setKeymaps()
end

function connectionform:close()
	-- Close window if valid
	if self.win and vim.api.nvim_win_is_valid(self.win) then
		vim.api.nvim_win_close(self.win, true)
	end
	-- Delete buffer if valid
	if self.buf and vim.api.nvim_buf_is_valid(self.buf) then
		vim.api.nvim_buf_delete(self.buf, { force = true })
	end

	self.win = nil
	self.buf = nil
end

function connectionform:submit()
	local lines = vim.api.nvim_buf_get_lines(self.buf, 0, -1, false)

	local function get_value(prefix)
		for _, line in ipairs(lines) do
			if line:match("^" .. prefix) then
				return vim.trim(line:gsub(prefix, ""))
			end
		end
	end

	local values = {
		name = get_value("name:"),
		host = get_value("host:"),
		port = get_value("port:"),
		database = get_value("database:"),
		username = get_value("username:"),
		password = get_value("password:"),
		clusterType = get_value("clusterType:"),
	}

	if not values.name or values.name == "" then
		vim.notify("name cannot be empty", vim.log.levels.WARN)
		return
	end

	local conns = self.connectionmanager:load_connections()

	if self.edit_index then
		conns[self.edit_index] = values

		local ok = self.connectionmanager:save_connections(conns)
		if ok then
			vim.notify("Connection updated successfully", vim.log.levels.INFO)
			vim.api.nvim_win_close(self.win, true)
			if self.on_success then
				self.on_success()
			end
		else
			vim.notify("Failed to update connection", vim.log.levels.ERROR)
		end
		return
	end

	if self.connectionmanager:connection_exists(conns, values) then
		vim.notify("Connection already exists!", vim.log.levels.WARN)
		return
	end

	table.insert(conns, values)

	local ok = self.connectionmanager:save_connections(conns)

	if ok then
		vim.notify("Connection saved successfully", vim.log.levels.INFO)
		vim.api.nvim_win_close(self.win, true)
		if self.on_success then
			self.on_success()
		end
	else
		vim.notify("Failed to save connection", vim.log.levels.ERROR)
	end
end

function connectionform:setKeymaps()
	-- Closing the connectionform without submitting
	vim.keymap.set("n", "<Esc>", function()
		self:close()
	end, { buffer = self.buf })

	-- Closing the connectionform with submitting
	vim.keymap.set("n", "<CR>", function()
		self:submit()
	end, { buffer = self.buf })
end

return connectionform
