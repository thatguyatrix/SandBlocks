local modname = minetest.get_current_modname()
local modpath = minetest.get_modpath(modname)
vl_redstone = {}
local mod = vl_redstone

local REDSTONE_POWER_META = modname .. ".power"
local REDSTONE_POWER_META_LAST_STATE = modname .. ".last-power"
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

	local last_strength = meta:get_int(REDSTONE_POWER_META_LAST_STATE)

	if last_strength ~= strength then
		-- Inform the node of changes
		if strength > 0 then
			-- Handle activation
			if sink.action_on then
				sink.action_on(pos, node)
			end

		else
			-- Handle deactivation
			if sink.action_off then
				sink.action_off(pos, node)
			end
		end

		-- TODO: handle signal level change notification

		-- Update the state as the last thing in case there is a crash in the above code
		meta:set_int(REDSTONE_POWER_META_LAST_STATE, strength)
	end
end

local function get_positions_from_node_rules(pos, rules_type, list)
	list = list or {}

	local node = minetest.get_node(pos)
	local nodedef = minetest.registered_nodes[node.name]
	if not nodedef.mesecons then return list end

	-- Get mesecons rules
	if not nodedef.mesecons[rules_type] then
		minetest.log("info","Node "..node.name.." has no mesecons."..rules_type.." rules")
		return list
	end
	local rules = nodedef.mesecons[rules_type].rules
	if type(rules) == "function" then rules = rules(node) end

	--print("rules="..dump(rules))

	-- Convert to absolute positions
	for i=1,#rules do
		local next_pos = vector.add(pos, rules[i])
		local next_pos_str = vector.to_string(next_pos)
		list[next_pos_str] = true
	end

	return list
end

vl_scheduler.register_function("vl_redstone:flow_power",function(task, source_pos, strength, distance)
	print("Flowing lv"..tostring(strength).." power from "..vector.to_string(source_pos).." for "..tostring(distance).." blocks")
	local processed = {}
	local source_pos_str = vector.to_string(source_pos)

	-- Update the source node's redstone power
	local meta = minetest.get_meta(source_pos)
	meta:set_int(REDSTONE_POWER_META, strength)

	-- Get rules
	local list = {}
	get_positions_from_node_rules(source_pos, "receptor", list)
	print("initial list="..dump(list))

	for i=1,distance do
		local next_list = {}
		local strength = strength - (i - 1)
		if strength < 0 then strength = 0 end

		for pos_str,dir in pairs(list) do
			print("Processing "..pos_str)

			if not processed[pos_str] then
				processed[pos_str] = true

				local pos = vector.from_string(pos_str)
				local meta = minetest.get_meta(pos)

				-- Update node power directly
				meta:set_int(REDSTONE_POWER_META.."."..source_pos_str, strength)
				print("pos="..vector.to_string(pos)..", strength="..tostring(strength))

				-- handle spread
				local spread_to = get_positions_from_node_rules(pos, "conductor")
				for j=1,#spread_to do
					next_list[vector.to_string(spread_to[j])] = true
				end

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
	if distance < strength then
		distance = strength
	end

	vl_scheduler.add_task(0, "vl_redstone:flow_power", 2, {pos, strength, distance})
end

