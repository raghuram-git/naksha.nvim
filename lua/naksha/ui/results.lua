local Checklist = require("naksha.ui.checkboxpicker")

local results = {}
results.__index = results

-- Result builder Helpers
local function compute_column_widths(headers, rows)
	local col_widths = {}

	for i, h in ipairs(headers) do
		col_widths[i] = #tostring(h)
	end

	for _, row in ipairs(rows) do
		for i, v in ipairs(row) do
			local len = #tostring(v)
			if not col_widths[i] or len > col_widths[i] then
				col_widths[i] = len
			end
		end
	end

	return col_widths
end

local function build_separator(col_widths, left, mid, right, fill)
	local parts = {}

	for _, w in ipairs(col_widths) do
		table.insert(parts, fill:rep(w + 2))
	end

	return left .. table.concat(parts, mid) .. right
end

local function build_row(col_widths, values)
	local parts = {}

	for i, w in ipairs(col_widths) do
		local str = tostring(values[i] or "")
		local padding = w - #str
		table.insert(parts, " " .. str .. (" "):rep(padding + 1))
	end

	return "│" .. table.concat(parts, "│") .. "│"
end

local function format_ascii_table(headers, rows)
	if #headers == 0 then
		return {}, {}
	end

	local col_widths = compute_column_widths(headers, rows)

	local top_border = build_separator(col_widths, "┌", "┬", "┐", "─")
	local header_row = build_row(col_widths, headers)
	local header_split = build_separator(col_widths, "├", "┼", "┤", "─")
	local bottom_border = build_separator(col_widths, "└", "┴", "┘", "─")

	-- Header-only section (for sticky window)
	local header_lines = {
		top_border,
		header_row,
		header_split,
	}

	-- Full table (header + rows + bottom border)
	local body_lines = {
		top_border,
		header_row,
		header_split,
	}

	for _, row in ipairs(rows) do
		table.insert(body_lines, build_row(col_widths, row))
	end

	table.insert(body_lines, bottom_border)

	return header_lines, body_lines
end
-- Result builder Helpers

function results.new(results_win, editor_win)
	local self = setmetatable({}, results)
	self.buffers = {}
	self.data_store = {}
	self.current_buf = nil
	self.results_win = results_win
	self.editor_win = editor_win
	self:create_header_window()

	vim.wo[self.results_win].number = true
	vim.wo[self.results_win].statuscolumn = "%=%{v:lnum > 3 ? v:lnum : ''} "

	return self
end

-- Header window Helpers
-- This funciton is to make sure the headers aslo move if we move horizontally on results buffer
function results:attach_header_sync()
	if self._header_autocmd then
		return
	end

	self._header_autocmd = vim.api.nvim_create_autocmd("WinScrolled", {
		callback = function()
			if not vim.api.nvim_win_is_valid(self.results_win) then
				return
			end

			local info = vim.fn.getwininfo(self.results_win)[1]
			local textoff = info.textoff
			local width = vim.api.nvim_win_get_width(self.results_win)

			-- Reposition + resize header
			if vim.api.nvim_win_is_valid(self.header_window) then
				vim.api.nvim_win_set_config(self.header_window, {
					relative = "win",
					win = self.results_win,
					row = 0,
					col = textoff,
					width = width - textoff,
				})

				-- Sync horizontal scroll
				local view = vim.api.nvim_win_call(self.results_win, function()
					return vim.fn.winsaveview()
				end)

				vim.api.nvim_win_call(self.header_window, function()
					vim.fn.winrestview({ leftcol = view.leftcol })
				end)
			end
		end,
	})
end

function results:create_header_window()
	self.header_buf = vim.api.nvim_create_buf(false, true)
	vim.bo[self.header_buf].modifiable = true

	local width = vim.api.nvim_win_get_width(self.results_win)
	local info = vim.fn.getwininfo(self.results_win)[1]
	local textoff = info.textoff

	self.header_window = vim.api.nvim_open_win(self.header_buf, false, {
		relative = "win",
		win = self.results_win,
		width = width - textoff,
		height = 3,
		row = 0,
		col = textoff,
		style = "minimal",
		border = "none",
	})

	vim.wo[self.header_window].winhighlight = "Normal:Normal"
	vim.wo[self.header_window].number = false
	vim.wo[self.header_window].relativenumber = false
	vim.wo[self.header_window].signcolumn = "no"
	vim.wo[self.header_window].foldcolumn = "0"

	self:attach_header_sync()
end

function results:refresh_header()
	if not self.header_buf or not vim.api.nvim_buf_is_valid(self.header_buf) then
		return
	end
	if not self.current_buf then
		return
	end
	local lines = vim.api.nvim_buf_get_lines(self.current_buf, 0, 3, false)
	vim.api.nvim_buf_set_lines(self.header_buf, 0, -1, false, lines)
end
-- Header window Helpers

-- Column filter functions

function results:get_unique_column_values(key)
	if not key then
		return { all = {}, filtered = {} }
	end

	local all_set = {}
	local filtered_set = {}

	for _, row in ipairs(self.data_store[self.current_buf].raw_data or {}) do
		local val = tostring(row[key] or "")
		all_set[val] = true
	end

	for _, row in ipairs(self:get_filtered_data()) do
		local val = tostring(row[key] or "")
		filtered_set[val] = true
	end

	local all_values = {}
	local filtered_values = {}

	for v, _ in pairs(all_set) do
		table.insert(all_values, v)
	end
	table.sort(all_values)

	for v, _ in pairs(filtered_set) do
		table.insert(filtered_values, v)
	end

	return { all = all_values, filtered = filtered_values }
end

function results:get_filtered_data()
	local filters = self.data_store[self.current_buf].filters or {}
	local data = self.data_store[self.current_buf].raw_data or {}

	for filter_key, allowed_values in pairs(filters) do
		local allowed_set = {}
		for _, v in ipairs(allowed_values) do
			allowed_set[tostring(v)] = true
		end

		local filtered = {}
		for _, row in ipairs(data) do
			local val = tostring(row[filter_key] or "")
			if allowed_set[val] then
				table.insert(filtered, row)
			end
		end
		data = filtered
	end

	return data
end

function results:filter_on_column()
	local key = vim.fn.expand("<cword>")
	if not key:match("^[%w_]+$") then
		vim.notify("Move cursor to a column header", vim.log.levels.WARN)
		return
	end
	local result = self:get_unique_column_values(key)
	if not result.all or #result.all == 0 then
		return
	end
	local current_filter = self.data_store[self.current_buf].filters[key] or {}
	local preselected = #result.filtered > 0 and result.filtered or current_filter
	local popup = Checklist:new({
		title = "Filter: " .. key,
		items = result.all,
		preselected = preselected,
		on_confirm = function(selected)
			self:apply_filter(key, selected)
		end,
	})
	popup:open()
end

function results:apply_filter(key, allowed)
	if not key then
		return
	end

	self.data_store[self.current_buf].filters[key] = allowed

	local filtered = self:get_filtered_data()

	local rows = {}
	for _, row in ipairs(filtered) do
		local values = {}
		for _, h in ipairs(self.data_store[self.current_buf].headers) do
			table.insert(values, row[h])
		end
		table.insert(rows, values)
	end
	local header_lines, body_lines = format_ascii_table(self.data_store[self.current_buf].headers, rows)

	vim.api.nvim_buf_set_lines(self.current_buf, 0, -1, false, body_lines)
	vim.api.nvim_buf_set_lines(self.header_buf, 0, -1, false, header_lines)
end

function results:clear_filters()
	self.data_store[self.current_buf].filters = {}
	local rows = {}
	for _, row in ipairs(self.data_store[self.current_buf].raw_data) do
		local values = {}
		for _, h in ipairs(self.data_store[self.current_buf].headers) do
			table.insert(values, row[h])
		end
		table.insert(rows, values)
	end
	local header_lines, body_lines = format_ascii_table(self.data_store[self.current_buf].headers, rows)
	vim.api.nvim_buf_set_lines(self.current_buf, 0, -1, false, body_lines)
	vim.api.nvim_buf_set_lines(self.header_buf, 0, -1, false, header_lines)
end

-- Column filter functions

function results:add_buffer(editor, sql)
	local buf = vim.api.nvim_create_buf(false, true)
	if buf and vim.api.nvim_buf_is_valid(buf) then
		vim.b[buf].query_sql = sql

		table.insert(self.buffers, buf)
		self.current_buf = buf
		if vim.api.nvim_win_is_valid(self.results_win) then
			vim.api.nvim_win_set_buf(self.results_win, buf)
		end
		if editor and vim.api.nvim_buf_is_valid(editor.current_buf) then
			vim.b[self.current_buf].editor_tag = vim.api.nvim_buf_get_name(editor.current_buf)
		end
	end
	self:set_keymaps()
end

function results:display_results(decoded_data, editor, sql)
	local header_lines = {}
	local body_lines = {}
	local headers = {}
	local rows = {}

	if #decoded_data > 0 then
		headers = vim.tbl_keys(decoded_data[1])
		for _, row in ipairs(decoded_data) do
			local values = vim.tbl_values(row)
			table.insert(rows, values)
		end
		header_lines, body_lines = format_ascii_table(headers, rows)
	end

	self:add_buffer(editor, sql)
	self.data_store[self.current_buf] = {
		raw_data = decoded_data,
		headers = headers,
		rows = rows,
		filters = {},
	}
	if self.current_buf and vim.api.nvim_buf_is_valid(self.current_buf) then
		vim.api.nvim_buf_set_lines(self.current_buf, 0, -1, false, body_lines)
	end
	if self.header_buf and vim.api.nvim_buf_is_valid(self.header_buf) then
		vim.api.nvim_buf_set_lines(self.header_buf, 0, -1, false, header_lines)
	end
	if vim.api.nvim_win_is_valid(self.results_win) then
		vim.api.nvim_win_set_buf(self.results_win, self.current_buf)
	end
end

function results:pick_buffer()
	local pickers = require("telescope.pickers")
	local previewers = require("telescope.previewers")
	local finders = require("telescope.finders")
	local actions = require("telescope.actions")
	local action_state = require("telescope.actions.state")
	local conf = require("telescope.config").values

	local current_editor_buf = nil
	if self.editor_win and vim.api.nvim_win_is_valid(self.editor_win) then
		current_editor_buf = vim.api.nvim_win_get_buf(self.editor_win)
	end

	local filtered_buffers = self.buffers
	if current_editor_buf then
		local current_editor_name = vim.api.nvim_buf_get_name(current_editor_buf)
		filtered_buffers = vim.tbl_filter(function(buf)
			local tag = vim.b[buf].editor_tag
			return tag and tag == current_editor_name
		end, self.buffers)
	end

	pickers
		.new({}, {
			prompt_title = "Results Buffers",

			-- ⭐ Vertical layout = list on top, preview at bottom
			layout_strategy = "vertical",

			layout_config = {
				vertical = {
					width = 0.9,
					height = 0.9,
					preview_height = 0.4,
					preview_cutoff = 0,
				},
			},

			finder = finders.new_table({
				results = filtered_buffers,
				entry_maker = function(buf)
					local sql = vim.b[buf].query_sql or ""
					local max_len = 50
					local display = #sql > max_len and sql:sub(1, max_len) .. "..." or sql
					if display == "" then
						display = "[No Name]"
					end

					return {
						value = buf,
						display = display,
						ordinal = display,
					}
				end,
			}),

			sorter = conf.generic_sorter({}),

			previewer = previewers.new_buffer_previewer({
				define_preview = function(preview_self, entry)
					local lines = vim.api.nvim_buf_get_lines(entry.value, 0, -1, false)
					vim.api.nvim_buf_set_lines(preview_self.state.bufnr, 0, -1, false, lines)
				end,
			}),

			attach_mappings = function(prompt_bufnr)
				actions.select_default:replace(function()
					local selection = action_state.get_selected_entry()

					actions.close(prompt_bufnr)

					if selection and selection.value then
						vim.api.nvim_win_set_buf(self.results_win, selection.value)
						self.current_buf = selection.value

						-- Refresh header
						self:refresh_header()
					end
				end)

				return true
			end,
		})
		:find()
end

function results:set_keymaps()
	local buf = vim.api.nvim_win_get_buf(self.results_win)
	vim.keymap.set("n", "<leader>hr", function()
		self:pick_buffer()
	end, { silent = true, buffer = buf, desc = "Pick results buffer" })
	vim.keymap.set("n", "<leader>hf", function()
		self:filter_on_column()
	end, { silent = true, buffer = buf, desc = "Filter column" })
	vim.keymap.set("n", "<leader>hC", function()
		self:clear_filters()
	end, { silent = true, buffer = buf, desc = "Clear all filters" })
end

return results
