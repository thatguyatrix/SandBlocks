minetest.register_node("farming:soil", {
	tiles = {"farming_soil.png", "default_dirt.png", "default_dirt.png", "default_dirt.png", "default_dirt.png", "default_dirt.png"},
	description = "Farmland",
	drop = "default:dirt",
	drawtype = "nodebox",
	paramtype = "light",
	node_box = {
		type = "fixed",
		fixed = {
			-- 15/16 of the normal height
			{-0.5, -0.5, -0.5, 0.5, 0.4375, 0.5},
		}
	},
	groups = { crumbly=3, not_in_creative_inventory=1, soil=2, soil_sapling=1 },
	sounds = default.node_sound_dirt_defaults(),
})

minetest.register_node("farming:soil_wet", {
	tiles = {"farming_soil_wet.png", "default_dirt.png", "default_dirt.png", "default_dirt.png", "default_dirt.png", "default_dirt.png"},
	description = "Hydrated Farmland",
	drop = "default:dirt",
	drawtype = "nodebox",
	paramtype = "light",
	node_box = {
		type = "fixed",
		fixed = {
			{-0.5, -0.5, -0.5, 0.5, 0.4375, 0.5},
		}
	},
	groups = { crumbly=3, not_in_creative_inventory=1, soil=3, soil_sapling=1 },
	sounds = default.node_sound_dirt_defaults(),
})

minetest.register_abm({
	nodenames = {"farming:soil"},
	interval = 15,
	chance = 3,
	action = function(pos, node)
		if minetest.find_node_near(pos, 3, {"default:water_source", "default:water_flowing"}) then
			node.name = "farming:soil_wet"
			minetest.set_node(pos, node)
		end
	end,
})

