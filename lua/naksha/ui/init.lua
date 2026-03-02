local ui = {}
ui.__index = ui

local layout = require("naksha.ui.layout")
local connectionform = require("naksha.ui.connectionform")
local sessionlist = require("naksha.ui.sessionlist")
local connections = require("naksha.connections.connectionmanager")

function ui.new(sessionmanager, connectionmanager, rpcclient)
	local self = setmetatable({}, ui)
	self.sessionmanager = sessionmanager
	self.connectionmanager = connectionmanager
	self.layout = layout.new(sessionmanager, connectionmanager)
	return self
end

function ui:close_ui()
	if not self.layout then
		return
	end
	self.layout:close_layout()
end

function ui:toggle_ui()
	if not self.layout then
		return
	end
	ui.layout:go_to_previous_tab()
end

--Note: Connection Form is a seperate window, thats why it is here
function ui:open_create_connections()
	connectionform.new(self.connectionmanager, nil, nil, function()
		self.layout.sidebar:refresh()
	end)
end

--Note: Session Form is a seperate window, thats why it is here
function ui:open_list_sessions(on_select)
	sessionlist.new(self.sessionmanager, on_select)
end

return ui
