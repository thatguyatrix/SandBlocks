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
local math_floor = math.floor

-- Constants
local REDSTONE_POWER_META = modname .. ".power"
local REDSTONE_POWER_META_SOURCE = REDSTONE_POWER_META.."."

local multipower_cache = {}

local function hash_from_direction(dir)
	return 9 * (dir.x + 1) + 3 * (dir.y + 1) + dir.z + 1
end
local function direction_from_hash(dir_hash)
	local x = math_floor(dir_hash / 9) - 1
	local y = math_floor((dir_hash % 9) / 3 ) - 1
	local z = dir_hash % 3 - 1
	return vector.new(x,y,z)
end
local HASH_REVERSES = {}
for i=0,27 do
	local dir = direction_from_hash(i)
	local dir_rev = vector.subtract(vector.zero(), dir)
	local dir_rev_hash = hash_from_direction(dir_rev)
	HASH_REVERSES[dir_rev_hash] = i
	--print("hash["..tostring(i).."] = "..vector_to_string(direction_from_hash(i))..", rev="..tostring(dir_rev_hash))
end

local DIR_HASH_ZERO = hash_from_direction(vector.zero())
print("DIR_HASH_ZERO="..tostring(DIR_HASH_ZERO))

local function get_input_rules_hash(mesecons, input_rules)
	-- Skip build if already built
	local redstone = mesecons._vl_redtone or {}
	mesecons._vl_redstone = redstone
	if redstone.input_rules_hash then return redstone.input_rules_hash end

	-- Build the rules
	local input_rules_hash = {}
	redstone.input_rules_hash = input_rules_hash
	for i=1,#input_rules do
		input_rules_hash[hash_from_direction(input_rules[i])] = true
	end

	return input_rules_hash
end

local function get_node_multipower_data(pos, no_create)
	local hash = minetest_hash_node_pos(pos)
	local node_multipower = multipower_cache[hash]
	if not node_multipower and not no_create then
		local meta = minetest_get_meta(pos)
		node_multipower = minetest_deserialize(meta:get_string("vl_redstone.multipower"))
		if not node_multipower or node_multipower.version ~= 1 then
			node_multipower = {
				version = 1,
				sources={}
			}
		end
		multipower_cache[hash] = node_multipower
	end
	return node_multipower
end

local function calculate_driven_strength(pos, input_rules_hash)
	local dir_hash = dir and hash_from_direction(dir)
	local node_multipower = get_node_multipower_data(pos)
	local strength = 0
	local strongest_direction_hash = nil
	local sources = node_multipower.sources
	input_rules_hash = input_rules_hash or {}

	--print("in update_node(pos="..vector_to_string(pos)..") node_multipower("..tostring(node_multipower)..")="..dump(node_multipower))
	for pos_hash,data in pairs(sources) do
		local source_strength = data[1]
		local dirs = data[2]
		--print("data="..dump(data))
		--print("\t"..vector_to_string(pos)..".source["..vector_to_string(minetest_get_position_from_hash(pos_hash)).."] = "..tostring(strength))

		-- Filter by specified direction
		local match = false
		if not dir_hash then
			match = true
		else
			for i=1,#dirs do
				match = match or input_rules_hash[dirs[i]]
			end
		end

		--print("match="..tostring(match)..",source_strength="..tostring(source_strength))

		-- Update strength and track which direction the strongest power is coming from
		if match and source_strength >= strength then
			strength = source_strength
			if #dirs ~= 0 then
				strongest_direction_hash = dirs[1]
			end
		end
	end

	return strength,HASH_REVERSES[strongest_direction_hash]
end

local function update_node(pos)
	local node = mcl_util_force_get_node(pos)
	local nodedef = minetest.registered_nodes[node.name]

	-- Only do this processing of signal sinks and conductors
	local nodedef_mesecons = nodedef.mesecons
	if not nodedef_mesecons then return end

	--print("Running update_node(pos="..vector_to_string(pos)..", node.name="..node.name..")")

	-- Get input rules
	local input_rules = nil
	if nodedef_mesecons.conductor then
		input_rules = nodedef_mesecons.conductor.rules
	elseif nodedef_mesecons.effector then
		input_rules = nodedef_mesecons.effector.rules
	else
		-- No input rules, can't act
		--print("Unable to find input rules for "..node.name..": mesecons="..dump(nodedef_mesecons))
		return
	end
	if type(input_rules) == "function" then
		input_rules = input_rules(node)
	end

	-- Calculate the maximum power feeding into this node
	local input_rules_hash = get_input_rules_hash(nodedef_mesecons, input_rules)
	--print("input_rules_hash="..dump(input_rules_hash)..", input_rules="..dump(input_rules))
	local strength,dir_hash = calculate_driven_strength(pos, input_rules_hash)
	--print("strength="..tostring(strength)..",dir_hash="..tostring(dir_hash))

	-- Don't do any processing inf the actual strength at this node has changed
	local node_multipower = get_node_multipower_data(pos)
	local last_strength = node_multipower.strength or 0

	--[[
	print("At "..vector_to_string(pos).."("..node.name..") strength="..tostring(strength)..",last_strength="..tostring(last_strength))
	if last_strength == strength then
		print("No strength change")
		return
	end
	--]]

	-- Determine the input rule that the strength is coming from (for mesecons compatibility; there are mods that depend on it)
	local rule = nil
	--print("input_rules="..dump(input_rules))
	--print("input_rules_hash="..dump(input_rules_hash))
	--print("dir_hash="..tostring(dir_hash))
	for i = 1,#input_rules do
		local input_rule = input_rules[i]
		local input_rule_hash = hash_from_direction(input_rule)
		if dir_hash == input_rule_hash then
			rule = input_rule
			break
		end
	end
	if not rule then
		--print("No rule found")
		return
	end

	-- Update the state
	node_multipower.strength = strength

	local sink = nodedef_mesecons.effector
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

		-- handle signal level change notification
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

	local conductor = nodedef_mesecons.conductor
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
			node.param2 = strength
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
		local rule = rules[i]
		local next_pos = vector_add(pos, rule)
		local next_pos_hash = minetest_hash_node_pos(next_pos)
		--print("\tnext: "..next_pos_str..", prev="..tostring(list[next_pos_str]))
		local dirs = list[next_pos_hash] or {}
		list[next_pos_hash] = dirs
		dirs[hash_from_direction(rule)] = true

		-- Power solid blocks
		if rules[i].spread then
			powered[next_pos_hash] = true
			--print("powering "..vector_to_string(next_pos)
		end
	end

	return list
end

vl_scheduler.register_function("vl_redstone:flow_power",function(task, source_pos, source_strength, distance)
	--print("Flowing lv"..tostring(source_strength).." power from "..vector_to_string(source_pos).." for "..tostring(distance).." blocks")
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

		for pos_hash,dir_list in pairs(list) do
			--print("Processing "..pos_str)

			if not processed[pos_hash] then
				processed[pos_hash] = true

				local pos = minetest_get_position_from_hash(pos_hash)

				-- Update node power directly
				local node_multipower = get_node_multipower_data(pos)
				--local old_data = node_multipower.sources[source_pos_hash]
				--local old_strength = old_data and old_data[1] or 0
				--print("Changing "..vector.to_string(pos)..".source["..vector_to_string(source_pos).."] from "..tostring(old_strength).." to "..tostring(strength))
				--print("\tBefore node_multipower("..tostring(node_multipower)..")="..dump(node_multipower))
				--print("\tdir_list="..dump(dir_list))
				local dirs = {}
				for k,_ in pairs(dir_list) do
					dirs[#dirs+1] = k
				end
				node_multipower.sources[source_pos_hash] = {strength,dirs}
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

function vl_redstone.set_power(pos, strength, delay)
	-- Get existing multipower data, but don't create the data if the strength is zero
	local no_create
	if strength == 0 then no_create = true end
	local node_multipower = get_node_multipower_data(pos, no_create)
	if not node_multipower then return end

	-- Determine how far we need to trace conductors
	local distance = node_multipower.drive_strength or 0

	-- Don't perform an update if the power level is the same as before
	if distance == strength then return end

	--print("previous="..tostring(distance)..", new="..tostring(strength))

	-- Make the update distance the maximum of the new strength and the old strength
	if distance < strength then
		distance = strength
	end

	-- Schedule an update
	vl_scheduler.add_task(delay or 0, "vl_redstone:flow_power", 2, {pos, strength, distance + 1})
end

function vl_redstone.get_power(pos)
	local node_multipower = get_node_multipower_data(pos)
	return node_multipower.strength or 0
end

function vl_redstone.on_placenode(pos, node)
	local nodedef = minetest.registered_nodes[node.name]
	if not nodedef then return end
	if not nodedef.mesecons then return end
	local receptor = nodedef.mesecons.receptor
	if not receptor then return end

	if receptor.state == mesecon.state.on then
		vl_redstone.set_power(pos, 15)
	else
		vl_redstone.set_power(pos, 0)
	end
end
function vl_redstone.on_dignode(pos, node)
	print("Dug node at "..vector.to_string(pos))

	-- Node was dug, can't power anything
	-- This doesn't work because the node is gone and we don't know what we were powering
	-- TODO: get the rules here and use that for the first step
	vl_redstone.set_power(pos, 0)
end

-- Persist multipower data
minetest.register_on_shutdown(function()
	for pos_hash,node_multipower in pairs(multipower_cache) do
		local pos = minetest_get_position_from_hash(pos_hash)
		local meta = minetest_get_meta(pos)
		meta:set_string("vl_redstone.multipower", minetest_serialize(node_multipower))
	end
end)
minetest.register_on_placenode(vl_redstone.on_placenode)
minetest.register_on_dignode(vl_redstone.on_dignode)

