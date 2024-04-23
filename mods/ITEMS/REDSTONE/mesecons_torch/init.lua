-- REDSTONE TORCH AND BLOCK OF REDSTONE

local S = minetest.get_translator(minetest.get_current_modname())

local TORCH_COOLOFF = 120 -- Number of seconds it takes for a burned-out torch to reactivate

local function rotate_torch_rules(rules, param2)
	if param2 == 1 then
		return rules
	elseif param2 == 5 then
		return mesecon.rotate_rules_right(rules)
	elseif param2 == 2 then
		return mesecon.rotate_rules_right(mesecon.rotate_rules_right(rules)) --180 degrees
	elseif param2 == 4 then
		return mesecon.rotate_rules_left(rules)
	elseif param2 == 0 then
		return rules
	else
		return rules
	end
end

local function torch_get_output_rules(node)
	if node.param2 == 1 then
		return {
			{ x = -1, y =  0, z =  0 },
			{ x =  1, y =  0, z =  0 },
			{ x =  0, y =  1, z =  0, spread = true },
			{ x =  0, y =  0, z = -1 },
			{ x =  0, y =  0, z =  1 },
		}
	else
		return rotate_torch_rules({
			{ x =  1, y =  0, z =  0 },
			{ x =  0, y = -1, z =  0 },
			{ x =  0, y =  1, z =  0, spread = true },
			{ x =  0, y =  1, z =  0 },
			{ x =  0, y =  0, z = -1 },
			{ x =  0, y =  0, z =  1 },
		}, node.param2)
	end
end

local function torch_get_input_rules(node)
	if node.param2 == 1 then
		return {{x = 0, y = -1, z = 0 }}
	else
		return rotate_torch_rules({{ x = -1, y = 0, z = 0 }}, node.param2)
	end
end

local function torch_overheated(pos)
	minetest.sound_play("fire_extinguish_flame", {pos = pos, gain = 0.02, max_hear_distance = 6}, true)
	minetest.add_particle({
		pos = {x=pos.x, y=pos.y+0.2, z=pos.z},
		velocity = {x = 0, y = 0.6, z = 0},
		expirationtime = 1.2,
		size = 1.5,
		texture = "mcl_particles_smoke.png",
	})
	local timer = minetest.get_node_timer(pos)
	timer:start(TORCH_COOLOFF)
end

local TORCH_STATE_ON = {
	["mesecons_torch:mesecon_torch_off"] = "mesecons_torch:mesecon_torch_on",
	["mesecons_torch:mesecon_torch_off_wall"] = "mesecons_torch:mesecon_torch_on_wall",
}
local TORCH_STATE_OFF = {
	["mesecons_torch:mesecon_torch_on"] = "mesecons_torch:mesecon_torch_off",
	["mesecons_torch:mesecon_torch_on_wall"] = "mesecons_torch:mesecon_torch_off_wall",
}
local TORCH_STATE_OVERHEAT = {
	["mesecons_torch:mesecon_torch_on"] = "mesecons_torch:mesecon_torch_overheated",
	["mesecons_torch:mesecon_torch_on_wall"] = "mesecons_torch:mesecon_torch_overheated_wall",
	["mesecons_torch:mesecon_torch_off"] = "mesecons_torch:mesecon_torch_overheated",
	["mesecons_torch:mesecon_torch_off_wall"] = "mesecons_torch:mesecon_torch_overheated_wall",
}

local function torch_action_change(pos, node, rule, strength)
	local nodedef = minetest.registered_nodes[node.name]
	--local effector_state = ((nodedef.mesecons or {}).effector or {}).state
	--local is_on = ( effector_state == mesecon.state.on )
	local overheat = false
	local original_name = node.name

	if strength == 0 then
		-- Turn on
		node.name = TORCH_STATE_ON[node.name] or node.name
		vl_redstone.set_power(pos, 15, 0.1)
		overheat = mesecon.do_overheat(pos)
	else
		-- Turn off
		node.name = TORCH_STATE_OFF[node.name] or node.name
		vl_redstone.set_power(pos, 0, 0.1)
	end

	if overheat then
		print("overheat")
		torch_overheated(pos)
		node.name = TORCH_STATE_OVERHEAT[node.name] or node.name
	end

	if node.name ~= original_name then
		minetest.swap_node(pos, node)
	end
end

minetest.register_craft({
	output = "mesecons_torch:mesecon_torch_on",
	recipe = {
	{"mesecons:redstone"},
	{"mcl_core:stick"},}
})

local off_def = {
	name = "mesecon_torch_off",
	description = S("Redstone Torch (off)"),
	doc_items_create_entry = false,
	icon = "jeija_torches_off.png",
	tiles = {"jeija_torches_off.png"},
	light = 0,
	groups = {dig_immediate=3, dig_by_water=1, redstone_torch=2, mesecon_ignore_opaque_dig=1, not_in_creative_inventory=1},
	sounds = mcl_sounds.node_sound_wood_defaults(),
	drop = "mesecons_torch:mesecon_torch_on",
}

mcl_torches.register_torch(off_def)

local off_override = {
	mesecons = {
		receptor = {
			state = mesecon.state.off,
			rules = torch_get_output_rules,
		},
		effector = {
			state = mesecon.state.on,
			rules = torch_get_input_rules,
			action_change = torch_action_change,
		},
	},
}

minetest.override_item("mesecons_torch:mesecon_torch_off", off_override)
minetest.override_item("mesecons_torch:mesecon_torch_off_wall", off_override)

local overheated_def = table.copy(off_def)
overheated_def.name = "mesecon_torch_overheated"
overheated_def.description = S("Redstone Torch (overheated)")

mcl_torches.register_torch(overheated_def)

local overheated_override = {
	on_timer = function(pos, elapsed)
		if not mesecon.is_powered(pos) then
			local node = minetest.get_node(pos)
			torch_action_change(pos, node, nil, 0)
		end
	end
}

minetest.override_item("mesecons_torch:mesecon_torch_overheated", overheated_override)
minetest.override_item("mesecons_torch:mesecon_torch_overheated_wall", overheated_override)

local on_def = {
	name = "mesecon_torch_on",
	description = S("Redstone Torch"),
	doc_items_longdesc = S("A redstone torch is a redstone component which can be used to invert a redstone signal. It supplies its surrounding blocks with redstone power, except for the block it is attached to. A redstone torch is normally lit, but it can also be turned off by powering the block it is attached to. While unlit, a redstone torch does not power anything."),
	doc_items_usagehelp = S("Redstone torches can be placed at the side and on the top of full solid opaque blocks."),
	icon = "jeija_torches_on.png",
	tiles = {"jeija_torches_on.png"},
	light = 7,
	groups = {dig_immediate=3, dig_by_water=1, redstone_torch=1, mesecon_ignore_opaque_dig=1},
	sounds = mcl_sounds.node_sound_wood_defaults(),
}

mcl_torches.register_torch(on_def)

local on_override = {
	on_destruct = function(pos, oldnode)
		local node = minetest.get_node(pos)
		torch_action_change(pos, node, nil, 0)
	end,
	mesecons = {
		receptor = {
			state = mesecon.state.on,
			rules = torch_get_output_rules
		},
		effector = {
			state = mesecon.state.off,
			rules = torch_get_input_rules,
			action_change = torch_action_change,
		},
	},
	_tt_help = S("Provides redstone power when it's not powered itself"),
}

minetest.override_item("mesecons_torch:mesecon_torch_on", on_override)
minetest.override_item("mesecons_torch:mesecon_torch_on_wall", on_override)

minetest.register_node("mesecons_torch:redstoneblock", {
	description = S("Block of Redstone"),
	_tt_help = S("Provides redstone power"),
	_doc_items_longdesc = S("A block of redstone permanently supplies redstone power to its surrounding blocks."),
	tiles = {"redstone_redstone_block.png"},
	stack_max = 64,
	groups = {pickaxey=1},
	sounds = mcl_sounds.node_sound_stone_defaults(),
	is_ground_content = false,
	mesecons = {receptor = {
		state = mesecon.state.on,
		rules = mesecon.rules.alldirs,
	}},
	_mcl_blast_resistance = 6,
	_mcl_hardness = 5,
})

minetest.register_craft({
	output = "mesecons_torch:redstoneblock",
	recipe = {
		{"mesecons:wire_00000000_off","mesecons:wire_00000000_off","mesecons:wire_00000000_off"},
		{"mesecons:wire_00000000_off","mesecons:wire_00000000_off","mesecons:wire_00000000_off"},
		{"mesecons:wire_00000000_off","mesecons:wire_00000000_off","mesecons:wire_00000000_off"},
	}
})

minetest.register_craft({
	output = "mesecons:wire_00000000_off 9",
	recipe = {
		{"mesecons_torch:redstoneblock"},
	}
})

if minetest.get_modpath("doc") then
	doc.add_entry_alias("nodes", "mesecons_torch:mesecon_torch_on", "nodes", "mesecons_torch:mesecon_torch_off")
	doc.add_entry_alias("nodes", "mesecons_torch:mesecon_torch_on", "nodes", "mesecons_torch:mesecon_torch_off_wall")
end
