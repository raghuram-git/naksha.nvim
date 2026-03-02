local M = {}

local ui = require("naksha.ui")
local connectionmanager = require("naksha.connections.connectionmanager")
local sessionmanager = require("naksha.connections.sessionmanager")
local rpcclient = require("naksha.rpcclient")

function M.start()
	M.rpcclient = rpcclient.new()
	M.connectionmanager = connectionmanager.new()
	M.sessionmanager = sessionmanager.new(M.rpcclient)
	M.ui = ui.new(M.sessionmanager, M.connectionmanager)
end

function M.stop()
	M.ui:close_ui()
	M.rpcclient:stop_backend_server()
end

function M.setup()
	vim.api.nvim_create_user_command("NakshaStart", M.start, {})
	vim.api.nvim_create_user_command("NakshaStop", M.stop, {})
	vim.api.nvim_create_user_command("NakshaToggle", function()
		M.ui:toggle_ui()
	end, {})
	vim.api.nvim_create_user_command("NakshaCreateConnection", function()
		M.ui:open_create_connections()
	end, {})
	vim.api.nvim_create_user_command("NakshaListSessions", function()
		M.ui:open_list_sessions()
	end, {})
end

return M
