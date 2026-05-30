# OBS Study With Me Manager 🍅🎓

An advanced Pomodoro and "Study With Me" stream manager for OBS Studio, co-created with Agentic AI. 
This Lua script completely automates your study streams so you can focus on working, not on clicking buttons in OBS.

## ✨ Features

- **🪄 1-Click Auto-Setup**: Automatically generates and positions all necessary text and media sources in your current scene. No more manual text source linking!
- **🎬 Auto-Scene Switching**: Automatically switches between your "Focus" scene and your "Break" scene based on the timer.
- **🛑 Stream Auto-Stop**: Going to bed? The script can automatically end your live stream when your final Long Break is over.
- **📊 Daily Goal Tracker**: Keeps track of how many Pomodoro sessions you have completed during your stream.
- **🔊 Reliable Audio Routing**: Uses native OBS Media Sources for alerts (Focus, Break, 1-Min Warning) so they appear in your Audio Mixer. Gives you full control over volume and monitoring!
- **🕒 Local Stream Clock**: Displays your real-time local clock on stream.

## 📦 Installation & Setup

1. Open OBS Studio.
2. Go to **Tools -> Scripts**.
3. Click the **+** button and load `pomorodo.lua`.
4. Select the script in the menu. At the very top of the properties, click the **🪄 Auto-Create Scene Setup (Recommended)** button.
5. Click **Defaults** at the bottom of the script window to auto-link all the newly created sources.

## 🔊 Fixing Audio Monitoring (Important!)

Because this script uses standard OBS Media Sources, you need to tell OBS to output the sound to your headphones!
1. Check your OBS **Sources** list for `Sound: Focus`, `Sound: Short Break`, `Sound: Long Break`, and `Sound: Warning`.
2. **Double-click** them to add your own MP3 sound files.
3. Open your OBS **Audio Mixer**, click the **Gear Icon ⚙️**, and open **Advanced Audio Properties**.
4. Find the `Sound:` sources and change **Audio Monitoring** to **"Monitor and Output"**.

## 💡 Customization
Once you hit the Auto-Setup button, you can freely move, resize, and change the fonts of the generated Text Sources directly in OBS. The script will simply update their text values in the background!
