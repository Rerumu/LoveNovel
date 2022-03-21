local FIXED_STEP = 1 / 90
local pending_step = 0

local function run_event_handler()
	love.event.pump()

	for name, a, b, c, d, e, f in love.event.poll() do
		love.handlers[name](a, b, c, d, e, f)
	end
end

local function run_update_handler()
	pending_step = pending_step + love.timer.step()

	while pending_step >= FIXED_STEP do
		love.user.update(FIXED_STEP)
		pending_step = pending_step - FIXED_STEP
	end
end

local function run_graphics_handler()
	if not love.graphics.isActive() then
		return
	end

	love.graphics.origin()
	love.graphics.clear()
	love.user.draw()
	love.graphics.present()
end

local function run_step()
	run_event_handler()
	run_update_handler()
	run_graphics_handler()

	love.timer.sleep(0.001)

	return love.state.result_code
end

function love.run()
	love.handlers = love.handlers or {}
	love.state = { result_code = nil }
	love.user = {}

	require("src.start")

	love.user.load()
	love.timer.step()

	return run_step
end
