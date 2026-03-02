-- Completely vibe coded
-- Completely vibe coded - Refactored Version
local CheckboxPicker = {}
CheckboxPicker.__index = CheckboxPicker

--------------------------------------------------
-- Utils
--------------------------------------------------

local function shallow_copy(tbl)
	local t = {}
	for _, v in ipairs(tbl) do
		table.insert(t, v)
	end
	return t
end

local function contains(tbl, val)
	for _, v in ipairs(tbl) do
		if v == val then
			return true
		end
	end
	return false
end

local function max_len(tbl)
	local m = 0
	for _, v in ipairs(tbl) do
		m = math.max(m, #tostring(v))
	end
	return m
end

--------------------------------------------------
-- Constructor
--------------------------------------------------

function CheckboxPicker:new(opts)
	local obj = setmetatable({}, self)

	obj.title = opts.title or "Picker"
	obj.items = opts.items or {}
	obj.on_confirm = opts.on_confirm or function() end

	obj.filtered_items = shallow_copy(obj.items)
	obj.selected = opts.preselected or {}

	obj.search = ""
	obj.buf = nil
	obj.win = nil
	obj.is_rendering = false -- Guard to prevent recursive autocmds

	obj.ns = vim.api.nvim_create_namespace("CheckboxPicker")
	obj.autocmds = {}

	return obj
end

--------------------------------------------------
-- Window sizing
--------------------------------------------------

function CheckboxPicker:calculate_size()
	local width = math.max(#self.title, #("🔍 " .. self.search), max_len(self.filtered_items) + 6) + 8
	local height = math.min(#self.filtered_items + 4, 20)

	return {
		width = math.floor(math.min(width, vim.o.columns * 0.8)),
		height = math.floor(math.min(height, vim.o.lines * 0.7)),
	}
end

--------------------------------------------------
-- Filtering
--------------------------------------------------

function CheckboxPicker:filter()
	local query = self.search:lower()
	if query == "" then
		self.filtered_items = shallow_copy(self.items)
		return
	end

	local result = {}
	for _, item in ipairs(self.items) do
		if tostring(item):lower():find(query, 1, true) then
			table.insert(result, item)
		end
	end
	self.filtered_items = result
end

--------------------------------------------------
-- Rendering
--------------------------------------------------

function CheckboxPicker:render()
	if not (self.buf and vim.api.nvim_buf_is_valid(self.buf)) or self.is_rendering then
		return
	end

	self.is_rendering = true -- Lock rendering to stop autocmd loops
	local cursor = vim.api.nvim_win_get_cursor(self.win)

	local lines = {}
	table.insert(lines, " " .. self.title)
	table.insert(lines, self.search)
	table.insert(lines, string.rep("-", 60))

	for _, item in ipairs(self.filtered_items) do
		local checked = contains(self.selected, item)
		local checkbox = checked and "[x]" or "[ ]"
		table.insert(lines, checkbox .. " " .. tostring(item))
	end

	vim.api.nvim_buf_set_lines(self.buf, 0, -1, false, lines)
	self:apply_highlights()

	-- Restore cursor, but pcall it in case filtered items list shrank
	pcall(vim.api.nvim_win_set_cursor, self.win, cursor)
	self.is_rendering = false -- Unlock
end

--------------------------------------------------
-- Highlighting
--------------------------------------------------

function CheckboxPicker:apply_highlights()
	vim.api.nvim_buf_clear_namespace(self.buf, self.ns, 0, -1)
	vim.api.nvim_buf_set_extmark(self.buf, self.ns, 0, 0, { hl_group = "Title" })
	vim.api.nvim_buf_set_extmark(self.buf, self.ns, 1, 0, { hl_group = "Comment" })

	for i = 3, 2 + #self.filtered_items do
		vim.api.nvim_buf_set_extmark(self.buf, self.ns, i - 1, 0, { hl_group = "Identifier" })
	end
end

--------------------------------------------------
-- Selection handling
--------------------------------------------------

function CheckboxPicker:get_current_item()
	local line = vim.api.nvim_win_get_cursor(self.win)[1]
	local index = line - 3
	return self.filtered_items[index]
end

function CheckboxPicker:toggle_current()
	local item = self:get_current_item()
	if not item then
		return
	end

	if contains(self.selected, item) then
		for i, v in ipairs(self.selected) do
			if v == item then
				table.remove(self.selected, i)
				break
			end
		end
	else
		table.insert(self.selected, item)
	end
	self:render()
end

function CheckboxPicker:select_all()
	self.selected = shallow_copy(self.items)
	self:render()
end

function CheckboxPicker:select_none()
	self.selected = {}
	self:render()
end

--------------------------------------------------
-- Search handling
--------------------------------------------------

function CheckboxPicker:update_search()
	if self.is_rendering then
		return
	end

	local lines = vim.api.nvim_buf_get_lines(self.buf, 1, 2, false)
	local line = lines[1] or ""

	-- Extract text after the emoji (🔍 is 3-4 bytes + space)
	local new_search = line:gsub("^🔍%s*", "")

	if new_search ~= self.search then
		self.search = new_search
		self:filter()
		self:render()

		-- ONLY force cursor to line 2 if we are actually in the search bar
		local r, c = unpack(vim.api.nvim_win_get_cursor(self.win))
		if r == 2 then
			-- We set column to a high number to stay at the end of the text
			vim.api.nvim_win_set_cursor(self.win, { 2, #line })
		end
	end
end

--------------------------------------------------
-- Window management
--------------------------------------------------

function CheckboxPicker:create_window()
	self.buf = vim.api.nvim_create_buf(false, true)
	local size = self:calculate_size()
	local col = math.floor((vim.o.columns - size.width) / 2)
	local row = math.floor((vim.o.lines - size.height) / 2)

	self.win = vim.api.nvim_open_win(self.buf, true, {
		relative = "editor",
		width = size.width,
		height = size.height,
		col = col,
		row = row,
		style = "minimal",
		border = "rounded",
	})

	-- THE FIX: Set nofile and a unique filetype to stop completion engines
	vim.bo[self.buf].buftype = "nofile"
	vim.bo[self.buf].filetype = "checkbox_picker"
	vim.bo[self.buf].modifiable = true
	vim.bo[self.buf].bufhidden = "wipe"

	-- Explicitly disable built-in completion
	vim.bo[self.buf].completefunc = ""
	vim.bo[self.buf].omnifunc = ""
end

--------------------------------------------------
-- Lifecycle & Keymaps
--------------------------------------------------

function CheckboxPicker:setup_autocmds()
	local group = vim.api.nvim_create_augroup("CheckboxPicker" .. tostring(self.buf), { clear = true })

	-- Disable nvim-cmp if it exists
	vim.api.nvim_create_autocmd("InsertEnter", {
		buffer = self.buf,
		group = group,
		callback = function()
			local ok, cmp = pcall(require, "cmp")
			if ok then
				cmp.setup.buffer({ enabled = false })
			end
		end,
	})

	vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
		buffer = self.buf,
		group = group,
		callback = function()
			self:update_search()
		end,
	})
end

function CheckboxPicker:setup_keymaps()
	local map = function(lhs, rhs)
		vim.keymap.set("n", lhs, rhs, { buffer = self.buf, nowait = true, silent = true })
	end

	map("<CR>", function()
		self:confirm()
	end)
	map("q", function()
		self:close()
	end)
	map("j", "j")
	map("k", "k")
	map("x", function()
		self:toggle_current()
	end)
	map("<leader>a", function()
		self:select_all()
	end)
	map("<leader>n", function()
		self:select_none()
	end)

	map("/", function()
		vim.api.nvim_win_set_cursor(self.win, { 2, 100 })
	end)
end

function CheckboxPicker:open()
	self:create_window()
	self:setup_autocmds()
	self:setup_keymaps()
	self:filter()
	self:render()
	vim.api.nvim_set_current_win(self.win)
end

function CheckboxPicker:confirm()
	self.on_confirm(shallow_copy(self.selected))
	self:close()
end

function CheckboxPicker:close()
	if self.win and vim.api.nvim_win_is_valid(self.win) then
		vim.api.nvim_win_close(self.win, true)
	end
	if self.buf and vim.api.nvim_buf_is_valid(self.buf) then
		vim.api.nvim_buf_delete(self.buf, { force = true })
	end
end

return CheckboxPicker
