local sessionmanager = {}
sessionmanager.__index = sessionmanager

local callback_counter = 0

local function generate_callback_id()
	callback_counter = callback_counter + 1
	return "cb_" .. callback_counter
end

function sessionmanager.new(rpcclient)
	local self = setmetatable({}, sessionmanager)
	self.session_pool = {}
	self.active_queries = {}
	self.rpcclient = rpcclient
	return self
end

function sessionmanager:add_session_to_pool(sessionid, connectionname)
	if not self.session_pool[connectionname] then
		self.session_pool[connectionname] = {}
	end

	table.insert(self.session_pool[connectionname], sessionid)
end

function sessionmanager:create_session(connection_name, callback)
	local callback_id = generate_callback_id()
	self.rpcclient:register_callback(callback_id, function(result)
		if result.error then
			vim.notify("Failed to create session: " .. tostring(result.error), vim.log.levels.ERROR)
			return
		end
		vim.notify("created session: " .. tostring(result.session_id), vim.log.levels.INFO)
		self:add_session_to_pool(result.session_id, connection_name)
		callback(result)
	end)

	local req = {
		connectionConfigName = connection_name,
		callback_id = callback_id,
	}
	vim.rpcnotify(self.rpcclient.job_id, "create_session", req)
end

function sessionmanager:list_sessions()
	return self.session_pool
end

function sessionmanager:run_query(session_id, sql, callback)
	local callback_id = generate_callback_id()
	self.active_queries[callback_id] = true
	self.rpcclient:register_callback(callback_id, function(result)
		self.active_queries[callback_id] = nil
		if result.error then
			if result.error == "query cancelled" then
				vim.notify("Query cancelled", vim.log.levels.INFO)
			else
				vim.notify("Failed to run query: " .. tostring(result.error), vim.log.levels.ERROR)
			end
		else
			vim.notify("Query executed successfully", vim.log.levels.INFO)
		end
		callback(result)
	end)

	local req = {
		session_id = session_id,
		query = sql,
		callback_id = callback_id,
	}
	vim.rpcnotify(self.rpcclient.job_id, "run_query", req)

	return callback_id
end

function sessionmanager:cancel_query(callback_id)
	if callback_id and callback_id ~= "" and self.active_queries[callback_id] then
		self.rpcclient:cancel_callback(callback_id)
		self.active_queries[callback_id] = nil
		vim.notify("Query cancelled", vim.log.levels.INFO)
	end
end

return sessionmanager
