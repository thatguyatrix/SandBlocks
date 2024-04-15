local modname = minetest.get_current_modname()
local modpath = minetest.get_modpath(modname)
vl_redstone = {}
local mod = vl_redstone

-- Imports
local mcl_util_force_get_node = mcl_util.force_get_node
local mcl_util_call_safe = mcl_util.call_safe
local minetest_get_item_group = minetest.get_item_group
local minetest_get_meta = minetest.get_meta
local minetest_hash_node_pos = minetest.hash_node_position
local minetest_get_position_from_hash = minetest.get_position_from_hash
local minetest_serialize = minetest.serialize
local minetest_deserialize = minetest.deserialize
local minetest_swap_node = minetest.swap_node
local vector_add = vector.add
local vector_to_string = vector.to_string
local vector_from_string = vector.from_string

-- Constants
local REDSTONE_POWER_META = modname .. ".power"
local REDSTONE_POWER_META_SOURCE = REDSTONE_POWER_META.."."

local multipower_cache = {}

local function get_node_multipower_data(pos)
	local hash = minetest_hash_node_pos(pos)
	local node_multipower = multipower_cache[hash]
	if not node_multipower then
		local meta = minetest_get_meta(pos)
		node_multipower = minetest_deserialize(meta:get_string("vl_redstone.multipower")) or {sources={}}
		multipower_cache[hash] = node_multipower
	end
	return node_multipower
end

local function update_node(pos)
	local node = mcl_util_force_get_node(pos)
	local nodedef = minetest.registered_nodes[node.name]

	-- Only do this processing of signal sinks
	if not nodedef.mesecons then return end

	-- Calculate the maximum power feeding into this node
	local node_multipower = get_node_multipower_data(pos)
	local strength = 0
	local sources = node_multipower.sources
	--print("in update_node(pos="..vector_to_string(pos)..") node_multipower("..tostring(node_multipower)..")="..dump(node_multipower))
	for pos_hash,source_strength in pairs(sources) do
		--print("\t"..vector_to_string(pos)..".source["..vector_to_string(minetest_get_position_from_hash(pos_hash)).."] = "..tostring(strength))
		if source_strength > strength then strength = source_strength end
	end

	-- Don't do any processing inf the actual strength at this node has changed
	local last_strength = node_multipower.strength or 0
	--print("At "..vector_to_string(pos).." strength="..tostring(strength)..",last_strength="..tostring(last_strength))
	if last_strength == strength then return end

	-- Update the state
	node_multipower.strength = strength

	-- TODO: determine the input rule that the strength is coming from (for mesecons compatibility; there are mods that depend on it)
	local rule = nil

	local sink = nodedef.mesecons.effector
	if sink then
		local new_node_name = nil
		--print("Updating "..node.name.." at "..vector_to_string(pos).."("..tostring(last_strength).."->"..tostring(strength)..")")
		-- Inform the node of changes
		if strength ~= 0 and last_strength == 0 then
			-- Handle activation
			local hook = sink.action_on
			if hook then
				mcl_util_call_safe(nil, hook, {pos, node, rule, strength})
			end
			if sink.onstate then
				new_node_name = sink.onstate
			end
		elseif strength == 0 and last_strength ~= 0 then
			-- Handle deactivation
			local hook = sink.action_off
			if hook then
				mcl_util_call_safe(nil, hook, {pos, node, rule, strength})
			end
			if sink.offstate then
				new_node_name = sink.offstate
			end
		end

		-- TODO: handle signal level change notification
		local hook = sink.action_change
		if hook then
			mcl_util_call_safe(nil, hook, {pos, node, rule, strength})
		end
		if sink.strength_state then
			new_node_name = sink.strength_state[strength]
		end

		-- Update the node
		if new_node_name and new_node_name ~= node.name then
			node.name = new_node_name
			minetest_swap_node(pos, node)
		end
		return
	end

	local conductor = nodedef.mesecons.conductor
	if conductor then
		-- Figure out if the node name changes based on the new state
		local new_node_name = nil
		if conductor.strength_state then
			new_node_name = conductor.strength_state[strength]
		elseif strength > 0 and conductor.onstate then
			new_node_name = conductor.onstate
		elseif strength == 0 and conductor.offstate then
			new_node_name = conductor.offstate
		end

		-- Update the node
		if new_node_name and new_node_name ~= node.name then
			--[[
			print("Changing "..vector_to_string(pos).." from "..node.name.." to "..new_node_name..
			    ", strength="..tostring(strength)..",last_strength="..tostring(last_strength))
			print("node.name="..node.name..
			     ",conductor.onstate="..tostring(conductor.onstate)..
			     ",conductor.offstate="..tostring(conductor.offstate)
			)
			--]]
			node.name = new_node_name
			minetest_swap_node(pos, node)
		end
	end
end

local POWERED_BLOCK_RULES = {
	vector.new( 1, 0, 0),
	vector.new(-1, 0, 0),
	vector.new( 0, 1, 0),
	vector.new( 0,-1, 0),
	vector.new( 0, 0, 1),
	vector.new( 0, 0,-1),
}

local function get_positions_from_node_rules(pos, rules_type, list, powered)
	list = list or {}

	local node = mcl_util_force_get_node(pos)
	local nodedef = minetest.registered_nodes[node.name]
	local rules
	if nodedef.mesecons then
		-- Get mesecons rules
		if not nodedef.mesecons[rules_type] then
			minetest.log("info","Node "..node.name.." has no mesecons."..rules_type.." rules")
			return list
		end
		rules = nodedef.mesecons[rules_type].rules
		if type(rules) == "function" then rules = rules(node) end
	else
		-- The only blocks that don't support mesecon that propagate power are solid blocks that
		-- are powered by another device. Mesecons calls this 'spread'
		if not powered[minetest_hash_node_pos(pos)] then return list end
		if minetest_get_item_group(node.name,"solid") == 0 then return list end

		rules = POWERED_BLOCK_RULES
	end

	--print("rules="..dump(rules))

	-- Convert to absolute positions
	for i=1,#rules do
		local next_pos = vector_add(pos, rules[i])
		local next_pos_hash = minetest_hash_node_pos(next_pos)
		--print("\tnext: "..next_pos_str..", prev="..tostring(list[next_pos_str]))
		list[next_pos_hash] = true

		-- Power solid blocks
		if rules[i].spread then
			powered[next_pos_hash] = true
			--print("powering "..vector_to_string(next_pos)
		end
	end

	return list
end

vl_scheduler.register_function("vl_redstone:flow_power",function(task, source_pos, source_strength, distance)
	print("Flowing lv"..tostring(source_strength).." power from "..vector_to_string(source_pos).." for "..tostring(distance).." blocks")
	local processed = {}
	local powered = {}
	local source_pos_hash = minetest_hash_node_pos(source_pos)
	processed[source_pos_hash] = true

	-- Update the source node's redstone power
	local node_multipower = get_node_multipower_data(source_pos)
	node_multipower.strength = source_strength
	node_multipower.drive_strength = source_strength

	-- Get rules
	local list = {}
	get_positions_from_node_rules(source_pos, "receptor", list, powered)
	--print("initial list="..dump(list))

	for i=1,distance do
		local next_list = {}
		local strength = source_strength - (i - 1)
		if strength < 0 then strength = 0 end

		for pos_hash,dir in pairs(list) do
			--print("Processing "..pos_str)

			if not processed[pos_hash] then
				processed[pos_hash] = true

				local pos = minetest_get_position_from_hash(pos_hash)

				-- Update node power directly
				local node_multipower = get_node_multipower_data(pos)
				--local old_strength = node_multipower.sources[source_pos_hash] or 0
				--print("Changing "..vector.to_string(pos)..".source["..vector_to_string(source_pos).."] from "..tostring(old_strength).." to "..tostring(strength))
				--print("\tBefore node_multipower("..tostring(node_multipower)..")="..dump(node_multipower))
				node_multipower.sources[source_pos_hash] = strength
				--print("\tAfter  node_multipower("..tostring(node_multipower)..")="..dump(node_multipower))

				-- handle spread
				get_positions_from_node_rules(pos, "conductor", next_list, powered)

				-- Update the position
				update_node(pos)
			end
		end

		-- Continue onto the next set of nodes to process
		list = next_list
	end
end)

function vl_redstone.set_power(pos, strength)
	local node_multipower = get_node_multipower_data(pos)
	local distance = node_multipower.drive_strength or 0

	-- Don't perform an update if the power level is the same as before
	if distance == strength then return end

	--print("previous="..tostring(distance)..", new="..tostring(strength))

	-- Make the update distance the maximum of the new strength and the old strength
	if distance < strength then
		distance = strength
	end

	-- Schedule an update
	vl_scheduler.add_task(0, "vl_redstone:flow_power", 2, {pos, strength, distance + 1})
end

function vl_redstone.get_power_level(pos)
	local node_multipower = get_node_multipower_data(pos)
	return node_multipower.strength or 0
end

-- Persist multipower data
minetest.register_on_shutdown(function()
	for pos_hash,node_multipower in pairs(multipower_cache) do
		local pos = minetest_get_position_from_hash(pos_hash)
		local meta = minetest_get_meta(pos)
		meta:set_string("vl_redstone.multipower", minetest_serialize(node_multipower))
	end
end)
