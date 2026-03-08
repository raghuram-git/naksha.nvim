local gutter = {}
gutter.__index = gutter

function gutter.new()
	local obj = setmetatable({}, gutter)

	obj.spinner_frames = {
		"⠋",
		"⠙",
		"⠹",
		"⠸",
		"⠼",
		"⠴",
		"⠦",
		"⠧",
		"⠇",
		"⠏",
	}

	obj.spinners = {}

	-- uv compatibility (VERY IMPORTANT)
	obj.uv = vim.uv or vim.loop

	-- Define spinner signs once
	for i, frame in ipairs(obj.spinner_frames) do
		vim.fn.sign_define("QuerySpinner" .. i, {
			text = frame,
			texthl = "DiagnosticInfo",
		})
	end

	vim.fn.sign_define("QuerySuccess", {
		text = "✓",
		texthl = "DiagnosticOk",
	})

	vim.fn.sign_define("QueryError", {
		text = "✗",
		texthl = "DiagnosticError",
	})

	return obj
end

function gutter:start_spinner(bufnr, line)
	bufnr = bufnr or vim.api.nvim_get_current_buf()

	local key = bufnr .. ":" .. line

	if self.spinners[key] then
		return
	end

	local frame = 1
	local uv = self.uv

	local timer = uv.new_timer()

	timer:start(
		0,
		80,
		vim.schedule_wrap(function()
			if self.spinners[key] ~= timer then
				return
			end
			if not vim.api.nvim_buf_is_valid(bufnr) then
				timer:stop()
				timer:close()
				self.spinners[key] = nil
				return
			end

			-- Remove old sign
			vim.fn.sign_unplace("query_runner", {
				buffer = bufnr,
				id = line,
			})

			-- Place spinner sign
			local sign_name = "QuerySpinner" .. frame

			vim.fn.sign_place(line, "query_runner", sign_name, bufnr, {
				lnum = line,
				priority = 10,
			})

			frame = frame % #self.spinner_frames + 1
		end)
	)

	self.spinners[key] = timer
end

function gutter:show_status(bufnr, line, status)
	bufnr = bufnr or vim.api.nvim_get_current_buf()

	local key = bufnr .. ":" .. line

	local timer = self.spinners[key]
	if timer then
		timer:stop()
		timer:close()
		self.spinners[key] = nil
	end

	vim.fn.sign_unplace("query_runner", {
		buffer = bufnr,
		id = line,
	})

	local sign_name = status == "success" and "QuerySuccess" or "QueryError"

	vim.fn.sign_place(line, "query_runner", sign_name, bufnr, {
		lnum = line,
		priority = 10,
	})
end

function gutter:clear(bufnr, line)
	bufnr = bufnr or vim.api.nvim_get_current_buf()

	local key = bufnr .. ":" .. line

	local timer = self.spinners[key]
	if timer then
		timer:stop()
		timer:close()
		self.spinners[key] = nil
	end

	vim.fn.sign_unplace("query_runner", {
		buffer = bufnr,
		id = line,
	})
end

return gutter
