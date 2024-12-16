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

local ssp2_day                 = 0
local ssp2_ufo_count           = 0
local ssp2_posix               = 0
local photographed_ufos        = 0
local times_abducted           = 0
local times_spawned_in_room    = 0
local bunker_time              = "N/A"
local bunker_lever_order       = "N/A"
local zancudo_ufo_photographed = false
local ssp2_ufo_table           = {}

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
    local timer    = globals.get_int(1882379 + 1 + (1 + (6 * 15)) + 1)
    local cooldown = locals.get_int("freemode", 15827 + (1 + (6 * 12)) + 6)
    
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
    if not script.is_active("fm_content_sightseeing") then
    	return -1
    else
    	return locals.get_int("fm_content_sightseeing", 3401)
    end
end

local function get_photographed_ufo_count()
    local count = 0
    
    for i = 0, 25 do
    	local progress = stats.get_int("MPX_SSP2_PROGRESS")
    
    	if (progress & (1 << i)) ~= 0 then
    		count = count + 1
    	end
    end
    
    return count
end

local function get_bunker_lever_order()
    if not script.is_active("fm_content_ufo_abduction") then
        return "N/A"
    else
        local str = ""
        for i = 1, 4 do
            local index = locals.get_int("fm_content_ufo_abduction", 2934 + 393 + 2 + i) + 1
            if i > 1 then
                str = str .. " - "
            end
            str = str .. index
        end
        
        return str
    end
end

local function get_bunker_time()
    if not script.is_active("fm_content_ufo_abduction") then
        return "N/A"
    else
        local time_passed   = MISC.ABSI(NETWORK.GET_TIME_DIFFERENCE(NETWORK.GET_NETWORK_TIME(), locals.get_int("fm_content_ufo_abduction", 2934 + 375)))
        local diff          = NETWORK.GET_TIME_DIFFERENCE(tunables.get_int(-348918520), time_passed)
        local total_seconds = math.floor(diff / 1000)
        local hours         = math.floor(total_seconds / 3600)
        local minutes       = math.floor((total_seconds % 3600) / 60)
        local seconds       = total_seconds % 60
        local formatted     = string.format("%02d:%02d", minutes, seconds)
        
        return formatted
    end
end

script.register_looped("Sightseeing", function()
    ssp2_day                 = get_current_day()
    photographed_ufos        = get_photographed_ufo_count()
    ssp2_ufo_table           = create_ufo_combo(ssp2_ufo_count)
    bunker_lever_order       = get_bunker_lever_order()
    bunker_time              = get_bunker_time()
    ssp2_ufo_count           = globals.get_int(1963949)
    ssp2_posix               = tunables.get_int("SSP2POSIX")
    zancudo_ufo_photographed = (stats.get_int("MPX_SSP2_PROGRESS") & (1 << 31)) ~= 0
    times_abducted           = stats.get_int("MPX_SSP2_LIGHT")
    times_spawned_in_room    = stats.get_int("MPX_SSP2_ROOM")
    
    if remove_cooldown then
    	locals.set_int("freemode", 15827 + (1 + (6 * 12)) + 6, 1000)
    end
    
    if halloween_weather then
    	tunables.set_bool("SSP2WEATHER", true)
    end
    
    if always_spawn_inside then
        tunables.set_int("SSP2TP", 100)
        globals.set_int(1887549 + (1 + (self.get_id() * 611)) + 10, -1) -- Sign player out of CEO/MC
        
        local value = locals.get_int("fm_content_sightseeing", 1834 + 1) & ~(1 << 14)
        locals.set_int("fm_content_sightseeing", 1834 + 1, value)
    end
end)

sightseeing_tab:add_imgui(function()
    selected_day = ImGui.Combo("Select Day", selected_day, ssp2_days, #ssp2_days)
    selected_ufo = ImGui.Combo("Select UFO", selected_ufo, ssp2_ufo_table, #ssp2_ufo_table)

    if ImGui.Button("Start Event") then
        script.run_in_fiber(function(script)
            if has_cooldown_expired() then
                if is_time_valid() then
                    -- Kill it if it's already active.
                    while SCRIPT.GET_NUMBER_OF_THREADS_RUNNING_THE_SCRIPT_WITH_THIS_HASH(joaat("fm_content_sightseeing")) ~= 0 do
                        if NETWORK.NETWORK_GET_HOST_OF_SCRIPT("fm_content_sightseeing", 6, 0) ~= self.get_id() then
                            network.force_script_host("fm_content_sightseeing")
                        end
                        locals.set_int("fm_content_sightseeing", 1875 + 84, 3)
                        script:yield()
                    end
                    local value = get_epoch_x_days_ago(selected_day)
                    tunables.set_int("SSP2POSIX", value)
                    selected_ufo = 0
                else
                    if halloween_weather then
                        gui.show_error("Sightseeing", "Invalid time. It must be between 7:30pm and 6:30am.")
                    else
                        gui.show_error("Sightseeing", "Invalid time. It must be between 10:00pm and 3:00am.")
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
            local coords = locals.get_vec3("fm_content_sightseeing", 3421 + (1 + (selected_ufo * 3)))
            if coords ~= vec3:new(0.0, 0.0, 0.0) then
                PED.SET_PED_COORDS_KEEP_VEHICLE(self.get_ped(), coords.x, coords.y, coords.z)
            else
                gui.show_error("Sightseeing", "No UFOs found.")
            end
        end)
    end

    ImGui.Separator()

    ImGui.Text("Current Day: " .. (ssp2_day ~= -1 and ssp2_day + 1 or "N/A"))
    ImGui.Text("Active UFOs: " .. ssp2_ufo_count)
    ImGui.Text("UFOs Photographed: " .. photographed_ufos .. "/26")
    ImGui.Text("Zancudo UFO Photographed: " .. (zancudo_ufo_photographed and "Yes" or "No"))
    ImGui.Text("Times Abducted: " .. times_abducted)
    ImGui.Text("Times Spawned Inside: " .. times_spawned_in_room)
    ImGui.Text("Lever Order: " .. bunker_lever_order)
    ImGui.Text("Time Left: " .. bunker_time)

    ImGui.Separator()

    remove_cooldown, on_tick = ImGui.Checkbox("Remove Cooldown", remove_cooldown)
    if on_tick then
        if not remove_cooldown then
            local value = tunables.get_int("SSP2_COOLDOWN")
            locals.set_int("freemode", 15827 + (1 + (6 * 12)) + 6, value)
        end
    end

    halloween_weather, on_tick = ImGui.Checkbox("Halloween Weather", halloween_weather)
    if on_tick then
        if not halloween_weather then
            tunables.set_bool("SSP2WEATHER", false)
        end
    end

    always_spawn_inside, on_tick = ImGui.Checkbox("Always Spawn in Bunker", always_spawn_inside)
    if on_tick then
        if not always_spawn_inside then
            tunables.set_int("SSP2TP", 50)
        end
    end
end)