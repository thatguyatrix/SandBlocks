local mod = mcl_scheduler

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
function fifo.insert(node)
	node.next = fifo.inbox
	fifo.inbox = node.next
end
function fifo.get()
	if not fifo.outbox then
		-- reverse inbox
		local iter = fifo.inbox
		fifo.inbox = nil

		while iter do
			local i = iter
			iter = iter.next

			i.next = fifo.outbox
			fifo.outbox = i
		end
	end

	local res = fifo.outbox
	if res then
		fifo.outbox = res.next
		res.next = nil
	end
	return res
end

