--[[
	Simple Speedrun Timer: A hotkey controlled text timer for timed content (marathons, speedruns, etc.).
--]]

-- obs values
obs = obslua
hotkey_id_pause = obs.OBS_INVALID_HOTKEY_ID
hotkey_id_reset = obs.OBS_INVALID_HOTKEY_ID

-- user values
source_name = nil
active_color = nil
paused_color = nil

-- internal values
paused = true
started_at = nil

function get_time_text()
	if not started_at then
		return "0:00:00"
	end
	
	local total_seconds = os.difftime(os.time(), started_at)
	
	local seconds = total_seconds % 60
	total_seconds = (total_seconds - seconds) / 60
	local minutes = total_seconds % 60
	total_seconds = (total_seconds - minutes) / 60
	local hours   = total_seconds
	
	return string.format("%d:%02d:%02d", hours, minutes, seconds)
end

function get_time_color()
	if paused and started_at then
		return paused_color
	end
	return active_color
end

function update_source_properties()
	local source = obs.obs_get_source_by_name(source_name)
	if source ~= nil then
		local settings = obs.obs_data_create()
		obs.obs_data_set_string(settings, "text", get_time_text())
		obs.obs_data_set_int(settings, "color", get_time_color())
		obs.obs_source_update(source, settings)
		obs.obs_data_release(settings)
		obs.obs_source_release(source)
	end
end

function timer_callback()
	update_source_properties()
end

function start_timer()
	obs.timer_add(timer_callback, 1000) -- once per second
end

function stop_timer()
	obs.timer_remove(timer_callback)
end

-- TODO: Add double tap prevention buffer
function on_pause(pressed)
	if not pressed then
		return
	end
	
	if paused then
		paused = false
		started_at = started_at or os.time() -- don't overwrite existing start time (allows resuming timer from accidental pause)
		start_timer()
	else
		paused = true
		stop_timer()
	end
	
	update_source_properties()
end

function on_reset(pressed)
	if not pressed then
		return
	end
	
	if paused then  -- only allow reset if paused (helps prevent accidental resets)
		started_at = nil -- clear start time (needed to enable unpausing logic)
		stop_timer()
		update_source_properties()
	end
end

function pause_button_clicked(props, p)
	on_pause(true)
end

function reset_button_clicked(props, p)
	on_reset(true)
end

function script_properties()
	local props = obs.obs_properties_create()
	
	obs.obs_properties_add_color(props, "active_color", "Text color when active")
	obs.obs_properties_add_color(props, "paused_color", "Text color when paused")
	
	local p = obs.obs_properties_add_list(props, "source", "Text Source", obs.OBS_COMBO_TYPE_EDITABLE, obs.OBS_COMBO_FORMAT_STRING)
	local sources = obs.obs_enum_sources()
	if sources ~= nil then
		for _, source in ipairs(sources) do
			source_id = obs.obs_source_get_id(source)
			if source_id == "text_gdiplus" or source_id == "text_gdiplus_v2" then
				local name = obs.obs_source_get_name(source)
				obs.obs_property_list_add_string(p, name, name)
			end
		end
	end
	obs.source_list_release(sources)
	
	obs.obs_properties_add_button(props, "pause_button", "Start / Pause", pause_button_clicked)
	obs.obs_properties_add_button(props, "reset_button", "Reset", reset_button_clicked)
	
	return props
end

function script_description()
	return "A hotkey controlled text timer for timed content (marathons & speedruns).\n\n" ..
		"Note: Unpausing the timer will cause it to snap forward, as if it were never paused. Also, you can only reset the timer while paused!"
end

function script_update(settings)
	source_name = obs.obs_data_get_string(settings, "source")
	active_color = obs.obs_data_get_int(settings, "active_color")
	paused_color = obs.obs_data_get_int(settings, "paused_color")
	paused = true -- can only reset timer when paused
	on_reset(true)
end

function script_defaults(settings)
	obs.obs_data_set_default_int(settings, "active_color", 0xffffffff)
	obs.obs_data_set_default_int(settings, "paused_color", 0xffffbb00)
end

function script_save(settings)
	local hotkey_save_array_pause = obs.obs_hotkey_save(hotkey_id_pause)
	local hotkey_save_array_reset = obs.obs_hotkey_save(hotkey_id_reset)
	obs.obs_data_set_array(settings, "pause_hotkey", hotkey_save_array_pause)
	obs.obs_data_set_array(settings, "reset_hotkey", hotkey_save_array_reset)
	obs.obs_data_array_release(hotkey_save_array_pause)
	obs.obs_data_array_release(hotkey_save_array_reset)
end

function script_load(settings)
	hotkey_id_pause = obs.obs_hotkey_register_frontend("pause_speedrun", "Start / Pause Speedrun", on_pause)
	hotkey_id_reset = obs.obs_hotkey_register_frontend("reset_speedrun", "Reset Speedrun", on_reset)
	local hotkey_save_array_pause = obs.obs_data_get_array(settings, "pause_hotkey")
	local hotkey_save_array_reset = obs.obs_data_get_array(settings, "reset_hotkey")
	obs.obs_hotkey_load(hotkey_id_pause, hotkey_save_array_pause)
	obs.obs_hotkey_load(hotkey_id_reset, hotkey_save_array_reset)
	obs.obs_data_array_release(hotkey_save_array_pause)
	obs.obs_data_array_release(hotkey_save_array_reset)
end

