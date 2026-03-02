local sessionmanager = {}
sessionmanager.__index = sessionmanager

function sessionmanager.new(rpcclient)
	local self = setmetatable({}, sessionmanager)
	self.session_pool = {}
	self.rpcclient = rpcclient.job_id
	return self
end

function sessionmanager:add_session_to_pool(sessionid, connectionname)
	if not self.session_pool[connectionname] then
		self.session_pool[connectionname] = {}
	end

	table.insert(self.session_pool[connectionname], sessionid)
end

function sessionmanager:create_session(connection_name, callback)
	local req = {
		connectionConfigName = connection_name,
	}
	local result, ok = vim.fn.rpcrequest(self.rpcclient, "create_session", req)

	if ok ~= nil then
		vim.notify("Failed to create session: " .. tostring(ok), vim.log.levels.ERROR)
		return
	end

	vim.notify("created session: " .. tostring(result.session_id), vim.log.levels.INFO)
	self:add_session_to_pool(result.session_id, connection_name)
	callback(result)
end

function sessionmanager:list_sessions()
	return self.session_pool
end

function sessionmanager:run_query(session_id, sql, callback)
	local req = {
		session_id = session_id,
		query = sql,
	}
	local result, err = vim.fn.rpcrequest(self.rpcclient, "run_query", req)

	if err ~= nil then
		vim.notify("Failed to run query: " .. tostring(err), vim.log.levels.ERROR)
		return
	end
	vim.notify("Query executed successfully", vim.log.levels.INFO)
	callback(result)
end

return sessionmanager
