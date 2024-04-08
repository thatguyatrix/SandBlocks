local modname = minetest.get_current_modname()
local modpath = minetest.get_modpath(modname)

mcl_scheduler = {}
local mod = mcl_scheduler

dofile(modpath.."/queue.lua")
dofile(modpath.."/fifo.lua")

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

local run_queues = {}
for i = 1,4 do
	run_queues[i] = mod.fifo:new()
end
local time = 0
local priority_queue = mod.queue:new()
local functions = {}

print(dump(run_queues))

minetest.register_globalstep(function(dtime)
	local start_time = minetest.get_us_time()
	time = time + dtime
	local limit = 4
	while time > 0.05 and limit > 0 do
		-- Add tasks to the run queues
		local iter = priority_queue:tick()
		while iter do
			local task = iter
			iter = iter.next

			local priority = task.priority or 3
			run_queues[priority]:insert(task)
		end

		-- Run tasks until we run out of timeslice
		local i = 1
		while i < 4 and (minetest.get_us_time() - start_time) < 50000 do
			local task = run_queues[i]:get()
			if task then
				print("Running task "..dump(task))
				local func = functions[task.fid]
				local cancel = false
				if func then
					local err
					cancel,err = pcall(func, task.dtime, table.unpack(task.args))
					if err then
						minetest.log("error","Error while running task: err")
					end
				end

				-- Add 
				if task.period and not cancel then
					task.time = task.period
					priority_queue:add_task(task)
				end
			end
		end

		time = time - 0.05
		limit = limit - 1
	end
end)

