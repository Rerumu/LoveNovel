local Novel = {}

local utf8 = require("utf8")

local gfx_translate = love.graphics.translate
local gfx_pop = love.graphics.pop
local gfx_push = love.graphics.push
local gfx_draw = love.graphics.draw
local gfx_printf = love.graphics.printf

local function new_single_pixel(r, g, b, a)
	local data = love.image.newImageData(1, 1)

	data:setPixel(0, 0, r, g, b, a)

	return love.graphics.newImage(data)
end

local red_pixel = new_single_pixel(196 / 255, 141 / 255, 153 / 255, 0.5)
local blue_pixel = new_single_pixel(141 / 255, 161 / 255, 196 / 255, 0.5)

local prof_name = {
	margin_x = 6,
	margin_y = 4,

	color = { 1, 1, 0, 1 },
	font = love.graphics.newFont(26),
	background = blue_pixel,
}

local prof_data = {
	margin_x = 4,
	margin_y = 4,
	size_x = 1200,
	size_y = 200,

	color = { 1, 1, 1, 1 },
	font = love.graphics.newFont(20),
	background = blue_pixel,

	rate_of_grapheme = 60,
}

local prof_option = {
	margin_x = 4,
	margin_y = 4,
	size_x = 800,
	size_y = 32,

	color = { 1, 1, 1, 1 },
	font = love.graphics.newFont(22),
	selected = red_pixel,
	not_selected = blue_pixel,
}

function table.copy_kv(from, to)
	for k, v in pairs(from) do
		if to[k] == nil then
			to[k] = v
		end
	end
end

function utf8.sub(data, i, j)
	return string.sub(data, utf8.offset(data, i), utf8.offset(data, j + 1) - 1)
end

local Partial

do
	Partial = {}
	Partial.__index = Partial

	function Partial.new(data)
		local self = {
			data = data,
			index = 0,
			length = utf8.len(data),
		}

		return setmetatable(self, Partial)
	end

	function Partial:read()
		return utf8.sub(self.data, 1, math.floor(self.index))
	end

	function Partial:set_done()
		self.index = self.length
	end

	function Partial:is_done()
		return self.index == self.length
	end

	function Partial:advance(length)
		if self:is_done() then
			return
		end

		self.index = math.min(self.index + length, self.length)
	end
end

local selection = 1
local pending = {}

function Novel.say(name, data, option_list)
	data = Partial.new(data)

	table.insert(pending, 1, {
		type = "Say",
		name = name,
		data = data,
		option_list = option_list,
	})
end

function Novel.call(handler)
	table.insert(pending, 1, {
		type = "Call",
		handler = handler,
	})
end

function Novel.update(dt)
	local now = pending[#pending]

	while now and now.type == "Call" do
		table.remove(pending)

		now.handler()
		now = pending[#pending]
	end

	if now and now.data then
		local length = dt * prof_data.rate_of_grapheme

		now.data:advance(length)
	end
end

local function get_clamped_size(setting)
	local window_sx, window_sy = love.graphics.getDimensions()

	return math.min(window_sx, setting.size_x), math.min(window_sy, setting.size_y), window_sx, window_sy
end

local function draw_name_field(name)
	local background = prof_name.background
	local font = prof_name.font
	local margin_x = prof_name.margin_x
	local margin_y = prof_name.margin_y

	local sx = font:getWidth(name) + margin_x * 2
	local sy = font:getHeight() + margin_y * 2
	local ux, uy = background:getDimensions()

	gfx_push()

	gfx_translate(0, -sy)

	gfx_draw(background, 0, 0, 0, sx / ux, sy / uy)

	gfx_translate(margin_x, margin_y)
	gfx_printf({ prof_name.color, name }, font, 0, 0, sx)

	gfx_pop()
end

local function draw_data_field(data, align, setting)
	local background = setting.background
	local margin_x = setting.margin_x
	local margin_y = setting.margin_y

	local sx, sy = get_clamped_size(setting)
	local ux, uy = background:getDimensions()

	gfx_push()

	gfx_draw(background, 0, 0, 0, sx / ux, sy / uy)

	gfx_translate(margin_x, margin_y)
	gfx_printf({ setting.color, data }, setting.font, 0, 0, sx - margin_x * 2, align)

	gfx_pop()
end

function Novel.draw()
	if #pending == 0 then
		return
	end

	local now = pending[#pending]
	local data_sx, data_sy, window_sx, window_sy = get_clamped_size(prof_data)

	gfx_push()
	gfx_translate(window_sx / 2, window_sy - data_sy)

	if now.data then
		gfx_push()

		gfx_translate(-data_sx / 2, 0)
		draw_data_field(now.data:read(), "left", prof_data)

		if now.name then
			draw_name_field(now.name)
		end

		gfx_pop()
	end

	if now.option_list and now.data:is_done() then
		local opt_sx, opt_sy = get_clamped_size(prof_option)

		gfx_translate(-opt_sx / 2, 0)

		for i = #now.option_list, 1, -1 do
			if i == selection then
				prof_option.background = prof_option.selected
			else
				prof_option.background = prof_option.not_selected
			end

			local data = now.option_list[i].data

			gfx_translate(0, -math.floor(opt_sy * 1.2))
			draw_data_field(data, "center", prof_option)
		end
	end

	gfx_pop()
end

function Novel.prev_selection()
	selection = math.max(selection - 1, 1)
end

function Novel.next_selection()
	if #pending == 0 then
		return
	end

	local list = pending[#pending].option_list

	if list then
		selection = math.min(selection + 1, #list)
	end
end

local function soft_handler(now)
	if now.option_list then
		return
	end

	table.remove(pending)
end

local function hard_handler(now)
	table.remove(pending)

	if now.option_list then
		now.option_list[selection].on_select()

		selection = 1
	end
end

local function on_action_of(handler)
	return function()
		if #pending == 0 then
			return
		end

		local now = pending[#pending]

		if now.data:is_done() then
			handler(now)
		else
			now.data:set_done()
		end
	end
end

Novel.on_soft_action = on_action_of(soft_handler)
Novel.on_hard_action = on_action_of(hard_handler)

return Novel
