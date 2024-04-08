local mod = mcl_scheduler

--[[

== Radix/Finger queue class

This is a queue based off the concepts behind finger trees (https://en.wikipedia.org/wiki/Finger_tree),
the radix sort (https://en.wikipedia.org/wiki/Radix_sort) and funnel sort (https://en.wikipedia.org/wiki/Funnelsort)

This algorithm has O(1) deletion and O(k) insertion (k porportional to the time in the future) and uses log_4(n) tree nodes.

At the top level of the queue, there is a 20-element array of linked lists containing tasks that are scheduled to
start running in the current second. Removing the next linked list of tasks from this array is an O(1) operation.

The queue then has a one-sided finger tree of 20-element lists that are used to replace the initial queue when the
second rolls over.

]]

function Class()
	local cls = {}
	cls.mt = { __index = cls }
	function cls:new(...)
		local inst = setmetatable({}, cls.mt)
		local construct = inst.construct
		if construct then inst:construct(...) end
		return inst
	end
	return cls
end

local inner_queue = Class()
function inner_queue:construct(level)
	self.level = level
	self.items = {}
	self.unsorted_count = 0
	self.slots = 4

	-- Precompute slot size
	local slot_size = 20
	for i = 2,level do
		slot_size = slot_size * 4
	end
	self.slot_size = slot_size
end
function inner_queue:get()
	local slots = self.slots
	local slot = 5 - slots
	local ret = self.items[slot]
	self.items[slot] = nil

	-- Take a way a slot, then refill if needed
	slots = slots - 1
	if slots == 0 then
		if self.next_level then
			local next_level_get = self.next_level:get()
			if next_level_get then
				self.items = next_level_get.items
			else
				self.items = {}
			end
			slots = 4
		end
	end
	self.slots = slots

	return ret or self:init_slot_list()
end
function inner_queue:add_tasks(tasks, time)
	local task = tasks
	local slot_size = self.slot_size
	local level = self.level
	local slots = self.slots

	while task do
		local t = task.time
		t = t - time

		if t > slot_size * slots then
			-- Add to list for next level in the finger tree
			task.time = t
			local curr_task = task
			task = task.next
			curr_task.next = self.first_unsorted
			local count = self.unsorted_count + 1
			if count > 20 then
				if not self.next_level then
					self.next_level = inner_queue:new(self.level + 1)
				end
				self.next_level:add_tasks(curr_task, slot_size * slots)
				self.first_unsorted = nil
				self.unsorted_count = 0
			else
				self.first_unsorted = curr_task
				self.unsorted_count = count
			end
		else
			-- Task belongs in a slot on this level
			local slot = math.floor(t / slot_size) + 1 + ( slots - 4 )
			t = t % slot_size
			task.time = t
			local curr_task = task
			task = task.next

			local list = self.items[slot] or self:init_slot_list()
			self.items[slot] = list

			if level == 1 then
				curr_task.next = list[t]
				list[t] = curr_task
			else
				list:add_tasks(curr_task, (slot - 1) * slot_size)
			end
		end
	end
end
function inner_queue:init_slot_list()
	local level = self.level
	if level == 1 then
		return { {}, {}, {}, {} }
	else
		local r = {}
		for i=1,4 do
			r[i] = inner_queue:new(self.level - 1)
		end
	end
end

local queue = Class()
mod.queue = queue
function queue:construct()
	self.items = {}
	self.unsorted_count = 0
	self.m_tick = 1
	self.next_level = inner_queue:new(1)
end
function queue:add_task(task)
	-- Adjust time to align with the start of the current second
	task.time = task.time + self.m_tick

	-- Handle task in current seccond
	if task.time <= 20 then
		task.next = self.items[task.time]
		self.items[task.time] = task
		return
	end

	local count = self.unsorted_count + 1
	if count > 20 then
		-- Push to next level
		self.unsorted_count = 0
	else
		-- Add to the list of tasks for later time slots
		task.next = self.first_unsorted
		self.first_unsorted = task
		self.unsorted_count = count
	end
end
function queue:tick()
	-- Get the tasks for this tick
	local ret = self.items[self.m_tick]
	self.items[self.m_tick] = nil
	self.m_tick = self.m_tick + 1

	-- Handle second rollover
	if self.m_tick == 21 then
		-- Push items to next level
		if self.first_unsorted then
			self.next_level:add_tasks(self.first_unsorted, 20)
			self.first_unsorted = nil
			self.unsorted_count = 0
		end

		self.items = self.next_level:get()
		self.m_tick = 1
	end

	return ret or {}
end

