obs = obslua
global_settings = nil

-- ==== Defaults ====
timer_source_name = "Pomodoro Timer"
status_source_name = ""
focus_minutes = 25
short_break_minutes = 5
long_break_minutes = 15
sessions_before_long = 4
stop_after_long_break = true
stop_stream_after_long_break = true

clock_source_name = ""
clock_format = "%I:%M %p"

focus_scene_name = ""
short_break_scene_name = ""
long_break_scene_name = ""

daily_goal = 8
total_sessions_completed = 0
goal_source_name = ""

current_subject = ""
subject_source_name = ""

sound_warning_file = ""

show_mode_label = true
show_session_counter = true
session_label = "Session"
focus_message = "Focus Time!"
short_break_message = "Short Break!"
long_break_message = "Long Break!"
stopped_message = "Timer Stopped"
paused_message = "Paused"
label_focus = "🧠 FOCUS"
label_short_break = "☕ BREAK"
label_long_break = "🛌 LONG BREAK"

-- End time display
show_end_time = true
end_time_label = "Ends at"
end_time_inline = true
sep_char = "•"
use_24h = true

-- Sounds
enable_sounds = true
sound_focus_file = ""
sound_short_file = ""
sound_long_file = ""
sound_warning_file = ""

-- Colors (for timer text source)
color_focus = 0x00FF00
color_short_break = 0xFFFF00
color_long_break = 0xFF0000
color_paused = 0xFFFFFF
color_stopped = 0xAAAAAA

-- Auto-start
auto_scene_name = ""

-- State
mode = "stopped"      -- "focus" | "short_break" | "long_break" | "paused" | "stopped"
prev_mode = "focus"
time_left = 0
session_count = 0
timer_running = false

-- Hotkeys
hk_start = obs.OBS_INVALID_HOTKEY_ID
hk_pause = obs.OBS_INVALID_HOTKEY_ID
hk_resume= obs.OBS_INVALID_HOTKEY_ID
hk_reset = obs.OBS_INVALID_HOTKEY_ID
hk_skip  = obs.OBS_INVALID_HOTKEY_ID

-- ==== Utils ====
local function file_exists(path)
    if not path or path == "" then return false end
    local f = io.open(path, "rb")
    if f then f:close(); return true end
    return false
end

local function get_source(name)
    if not name or name == "" then return nil end
    return obs.obs_get_source_by_name(name)
end

local function set_text(name, text)
    local src = get_source(name)
    if src then
        local s = obs.obs_data_create()
        obs.obs_data_set_string(s, "text", text)
        obs.obs_source_update(src, s)
        obs.obs_data_release(s)
        obs.obs_source_release(src)
    end
end

local function set_color(name, color)
    local src = get_source(name)
    if src then
        local s = obs.obs_data_create()
        obs.obs_data_set_int(s, "color", color)
        obs.obs_source_update(src, s)
        obs.obs_data_release(s)
        obs.obs_source_release(src)
    end
end

local function switch_to_scene(name)
    if not name or name == "" then return end
    local scenes = obs.obs_frontend_get_scenes()
    if scenes ~= nil then
        for _, scene in ipairs(scenes) do
            local n = obs.obs_source_get_name(scene)
            if n == name then
                obs.obs_frontend_set_current_scene(scene)
                break
            end
        end
        obs.source_list_release(scenes)
    end
end

local function clock_tick()
    if clock_source_name ~= "" then
        local fmt = clock_format
        if fmt == "" then fmt = "%I:%M %p" end
        set_text(clock_source_name, os.date(fmt))
    end
end

local function fmt_mmss(sec)
    if sec < 0 then sec = 0 end
    local h = math.floor(sec / 3600)
    local m = math.floor((sec % 3600) / 60)
    local s = sec % 60
    if h > 0 then return string.format("%d:%02d:%02d", h, m, s) else return string.format("%02d:%02d", m, s) end
end

local function fmt_clock(ts)
    return os.date(use_24h and "%H:%M" or "%I:%M %p", ts)
end

local function current_label()
    if mode == "focus" then return label_focus
    elseif mode == "short_break" then return label_short_break
    elseif mode == "long_break" then return label_long_break
    elseif mode == "paused" then return paused_message
    else return stopped_message end
end

local function session_suffix()
    if not show_session_counter then return "" end
    local idx = session_count
    if mode == "focus" then idx = session_count + 1 end
    if sessions_before_long > 0 then
        return string.format(" (%s %d of %d)", session_label, idx, sessions_before_long)
    else
        return string.format(" (%s %d)", session_label, idx)
    end
end

-- ==== Sounds ====
local function play_source(path)
    if not enable_sounds or not path or path == "" then return end
    if not file_exists(path) then return end
    
    local src = obs.obs_get_source_by_name("Pomodoro Alert")
    if src then
        local s = obs.obs_data_create()
        obs.obs_data_set_string(s, "local_file", path)
        obs.obs_source_update(src, s)
        obs.obs_data_release(s)
        
        obs.obs_source_media_restart(src)
        obs.obs_source_release(src)
    end
end

local function play_cue_for_next(next_mode)
    if next_mode == "focus" then play_source(sound_focus_file)
    elseif next_mode == "short_break" then play_source(sound_short_file)
    elseif next_mode == "long_break" then play_source(sound_long_file)
    end
end

-- ==== Core ====
local function next_mode_after_current()
    if mode == "focus" then
        local next_s = session_count + 1
        if sessions_before_long > 0 and (next_s % sessions_before_long == 0) then return "long_break" else return "short_break" end
    elseif mode == "short_break" then
        return "focus"
    elseif mode == "long_break" then
        if stop_after_long_break then return "stopped" else return "focus" end
    end
    return nil
end

local function push_display()
    local base = fmt_mmss(time_left)
    if show_mode_label and (mode == "focus" or mode == "short_break" or mode == "long_break") then
        base = current_label() .. " " .. sep_char .. " " .. base
    end
    if mode ~= "stopped" and mode ~= "paused" then base = base .. session_suffix() end
    if show_end_time and mode ~= "stopped" and mode ~= "paused" then
        local end_txt = string.format("%s %s", end_time_label, fmt_clock(os.time() + time_left))
        if end_time_inline then
            base = base .. " " .. sep_char .. " " .. end_txt
        else
            base = base .. "\n" .. end_txt
        end
    end
    set_text(timer_source_name, base)
    local cmap = { focus=color_focus, short_break=color_short_break, long_break=color_long_break, paused=color_paused, stopped=color_stopped }
    set_color(timer_source_name, cmap[mode] or 0xFFFFFF)
    if status_source_name ~= "" then
        local m = { focus=focus_message, short_break=short_break_message, long_break=long_break_message, paused=paused_message, stopped=stopped_message }
        set_text(status_source_name, m[mode])
    end
    if goal_source_name ~= "" then
        set_text(goal_source_name, string.format("Goal: %d / %d Pomodoros Completed", total_sessions_completed, daily_goal))
    end
    if subject_source_name ~= "" then
        set_text(subject_source_name, current_subject)
    end
end

local function set_mode(new_mode)
    mode = new_mode
    if mode == "focus" then
        time_left = math.max(1, focus_minutes) * 60
        switch_to_scene(focus_scene_name)
    elseif mode == "short_break" then
        time_left = math.max(1, short_break_minutes) * 60
        switch_to_scene(short_break_scene_name)
    elseif mode == "long_break" then
        time_left = math.max(1, long_break_minutes) * 60
        switch_to_scene(long_break_scene_name)
    end
    push_display()
end

local function end_of_segment()
    if mode == "focus" then
        session_count = session_count + 1
        total_sessions_completed = total_sessions_completed + 1
        if sessions_before_long > 0 and (session_count % sessions_before_long == 0) then set_mode("long_break") else set_mode("short_break") end
    elseif mode == "long_break" then
        if stop_after_long_break then
            if stop_stream_after_long_break then
                obs.obs_frontend_streaming_stop()
            end
            obs.timer_remove(tick)
            timer_running = false
            mode = "stopped"
            time_left = 0
            push_display()
        else
            set_mode("focus")
        end
    else
        set_mode("focus")
    end
end

local function tick()
    if not timer_running or mode == "paused" or mode == "stopped" then return end
    if time_left == 1 then
        local nm = next_mode_after_current()
        play_cue_for_next(nm)
    elseif time_left == 60 and (mode == "short_break" or mode == "long_break") then
        play_source(sound_warning_file)
    end
    time_left = time_left - 1
    if time_left <= 0 then end_of_segment() else push_display() end
end

-- ==== Controls ====
function start_pressed(pressed)
    if not pressed then return end
    timer_running = true
    session_count = 0
    set_mode("focus")
    obs.timer_add(tick, 1000)
end

function pause_pressed(pressed)
    if pressed and timer_running and (mode=="focus" or mode=="short_break" or mode=="long_break") then prev_mode = mode; mode="paused"; push_display() end
end

function resume_pressed(pressed)
    if pressed and mode=="paused" then mode = prev_mode or "focus"; push_display() end
end

function reset_pressed(pressed)
    if pressed then obs.timer_remove(tick); timer_running=false; mode="stopped"; session_count=0; time_left=0; push_display() end
end

function skip_pressed(pressed)
    if pressed and timer_running then end_of_segment(); push_display() end
end

function reset_goal_pressed(pressed)
    if pressed then total_sessions_completed = 0; push_display() end
end

-- ==== OBS UI ====
local function create_text_source(name, text)
    local src = obs.obs_get_source_by_name(name)
    if not src then
        local s = obs.obs_data_create()
        obs.obs_data_set_string(s, "text", text)
        src = obs.obs_source_create("text_gdiplus", name, s, nil)
        obs.obs_data_release(s)
    end
    return src
end

local function create_media_source_stub(name)
    local src = obs.obs_get_source_by_name(name)
    if not src then
        local s = obs.obs_data_create()
        obs.obs_data_set_bool(s, "is_local_file", true)
        obs.obs_data_set_bool(s, "looping", false)
        obs.obs_data_set_bool(s, "close_when_inactive", false)
        obs.obs_data_set_bool(s, "restart_on_activate", false)
        src = obs.obs_source_create("ffmpeg_source", name, s, nil)
        obs.obs_data_release(s)
    end
    
    if src then
        local scenes = obs.obs_frontend_get_scenes()
        if scenes then
            for _, cur_scene in ipairs(scenes) do
                local scene = obs.obs_scene_from_source(cur_scene)
                if scene then
                    local found = obs.obs_scene_find_source(scene, name)
                    if not found then
                        local item = obs.obs_scene_add(scene, src)
                        local pos = obs.vec2()
                        pos.x = -1000
                        pos.y = -1000
                        obs.obs_sceneitem_set_pos(item, pos)
                    end
                end
            end
            obs.source_list_release(scenes)
        end
        obs.obs_source_release(src)
    end
end

function auto_setup_pressed(props, prop)
    local scene_names = {"Study With Me - Focus", "Study With Me - Short Break", "Study With Me - Long Break"}
    local scenes = {}
    local created_scenes = {}
    
    for _, name in ipairs(scene_names) do
        local source = obs.obs_get_source_by_name(name)
        if source then
            local scene = obs.obs_scene_from_source(source)
            table.insert(scenes, {scene=scene, source=source})
        else
            local scene = obs.obs_scene_create(name)
            table.insert(scenes, {scene=scene, source=nil})
            table.insert(created_scenes, scene)
        end
    end
    
    local texts = {
        {name="Pomodoro Timer", default="25:00", y=50},
        {name="Pomodoro Status", default="Focus Time!", y=150},
        {name="Pomodoro Clock", default="12:00 PM", y=250},
        {name="Pomodoro Goal", default="Goal: 0 / 8", y=350},
        {name="Pomodoro Subject", default="Studying...", y=450}
    }
    
    for _, t in ipairs(texts) do
        local src = create_text_source(t.name, t.default)
        if src then
            for _, sc in ipairs(scenes) do
                local found = obs.obs_scene_find_source(sc.scene, t.name)
                if not found then
                    local item = obs.obs_scene_add(sc.scene, src)
                    local pos = obs.vec2()
                    pos.x = 50
                    pos.y = t.y
                    obs.obs_sceneitem_set_pos(item, pos)
                end
            end
            obs.obs_source_release(src)
        end
    end
    
    for _, sc in ipairs(scenes) do
        if sc.source then obs.obs_source_release(sc.source) end
    end
    for _, scene in ipairs(created_scenes) do
        obs.obs_scene_release(scene)
    end
    
    create_media_source_stub("Pomodoro Alert")
    
    if global_settings then
        obs.obs_data_set_string(global_settings, "focus_scene_name", "Study With Me - Focus")
        obs.obs_data_set_string(global_settings, "short_break_scene_name", "Study With Me - Short Break")
        obs.obs_data_set_string(global_settings, "long_break_scene_name", "Study With Me - Long Break")
        
        obs.obs_data_set_string(global_settings, "timer_source_name", "Pomodoro Timer")
        obs.obs_data_set_string(global_settings, "status_source_name", "Pomodoro Status")
        obs.obs_data_set_string(global_settings, "clock_source_name", "Pomodoro Clock")
        obs.obs_data_set_string(global_settings, "goal_source_name", "Pomodoro Goal")
        obs.obs_data_set_string(global_settings, "subject_source_name", "Pomodoro Subject")
        
        script_update(global_settings)
    end
    
    return true
end

function script_defaults(settings)
    obs.obs_data_set_default_bool(settings, "stop_after_long_break", true)
    obs.obs_data_set_default_bool(settings, "stop_stream_after_long_break", true)
    obs.obs_data_set_default_string(settings, "clock_format", "%I:%M %p")
    obs.obs_data_set_default_string(settings, "current_subject", "Studying...")
    
    obs.obs_data_set_default_string(settings, "focus_scene_name", "Study With Me - Focus")
    obs.obs_data_set_default_string(settings, "short_break_scene_name", "Study With Me - Short Break")
    obs.obs_data_set_default_string(settings, "long_break_scene_name", "Study With Me - Long Break")
    
    obs.obs_data_set_default_string(settings, "timer_source_name", "Pomodoro Timer")
    obs.obs_data_set_default_string(settings, "status_source_name", "Pomodoro Status")
    obs.obs_data_set_default_string(settings, "clock_source_name", "Pomodoro Clock")
    obs.obs_data_set_default_string(settings, "goal_source_name", "Pomodoro Goal")
    obs.obs_data_set_default_string(settings, "subject_source_name", "Pomodoro Subject")
end

function script_properties()
    local p = obs.obs_properties_create()
    obs.obs_properties_add_button(p, "btn_auto_setup", "🪄 Auto-Create Scene Setup (Recommended)", auto_setup_pressed)
    
    local function populate_text_sources(list_property)
        obs.obs_property_list_clear(list_property)
        obs.obs_property_list_add_string(list_property, "", "")
        local sources = obs.obs_enum_sources()
        if sources ~= nil then
            for _, source in ipairs(sources) do
                local source_id = obs.obs_source_get_unversioned_id(source)
                if source_id == "text_gdiplus" or source_id == "text_ft2_source" or source_id == "text_gdiplus_v2" then
                    local name = obs.obs_source_get_name(source)
                    obs.obs_property_list_add_string(list_property, name, name)
                end
            end
        end
        obs.source_list_release(sources)
    end

    local function populate_scenes(list_property)
        obs.obs_property_list_clear(list_property)
        obs.obs_property_list_add_string(list_property, "", "")
        local scenes = obs.obs_frontend_get_scenes()
        if scenes ~= nil then
            for _, scene in ipairs(scenes) do
                local name = obs.obs_source_get_name(scene)
                obs.obs_property_list_add_string(list_property, name, name)
            end
            obs.source_list_release(scenes)
        end
    end

    

    local p_timer = obs.obs_properties_add_list(p, "timer_source_name", "Timer Source", obs.OBS_COMBO_TYPE_EDITABLE, obs.OBS_COMBO_FORMAT_STRING)
    populate_text_sources(p_timer)
    
    local p_status = obs.obs_properties_add_list(p, "status_source_name", "Status Source", obs.OBS_COMBO_TYPE_EDITABLE, obs.OBS_COMBO_FORMAT_STRING)
    populate_text_sources(p_status)
    
    local p_clock = obs.obs_properties_add_list(p, "clock_source_name", "Local Clock Source", obs.OBS_COMBO_TYPE_EDITABLE, obs.OBS_COMBO_FORMAT_STRING)
    populate_text_sources(p_clock)
    
    obs.obs_properties_add_text(p, "clock_format", "Clock Format (e.g. %I:%M %p)", obs.OBS_TEXT_DEFAULT)
    
    local p_fscene = obs.obs_properties_add_list(p, "focus_scene_name", "Focus Scene (Auto-switch)", obs.OBS_COMBO_TYPE_EDITABLE, obs.OBS_COMBO_FORMAT_STRING)
    populate_scenes(p_fscene)
    
    local p_sscene = obs.obs_properties_add_list(p, "short_break_scene_name", "Short Break Scene (Auto-switch)", obs.OBS_COMBO_TYPE_EDITABLE, obs.OBS_COMBO_FORMAT_STRING)
    populate_scenes(p_sscene)
    
    local p_lscene = obs.obs_properties_add_list(p, "long_break_scene_name", "Long Break Scene (Auto-switch)", obs.OBS_COMBO_TYPE_EDITABLE, obs.OBS_COMBO_FORMAT_STRING)
    populate_scenes(p_lscene)
    
    obs.obs_properties_add_int(p, "daily_goal", "Daily Goal (Sessions)", 1, 100, 1)
    
    local p_goal = obs.obs_properties_add_list(p, "goal_source_name", "Daily Goal Source", obs.OBS_COMBO_TYPE_EDITABLE, obs.OBS_COMBO_FORMAT_STRING)
    populate_text_sources(p_goal)
    
    obs.obs_properties_add_text(p, "current_subject", "Current Subject/Task", obs.OBS_TEXT_DEFAULT)
    
    local p_subj = obs.obs_properties_add_list(p, "subject_source_name", "Subject Source", obs.OBS_COMBO_TYPE_EDITABLE, obs.OBS_COMBO_FORMAT_STRING)
    populate_text_sources(p_subj)

    obs.obs_properties_add_int(p, "focus_minutes", "Focus (min)", 1, 240, 1)
    obs.obs_properties_add_int(p, "short_break_minutes", "Short Break (min)", 1, 120, 1)
    obs.obs_properties_add_int(p, "long_break_minutes", "Long Break (min)", 1, 240, 1)
    obs.obs_properties_add_int(p, "sessions_before_long", "Sessions before Long Break", 1, 24, 1)
    obs.obs_properties_add_bool(p, "stop_after_long_break", "Stop timer after Long Break")
    obs.obs_properties_add_bool(p, "stop_stream_after_long_break", "Stop stream after Long Break")

    obs.obs_properties_add_bool(p, "show_mode_label", "Show mode label")
    obs.obs_properties_add_bool(p, "show_session_counter", "Show session counter")
    obs.obs_properties_add_text(p, "session_label", "Session Label", obs.OBS_TEXT_DEFAULT)

    obs.obs_properties_add_bool(p, "show_end_time", "Show end time")
    obs.obs_properties_add_bool(p, "end_time_inline", "End time inline")
    obs.obs_properties_add_text(p, "end_time_label", "End time label", obs.OBS_TEXT_DEFAULT)
    obs.obs_properties_add_text(p, "sep_char", "Separator", obs.OBS_TEXT_DEFAULT)
    obs.obs_properties_add_bool(p, "use_24h", "Use 24h clock")

    obs.obs_properties_add_bool(p, "enable_sounds", "Enable Sounds")
    obs.obs_properties_add_path(p, "sound_focus_file", "Sound: Focus", obs.OBS_PATH_FILE, "*.mp3;*.wav", nil)
    obs.obs_properties_add_path(p, "sound_short_file", "Sound: Short Break", obs.OBS_PATH_FILE, "*.mp3;*.wav", nil)
    obs.obs_properties_add_path(p, "sound_long_file",  "Sound: Long Break",  obs.OBS_PATH_FILE, "*.mp3;*.wav", nil)
    obs.obs_properties_add_path(p, "sound_warning_file", "Sound: 1-Min Warning", obs.OBS_PATH_FILE, "*.mp3;*.wav", nil)

    obs.obs_properties_add_color(p, "color_focus", "Color: Focus")
    obs.obs_properties_add_color(p, "color_short_break", "Color: Short Break")
    obs.obs_properties_add_color(p, "color_long_break", "Color: Long Break")
    obs.obs_properties_add_color(p, "color_paused", "Color: Paused")
    obs.obs_properties_add_color(p, "color_stopped", "Color: Stopped")

    local p_auto = obs.obs_properties_add_list(p, "auto_scene_name", "Auto-start on Scene", obs.OBS_COMBO_TYPE_EDITABLE, obs.OBS_COMBO_FORMAT_STRING)
    populate_scenes(p_auto)

    obs.obs_properties_add_button(p, "btn_start", "▶ Start", start_pressed)
    obs.obs_properties_add_button(p, "btn_pause", "⏸ Pause", pause_pressed)
    obs.obs_properties_add_button(p, "btn_resume", "⏵ Resume", resume_pressed)
    obs.obs_properties_add_button(p, "btn_reset", "⟲ Reset", reset_pressed)
    obs.obs_properties_add_button(p, "btn_skip",  "⤼ Skip",  skip_pressed)
    obs.obs_properties_add_button(p, "btn_reset_goal", "⟲ Reset Daily Goal", reset_goal_pressed)
    return p
end

function script_update(s)
    global_settings = s
    timer_source_name = obs.obs_data_get_string(s, "timer_source_name")
    status_source_name= obs.obs_data_get_string(s, "status_source_name")
    
    clock_source_name = obs.obs_data_get_string(s, "clock_source_name")
    clock_format = obs.obs_data_get_string(s, "clock_format")
    
    focus_scene_name = obs.obs_data_get_string(s, "focus_scene_name")
    short_break_scene_name = obs.obs_data_get_string(s, "short_break_scene_name")
    long_break_scene_name = obs.obs_data_get_string(s, "long_break_scene_name")
    
    daily_goal = math.max(1, obs.obs_data_get_int(s, "daily_goal"))
    goal_source_name = obs.obs_data_get_string(s, "goal_source_name")
    
    current_subject = obs.obs_data_get_string(s, "current_subject")
    subject_source_name = obs.obs_data_get_string(s, "subject_source_name")

    focus_minutes = math.max(1, obs.obs_data_get_int(s, "focus_minutes"))
    short_break_minutes = math.max(1, obs.obs_data_get_int(s, "short_break_minutes"))
    long_break_minutes  = math.max(1, obs.obs_data_get_int(s, "long_break_minutes"))
    sessions_before_long= math.max(1, obs.obs_data_get_int(s, "sessions_before_long"))
    stop_after_long_break = obs.obs_data_get_bool(s, "stop_after_long_break")
    stop_stream_after_long_break = obs.obs_data_get_bool(s, "stop_stream_after_long_break")

    show_mode_label = obs.obs_data_get_bool(s, "show_mode_label")
    show_session_counter = obs.obs_data_get_bool(s, "show_session_counter")
    session_label = obs.obs_data_get_string(s, "session_label")

    show_end_time = obs.obs_data_get_bool(s, "show_end_time")
    end_time_inline = obs.obs_data_get_bool(s, "end_time_inline")
    end_time_label = obs.obs_data_get_string(s, "end_time_label")
    sep_char = obs.obs_data_get_string(s, "sep_char"); if sep_char == "" then sep_char = "•" end
    use_24h = obs.obs_data_get_bool(s, "use_24h")

    enable_sounds = obs.obs_data_get_bool(s, "enable_sounds")
    sound_focus_file = obs.obs_data_get_string(s, "sound_focus_file")
    sound_short_file = obs.obs_data_get_string(s, "sound_short_file")
    sound_long_file  = obs.obs_data_get_string(s, "sound_long_file")
    sound_warning_file = obs.obs_data_get_string(s, "sound_warning_file")

    color_focus = obs.obs_data_get_int(s, "color_focus")
    color_short_break = obs.obs_data_get_int(s, "color_short_break")
    color_long_break  = obs.obs_data_get_int(s, "color_long_break")
    color_paused = obs.obs_data_get_int(s, "color_paused")
    color_stopped= obs.obs_data_get_int(s, "color_stopped")

    auto_scene_name = obs.obs_data_get_string(s, "auto_scene_name")

    push_display()
end

-- ==== Hotkeys ====
local function hk_load(settings, id, name)
    local arr = obs.obs_data_get_array(settings, name)
    obs.obs_hotkey_load(id, arr)
    obs.obs_data_array_release(arr)
end

local function hk_save(settings, id, name)
    local arr = obs.obs_hotkey_save(id)
    obs.obs_data_set_array(settings, name, arr)
    obs.obs_data_array_release(arr)
end

function script_load(settings)
    hk_start = obs.obs_hotkey_register_frontend("pomo_start", "Pomodoro Start", function(pressed) if pressed then start_pressed(true) end end)
    hk_pause = obs.obs_hotkey_register_frontend("pomo_pause", "Pomodoro Pause", function(pressed) if pressed then pause_pressed(true) end end)
    hk_resume= obs.obs_hotkey_register_frontend("pomo_resume","Pomodoro Resume",function(pressed) if pressed then resume_pressed(true) end end)
    hk_reset = obs.obs_hotkey_register_frontend("pomo_reset", "Pomodoro Reset", function(pressed) if pressed then reset_pressed(true) end end)
    hk_skip  = obs.obs_hotkey_register_frontend("pomo_skip",  "Pomodoro Skip",  function(pressed) if pressed then skip_pressed(true)  end end)

    hk_load(settings, hk_start, "pomo_start")
    hk_load(settings, hk_pause, "pomo_pause")
    hk_load(settings, hk_resume,"pomo_resume")
    hk_load(settings, hk_reset, "pomo_reset")
    hk_load(settings, hk_skip,  "pomo_skip")

    obs.timer_add(clock_tick, 1000)

    obs.obs_frontend_add_event_callback(function(ev)
        if ev == obs.OBS_FRONTEND_EVENT_SCENE_CHANGED and auto_scene_name ~= "" then
            local cur = obs.obs_frontend_get_current_scene()
            if cur then
                local nm = obs.obs_source_get_name(cur)
                if nm == auto_scene_name and not timer_running then start_pressed(true) end
                obs.obs_source_release(cur)
            end
        end
    end)
end

function script_save(settings)
    hk_save(settings, hk_start, "pomo_start")
    hk_save(settings, hk_pause, "pomo_pause")
    hk_save(settings, hk_resume,"pomo_resume")
    hk_save(settings, hk_reset, "pomo_reset")
    hk_save(settings, hk_skip,  "pomo_skip")
end

function script_unload()
    obs.timer_remove(clock_tick)
end
