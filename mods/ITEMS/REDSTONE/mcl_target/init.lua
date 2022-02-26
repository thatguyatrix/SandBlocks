local S = minetest.get_translator("mcl_target")

mcl_target = {}

function mcl_target.hit(pos, time)
	minetest.set_node(pos, {name="mcl_target:target_on"})
	mesecon.receptor_on(pos, mesecon.rules.alldirs)

	local timer = minetest.get_node_timer(pos)
	timer:start(time)
end

minetest.register_node("mcl_target:target_off", {
	description = S("Target"),
	--_tt_help = S(""),
	--_doc_items_longdesc = longdesc,
	--_doc_items_usagehelp = buttonuse,
	tiles = {"mcl_target_target_top.png", "mcl_target_target_top.png", "mcl_target_target_side.png"},
	groups = {hoey = 1},
	sounds = mcl_sounds.node_sound_dirt_defaults({
		footstep = {name="default_grass_footstep", gain=0.1},
	}),
	mesecons = {
		receptor = {
			state = mesecon.state.off,
			rules = mesecon.rules.alldirs,
		},
	},
	_mcl_blast_resistance = 0.5,
	_mcl_hardness = 0.5,
})

minetest.register_node("mcl_target:target_on", {
	description = S("Target"),
	_doc_items_create_entry = false,
	tiles = {"mcl_target_target_top.png", "mcl_target_target_top.png", "mcl_target_target_side.png"},
	groups = {hoey = 1, not_in_creative_inventory = 1},
	drop = "mcl_target:target_off",
	sounds = mcl_sounds.node_sound_dirt_defaults({
		footstep = {name="default_grass_footstep", gain=0.1},
	}),
	on_timer = function(pos, elapsed)
		local node = minetest.get_node(pos)
		if node.name == "mcl_target:target_on" then --has not been dug
			minetest.set_node(pos, {name="mcl_target:target_off"})
			mesecon.receptor_off(pos, mesecon.rules.alldirs)
		end
	end,
	mesecons = {
		receptor = {
			state = mesecon.state.on,
			rules = mesecon.rules.alldirs,
		},
	},
	_mcl_blast_resistance = 0.5,
	_mcl_hardness = 0.5,
})
