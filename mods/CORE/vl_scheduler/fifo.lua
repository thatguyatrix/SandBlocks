local mod = vl_scheduler

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

-- Amoritized O(1) insert/delete functional First In, First Out (FIFO) queue
local fifo = Class()
mod.fifo = fifo
function fifo:insert(node)
	if not node then return end

	node.next = self.inbox
	self.inbox = node
end
function fifo:insert_many(nodes)
	while nodes do
		local node = nodes
		nodes = nodes.next

		node.next = self.inbox
		self.inbox = node.next
	end
end
function fifo:get()
	if not fifo.outbox then
		-- reverse inbox
		local iter = self.inbox
		self.inbox = nil

		while iter do
			local i = iter
			iter = iter.next

			i.next = self.outbox
			self.outbox = i
		end
	end

	local res = self.outbox
	if res then
		self.outbox = res.next
		res.next = nil
	end
	return res
end

