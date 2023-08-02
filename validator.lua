local DST = GLOBAL.TheSim:GetGameID() == "DST"
local game_version = DST and "DST" or "DS"

-- Placers defined in a file can be extracted with a script like so:
-- cat deco_placers.lua | grep -E "MakePlacer" | sed -E 's/^\s*(return)?\s*MakePlacer\(("[^"]*").*$/\2 = true,/' > deco_placers.txt
-- It would be nice to do this here in Lua but I gave up on trying to over-optimize

local disable_place_test_prefabs = {
	DST = {
		"moon_device_construction1_placer",
	},
	DS = {
		"tar_extractor_placer",
		
		"wood_door_placer",
		"stone_door_placer",
		"organic_door_placer",
		"iron_door_placer",
		"pillar_door_placer",
		"curtain_door_placer",
		"round_door_placer",
		"plate_door_placer",
		
		"deco_wood_cornerbeam_placer",
		"deco_millinery_cornerbeam_placer",
		"deco_round_cornerbeam_placer",
		"deco_marble_cornerbeam_placer",
		"chair_classic_placer",
		"chair_corner_placer",
		"chair_bench_placer",
		"chair_horned_placer",
		"chair_footrest_placer",
		"chair_lounge_placer",
		"chair_massager_placer",
		"chair_stuffed_placer",
		"chair_rocking_placer",
		"chair_ottoman_placer",
		"shelves_wood_placer",
		"shelves_basic_placer",
		"shelves_cinderblocks_placer",
		"shelves_marble_placer",
		"shelves_glass_placer",
		"shelves_ladder_placer",
		"shelves_hutch_placer",
		"shelves_industrial_placer",
		"shelves_adjustable_placer",
		"shelves_midcentury_placer",
		"shelves_wallmount_placer",
		"shelves_aframe_placer",
		"shelves_crates_placer",
		"shelves_fridge_placer",
		"shelves_floating_placer",
		"shelves_pipe_placer",
		"shelves_hattree_placer",
		"shelves_pallet_placer",
		"swinging_light_basic_bulb_placer",
		"swinging_light_floral_bloomer_placer",
		"swinging_light_basic_metal_placer",
		"swinging_light_chandalier_candles_placer",
		"swinging_light_rope_1_placer",
		"swinging_light_rope_2_placer",
		"swinging_light_floral_bulb_placer",
		"swinging_light_pendant_cherries_placer",
		"swinging_light_floral_scallop_placer",
		"swinging_light_floral_bloomer_placer",
		"swinging_light_tophat_placer",
		"swinging_light_derby_placer",
		"window_round_curtains_nails_placer",
		"window_round_burlap_placer",
		"window_small_peaked_curtain_placer",
		"window_small_peaked_placer",
		"window_large_square_placer",
		"window_tall_placer",
		"window_large_square_curtain_placer",
		"window_tall_curtain_placer",
		"window_greenhouse_placer",
		"deco_lamp_fringe_placer",
		"deco_lamp_stainglass_placer",
		"deco_lamp_downbridge_placer",
		"deco_lamp_2embroidered_placer",
		"deco_lamp_ceramic_placer",
		"deco_lamp_glass_placer",
		"deco_lamp_2fringes_placer",
		"deco_lamp_candelabra_placer",
		"deco_lamp_elizabethan_placer",
		"deco_lamp_gothic_placer",
		"deco_lamp_orb_placer",
		"deco_lamp_bellshade_placer",
		"deco_lamp_crystals_placer",
		"deco_lamp_upturn_placer",
		"deco_lamp_2upturns_placer",
		"deco_lamp_spool_placer",
		"deco_lamp_edison_placer",
		"deco_lamp_adjustable_placer",
		"deco_lamp_rightangles_placer",
		"deco_chaise_placer",
		"deco_lamp_hoofspa_placer",
		"deco_plantholder_marble_placer",
		"deco_table_banker_placer",
		"deco_table_round_placer",
		"deco_table_diy_placer",
		"deco_table_raw_placer",
		"deco_table_crate_placer",
		"deco_table_chess_placer",
		"rug_round_placer",
		"rug_square_placer",
		"rug_oval_placer",
		"rug_rectangle_placer",
		"rug_leather_placer",
		"rug_fur_placer",
		"rug_circle_placer",
		"rug_hedgehog_placer",
		"rug_porcupuss_placer",
		"rug_hoofprint_placer",
		"rug_octagon_placer",
		"rug_swirl_placer",
		"rug_catcoon_placer",
		"rug_rubbermat_placer",
		"rug_web_placer",
		"rug_metal_placer",
		"rug_wormhole_placer",
		"rug_braid_placer",
		"rug_beard_placer",
		"rug_nailbed_placer",
		"rug_crime_placer",
		"rug_tiles_placer",
		"deco_plantholder_basic_placer",
		"deco_plantholder_wip_placer",
		"deco_plantholder_fancy_placer",
		"deco_plantholder_bonsai_placer",
		"deco_plantholder_dishgarden_placer",
		"deco_plantholder_philodendron_placer",
		"deco_plantholder_orchid_placer",
		"deco_plantholder_draceana_placer",
		"deco_plantholder_xerographica_placer",
		"deco_plantholder_birdcage_placer",
		"deco_plantholder_palm_placer",
		"deco_plantholder_zz_placer",
		"deco_plantholder_fernstand_placer",
		"deco_plantholder_fern_placer",
		"deco_plantholder_terrarium_placer",
		"deco_plantholder_plantpet_placer",
		"deco_plantholder_traps_placer",
		"deco_plantholder_pitchers_placer",
		"deco_plantholder_winterfeasttreeofsadness_placer",
		"deco_plantholder_winterfeasttree_placer",
		"deco_antiquities_wallfish_placer",
		"deco_antiquities_beefalo_placer",
		"deco_wallornament_photo_placer",
		"deco_wallornament_fulllength_mirror_placer",
		"deco_wallornament_embroidery_hoop_placer",
		"deco_wallornament_mosaic_placer",
		"deco_wallornament_wreath_placer",
		"deco_wallornament_axe_placer",
		"deco_wallornament_hunt_placer",
		"deco_wallornament_periodic_table_placer",
		"deco_wallornament_gears_art_placer",
		"deco_wallornament_cape_placer",
		"deco_wallornament_no_smoking_placer",
		"deco_wallornament_black_cat_placer",
	},
}
local disable_place_test = {}
for _,v in pairs(disable_place_test_prefabs[game_version]) do
	disable_place_test[v] = true
end

local testfn_name = DST and "override_testfn" or "placeTestFn"

function validatePlaceTestFns(ALLOW_PLACE_TEST)
	AddPrefabPostInit("world", function(world)
		world:DoTaskInTime(5, function()

			local had_unknown_placers = false
			for k,v in pairs(GLOBAL.Prefabs) do
				if k:find("_placer$") and not (ALLOW_PLACE_TEST[k] or disable_place_test[k]) then
					local fake_placer_inst = GLOBAL.SpawnPrefab(k)
					local placer = fake_placer_inst.components.placer
					if placer[testfn_name] ~= nil then
						print("New placer with placeTestFn:", k)
						had_unknown_placers = true
					end
					fake_placer_inst:Remove()
				end
			end	
			if not had_unknown_placers then
				print("No unrecognized placers with placeTestFn, yay!")
			end
		end)
	end)
end