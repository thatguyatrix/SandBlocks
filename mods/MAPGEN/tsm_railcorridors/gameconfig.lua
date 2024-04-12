-- This file stores the various node types. This makes it easier to plug this mod into games
-- in which you need to change the node names.

-- Adapted for MineClone 2!

-- Imports
local create_minecart = mcl_minecarts.create_minecart
local get_cart_data = mcl_minecarts.get_cart_data
local save_cart_data = mcl_minecarts.save_cart_data

-- Node names (Don't use aliases!)
tsm_railcorridors.nodes = {
	dirt = "mcl_core:dirt",
	chest = "mcl_chests:chest",
	rail = "mcl_minecarts:rail_v2",
	torch_floor = "mcl_torches:torch",
	torch_wall = "mcl_torches:torch_wall",
	cobweb = "mcl_core:cobweb",
	spawner = "mcl_mobspawners:spawner",
}

local update_rail_connections = mcl_minecarts.update_rail_connections
local rails_to_update = {}
tsm_railcorridors.on_place_node = {
	[tsm_railcorridors.nodes.rail] = function(pos, node)
		rails_to_update[#rails_to_update + 1] = pos
	end,
}
tsm_railcorridors.on_start = function()
	rails_to_update = {}
end
tsm_railcorridors.on_finish = function()
	for _,pos in pairs(rails_to_update) do
		update_rail_connections(pos, {legacy = true, ignore_neighbor_connections = true})
	end
end

local mg_name = minetest.get_mapgen_setting("mg_name")

if mg_name == "v6" then
	-- In v6, wood is chosen randomly.
	--[[ Wood types for the corridors. Corridors are made out of full wood blocks
	and posts. For each corridor system, a random wood type is chosen with the chance
	specified in per mille. ]]
	tsm_railcorridors.nodes.corridor_woods = {
		{ wood = "mcl_core:wood", post = "mcl_fences:fence", chance = 900},
		{ wood = "mcl_core:darkwood", post = "mcl_fences:dark_oak_fence", chance = 100},
	}
else
	-- This generates dark oak wood in mesa biomes and oak wood everywhere else.
	function tsm_railcorridors.nodes.corridor_woods_function(pos, node)
		if minetest.get_item_group(node.name, "hardened_clay") ~= 0 then
			return "mcl_core:darkwood", "mcl_fences:dark_oak_fence"
		else
			return "mcl_core:wood", "mcl_fences:fence"
		end
	end
end


tsm_railcorridors.carts = { "mcl_minecarts:chest_minecart", "mcl_minecarts:hopper_minecart", "mcl_minecarts:minecart" }
local has_loot = {
	["mcl_minecarts:chest_minecart"] = true,
	["mcl_minecarts:hopper_minceart"] = true,
}

function tsm_railcorridors.create_cart_staticdata(entity_id,pos, pr)
	local uuid = create_minecart(entity_id, pos, vector.new(1,0,0))

	-- Fill the cart with loot
	local cartdata = get_cart_data(uuid)
	if cartdata and has_loot[entity_id] then
		local items = tsm_railcorridors.get_treasures(pr)

		-- Convert from ItemStack to itemstrings
		for k,item in pairs(items) do
			items[k] = item:to_string()
		end
		cartdata.inventory = items

		print("cartdata = "..dump(cartdata))
		save_cart_data(uuid)
	end

	return minetest.serialize({ uuid=uuid, seq=1 })
end

-- Fallback function. Returns a random treasure. This function is called for chests
-- only if the Treasurer mod is not found.
-- pr: A PseudoRandom object
function tsm_railcorridors.get_default_treasure(pr)
	-- UNUSED IN MINECLONE 2!
end

-- All spawners spawn cave spiders
function tsm_railcorridors.on_construct_spawner(pos)
	mcl_mobspawners.setup_spawner(pos, "mobs_mc:cave_spider", 0, 7)
end

-- MineClone 2's treasure function. Gets all treasures for a single chest.
-- Based on information from Minecraft Wiki.
function tsm_railcorridors.get_treasures(pr)
	local loottable = {
	{
		stacks_min = 1,
		stacks_max = 1,
		items = {
			{ itemstring = "mcl_mobs:nametag", weight = 30 },
			{ itemstring = "mcl_core:apple_gold", weight = 20 },
			{ itemstring = "mcl_books:book", weight = 10, func = function(stack, pr)
				mcl_enchanting.enchant_uniform_randomly(stack, {"soul_speed"}, pr)
			end },
			{ itemstring = "", weight = 5},
			{ itemstring = "mcl_core:pick_iron", weight = 5 },
			{ itemstring = "mcl_core:apple_gold_enchanted", weight = 1 },
		}
	},
	{
		stacks_min = 2,
		stacks_max = 4,
		items = {
			{ itemstring = "mcl_farming:bread", weight = 15, amount_min = 1, amount_max = 3 },
			{ itemstring = "mcl_core:coal_lump", weight = 10, amount_min = 3, amount_max = 8 },
			{ itemstring = "mcl_farming:beetroot_seeds", weight = 10, amount_min = 2, amount_max = 4 },
			{ itemstring = "mcl_farming:melon_seeds", weight = 10, amount_min = 2, amount_max = 4 },
			{ itemstring = "mcl_farming:pumpkin_seeds", weight = 10, amount_min = 2, amount_max = 4 },
			{ itemstring = "mcl_core:iron_ingot", weight = 10, amount_min = 1, amount_max = 5 },
			{ itemstring = "mcl_core:lapis", weight = 5, amount_min = 4, amount_max = 9 },
			{ itemstring = "mesecons:redstone", weight = 5, amount_min = 4, amount_max = 9 },
			{ itemstring = "mcl_core:gold_ingot", weight = 5, amount_min = 1, amount_max = 3 },
			{ itemstring = "mcl_core:diamond", weight = 3, amount_min = 1, amount_max = 2 },
		}
	},
	{
		stacks_min = 3,
		stacks_max = 3,
		items = {
			{ itemstring = "mcl_minecarts:rail_v2", weight = 20, amount_min = 4, amount_max = 8 },
			{ itemstring = "mcl_torches:torch", weight = 15, amount_min = 1, amount_max = 16 },
			{ itemstring = "mcl_minecarts:activator_rail_v2", weight = 5, amount_min = 1, amount_max = 4 },
			{ itemstring = "mcl_minecarts:detector_rail_v2", weight = 5, amount_min = 1, amount_max = 4 },
			{ itemstring = "mcl_minecarts:golden_rail_v2", weight = 5, amount_min = 1, amount_max = 4 },
		}
	},
	-- non-MC loot: 50% chance to add a minecart, offered as alternative to spawning minecarts on rails.
	-- TODO: Remove this when minecarts spawn on rails.
	{
		stacks_min = 0,
		stacks_max = 1,
		items = {
			{ itemstring = "mcl_minecarts:minecart", weight = 1 },
		}
	}
	}

	-- Bonus loot for v6 mapgen: Otherwise unobtainable saplings.
	if mg_name == "v6" then
		table.insert(loottable, {
			stacks_min = 1,
			stacks_max = 3,
			items = {
				{ itemstring = "mcl_core:darksapling", weight = 1, amount_min = 1, amount_max = 3 },
				{ itemstring = "mcl_core:birchsapling", weight = 1, amount_min = 1, amount_max = 2 },
				{ itemstring = "", weight = 6 },
			},
		})
	end
	local items = mcl_loot.get_multi_loot(loottable, pr)

	return items
end
