local modname = minetest.get_current_modname()
local modpath = minetest.get_modpath(modname)

vl_scheduler = {}
local mod = vl_scheduler

dofile(modpath.."/queue.lua")
dofile(modpath.."/fifo.lua")

local run_queues = {}
for i = 1,4 do
	run_queues[i] = mod.fifo:new()
end
local time = 0
local priority_queue = mod.queue:new()
local functions = {}

minetest.register_globalstep(function(dtime)
	local start_time = minetest.get_us_time()
	time = time + dtime

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

			-- Add periodic tasks back into the queue
			if task.period and not cancel then
				task.time = task.period
				priority_queue:add_task(task)
			end
		else
			i = i + 1
		end
	end
end)

