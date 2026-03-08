local rpcclient = {}
rpcclient.__index = rpcclient

function rpcclient.new()
	local self = setmetatable({}, rpcclient)
	local plugin_root = vim.fn.fnamemodify(debug.getinfo(1).source:sub(2), ":h:h:h")
	self.bin_path = plugin_root .. "/bin/db_server"

	local data_dir = vim.fn.stdpath("data")
	local naksha_dir = data_dir .. "/naksha"

	if vim.fn.isdirectory(naksha_dir) == 0 then
		vim.fn.mkdir(naksha_dir, "p")
	end

	self.config_path = naksha_dir

	if vim.fn.executable(self.bin_path) ~= 1 then
		vim.notify("Go binary not found at " .. self.bin_path, vim.log.levels.ERROR)
		return
	end

	self.callbacks = {}

	self.job_id = vim.fn.jobstart({
		self.bin_path,
		self.config_path,
	}, {
		rpc = true,
		on_stderr = function(_, data)
			local line = table.concat(data, "")
			if line:match("^NAKSHA_CALLBACK:") then
				self:handle_callback(line)
			elseif line ~= "" then
				vim.notify("Go stderr: " .. line, vim.log.levels.WARN)
			end
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

function rpcclient:handle_callback(line)
	local json_str = line:gsub("^NAKSHA_CALLBACK:", "")
	local ok, callback_data = pcall(vim.json.decode, json_str)
	if not ok then
		vim.notify("Failed to parse callback: " .. json_str, vim.log.levels.ERROR)
		return
	end

	local callback_id = callback_data.callback_id
	local result = callback_data.result

	local callback_fn = self.callbacks[callback_id]
	if callback_fn then
		vim.schedule_wrap(callback_fn)(result)
		self.callbacks[callback_id] = nil
	end
end

function rpcclient:register_callback(callback_id, callback_fn)
	self.callbacks[callback_id] = callback_fn
end

function rpcclient:cancel_callback(callback_id)
	if self.job_id and self.job_id > 0 then
		local req = {
			callback_id = callback_id,
		}
		vim.rpcnotify(self.job_id, "cancel_query", req)
	end
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
