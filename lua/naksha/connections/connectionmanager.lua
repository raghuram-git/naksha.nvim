local connectionmanager = {}
connectionmanager.__index = connectionmanager

local json = vim.fn.json_decode
local json_encode = vim.fn.json_encode

local function get_default_config_path()
	local data_dir = vim.fn.stdpath("data")
	local naksha_dir = data_dir .. "/naksha"
	if vim.fn.isdirectory(naksha_dir) == 0 then
		vim.fn.mkdir(naksha_dir, "p")
	end
	return naksha_dir .. "/connections.json"
end

function connectionmanager.new()
	local self = setmetatable({}, connectionmanager)
	self.config_path = get_default_config_path()
	return self
end

function connectionmanager:load_connections()
	local f = io.open(self.config_path, "r")
	if not f then
		return {}
	end
	local content = f:read("*a")
	f:close()
	local ok, data = pcall(vim.fn.json_decode, content)
	if ok and type(data) == "table" then
		return data
	end
	return {}
end

function connectionmanager:save_connections(data)
	local f = io.open(self.config_path, "w")
	if not f then
		vim.notify("Failed to open connection file for writing: " .. self.config_path, vim.log.levels.ERROR)
		return false
	end
	f:write(vim.fn.json_encode(data))
	f:close()
	return true
end

function connectionmanager:connection_exists(conns, new_conn)
	for _, c in ipairs(conns) do
		if c.name == new_conn.name then
			return true
		end
	end
	return false
end

function connectionmanager:delete_connection(idx)
	local conns = self:load_connections()
	if idx < 1 or idx > #conns then
		return false
	end
	table.remove(conns, idx)
	return self:save_connections(conns)
end

return connectionmanager
