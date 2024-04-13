local mod = vl_scheduler
function mod.test()
	local t = mod.queue.new()

	local pr = PseudoRandom(123456789)

	local start_time = minetest.get_us_time()
	for i=1,500 do
		t:add_task({ time = pr:next(1,3600) })

		local stop_time = minetest.get_us_time()
		print("took "..tostring(stop_time - start_time).."us")
		start_time = stop_time
	end

	--print(dump(t:tick()))
	print(dump(t))

	print("starting ticks")

	local start_time = minetest.get_us_time()
	for i=1,3600 do
		local s = t:tick()
		print("time="..tostring(i+1))
		--print(dump(s))

		local stop_time = minetest.get_us_time()
		print("took "..tostring(stop_time - start_time).."us")
		start_time = stop_time
	end
end

--mod.test()
--error("test failed")
