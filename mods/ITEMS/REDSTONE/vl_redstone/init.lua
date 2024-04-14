local modname = minetest.get_current_modname()
local modpath = minetest.get_modpath(modname)
vl_redstone = {}
local mod = vl_redstone

local REDSTONE_POWER_META = modname .. ".power"
local REDSTONE_POWER_META_SOURCE = REDSTONE_POWER_META.."."

local function update_sink(pos)
	local node = minetest.get_node(pos)
	local nodedef = minetest.registered_nodes[node.name]

	-- Only do this processing of signal sinks
	if not nodedef.mesecons then return end
	local sink = nodedef.mesecons.effector
	if not sink then return end

	local meta = minetest.get_meta(pos)

	-- Calculate the maximum power feeding into this node
	local strength = 0
	local meta_tbl = meta:to_table()
	for k,v in pairs(meta_tbl.fields) do
		if string.sub(k,1,#REDSTONE_POWER_META_SOURCE) == REDSTONE_POWER_META_SOURCE then
			--local source_pos_str = string.sub(k,#REDSTONE_POWER_META_SOURCE+1)
			--print("\tsource_pos_str="..source_pos_str)
			local source_strength = tonumber(v)
			--print("\tstrength="..source_strength)
			if source_strength > strength then
				strength = source_strength
			end
		end
	end

	local last_strength = meta:get_int(REDSTONE_POWER_META)

	if last_strength ~= strength then
		--print("Updating "..node.name.." at "..vector.to_string(pos).."("..tostring(last_strength).."->"..tostring(strength)..")")
		-- Inform the node of changes
		if strength > 0 then
			-- Handle activation
			if sink.action_on then
				mcl_util.call_safe(nil, sink.action_on, {pos, node})
			end

		else
			-- Handle deactivation
			if sink.action_off then
				mcl_util.call_safe(nil, sink.action_off, {pos, node})
			end
		end

		-- TODO: handle signal level change notification

		-- Update the state as the last thing in case there is a crash in the above code
		meta:set_int(REDSTONE_POWER_META, strength)
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

	local node = minetest.get_node(pos)
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
		if not powered[vector.to_string(pos)] then return list end
		if minetest.get_item_group(node.name,"solid") == 0 then return list end

		rules = POWERED_BLOCK_RULES
	end

	--print("rules="..dump(rules))

	-- Convert to absolute positions
	for i=1,#rules do
		local next_pos = vector.add(pos, rules[i])
		local next_pos_str = vector.to_string(next_pos)
		--print("\tnext: "..next_pos_str..", prev="..tostring(list[next_pos_str]))
		list[next_pos_str] = true

		-- Power solid blocks
		if rules[i].spread then
			powered[next_pos_str] = true
			--print("powering "..next_pos_str)
		end
	end

	return list
end

vl_scheduler.register_function("vl_redstone:flow_power",function(task, source_pos, source_strength, distance)
	print("Flowing lv"..tostring(source_strength).." power from "..vector.to_string(source_pos).." for "..tostring(distance).." blocks")
	local processed = {}
	local powered = {}
	local source_pos_str = vector.to_string(source_pos)
	processed[source_pos_str] = true

	-- Update the source node's redstone power
	local meta = minetest.get_meta(source_pos)
	meta:set_int(REDSTONE_POWER_META, source_strength)

	-- Get rules
	local list = {}
	get_positions_from_node_rules(source_pos, "receptor", list, powered)
	--print("initial list="..dump(list))

	for i=1,distance do
		local next_list = {}
		local strength = source_strength - (i - 1)
		if strength < 0 then strength = 0 end

		for pos_str,dir in pairs(list) do
			--print("Processing "..pos_str)

			if not processed[pos_str] then
				processed[pos_str] = true

				local pos = vector.from_string(pos_str)
				local meta = minetest.get_meta(pos)

				-- Update node power directly
				meta:set_int(REDSTONE_POWER_META.."."..source_pos_str, strength)
				--print("pos="..vector.to_string(pos)..", strength="..tostring(strength))

				-- handle spread
				get_positions_from_node_rules(pos, "conductor", next_list, powered)

				-- Update the position
				update_sink(pos)
			end
		end

		-- Continue onto the next set of nodes to process
		list = next_list
	end
end)

function vl_redstone.set_power(pos, strength)
	local meta = minetest.get_meta(pos)
	local distance = meta:get_int(REDSTONE_POWER_META)

	-- Don't perform an update if the power level is the same as before
	if distance == strength then return end

	print("previous="..tostring(distance)..", new="..tostring(strength))

	-- Make the update distance the maximum of the new strength and the old strength
	if distance < strength then
		distance = strength
	end

	-- Schedule an update
	vl_scheduler.add_task(0, "vl_redstone:flow_power", 2, {pos, strength, distance + 1})
end

function vl_redstone.get_power_level(pos)
	local meta = minetest.get_meta(pos)
	return meta:get_int(REDSTONE_POWER_META)
end

