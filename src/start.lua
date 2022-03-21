local Novel = require("lib.novel")

local key_action_map = {
	["return"] = Novel.on_hard_action,
	space = Novel.on_soft_action,
	down = Novel.next_selection,
	up = Novel.prev_selection,
	s = Novel.next_selection,
	w = Novel.prev_selection,
}

local function on_right()
	Novel.say("Voice", "You can do basic arithmetic!")
end

local function on_wrong()
	Novel.say("Voice", "Wow that's just sad.")
end

function love.user.load()
	Novel.say("Voice", "What is 4 + 4 equal to?")
	Novel.say(nil, "Well the answer is obviously...", {
		{ data = "8", on_select = on_right },
		{ data = "4", on_select = on_wrong },
		{ data = "2", on_select = on_wrong },
		{ data = "1", on_select = on_wrong },
	})

	Novel.call(function()
		print("Wow this function was called!")
	end)
end

function love.user.update(dt)
	Novel.update(dt)
end

function love.user.draw()
	Novel.draw()
end

function love.handlers.keyreleased(key)
	local func = key_action_map[key]

	if func then
		func()
	end
end

function love.handlers.quit(code)
	love.state.result_code = code or 0
end
