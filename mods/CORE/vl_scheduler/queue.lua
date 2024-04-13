local mod = vl_scheduler

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

-- Imperative forward declarations
local inner_queue_construct
local inner_queue_get
local inner_queue_insert_task
local inner_queue_add_tasks
local inner_queue_init_slot_list

function inner_queue:construct(level)
	self.level = level
	--self.items = {}
	self.unsorted_count = 0

	-- Precompute slot size
	local slot_size = 20
	for i = 2,level do
		slot_size = slot_size * 4
	end
	self.slot_size = slot_size
end
inner_queue_construct = inner_queue.construct

function inner_queue:get()
	local slots = 4
	local slot = 5 - slots
	if not self.items then
		self.items = inner_queue_init_slot_list(self)
	end
	local ret = self.items[slot]
	self.items[slot] = nil

	-- Take a way a slot, then refill if needed
	slots = slots - 1
	if slots == 0 then
		if self.next_level then
			local next_level_get = inner_queue_get(self.next_level)
			if next_level_get then
				self.items = next_level_get.items
			else
				self.items = {}
			end
			slots = 4
		end
	end
	self.slots = slots

	return ret
end
inner_queue_get = inner_queue.get

function inner_queue:insert_task(task)
	local slots = self.slots
	local slot_size = self.slot_size
	local level = self.level

	local t = task.time
	--task.log = tostring(t).."(1)<- "..(task.log or "")
	--print("<"..tostring(self.level).."> t="..tostring(t)..",task.time="..tostring(task.time)..",time="..tostring(time))
	if not (t >= 1 ) then
		error("Invalid time: task="..dump(task))
	end

	if t > slot_size * slots then
		-- Add to list for next level in the finger tree
		local count = self.unsorted_count + 1
		if count > 20 then
			if not self.next_level then
				self.next_level = inner_queue:new(self.level + 1)
			end

			inner_queue_add_tasks( self.next_level, self.first_unsorted, slot_size * slots)
			self.first_unsorted = nil
			self.unsorted_count = 0
			count = 0
		end

		task.next = self.first_unsorted
		self.first_unsorted = task
		self.unsorted_count = count + 1
		return
	end

	-- Task belongs in a slot on this level
	--print("t="..tostring(t)..",slot_size="..tostring(slot_size)..",slots="..tostring(slots))
	local slot = math.floor((t-1) / slot_size) + 1 -- + ( slots - 4 )
	t = (t - 1) % slot_size + 1
	--print("slot="..tostring(slot)..",t="..tostring(t))
	task.time = t
	--task.log = tostring(t).."(2)<- "..(task.log or "")

	-- Lazily initialize items
	if not self.items then
		self.items = inner_queue_init_slot_list(self)
	end

	-- Get the sublist the item belongs in
	local list = self.items[slot]

	if level == 1 then
		assert(task.time <= 20)
		task.next = list[t]
		list[t] = task

		--print("list="..dump(list))
	else
		--print("list="..dump(list))
		inner_queue_insert_task(list, task, 0)
	end
end
inner_queue_insert_task = inner_queue.insert_task

function inner_queue:add_tasks(tasks, time)
	--print("inner_queue<"..tostring(self.level)..">:add_tasks()")
	local task = tasks
	local slots = self.slots
	local slot_size = self.slot_size

	--print("This queue handles times 1-"..tostring(slot_size*slots))
	while task do
		local curr_task = task
		task = task.next
		curr_task.next = nil
		curr_task.time = curr_task.time - time

		inner_queue_insert_task(self, curr_task)
	end

	--print("self="..dump(self))
end
inner_queue_add_tasks = inner_queue.add_tasks

function inner_queue:init_slot_list()
	local level = self.level
	if level == 1 then
		return { {}, {}, {}, {} }
	else
		local r = {}
		for i=1,4 do
			r[i] = inner_queue:new(level - 1)
		end
		return r
	end
end
inner_queue_init_slot_list = inner_queue.init_slot_list

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
	local t = task.time
	task.original_time = t
	t = t + self.m_tick
	--print("add_task({ time="..tostring(t).." })")

	-- Handle task in current seccond
	if t <= 20 then
		task.next = self.items[t]
		self.items[t] = task
		return
	end

	local count = self.unsorted_count
	if count > 20 then
		-- Push to next level
		self.unsorted_count = 0
		inner_queue_add_tasks( self.next_level, self.first_unsorted, 0)
		self.first_unsorted = nil
		count = 0
	end

	-- Add to the list of tasks for later time slots
	task.next = self.first_unsorted
	task.time = task.time
	self.first_unsorted = task
	self.unsorted_count = count + 1
end
function queue:tick()
	-- Get the tasks for this tick
	local ret = nil
	if self.items then
		ret = self.items[self.m_tick]
		self.items[self.m_tick] = nil
	end
	self.m_tick = self.m_tick + 1

	-- Handle second rollover
	if self.m_tick == 21 then
		-- Push items to next level
		if self.first_unsorted then
			inner_queue_add_tasks(self.next_level, self.first_unsorted, 20)
			self.first_unsorted = nil
			self.unsorted_count = 0
		end

		self.items = inner_queue_get(self.next_level)
		self.m_tick = 1
	end

	return ret or {}
end

