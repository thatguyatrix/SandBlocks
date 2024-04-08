local modname = minetest.get_current_modname()
local modpath = minetest.get_modpath(modname)

mcl_scheduler = {}
local mod = mcl_scheduler

dofile(modpath.."/queue.lua")

function mod.test()
	local t = mod.queue.new()

	local test_times = { 15, 1, 7, 34, 50, 150, 14, 18, 20, 20, 15, }

	local start_time = minetest.get_us_time()
	for _,time in pairs(test_times) do
		t:add_task({ time = time })

		local stop_time = minetest.get_us_time()
		print("took "..tostring(stop_time - start_time).."us")
		start_time = stop_time
	end

	print(dump(t:tick()))
	print(dump(t))

	local start_time = minetest.get_us_time()
	for i=1,60 do
		local s = t:tick()
		print("time="..tostring(i+1))
		print(dump(s))

		local stop_time = minetest.get_us_time()
		print("took "..tostring(stop_time - start_time).."us")
		start_time = stop_time
	end
end

mod.test()

