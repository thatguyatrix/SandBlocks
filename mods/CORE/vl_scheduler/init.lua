local modname = minetest.get_current_modname()
local modpath = minetest.get_modpath(modname)

vl_scheduler = {}
local mod = vl_scheduler

dofile(modpath.."/queue.lua")
dofile(modpath.."/fifo.lua")
dofile(modpath.."/test.lua")

local run_queues = {}
for i = 1,4 do
	run_queues[i] = mod.fifo:new()
end
local time = 0
local priority_queue = mod.queue:new()
local functions = {}
local function_id_from_name = {}

local table_unpack = table.unpack
local minetest_get_us_time = minetest.get_us_time
local queue_add_task = mod.queue.add_task
local queue_get = mod.queue.get
local queue_tick = mod.queue.tick
local fifo_insert = mod.fifo.insert
local fifo_get = mod.fifo.get

function mod.add_task(time, name)
	local fid = function_id_from_name[name]
	local task = {
		time = time,
		fid = fid,
	}
	queue_add_task(priority_queue, task)
end

function mod.register_function(name, func)
	local fid = #functions + 1
	functions[fid] = {
		func = func,
		name = name,
		fid = fid,
	}
	function_id_from_name = name
	print("Registering "..name.." as #"..tostring(fid))
end

minetest.register_globalstep(function(dtime)
	local start_time = minetest_get_us_time()
	time = time + dtime

	-- Add tasks to the run queues
	local iter = queue_tick(priority_queue)
	while iter do
		local task = iter
		iter = iter.next

		local priority = task.priority or 3
		fifo_insert(run_queues[priority], task)
	end

	-- Run tasks until we run out of timeslice
	local i = 1
	while i < 4 and (minetest_get_us_time() - start_time) < 50000 do
		local task = fifo_get(run_queues[i])
		if task then
			print("Running task "..dump(task))
			local func = functions[task.fid]
			local cancel = false
			if func then
				local err
				cancel,err = pcall(func, task.dtime, table_unpack(task.args))
				if err then
					minetest.log("error","Error while running task: err")
				end
			end

			-- Add periodic tasks back into the queue
			if task.period and not cancel then
				task.time = task.period
				queue_add_task(priority_queue, task)
			end
		else
			i = i + 1
		end
	end
	print("Total scheduler time: "..tostring(minetest_get_us_time() - start_time).." microseconds")
end)

