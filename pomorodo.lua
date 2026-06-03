obs = obslua
global_settings = nil

-- Plugin metadata
SCRIPT_NAME = "OBS Pomodoro Timer"
SCRIPT_VERSION = "1.0.0"
SCRIPT_AUTHOR = "Study With Me"

-- First-run / installer state
first_run = false
has_run_before = false
auto_install_on_first_load = false
control_dock_url = ""
auto_install_mode = false

-- ==== Defaults ====
timer_source_name = "Pomodoro Timer"
status_source_name = ""
focus_minutes = 25
short_break_minutes = 5
long_break_minutes = 15
sessions_before_long = 4
stop_after_long_break = true

-- Prep time
enable_prep = true
prep_minutes = 1
stop_stream_after_long_break = true

clock_source_name = ""
clock_format = "%I:%M %p"

focus_scene_name = ""
short_break_scene_name = ""
long_break_scene_name = ""
prep_scene_name = ""

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
prep_message = "Starting Focus In..."
stopped_message = "Timer Stopped"
paused_message = "Paused"
label_focus = "🧠 FOCUS"
label_short_break = "☕ BREAK"
label_long_break = "🛌 LONG BREAK"
label_prep = "⏱ PREP"

-- End time display
show_end_time = true
end_time_label = "Ends at"
end_time_inline = true
sep_char = "•"
use_24h = true

-- Sounds (transition ding alerts)
enable_sounds = true
sound_focus_file = ""
sound_short_file = ""
sound_long_file = ""
sound_warning_file = ""

-- Background music per scene (looping)
bgm_focus_file = ""
bgm_short_file = ""
bgm_long_file = ""

-- Colors (for timer text source)
color_focus = 0x00FF00
color_short_break = 0xFFFF00
color_long_break = 0xFF0000
color_prep = 0x00CFFF
color_paused = 0xFFFFFF
color_stopped = 0xAAAAAA

-- Auto-start
auto_scene_name = ""

-- State
mode = "stopped"      -- "prep" | "focus" | "short_break" | "long_break" | "paused" | "stopped"
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
hk_toggle = obs.OBS_INVALID_HOTKEY_ID
hk_stop = obs.OBS_INVALID_HOTKEY_ID
hk_focus = obs.OBS_INVALID_HOTKEY_ID
hk_short_break = obs.OBS_INVALID_HOTKEY_ID
hk_long_break = obs.OBS_INVALID_HOTKEY_ID

-- External control hotkey mapping
-- Use these exact names for OBS WebSocket or Stream Deck actions:
--   pomo_start
--   pomo_pause
--   pomo_resume
--   pomo_reset
--   pomo_skip
--   pomo_toggle
--   pomo_stop
--   pomo_focus
--   pomo_short_break
--   pomo_long_break
--
-- Chat bot commands supported (via external trigger logic):
--   !start      -> pomo_start
--   !pause      -> pomo_pause
--   !resume     -> pomo_resume
--   !toggle     -> pomo_toggle
--   !skip       -> pomo_skip
--   !reset      -> pomo_reset
--   !stop       -> pomo_stop
--   !focus      -> pomo_focus
--   !break / !shortbreak -> pomo_short_break
--   !longbreak  -> pomo_long_break

-- Countdown + external control
countdown_seconds = 3
sound_countdown_file = ""
chat_control_enabled = false
chat_control_mod_only = true
panel_source_name = ""
notification_source_name = ""
toast_notifications = true

debug_mode = false
last_text_cache = {}
last_color_cache = {}

notification_message = ""
notification_expire = 0
transition_in_progress = false
segment_changing = false          -- blocks tick from running during a segment transition
pending_scene_switch = nil
scene_switch_delay = 0
frontend_event_callback = nil

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

local function safe_log(level, message)
    if level == obs.LOG_DEBUG and not debug_mode then
        return
    end
    obs.script_log(level, string.format("[%s] %s", SCRIPT_NAME, tostring(message)))
end

local function debug_log(message)
    if debug_mode then
        safe_log(obs.LOG_DEBUG, message)
    end
end

local function safe_call(fn, name)
    local ok, err = pcall(fn)
    if not ok then
        safe_log(obs.LOG_WARNING, string.format("%s error: %s", name, tostring(err)))
    end
end

local function set_text(name, text)
    if not name or name == "" then return end
    text = text or ""
    if last_text_cache[name] == text then
        debug_log(string.format("set_text skip unchanged %s", name))
        return
    end
    local src = get_source(name)
    if src then
        local id = obs.obs_source_get_id(src)
        if id ~= "scene" and id ~= "group" then
            local s = obs.obs_data_create()
            obs.obs_data_set_string(s, "text", text)
            obs.obs_source_update(src, s)
            obs.obs_data_release(s)
            last_text_cache[name] = text
        end
        obs.obs_source_release(src)
    end
end

local function set_color(name, color)
    if not name or name == "" then return end
    color = color or 0xFFFFFF
    if last_color_cache[name] == color then
        debug_log(string.format("set_color skip unchanged %s", name))
        return
    end
    local src = get_source(name)
    if src then
        local id = obs.obs_source_get_id(src)
        if id ~= "scene" and id ~= "group" then
            local s = obs.obs_data_create()
            obs.obs_data_set_int(s, "color", color)
            obs.obs_source_update(src, s)
            obs.obs_data_release(s)
            last_color_cache[name] = color
        end
        obs.obs_source_release(src)
    end
end

-- Scene switch using low-level output channel API.
-- obs_set_output_source(0, src) switches the program output WITHOUT
-- touching the Qt UI thread, so it CANNOT deadlock OBS.
local function do_scene_switch_now(scene_name)
    if not scene_name or scene_name == "" then return end
    local ok, err = pcall(function()
        local src = obs.obs_get_source_by_name(scene_name)
        if not src then
            debug_log("Scene not found: " .. scene_name)
            return
        end
        -- Low-level switch: bypasses frontend/Qt entirely (no freeze)
        obs.obs_set_output_source(0, src)
        obs.obs_source_release(src)
        debug_log("Scene switch done (output channel): " .. scene_name)
    end)
    if not ok then
        -- Fallback silently — timer keeps running even if scene switch fails
        obs.script_log(obs.LOG_WARNING, "[Pomodoro] scene switch skipped: " .. tostring(err))
    end
end

-- Queue a scene switch for 2 ticks in the future (gives OBS UI time to be idle)
local function schedule_scene_switch(name)
    if not name or name == "" then return end
    pending_scene_switch = name
    scene_switch_delay = 2
end

local function switch_to_scene(name)
    schedule_scene_switch(name)
end

local function tick_impl()
    -- While segment is changing, do nothing (prevents time_left going negative)
    if segment_changing then return end

    -- Handle deferred scene switch (runs on its own tick, isolated from timer logic)
    if pending_scene_switch then
        if scene_switch_delay > 0 then
            scene_switch_delay = scene_switch_delay - 1
        else
            local name = pending_scene_switch
            pending_scene_switch = nil
            do_scene_switch_now(name)
        end
        -- Always return here — never mix scene switch ticks with countdown ticks
        return
    end

    if not timer_running or mode == "paused" or mode == "stopped" then return end

    -- Safety: if time_left somehow went deeply negative, recover
    if time_left < -2 then
        obs.script_log(obs.LOG_WARNING, "[Pomodoro] time_left runaway detected, recovering")
        time_left = 1
    end

    if mode == "prep" then
        if time_left <= countdown_seconds + 1 and time_left > 1 and sound_countdown_file ~= "" then
            play_source(sound_countdown_file)
        end
    elseif time_left == 60 and (mode == "short_break" or mode == "long_break") then
        play_source(sound_warning_file)
    end

    time_left = time_left - 1
    if time_left <= 0 then
        end_of_segment()
    else
        push_display()
    end
end

-- tick and clock_tick are GLOBAL so OBS timer always calls the latest version
-- after a script reload, preventing stale-closure nil errors
function tick()
    safe_call(tick_impl, "tick")
end

function clock_tick()
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
    if mode == "prep" then return prep_message
    elseif mode == "focus" then return label_focus
    elseif mode == "short_break" then return label_short_break
    elseif mode == "long_break" then return label_long_break
    elseif mode == "paused" then return paused_message
    else return stopped_message end
end

local function mode_readable(m)
    if m == "prep" then return "Prep" end
    if m == "focus" then return "Focus" end
    if m == "short_break" then return "Short Break" end
    if m == "long_break" then return "Long Break" end
    if m == "paused" then return "Paused" end
    return "Stopped"
end

local function show_notification(message)
    if not toast_notifications then return end
    notification_message = message or ""
    notification_expire = os.time() + 4
    if notification_source_name ~= "" then
        set_text(notification_source_name, notification_message)
    end
end

local function clear_notification()
    notification_message = ""
    notification_expire = 0
    if notification_source_name ~= "" then
        set_text(notification_source_name, "")
    end
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
local function update_bgm_source(name, path)
    local src = obs.obs_get_source_by_name(name)
    if src then
        local id = obs.obs_source_get_id(src)
        if id ~= "scene" and id ~= "group" then
            local current_settings = obs.obs_source_get_settings(src)
            local current_file = obs.obs_data_get_string(current_settings, "local_file")
            obs.obs_data_release(current_settings)
            
            if current_file ~= (path or "") then
                local s = obs.obs_data_create()
                obs.obs_data_set_string(s, "local_file", path or "")
                obs.obs_data_set_bool(s, "is_local_file", true)
                obs.obs_data_set_bool(s, "looping", true)
                obs.obs_data_set_bool(s, "restart_on_activate", true)
                obs.obs_source_update(src, s)
                obs.obs_data_release(s)
            end
        end
        obs.obs_source_release(src)
    end
end

function play_source(path)
    if not enable_sounds or not path or path == "" then return end
    if not file_exists(path) then return end
    
    local src = obs.obs_get_source_by_name("Pomodoro Alert")
    if not src then return end
    
    local id = obs.obs_source_get_id(src)
    if id ~= "scene" and id ~= "group" then
        local current_settings = obs.obs_source_get_settings(src)
        local current_file = obs.obs_data_get_string(current_settings, "local_file")
        obs.obs_data_release(current_settings)
        
        if current_file ~= path then
            local s2 = obs.obs_data_create()
            obs.obs_data_set_string(s2, "local_file", path)
            obs.obs_data_set_bool(s2, "is_local_file", true)
            obs.obs_data_set_bool(s2, "looping", false)
            obs.obs_data_set_bool(s2, "restart_on_activate", false)
            obs.obs_data_set_bool(s2, "close_when_inactive", false)
            obs.obs_source_update(src, s2)
            obs.obs_data_release(s2)
        end
        
        obs.obs_source_media_restart(src)
    end
    obs.obs_source_release(src)
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

function push_display()
    local base
    if mode == "prep" then
        if time_left > countdown_seconds + 1 then
            base = "Starting Focus In..."
        elseif time_left > 1 then
            base = tostring(time_left - 1)
        else
            base = "FOCUS!"
        end
    else
        base = fmt_mmss(time_left)
        if show_mode_label and (mode == "focus" or mode == "short_break" or mode == "long_break") then
            base = current_label() .. " " .. sep_char .. " " .. base
        end
        if mode ~= "stopped" and mode ~= "paused" then base = base .. session_suffix() end
    end

    if show_end_time and mode ~= "stopped" and mode ~= "paused" and mode ~= "prep" then
        local end_txt = string.format("%s %s", end_time_label, fmt_clock(os.time() + time_left))
        if end_time_inline then
            base = base .. " " .. sep_char .. " " .. end_txt
        else
            base = base .. "\n" .. end_txt
        end
    end

    set_text(timer_source_name, base)
    local cmap = { prep=color_prep, focus=color_focus, short_break=color_short_break, long_break=color_long_break, paused=color_paused, stopped=color_stopped }
    set_color(timer_source_name, cmap[mode] or 0xFFFFFF)

    if status_source_name ~= "" then
        local m = { prep=prep_message, focus=focus_message, short_break=short_break_message, long_break=long_break_message, paused=paused_message, stopped=stopped_message }
        set_text(status_source_name, m[mode] or "")
    end

    if goal_source_name ~= "" then
        set_text(goal_source_name, string.format("Goal: %d / %d Pomodoros Completed", total_sessions_completed, daily_goal))
    end
    if subject_source_name ~= "" then
        set_text(subject_source_name, current_subject)
    end

    if panel_source_name ~= "" then
        local next_segment = mode_readable(next_mode_after_current() or "stopped")
        local session_text = "N/A"
        if sessions_before_long > 0 then
            local idx = session_count
            if mode == "focus" then idx = session_count + 1 end
            session_text = string.format("%d of %d", idx, sessions_before_long)
        elseif mode == "focus" then
            session_text = tostring(session_count + 1)
        else
            session_text = tostring(session_count)
        end
        local time_display
        if mode == "prep" then
            if time_left > countdown_seconds + 1 then
                time_display = "Starting Focus In..."
            elseif time_left > 1 then
                time_display = tostring(time_left - 1)
            else
                time_display = "FOCUS!"
            end
        else
            time_display = fmt_mmss(time_left)
        end
        local panel_text = string.format(
            "Current Mode: %s\nTime Remaining: %s\nSession: %s\nCurrent Subject: %s\nNext Segment: %s\nDaily Goal Progress: %d / %d",
            mode_readable(mode), time_display, session_text, current_subject ~= "" and current_subject or "None", next_segment,
            total_sessions_completed, daily_goal
        )
        set_text(panel_source_name, panel_text)
    end

    if notification_source_name ~= "" then
        if notification_message ~= "" and os.time() < notification_expire then
            set_text(notification_source_name, notification_message)
        else
            clear_notification()
        end
    end
end

local function set_mode_impl(new_mode)
    mode = new_mode
    local scene_name = nil
    debug_log(string.format("set_mode %s (timer_running=%s, time_left=%d)", new_mode, tostring(timer_running), time_left))
    if mode == "prep" then
        time_left = math.max(1, countdown_seconds) + 2
        scene_name = prep_scene_name
    elseif mode == "focus" then
        time_left = math.max(1, focus_minutes) * 60
        scene_name = focus_scene_name
    elseif mode == "short_break" then
        time_left = math.max(1, short_break_minutes) * 60
        scene_name = short_break_scene_name
    elseif mode == "long_break" then
        time_left = math.max(1, long_break_minutes) * 60
        scene_name = long_break_scene_name
    end
    if scene_name and scene_name ~= "" then
        schedule_scene_switch(scene_name)
    end
    push_display()
end

local function set_mode(new_mode)
    safe_call(function() set_mode_impl(new_mode) end, "set_mode")
end

local function stop_timer()
    pending_scene_switch = nil
    scene_switch_delay = 0
    transition_in_progress = false
    segment_changing = false
    timer_running = false
end

local function end_of_segment_impl()
    if transition_in_progress then
        obs.script_log(obs.LOG_WARNING, "[Pomodoro] end_of_segment re-entry prevented")
        return
    end
    transition_in_progress = true
    segment_changing = true   -- BLOCK tick from running during transition
    obs.script_log(obs.LOG_INFO, string.format("[Pomodoro] end_of_segment current=%s timer_running=%s time_left=%d", mode, tostring(timer_running), time_left))
    if mode == "prep" then
        play_source(sound_focus_file)
        show_notification("Focus started")
        set_mode("focus")
    elseif mode == "focus" then
        session_count = session_count + 1
        total_sessions_completed = total_sessions_completed + 1
        if sessions_before_long > 0 and (session_count % sessions_before_long == 0) then
            play_source(sound_long_file)
            show_notification("Long break started")
            set_mode("long_break")
        else
            play_source(sound_short_file)
            show_notification("Short break started")
            set_mode("short_break")
        end
    elseif mode == "long_break" then
        if stop_after_long_break then
            play_source(sound_focus_file)
            if stop_stream_after_long_break then
                obs.obs_frontend_streaming_stop()
            end
            stop_timer()
            mode = "stopped"
            time_left = 0
            show_notification("Session completed")
            push_display()
        else
            play_source(sound_focus_file)
            show_notification("Focus started")
            set_mode("focus")
        end
    else
        play_source(sound_focus_file)
        show_notification("Focus started")
        set_mode("focus")
    end
    transition_in_progress = false
    segment_changing = false  -- Re-allow tick after transition is fully complete
end

function end_of_segment()
    local ok, err = pcall(end_of_segment_impl)
    if not ok then
        obs.script_log(obs.LOG_WARNING, string.format("[Pomodoro] end_of_segment error: %s", tostring(err)))
    end
    -- Always clear both flags so timer never stays permanently blocked
    transition_in_progress = false
    segment_changing = false
end

-- duplicate tick removed; using tick wrapper defined earlier

-- ==== Controls ====
function start_pressed(pressed)
    if not pressed then return end
    if timer_running then
        debug_log("start_pressed ignored because timer already running")
        return
    end
    stop_timer()
    timer_running = true
    session_count = 0
    if enable_prep and countdown_seconds > 0 and prep_scene_name and prep_scene_name ~= "" then
        set_mode("prep")
    else
        set_mode("focus")
    end
end

function pause_pressed(pressed)
    if pressed and timer_running and (mode=="prep" or mode=="focus" or mode=="short_break" or mode=="long_break") then
        prev_mode = mode
        mode = "paused"
        push_display()
    end
end

function resume_pressed(pressed)
    if pressed and mode=="paused" then
        mode = prev_mode or "focus"
        push_display()
    end
end

function stop_pressed(pressed)
    if pressed then
        stop_timer()
        mode = "stopped"
        time_left = 0
        push_display()
    end
end

function reset_pressed(pressed)
    if pressed then
        stop_timer()
        mode = "stopped"
        session_count = 0
        time_left = 0
        push_display()
    end
end

function skip_pressed(pressed)
    if pressed and timer_running then
        end_of_segment()
        push_display()
    end
end

function toggle_pressed(pressed)
    if not pressed then return end
    if mode == "stopped" then
        start_pressed(true)
    elseif mode == "paused" then
        resume_pressed(true)
    elseif timer_running then
        pause_pressed(true)
    else
        start_pressed(true)
    end
end

function focus_pressed(pressed)
    if pressed then
        if not timer_running then
            stop_timer()
            timer_running = true
        end
        set_mode("focus")
    end
end

function short_break_pressed(pressed)
    if pressed then
        if not timer_running then
            stop_timer()
            timer_running = true
        end
        set_mode("short_break")
    end
end

function long_break_pressed(pressed)
    if pressed then
        if not timer_running then
            stop_timer()
            timer_running = true
        end
        set_mode("long_break")
    end
end

function handle_external_command(command, isModerator)
    if not chat_control_enabled then return end
    if chat_control_mod_only and not isModerator then return end
    local cmd = command:lower():gsub("^!", "")
    if cmd == "start" then start_pressed(true)
    elseif cmd == "pause" then pause_pressed(true)
    elseif cmd == "resume" then resume_pressed(true)
    elseif cmd == "toggle" then toggle_pressed(true)
    elseif cmd == "skip" then skip_pressed(true)
    elseif cmd == "reset" then reset_pressed(true)
    elseif cmd == "stop" then stop_pressed(true)
    elseif cmd == "focus" then focus_pressed(true)
    elseif cmd == "break" or cmd == "shortbreak" then short_break_pressed(true)
    elseif cmd == "longbreak" then long_break_pressed(true)
    elseif cmd == "subject" then -- subject commands should be handled externally by setting current_subject via script property
    end
end

function reset_goal_pressed(pressed)
    if pressed then
        total_sessions_completed = 0
        push_display()
    end
end

-- ==== OBS UI ====
local function make_audio_source(name, looping, restart_on_activate)
    local src = obs.obs_get_source_by_name(name)
    if not src then
        local s = obs.obs_data_create()
        obs.obs_data_set_bool(s, "is_local_file", true)
        obs.obs_data_set_bool(s, "looping", looping)
        obs.obs_data_set_bool(s, "close_when_inactive", false)
        obs.obs_data_set_bool(s, "restart_on_activate", restart_on_activate)
        src = obs.obs_source_create("ffmpeg_source", name, s, nil)
        obs.obs_data_release(s)
    end
    -- Auto-enable monitoring so user can hear it immediately
    if src then
        obs.obs_source_set_monitoring_type(src, obs.OBS_MONITORING_TYPE_MONITOR_AND_OUTPUT)
    end
    return src
end

local function add_source_to_scene_offscreen(scene, src)
    if not scene or not src then return end
    local name = obs.obs_source_get_name(src)
    local found = obs.obs_scene_find_source(scene, name)
    if not found then
        local item = obs.obs_scene_add(scene, src)
        local pos = obs.vec2()
        pos.x = -1000
        pos.y = -1000
        obs.obs_sceneitem_set_pos(item, pos)
    end
end

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

function auto_setup_pressed(props, prop)
    local scene_defs = {
        {name="Study With Me - Prep",         bgm="Pomodoro BGM - Prep"},
        {name="Study With Me - Focus",         bgm="Pomodoro BGM - Focus"},
        {name="Study With Me - Short Break",   bgm="Pomodoro BGM - Short Break"},
        {name="Study With Me - Long Break",    bgm="Pomodoro BGM - Long Break"}
    }
    local scene_objects = {}

    -- Create or fetch scenes
    for _, def in ipairs(scene_defs) do
        local source = obs.obs_get_source_by_name(def.name)
        if source then
            def.scene = obs.obs_scene_from_source(source)
            def.owned_source = source
            def.owned_scene = true
        else
            def.scene = obs.obs_scene_create(def.name)
            def.owned_new = true
            def.owned_scene = true
        end
        table.insert(scene_objects, def)
    end

    -- Text sources added to ALL scenes
    local texts = {
        {name="Pomodoro Timer",   default="25:00",        y=50},
        {name="Pomodoro Status",  default="Focus Time!",  y=150},
        {name="Pomodoro Clock",   default="12:00 PM",     y=250},
        {name="Pomodoro Goal",    default="Goal: 0 / 8",  y=350},
        {name="Pomodoro Subject", default="Studying...",  y=450},
        {name="Pomodoro Panel",   default="Current Mode: Stopped\nTime Remaining: 00:00\nSession: 0 of 0\nCurrent Subject: None\nNext Segment: None\nDaily Goal Progress: 0 / 8", y=550},
        {name="Pomodoro Toast",   default="",            y=650}
    }
    for _, t in ipairs(texts) do
        local src = create_text_source(t.name, t.default)
        if src then
            for _, def in ipairs(scene_objects) do
                local found = obs.obs_scene_find_source(def.scene, t.name)
                if not found then
                    local item = obs.obs_scene_add(def.scene, src)
                    local pos = obs.vec2()
                    pos.x = 50; pos.y = t.y
                    obs.obs_sceneitem_set_pos(item, pos)
                end
            end
            obs.obs_source_release(src)
        end
    end

    -- Per-scene looping BGM sources (each unique to its scene)
    for _, def in ipairs(scene_objects) do
        local bgm = make_audio_source(def.bgm, true, true)
        if bgm then
            add_source_to_scene_offscreen(def.scene, bgm)
            obs.obs_source_release(bgm)
        end
    end

    -- Shared alert source (non-looping) added to ALL scenes
    local alert = make_audio_source("Pomodoro Alert", false, false)
    if alert then
        for _, def in ipairs(scene_objects) do
            add_source_to_scene_offscreen(def.scene, alert)
        end
        obs.obs_source_release(alert)
    end

    -- Cleanup references
    for _, def in ipairs(scene_objects) do
        if def.owned_source then obs.obs_source_release(def.owned_source) end
        if def.owned_scene  then obs.obs_scene_release(def.scene) end
    end

    -- Auto-link all names in settings
    if global_settings then
        obs.obs_data_set_string(global_settings, "prep_scene_name",        "Study With Me - Prep")
        obs.obs_data_set_string(global_settings, "focus_scene_name",       "Study With Me - Focus")
        obs.obs_data_set_string(global_settings, "short_break_scene_name", "Study With Me - Short Break")
        obs.obs_data_set_string(global_settings, "long_break_scene_name",  "Study With Me - Long Break")
        obs.obs_data_set_string(global_settings, "timer_source_name",   "Pomodoro Timer")
        obs.obs_data_set_string(global_settings, "status_source_name",  "Pomodoro Status")
        obs.obs_data_set_string(global_settings, "clock_source_name",   "Pomodoro Clock")
        obs.obs_data_set_string(global_settings, "goal_source_name",    "Pomodoro Goal")
        obs.obs_data_set_string(global_settings, "subject_source_name", "Pomodoro Subject")
        obs.obs_data_set_string(global_settings, "panel_source_name", "Pomodoro Panel")
        obs.obs_data_set_string(global_settings, "notification_source_name", "Pomodoro Toast")
        script_update(global_settings)
    end

    return true
end

function script_defaults(settings)
    obs.obs_data_set_default_bool(settings, "stop_after_long_break", true)
    obs.obs_data_set_default_bool(settings, "stop_stream_after_long_break", true)
    obs.obs_data_set_default_string(settings, "clock_format", "%I:%M %p")
    obs.obs_data_set_default_string(settings, "current_subject", "Studying...")

    obs.obs_data_set_default_bool(settings, "enable_prep", true)
    obs.obs_data_set_default_int(settings, "prep_minutes", 1)
    obs.obs_data_set_default_int(settings, "countdown_seconds", 3)
    obs.obs_data_set_default_string(settings, "countdown_sound_file", "")
    obs.obs_data_set_default_string(settings, "prep_scene_name", "Study With Me - Prep")
    obs.obs_data_set_default_int(settings, "color_prep", 0x00CFFF)
    obs.obs_data_set_default_bool(settings, "toast_notifications", true)
    obs.obs_data_set_default_bool(settings, "chat_control_enabled", false)
    obs.obs_data_set_default_bool(settings, "chat_control_mod_only", true)
    obs.obs_data_set_default_bool(settings, "debug_mode", false)
    obs.obs_data_set_default_bool(settings, "auto_install_on_first_load", false)
    obs.obs_data_set_default_bool(settings, "has_run_before", false)
    obs.obs_data_set_default_string(settings, "control_dock_url", "")
    obs.obs_data_set_default_string(settings, "panel_source_name", "Pomodoro Panel")
    obs.obs_data_set_default_string(settings, "notification_source_name", "Pomodoro Toast")
    
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
    
    local p_panel = obs.obs_properties_add_list(p, "panel_source_name", "Status Panel Source", obs.OBS_COMBO_TYPE_EDITABLE, obs.OBS_COMBO_FORMAT_STRING)
    populate_text_sources(p_panel)
    
    local p_notify = obs.obs_properties_add_list(p, "notification_source_name", "Toast Notification Source", obs.OBS_COMBO_TYPE_EDITABLE, obs.OBS_COMBO_FORMAT_STRING)
    populate_text_sources(p_notify)
    
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

    obs.obs_properties_add_bool(p, "enable_prep", "Enable Prep Time (before each focus session)")
    obs.obs_properties_add_int(p, "prep_minutes", "Prep Time (min)", 1, 30, 1)
    obs.obs_properties_add_int(p, "countdown_seconds", "Countdown Seconds", 1, 10, 1)
    obs.obs_properties_add_path(p, "countdown_sound_file", "Countdown Sound (optional)", obs.OBS_PATH_FILE, "*.mp3;*.wav", nil)
    local p_pscene = obs.obs_properties_add_list(p, "prep_scene_name", "Prep Scene (Auto-switch)", obs.OBS_COMBO_TYPE_EDITABLE, obs.OBS_COMBO_FORMAT_STRING)
    populate_scenes(p_pscene)

    obs.obs_properties_add_bool(p, "toast_notifications", "Enable Toast Notifications")
    obs.obs_properties_add_bool(p, "chat_control_enabled", "Enable Chat Control Integration")
    obs.obs_properties_add_bool(p, "chat_control_mod_only", "Chat Control Moderators Only")
    obs.obs_properties_add_bool(p, "debug_mode", "Enable Debug Logging")
    obs.obs_properties_add_bool(p, "auto_install_on_first_load", "Run Install on First Load")
    obs.obs_properties_add_text(p, "control_dock_url", "Control Dock URL", obs.OBS_TEXT_DEFAULT)

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

    obs.obs_properties_add_bool(p, "enable_sounds", "Enable Transition Sounds (ding on segment change)")
    obs.obs_properties_add_path(p, "sound_focus_file",   "Ding: Start Focus",    obs.OBS_PATH_FILE, "*.mp3;*.wav", nil)
    obs.obs_properties_add_path(p, "sound_short_file",   "Ding: Short Break",    obs.OBS_PATH_FILE, "*.mp3;*.wav", nil)
    obs.obs_properties_add_path(p, "sound_long_file",    "Ding: Long Break",     obs.OBS_PATH_FILE, "*.mp3;*.wav", nil)
    obs.obs_properties_add_path(p, "sound_warning_file", "Ding: 1-Min Warning",  obs.OBS_PATH_FILE, "*.mp3;*.wav", nil)

    obs.obs_properties_add_path(p, "bgm_focus_file", "BGM: Focus (looping)",       obs.OBS_PATH_FILE, "*.mp3;*.wav", nil)
    obs.obs_properties_add_path(p, "bgm_short_file", "BGM: Short Break (looping)", obs.OBS_PATH_FILE, "*.mp3;*.wav", nil)
    obs.obs_properties_add_path(p, "bgm_long_file",  "BGM: Long Break (looping)",  obs.OBS_PATH_FILE, "*.mp3;*.wav", nil)

    obs.obs_properties_add_color(p, "color_prep", "Color: Prep")
    obs.obs_properties_add_color(p, "color_focus", "Color: Focus")
    obs.obs_properties_add_color(p, "color_short_break", "Color: Short Break")
    obs.obs_properties_add_color(p, "color_long_break", "Color: Long Break")
    obs.obs_properties_add_color(p, "color_paused", "Color: Paused")
    obs.obs_properties_add_color(p, "color_stopped", "Color: Stopped")

    local p_auto = obs.obs_properties_add_list(p, "auto_scene_name", "Auto-start on Scene", obs.OBS_COMBO_TYPE_EDITABLE, obs.OBS_COMBO_FORMAT_STRING)
    populate_scenes(p_auto)

    obs.obs_properties_add_button(p, "btn_start", "▶ Start", function(props, prop) start_pressed(true); return true end)
    obs.obs_properties_add_button(p, "btn_pause", "⏸ Pause", function(props, prop) pause_pressed(true); return true end)
    obs.obs_properties_add_button(p, "btn_resume", "⏵ Resume", function(props, prop) resume_pressed(true); return true end)
    obs.obs_properties_add_button(p, "btn_reset", "⟲ Reset", function(props, prop) reset_pressed(true); return true end)
    obs.obs_properties_add_button(p, "btn_skip",  "⤼ Skip",  function(props, prop) skip_pressed(true); return true end)
    obs.obs_properties_add_button(p, "btn_reset_goal", "⟲ Reset Daily Goal", function(props, prop) reset_goal_pressed(true); return true end)
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

    enable_prep = obs.obs_data_get_bool(s, "enable_prep")
    prep_minutes = math.max(1, obs.obs_data_get_int(s, "prep_minutes"))
    countdown_seconds = math.max(1, obs.obs_data_get_int(s, "countdown_seconds"))
    sound_countdown_file = obs.obs_data_get_string(s, "countdown_sound_file")
    prep_scene_name = obs.obs_data_get_string(s, "prep_scene_name")
    if enable_prep and (not prep_scene_name or prep_scene_name == "") then
        prep_scene_name = "Study With Me - Prep"
    end

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
    sound_countdown_file = obs.obs_data_get_string(s, "countdown_sound_file")
    toast_notifications = obs.obs_data_get_bool(s, "toast_notifications")
    debug_mode = obs.obs_data_get_bool(s, "debug_mode")
    auto_install_on_first_load = obs.obs_data_get_bool(s, "auto_install_on_first_load")
    control_dock_url = obs.obs_data_get_string(s, "control_dock_url")
    has_run_before = obs.obs_data_get_bool(s, "has_run_before")
    panel_source_name = obs.obs_data_get_string(s, "panel_source_name")
    notification_source_name = obs.obs_data_get_string(s, "notification_source_name")
    chat_control_enabled = obs.obs_data_get_bool(s, "chat_control_enabled")
    chat_control_mod_only = obs.obs_data_get_bool(s, "chat_control_mod_only")

    bgm_focus_file = obs.obs_data_get_string(s, "bgm_focus_file")
    bgm_short_file = obs.obs_data_get_string(s, "bgm_short_file")
    bgm_long_file  = obs.obs_data_get_string(s, "bgm_long_file")
    update_bgm_source("Pomodoro BGM - Focus",       bgm_focus_file)
    update_bgm_source("Pomodoro BGM - Short Break", bgm_short_file)
    update_bgm_source("Pomodoro BGM - Long Break",  bgm_long_file)

    if not has_run_before then
        first_run = true
        safe_log(obs.LOG_INFO, "First run detected")
        obs.obs_data_set_bool(s, "has_run_before", true)
        has_run_before = true
        if auto_install_on_first_load then
            safe_log(obs.LOG_INFO, "Auto-install on first load is enabled")
            auto_install_mode = true
            auto_setup_pressed(nil, nil)
            auto_install_mode = false
        end
    end

    color_prep    = obs.obs_data_get_int(s, "color_prep")
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
    hk_toggle = obs.obs_hotkey_register_frontend("pomo_toggle", "Pomodoro Toggle", function(pressed) if pressed then toggle_pressed(true) end end)
    hk_stop = obs.obs_hotkey_register_frontend("pomo_stop", "Pomodoro Stop", function(pressed) if pressed then stop_pressed(true) end end)
    hk_focus = obs.obs_hotkey_register_frontend("pomo_focus", "Pomodoro Focus", function(pressed) if pressed then focus_pressed(true) end end)
    hk_short_break = obs.obs_hotkey_register_frontend("pomo_short_break", "Pomodoro Short Break", function(pressed) if pressed then short_break_pressed(true) end end)
    hk_long_break = obs.obs_hotkey_register_frontend("pomo_long_break", "Pomodoro Long Break", function(pressed) if pressed then long_break_pressed(true) end end)

    hk_load(settings, hk_start, "pomo_start")
    hk_load(settings, hk_pause, "pomo_pause")
    hk_load(settings, hk_resume,"pomo_resume")
    hk_load(settings, hk_reset, "pomo_reset")
    hk_load(settings, hk_skip,  "pomo_skip")
    hk_load(settings, hk_toggle, "pomo_toggle")
    hk_load(settings, hk_stop, "pomo_stop")
    hk_load(settings, hk_focus, "pomo_focus")
    hk_load(settings, hk_short_break, "pomo_short_break")
    hk_load(settings, hk_long_break, "pomo_long_break")

    obs.timer_add(clock_tick, 1000)
    obs.timer_add(tick, 1000)
end

function script_save(settings)
    hk_save(settings, hk_start, "pomo_start")
    hk_save(settings, hk_pause, "pomo_pause")
    hk_save(settings, hk_resume,"pomo_resume")
    hk_save(settings, hk_reset, "pomo_reset")
    hk_save(settings, hk_skip,  "pomo_skip")
    hk_save(settings, hk_toggle, "pomo_toggle")
    hk_save(settings, hk_stop, "pomo_stop")
    hk_save(settings, hk_focus, "pomo_focus")
    hk_save(settings, hk_short_break, "pomo_short_break")
    hk_save(settings, hk_long_break, "pomo_long_break")
end

function script_description()
    return string.format("%s v%s by %s\nA package-style Pomodoro timer tool for OBS with auto-install helper and browser dock control.", SCRIPT_NAME, SCRIPT_VERSION, SCRIPT_AUTHOR)
end

function script_unload()
    obs.timer_remove(clock_tick)
    obs.timer_remove(tick)
    stop_timer()
end
