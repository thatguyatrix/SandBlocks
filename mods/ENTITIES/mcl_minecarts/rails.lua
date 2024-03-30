local modname = minetest.get_current_modname()
local modpath = minetest.get_modpath(modname)
local mod = mcl_minecarts
mod.RAIL_GROUPS = {
	STANDARD = 1,
	CURVES = 2,
}
local S = minetest.get_translator(modname)

local function drop_railcarts(pos)
	-- Scan for minecarts in this pos and force them to execute their "floating" check.
	-- Normally, this will make them drop.
	local objs = minetest.get_objects_inside_radius(pos, 1)
	for o=1, #objs do
		local le = objs[o]:get_luaentity()
		if le then
			-- All entities in this mod are minecarts, so this works
			if string.sub(le.name, 1, 14) == "mcl_minecarts:" then
				le._last_float_check = mcl_minecarts.check_float_time
			end
		end
	end
end

local RAIL_DEFAULTS = {
	is_ground_content = true,
	paramtype = "light",
	selection_box = {
		type = "fixed",
		fixed = {-1/2, -1/2, -1/2, 1/2, -1/2+1/16, 1/2},
	},
	stack_max = 64,
	sounds = mcl_sounds.node_sound_metal_defaults(),
	_mcl_blast_resistance = 0.7,
	_mcl_hardness = 0.7,
	after_destruct = drop_railcarts,
}
local RAIL_DEFAULT_GROUPS = {
	handy=1, pickaxey=1,
	attached_node=1,
	rail=1,
	connect_to_raillike=minetest.raillike_group("rail"),
	dig_by_water=0,destroy_by_lava_flow=0,
	transport=1
}

local function table_merge(base, overlay)
	for k,v in pairs(overlay) do
		base[k] = v
	end
end

-- Template rail function
local function register_rail(itemstring, tiles, def_extras, creative)
	local groups = table.copy(RAIL_DEFAULT_GROUPS)
	if creative == false then
		groups.not_in_creative_inventory = 1
	end
	local ndef = {
		drawtype = "raillike",
		tiles = tiles,
		inventory_image = tiles[1],
		wield_image = tiles[1],
		groups = groups,
	}
	table_merge(ndef, RAIL_DEFAULTS)
	ndef.walkable = false -- Old behavior
	table_merge(ndef, def_extras)
	minetest.register_node(itemstring, ndef)
end
local function register_rail_v2(itemstring, def)
	assert(def.tiles)

	-- Extract out the craft recipe
	local craft = def.craft
	def.craft = nil

	-- Build rail groups
	local groups = table.copy(RAIL_DEFAULT_GROUPS)
	if def.groups then table_merge(groups, def.groups) end
	def.groups = groups

	-- Build the node definition
	local ndef = {
		drawtype = "nodebox",
		node_box = {
			type = "fixed",
			fixed = {
				{-8/16, -8/16, -8/16, 8/16, -7/16, 8/15}
			}
		}
	}
	table_merge(ndef, RAIL_DEFAULTS)
	table_merge(ndef, def)

	-- Add sensible defaults
	if not ndef.inventory_image then ndef.inventory_image = ndef.tiles[1] end
	if not ndef.wield_image then ndef.wield_image = ndef.tiles[1] end

	print("registering rail "..itemstring.." with definition: "..dump(ndef))

	-- Make registrations
	minetest.register_node(itemstring, ndef)
	if craft then minetest.register_craft(craft) end
end
mod.register_rail = register_rail_v2


local function register_rail_sloped(itemstring, def)
	assert(def.tiles)

	-- Build rail groups
	local groups = table.copy(RAIL_DEFAULT_GROUPS)
	if def.groups then table_merge(groups, def.groups) end
	def.groups = groups

	-- Build the node definition
	local ndef = table.copy(RAIL_DEFAULTS)
	table_merge(ndef,{
		drawtype = "mesh",
		mesh = "sloped_track.obj",
		collision_box = {
			type = "fixed",
			fixed = {
				{ -0.5, -0.5, -0.5,  0.5,  0.0,  0.5 },
				{ -0.5,  0.0,  0.0,  0.5,  0.5,  0.5 }
			}
		},
		selection_box = {
			type = "fixed",
			fixed = {
				{ -0.5, -0.5, -0.5,  0.5,  0.0,  0.5 },
				{ -0.5,  0.0,  0.0,  0.5,  0.5,  0.5 }
			}
		}
	})
	table_merge(ndef, def)

	-- Add sensible defaults
	if not ndef.inventory_image then ndef.inventory_image = ndef.tiles[1] end
	if not ndef.wield_image then ndef.wield_image = ndef.tiles[1] end

	print("registering sloped rail "..itemstring.." with definition: "..dump(ndef))

	-- Make registrations
	minetest.register_node(itemstring, ndef)
	if craft then minetest.register_craft(craft) end
end
mod.register_rail_sloped = register_rail_sloped

-- Setup shared text
local railuse = S(
	"Place them on the ground to build your railway, the rails will automatically connect to each other and will"..
	" turn into curves, T-junctions, crossings and slopes as needed."
)
mod.text = mod.text or {}
mod.text.railuse = railuse

-- Register rails
dofile(modpath.."/rails/standard.lua")

-- Redstone rules
local rail_rules_long =
{{x=-1,  y= 0, z= 0, spread=true},
 {x= 1,  y= 0, z= 0, spread=true},
-- {x= 0,  y=-1, z= 0, spread=true},
 {x= 0,  y= 1, z= 0, spread=true},
 {x= 0,  y= 0, z=-1, spread=true},
 {x= 0,  y= 0, z= 1, spread=true},

 {x= 1, y= 1, z= 0},
 {x= 1, y=-1, z= 0},
 {x=-1, y= 1, z= 0},
 {x=-1, y=-1, z= 0},
 {x= 0, y= 1, z= 1},
 {x= 0, y=-1, z= 1},
 {x= 0, y= 1, z=-1},
 {x= 0, y=-1, z=-1}}

local rail_rules_short = mesecon.rules.pplate

-- Normal rail
register_rail("mcl_minecarts:rail",
	{"default_rail.png", "default_rail_curved.png", "default_rail_t_junction.png", "default_rail_crossing.png"},
	{
		description = S("Rail"),
		_tt_help = S("Track for minecarts"),
		_doc_items_longdesc = S("Rails can be used to build transport tracks for minecarts. Normal rails slightly slow down minecarts due to friction."),
		_doc_items_usagehelp = railuse,
	}
)

-- Powered rail (off = brake mode)
register_rail("mcl_minecarts:golden_rail",
	{"mcl_minecarts_rail_golden.png", "mcl_minecarts_rail_golden_curved.png", "mcl_minecarts_rail_golden_t_junction.png", "mcl_minecarts_rail_golden_crossing.png"},
	{
		description = S("Powered Rail"),
		_tt_help = S("Track for minecarts").."\n"..S("Speed up when powered, slow down when not powered"),
		_doc_items_longdesc = S("Rails can be used to build transport tracks for minecarts. Powered rails are able to accelerate and brake minecarts."),
		_doc_items_usagehelp = railuse .. "\n" .. S("Without redstone power, the rail will brake minecarts. To make this rail accelerate"..
			" minecarts, power it with redstone power."),
		_rail_acceleration = -3,
		mesecons = {
			conductor = {
				state = mesecon.state.off,
				offstate = "mcl_minecarts:golden_rail",
				onstate = "mcl_minecarts:golden_rail_on",
				rules = rail_rules_long,
			},
		},
	}
)

-- Powered rail (on = acceleration mode)
register_rail("mcl_minecarts:golden_rail_on",
	{"mcl_minecarts_rail_golden_powered.png", "mcl_minecarts_rail_golden_curved_powered.png", "mcl_minecarts_rail_golden_t_junction_powered.png", "mcl_minecarts_rail_golden_crossing_powered.png"},
	{
		_doc_items_create_entry = false,
		_rail_acceleration = 4,
		_max_acceleration_velocity = 8,
		mesecons = {
			conductor = {
				state = mesecon.state.on,
				offstate = "mcl_minecarts:golden_rail",
				onstate = "mcl_minecarts:golden_rail_on",
				rules = rail_rules_long,
			},
		},
		drop = "mcl_minecarts:golden_rail",
	},
	false
)

-- Activator rail (off)
register_rail("mcl_minecarts:activator_rail",
	{"mcl_minecarts_rail_activator.png", "mcl_minecarts_rail_activator_curved.png", "mcl_minecarts_rail_activator_t_junction.png", "mcl_minecarts_rail_activator_crossing.png"},
	{
		description = S("Activator Rail"),
		_tt_help = S("Track for minecarts").."\n"..S("Activates minecarts when powered"),
		_doc_items_longdesc = S("Rails can be used to build transport tracks for minecarts. Activator rails are used to activate special minecarts."),
		_doc_items_usagehelp = railuse .. "\n" .. S("To make this rail activate minecarts, power it with redstone power and send a minecart over this piece of rail."),
		mesecons = {
			conductor = {
				state = mesecon.state.off,
				offstate = "mcl_minecarts:activator_rail",
				onstate = "mcl_minecarts:activator_rail_on",
				rules = rail_rules_long,

			},
		},
	}
)

-- Activator rail (on)
register_rail("mcl_minecarts:activator_rail_on",
	{"mcl_minecarts_rail_activator_powered.png", "mcl_minecarts_rail_activator_curved_powered.png", "mcl_minecarts_rail_activator_t_junction_powered.png", "mcl_minecarts_rail_activator_crossing_powered.png"},
	{
		_doc_items_create_entry = false,
		mesecons = {
			conductor = {
				state = mesecon.state.on,
				offstate = "mcl_minecarts:activator_rail",
				onstate = "mcl_minecarts:activator_rail_on",
				rules = rail_rules_long,
			},
			effector = {
				-- Activate minecarts
				action_on = function(pos, node)
					local pos2 = { x = pos.x, y =pos.y + 1, z = pos.z }
					local objs = minetest.get_objects_inside_radius(pos2, 1)
					for _, o in pairs(objs) do
						local l = o:get_luaentity()
						if l and string.sub(l.name, 1, 14) == "mcl_minecarts:" and l.on_activate_by_rail then
							l:on_activate_by_rail()
						end
					end
				end,
			},

		},
		_mcl_minecarts_on_enter = function(pos, cart)
			if cart.on_activate_by_rail then
				cart:on_activate_by_rail()
			end
		end,
		drop = "mcl_minecarts:activator_rail",
	},
	false
)

-- Detector rail (off)
register_rail("mcl_minecarts:detector_rail",
	{"mcl_minecarts_rail_detector.png", "mcl_minecarts_rail_detector_curved.png", "mcl_minecarts_rail_detector_t_junction.png", "mcl_minecarts_rail_detector_crossing.png"},
	{
		description = S("Detector Rail"),
		_tt_help = S("Track for minecarts").."\n"..S("Emits redstone power when a minecart is detected"),
		_doc_items_longdesc = S("Rails can be used to build transport tracks for minecarts. A detector rail is able to detect a minecart above it and powers redstone mechanisms."),
		_doc_items_usagehelp = railuse .. "\n" .. S("To detect a minecart and provide redstone power, connect it to redstone trails or redstone mechanisms and send any minecart over the rail."),
		mesecons = {
			receptor = {
				state = mesecon.state.off,
				rules = rail_rules_short,
			},
		},
		_mcl_minecarts_on_enter = function(pos, cart)
			local node = minetest.get_node(pos)

			local newnode = {
				name = "mcl_minecarts:detector_rail_on",
				param2 = node.param2
			}
			minetest.swap_node( pos, newnode )
			mesecon.receptor_on(pos)
		end,
	}
)

-- Detector rail (on)
register_rail("mcl_minecarts:detector_rail_on",
	{"mcl_minecarts_rail_detector_powered.png", "mcl_minecarts_rail_detector_curved_powered.png", "mcl_minecarts_rail_detector_t_junction_powered.png", "mcl_minecarts_rail_detector_crossing_powered.png"},
	{
		_doc_items_create_entry = false,
		mesecons = {
			receptor = {
				state = mesecon.state.on,
				rules = rail_rules_short,
			},
		},
		_mcl_minecarts_on_leave = function(pos, cart)
			local node = minetest.get_node(pos)

			local newnode = {
				name = "mcl_minecarts:detector_rail",
				param2 = node.param2
			}
			minetest.swap_node( pos, newnode )
			mesecon.receptor_off(pos)
		end,
		drop = "mcl_minecarts:detector_rail",
	},
	false
)


-- Crafting
minetest.register_craft({
	output = "mcl_minecarts:golden_rail 6",
	recipe = {
		{"mcl_core:gold_ingot", "", "mcl_core:gold_ingot"},
		{"mcl_core:gold_ingot", "mcl_core:stick", "mcl_core:gold_ingot"},
		{"mcl_core:gold_ingot", "mesecons:redstone", "mcl_core:gold_ingot"},
	}
})

minetest.register_craft({
	output = "mcl_minecarts:activator_rail 6",
	recipe = {
		{"mcl_core:iron_ingot", "mcl_core:stick", "mcl_core:iron_ingot"},
		{"mcl_core:iron_ingot", "mesecons_torch:mesecon_torch_on", "mcl_core:iron_ingot"},
		{"mcl_core:iron_ingot", "mcl_core:stick", "mcl_core:iron_ingot"},
	}
})

minetest.register_craft({
	output = "mcl_minecarts:detector_rail 6",
	recipe = {
		{"mcl_core:iron_ingot", "", "mcl_core:iron_ingot"},
		{"mcl_core:iron_ingot", "mesecons_pressureplates:pressure_plate_stone_off", "mcl_core:iron_ingot"},
		{"mcl_core:iron_ingot", "mesecons:redstone", "mcl_core:iron_ingot"},
	}
})


-- Aliases
if minetest.get_modpath("doc") then
	doc.add_entry_alias("nodes", "mcl_minecarts:golden_rail", "nodes", "mcl_minecarts:golden_rail_on")
end

