local rpcclient = {}
rpcclient.__index = rpcclient

function rpcclient.new()
	local self = setmetatable({}, rpcclient)
	local plugin_root = vim.fn.fnamemodify(debug.getinfo(1).source:sub(2), ":h:h:h")
	self.bin_path = plugin_root .. "/bin/db_server"
	self.config_path = plugin_root .. "/backend/configuration"

	if vim.fn.executable(self.bin_path) ~= 1 then
		vim.notify("Go binary not found at " .. self.bin_path, vim.log.levels.ERROR)
		return
	end

	self.job_id = vim.fn.jobstart({
		self.bin_path,
		self.config_path,
	}, {
		rpc = true,
		on_stderr = function(_, data)
			vim.notify("Go stderr: " .. table.concat(data, ""), vim.log.levels.WARN)
		end,
		on_exit = function(j, code, signal)
			self.job_id = nil
			if code ~= 0 then
				print("Go RPC server exited with code: " .. code)
			end
		end,
	})

	return self
end

function rpcclient:stop_backend_server()
	if self.job_id and self.job_id > 0 then
		vim.fn.jobstop(self.job_id)
		self.job_id = nil
		self.sessions = {}
		print("Go RPC Server stopped.")
	end
end

return rpcclient
