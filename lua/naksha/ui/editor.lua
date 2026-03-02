local sessionlist = require("naksha.ui.sessionlist")
local results = require("naksha.ui.results")

local editor = {}
editor.__index = editor

function editor.new(sessionmanager, connectionmanager, editor_win, results_win)
	local self = setmetatable({}, editor)
	self.buffers = {}
	self.current_buf = nil
	self.sessionmanager = sessionmanager
	self.connectionmanager = connectionmanager
	self.connection_counter = {}
	self.editor_win = editor_win
	self.results_win = results_win
	self.results = results.new(self.results_win, self.editor_win)

	self:set_keymaps()
	return self
end

function editor:add_buffer()
	local buf = vim.api.nvim_create_buf(true, false)
	if buf and vim.api.nvim_buf_is_valid(buf) then
		vim.bo[buf].filetype = "sql"
		vim.bo[buf].bufhidden = "hide"
		table.insert(self.buffers, buf)
		self.current_buf = buf
		if vim.api.nvim_win_is_valid(self.editor_win) then
			vim.api.nvim_win_set_buf(self.editor_win, buf)
		end
	end
end

function editor:open_file_buffer()
	local ok, telescope = pcall(require, "telescope")
	if not ok then
		vim.notify("telescope not installed", vim.log.levels.ERROR)
		return
	end

	local pickers = require("telescope.pickers")
	local finders = require("telescope.finders")
	local actions = require("telescope.actions")
	local action_state = require("telescope.actions.state")
	local conf = require("telescope.config").values

	local function open_file(prompt_bufnr)
		local selection = action_state.get_selected_entry()
		actions.close(prompt_bufnr)

		if selection and selection.value then
			local filepath = selection.value
			self:add_buffer()
			if self.current_buf then
				local lines = vim.fn.readfile(filepath)
				if lines then
					vim.api.nvim_buf_set_lines(self.current_buf, 0, -1, false, lines)
					vim.api.nvim_buf_set_name(self.current_buf, filepath)
					vim.bo[self.current_buf].filetype = "sql"
				else
					vim.notify("Could not read file: " .. filepath, vim.log.levels.ERROR)
				end
			end
		end
	end

	local cmd = { "rg", "--type", "sql", "--files", "--glob", "!**/node_modules/**", "--glob", "!**/.git/**" }
	local output = vim.fn.systemlist(cmd)
	if vim.v.shell_error ~= 0 then
		vim.notify("No SQL files found", vim.log.levels.WARN)
		return
	end

	local entries = {}
	for _, line in ipairs(output) do
		if vim.fn.isdirectory(line) == 0 then
			table.insert(entries, {
				value = line,
				display = vim.fn.fnamemodify(line, ":t") .. " - " .. vim.fn.fnamemodify(line, ":h"),
				ordinal = line,
			})
		end
	end

	pickers
		.new({}, {
			prompt_title = "SQL Files",
			layout_strategy = "horizontal",
			layout_config = {
				width = 0.8,
				height = 0.8,
			},
			finder = finders.new_table({
				results = entries,
				entry_maker = function(entry)
					return entry
				end,
			}),
			sorter = conf.generic_sorter({}),
			attach_mappings = function(prompt_bufnr)
				actions.select_default:replace(function()
					open_file(prompt_bufnr)
				end)
				return true
			end,
		})
		:find()
end
-- ExtraFunction. Telescope Handles it
function editor:switch_buffer(direction)
	if not self.current_buf or #self.buffers <= 1 then
		return
	end
	local current_idx = vim.tbl_index(self.buffers, self.current_buf)
	if not current_idx then
		return
	end
	local new_idx = current_idx + direction
	if new_idx < 1 then
		new_idx = #self.buffers
	elseif new_idx > #self.buffers then
		new_idx = 1
	end
	self.current_buf = self.buffers[new_idx]
	if vim.api.nvim_win_is_valid(self.editor_win) then
		vim.api.nvim_win_set_buf(self.editor_win, self.current_buf)
	end
end
-- ExtraFunction. Telescope Handles it
function editor:delete_current_buffer()
	if #self.buffers <= 1 then
		vim.notify("Cannot delete the last buffer", vim.log.levels.WARN)
		return
	end
	local current_idx = vim.tbl_index(self.buffers, self.current_buf)
	if not current_idx then
		return
	end
	vim.api.nvim_buf_delete(self.current_buf, { force = true })
	table.remove(self.buffers, current_idx)
	self.current_buf = self.buffers[math.min(current_idx, #self.buffers)]
	if vim.api.nvim_win_is_valid(self.editor_win) then
		vim.api.nvim_win_set_buf(self.editor_win, self.current_buf)
	end
end

function editor:get_current_session_id()
	if self.current_buf then
		return vim.b[self.current_buf].naksha_session_id
	end
	return nil
end

function editor:attach_session(session_items)
	if self.current_buf then
		vim.b[self.current_buf].naksha_session_id = session_items.session_id
		vim.b[self.current_buf].naksha_connection_name = session_items.conn_name

		--update buffer counter
		local connection = session_items.conn_name
		if not self.connection_counter[connection] then
			self.connection_counter[connection] = {
				counter = 1,
				buffers = { self.current_buf },
			}
		else
			self.connection_counter[connection].counter = self.connection_counter[connection].counter + 1
			table.insert(self.connection_counter[connection].buffers, self.current_buf)
		end

		--renaming buffer
		if vim.api.nvim_buf_get_name(self.current_buf) == "" then
			local name = string.format("[%s:%d]", connection, self.connection_counter[connection].counter)
			vim.api.nvim_buf_set_name(self.current_buf, name)
		end
	end
end

function editor:get_visual_selection()
	local s_start = vim.fn.getpos("'<")
	local s_end = vim.fn.getpos("'>")
	local n_lines = vim.api.nvim_buf_line_count(0)
	local lines = vim.api.nvim_buf_get_lines(0, s_start[2] - 1, math.min(s_end[2], n_lines), false)
	return table.concat(lines, "\n")
end

function editor:get_current_line()
	local row = vim.api.nvim_win_get_cursor(0)[1]
	local line = vim.api.nvim_buf_get_lines(0, row - 1, row, false)
	return line[1] or ""
end

function editor:run_query(sql)
	local session_id = self:get_current_session_id()
	if not session_id then
		vim.notify("No session attached to buffer", vim.log.levels.ERROR)
		return
	end

	if not sql or sql == "" then
		vim.notify("No query to execute", vim.log.levels.WARN)
		return
	end

	self.sessionmanager:run_query(session_id, sql, function(result)
		if result.status == "success" and result.results == "null" then
			print("DML Query")
			return
		else
			local decoded = vim.fn.json_decode(result.results)
			self.results:display_results(decoded, self, result.query)
		end
	end)
end

function editor:set_keymaps()
	vim.keymap.set("n", "<leader>hn", function()
		self:add_buffer()
	end, { silent = true, desc = "New SQL buffer" })

	vim.keymap.set("n", "<leader>hs", function()
		sessionlist = sessionlist.new(self.sessionmanager, function(session_items)
			self:attach_session(session_items)
		end)
	end, { silent = true, desc = "Attach Session to a buffer" })

	vim.keymap.set({ "n", "x" }, "<leader>hq", function()
		local mode = vim.fn.mode()
		vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "x", false)
		if mode == "v" or mode == "V" or mode == "\22" then
			local s_row = vim.api.nvim_buf_get_mark(0, "<")[1]
			local e_row = vim.api.nvim_buf_get_mark(0, ">")[1]
			local lines = vim.api.nvim_buf_get_lines(0, s_row - 1, e_row, false)
			self:run_query(table.concat(lines, "\n"))
		else
			self:run_query(self:get_current_line())
		end
	end, { silent = true })

	vim.keymap.set("n", "<leader>ho", function()
		self:open_file_buffer()
	end, { silent = true, desc = "Open SQL file via telescope" })
end

return editor
