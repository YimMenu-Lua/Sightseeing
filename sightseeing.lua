local sightseeing_tab = gui.get_tab("Sightseeing")

local ssp2_days = {
	"Day 1 (1)",
	"Day 2 (2)",
	"Day 3 (3)",
	"Day 4 (4)",
	"Day 5 (5)",
	"Day 6 (6)",
	"Day 7 (7)",
	"Day 8 (8)",
	"Day 9 (8-9)",
	"Day 10 (10)",
	"Day 11 (11)",
	"Day 12 (12)",
	"Day 13 (1-2-3)",
	"Day 14 (5-8-11)",
	"Day 15 (6-10-12)",
	"Day 16 (13-17)",
	"Day 17 (13-26)",
	"Day 18 (13-26)",
	"Day 19 (13-26)",
	"Day 20 (13-26)"
}

local selected_day        = 0
local selected_ufo        = 0
local remove_cooldown     = false
local halloween_weather   = false
local always_spawn_inside = false
local props_loaded        = false

local ssp2_day       = 0
local ssp2_ufo_count = 0
local ssp2_posix     = 0
local ssp2_ufo_table = {}

local function create_ufo_combo(count)
	if count == 0 then
		return {"No UFOs"}
	end
		
	local ufos = {}
		
	for i = 1, count do
		table.insert(ufos, "UFO " .. i)
	end

	return ufos
end

local function get_epoch_x_days_ago(x)
	if x == 0 then
		return os.time()
	end
	
	local current_epoch_time = os.time()
	local epoch_x_days_ago   = current_epoch_time - (24 * 60 * 60 * x)
	
	return epoch_x_days_ago
end

local function has_cooldown_expired()
	local timer    = globals.get_int(1882037 + 1 + (1 + (6 * 15)) + 1)
	local cooldown = locals.get_int("freemode", 15544 + (1 + (6 * 12)) + 6)

	return MISC.ABSI(NETWORK.GET_TIME_DIFFERENCE(NETWORK.GET_NETWORK_TIME(), timer)) >= cooldown
end

-- This is actually bypassable, but I won't bother with it.
local function is_time_valid()
	local hour   = CLOCK.GET_CLOCK_HOURS()
	local minute = CLOCK.GET_CLOCK_MINUTES()
	
	if halloween_weather then
		return (((hour >= 19 or hour <= 6) and not (hour == 19 and minute < 30)) and not (hour == 6 and minute > 30))
	else
		return (hour >= 22 or hour <= 3)
	end
end

local function get_current_day()
	if SCRIPT.GET_NUMBER_OF_THREADS_RUNNING_THE_SCRIPT_WITH_THIS_HASH(joaat("fm_content_sightseeing")) == 0 then
		return -1
	else
		return locals.get_int("fm_content_sightseeing", 3285)
	end
end

function load_entity_sets()
	local interior_id = INTERIOR.GET_INTERIOR_AT_COORDS(-1876.0, 3750.0, -100.0)
	INTERIOR.ACTIVATE_INTERIOR_ENTITY_SET(interior_id, "entity_set_crates")
	INTERIOR.ACTIVATE_INTERIOR_ENTITY_SET(interior_id, "entity_set_levers")
	INTERIOR.ACTIVATE_INTERIOR_ENTITY_SET(interior_id, "entity_set_lift_lights")
	INTERIOR.ACTIVATE_INTERIOR_ENTITY_SET(interior_id, "entity_set_weapons")
	INTERIOR.REFRESH_INTERIOR(interior_id)
end

function unload_entity_sets()
	local interior_id = INTERIOR.GET_INTERIOR_AT_COORDS(-1876.0, 3750.0, -100.0)
	INTERIOR.DEACTIVATE_INTERIOR_ENTITY_SET(interior_id, "entity_set_crates")
	INTERIOR.DEACTIVATE_INTERIOR_ENTITY_SET(interior_id, "entity_set_levers")
	INTERIOR.DEACTIVATE_INTERIOR_ENTITY_SET(interior_id, "entity_set_lift_lights")
	INTERIOR.DEACTIVATE_INTERIOR_ENTITY_SET(interior_id, "entity_set_weapons")
	INTERIOR.REFRESH_INTERIOR(interior_id)
end

event.register_handler(menu_event.ScriptsReloaded, function()
	local value = tunables.get_int("SSP2_COOLDOWN")
	locals.set_int("freemode", 15544 + (1 + (6 * 12)) + 6, value)
end)

event.register_handler(menu_event.MenuUnloaded, function()
	local value = tunables.get_int("SSP2_COOLDOWN")
	locals.set_int("freemode", 15544 + (1 + (6 * 12)) + 6, value)
end)

script.register_looped("Sightseeing", function()
	ssp2_day          = get_current_day()
	ssp2_ufo_count    = globals.get_int(1962287)
	ssp2_posix        = tunables.get_int("SSP2POSIX")
	ssp2_ufo_table    = create_ufo_combo(ssp2_ufo_count)
	
	if remove_cooldown then
		locals.set_int("freemode", 15544 + (1 + (6 * 12)) + 6, 1000)
	end
	
	if halloween_weather then
		tunables.set_bool("SSP2WEATHER", true)
	end
	halloween_weather = tunables.get_bool("SSP2WEATHER")	
	
	if always_spawn_inside then
		tunables.set_int(878931106, 100)
	end
end)

sightseeing_tab:add_imgui(function()
	ImGui.Text("Current Day: " .. (ssp2_day ~= -1 and ssp2_day + 1 or "N/A"))
	ImGui.Text("Total UFOs: " .. ssp2_ufo_count)
	
	selected_day = ImGui.Combo("Select Day", selected_day, ssp2_days, #ssp2_days)
	selected_ufo = ImGui.Combo("Select UFO", selected_ufo, ssp2_ufo_table, #ssp2_ufo_table)
	
	if ImGui.Button("Start") then
		script.run_in_fiber(function(script)
			if has_cooldown_expired() then
				if is_time_valid() then
					gui.show_message("Sightseeing", "Please wait while the event is being started...")
					
					-- Kill it if it's already active
					while SCRIPT.GET_NUMBER_OF_THREADS_RUNNING_THE_SCRIPT_WITH_THIS_HASH(joaat("fm_content_sightseeing")) ~= 0 do
						if NETWORK.NETWORK_GET_HOST_OF_SCRIPT("fm_content_sightseeing", 6, 0) ~= self.get_id() then
							network.force_script_host("fm_content_sightseeing")
						end
						locals.set_int("fm_content_sightseeing", 1790 + 84, 3)
						script:yield()
					end	
					local value = get_epoch_x_days_ago(selected_day)
					tunables.set_int("SSP2POSIX", value)
					selected_ufo = 0
				else
					if halloween_weather then
						gui.show_error("Sightseeing", "Invalid time. It must be between 19:30pm and 6:30am.")
					else
						gui.show_error("Sightseeing", "Invalid time. It must be between 22:00pm and 3:00am.")
					end
				end
			else
				gui.show_error("Sightseeing", "Cooldown hasn't expired yet.")
			end
		end)
	end
	
	ImGui.SameLine()
	
	if ImGui.Button("Teleport to Selected") then
		script.run_in_fiber(function()
			local coords = locals.get_vec3("fm_content_sightseeing", 3305 + (1 + (selected_ufo * 3)))
			if coords ~= vec3:new(0.0, 0.0, 0.0) then
				PED.SET_PED_COORDS_KEEP_VEHICLE(self.get_ped(), coords.x, coords.y, coords.z)
			else
				gui.show_error("Sightseeing", "No UFOs found.")
			end
		end)
	end	
	
	if ImGui.Button("TP to Fort Zancudo Bunker") then
		script.run_in_fiber(function()
			PED.SET_PED_COORDS_KEEP_VEHICLE(self.get_ped(), -1876.0, 3750.0, -100.0)
		end)
	end
	
	ImGui.SameLine()
	
	if ImGui.Button((props_loaded and "Unload" or "Load") .. " Interior Props") then
		script.run_in_fiber(function()
			if props_loaded then
				unload_entity_sets()
				props_loaded = false
			else
				load_entity_sets()
				props_loaded = true
			end
		end)
	end
	
	ImGui.Separator()
	
	remove_cooldown, on_tick = ImGui.Checkbox("Remove Cooldown", remove_cooldown)
	
	if on_tick then
		if not remove_cooldown then
			local value = tunables.get_int("SSP2_COOLDOWN")
			locals.set_int("freemode", 15544 + (1 + (6 * 12)) + 6, value)
		end
	end
	
	halloween_weather, on_tick = ImGui.Checkbox("Halloween Weather", halloween_weather)
	
	if on_tick then
		if not halloween_weather then
			tunables.set_bool("SSP2WEATHER", false)
		end
	end
	
	always_spawn_inside, on_tick = ImGui.Checkbox("Always Spawn Inside", always_spawn_inside)
	
	if on_tick then
		if not always_spawn_inside then
			tunables.set_int(878931106, 25)
		end
	end
end)