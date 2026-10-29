# -*- coding: utf-8 -*-
"""The text of the volunteer guide, kept apart from the typesetting.

Edit this file to change what the guide says; build-guide.py decides how it
looks. Every entry in SECTIONS becomes one page.

Markup inside step and paragraph text:
    <b>...</b>   bold - used for anything the reader clicks or types
    ARROW        replaced with the menu arrow, so paths read File ARROW Open
"""

TITLE = "Streaming to YouTube and Facebook"
SUBTITLE = ("OBS Studio + Aitum Multistream setup and go-live guide "
            "for A/V volunteers")
RUNNING_HEAD = "YouTube + Facebook streaming guide"
COVER_NOTE = "Written for macOS and OBS Studio 33.0 or newer."
CONTENTS_HEADING = "What's inside"

# Each section is a dict:
#   title     (str)            the heading, without its number
#   intro     (str)            one line under the heading
#   warning   (heading, lines) a box above the steps, for anything that has to
#                              happen before the steps do
#   steps     [str, ...]       numbered steps
#   table     (headers, rows)  a plain table instead of, or after, the steps
#   callout   (heading, body)  the box at the foot of the page
SECTIONS = [
    {
        "title": "Before you start",
        "intro": "Gather these once. After setup, going live takes only a few clicks.",
        "table": (
            ["You need", "Details"],
            [
                ["A Mac",
                 "Apple silicon recommended. Plug it in to power for the whole service."],
                ["OBS Studio 33.0 or newer",
                 "Older versions (32.x) crash on macOS 27 the moment you go live."],
                ["Aitum Multistream plugin",
                 "Sends the same stream to Facebook while OBS sends to YouTube."],
                ["A USB microphone",
                 "For example a Yeti X. Plug it in before opening OBS."],
                ["YouTube access",
                 "Permission to go live on the channel in YouTube Studio."],
                ["Facebook access",
                 "Permission to go live on the profile or Page you are streaming to."],
                ["Internet upload speed",
                 "At least 15 Mbps upload. Use a wired connection if you can."],
            ],
        ),
        "callout": (
            "Check your upload speed",
            "Open <b>fast.com</b> in your browser and click <b>Show more info</b>. The "
            "<b>Upload</b> number should be 15 Mbps or higher, because two streams at "
            "6 Mbps each need about 12 Mbps plus headroom.",
        ),
    },
    {
        "title": "Update OBS Studio",
        "intro": ("Do this before installing anything else. The Aitum installer will "
                  "refuse to run on older OBS versions."),
        "steps": [
            "Open OBS Studio. In the menu bar click <b>OBS Studio</b> ARROW "
            "<b>About OBS Studio</b> and note the version number.",
            "If it is lower than 33.0, click <b>OBS Studio</b> ARROW "
            "<b>Check for Updates</b>.",
            "When the update window appears, click <b>Install Update</b> and let OBS "
            "restart.",
            "If no update appears, download the latest Mac version from "
            "<b>obsproject.com/download</b> and drag it into Applications, replacing "
            "the old one.",
            "Open OBS again and confirm the version now says <b>33.0 or higher</b>.",
        ],
        "callout": (
            "If a plugin warning appears after updating",
            "OBS may say it could not load all third-party plugins. Click "
            "<b>Open Plugin Manager</b> to see which one. Anything that shows an "
            "Error and is not <b>Aitum Multistream</b> can be turned off with "
            "<b>Save</b> - streaming does not need it. If <b>Aitum Multistream</b> "
            "is the one erroring, run the installer again.",
        ),
    },
    {
        "title": "Install Aitum Multistream",
        "intro": ("Aitum adds a second output so Facebook receives the same picture and "
                  "sound as YouTube."),
        "steps": [
            "Quit OBS completely (<b>OBS Studio</b> ARROW <b>Quit</b>).",
            "Open the installer you were given and double-click it.",
            "The installer checks your OBS version first. If it says OBS is too old, or "
            "that you have a test version of OBS, it stops and offers to open the OBS "
            "download page. Go back to section 2, then run the installer again.",
            "Follow the prompts and click <b>Install</b>. No Mac password is needed. If "
            "the installer asks you to quit OBS, click <b>Quit OBS</b>.",
            "Open OBS. You should see a panel called <b>Aitum Multistream</b>. If you "
            "don't, click <b>Docks</b> in the menu bar and turn it on.",
        ],
        "callout": (
            "Good to know",
            "The installer only adds the plugin. Your scenes, sources, and stream keys "
            "stay exactly as they were.",
        ),
    },
    {
        "title": "Set up your microphone",
        "intro": ("Both YouTube and Facebook get their sound from the same OBS "
                  "microphone setting."),
        "steps": [
            "Open <b>System Settings</b> ARROW <b>Privacy &amp; Security</b> ARROW "
            "<b>Microphone</b> and make sure OBS is switched on. If you had to turn it "
            "on, quit and reopen OBS.",
            "In OBS open <b>Settings</b> ARROW <b>Audio</b>. Set <b>Sample Rate</b> to "
            "<b>48 kHz</b> and <b>Channels</b> to <b>Stereo</b>.",
            "Set <b>Mic/Auxiliary Audio</b> to your microphone (for example Yeti X). If "
            "it says Device not connected, plug the mic in and choose it again.",
            "Click <b>OK</b>. Speak normally and watch the <b>Mic/Aux</b> bar in the "
            "Audio Mixer at the bottom of OBS.",
            "Adjust the microphone's own gain knob so normal speech peaks around "
            "<b>-12 to -6 dB</b> (the yellow area). It should never sit in the red.",
        ],
        "callout": (
            "Headphone icon in the mixer",
            "A green headphone icon under Mic/Aux means OBS is playing your voice back "
            "to the Mac. Click it so it turns grey. This does not change what viewers "
            "hear, and it prevents echo.",
        ),
    },
    {
        "title": "Video and encoder settings",
        "intro": ("These settings are shared by YouTube and Facebook. Facebook is strict "
                  "about the keyframe setting."),
        "steps": [
            "Open <b>Settings</b> ARROW <b>Output</b> and set <b>Output Mode</b> (top of "
            "the page) to <b>Advanced</b>.",
            "Click the <b>Streaming</b> tab. Set <b>Rate Control</b> to <b>CBR</b>.",
            "Set <b>Bitrate</b> to <b>6000 Kbps</b>.",
            "Set <b>Keyframe Interval</b> to <b>2 s</b>. Facebook rejects or degrades "
            "other values.",
            "Make sure <b>Audio Track</b> is <b>1</b>.",
            "Open <b>Settings</b> ARROW <b>Video</b>. Set <b>Output (Scaled) "
            "Resolution</b> to <b>1920x1080</b> (or 1280x720 on slow internet) and "
            "<b>FPS</b> to <b>30</b>. Click <b>OK</b>.",
        ],
        "table": (
            ["Setting", "Value"],
            [
                ["Output Mode", "Advanced"],
                ["Rate Control", "CBR"],
                ["Bitrate", "6000 Kbps"],
                ["Keyframe Interval", "2 s"],
                ["Audio Track", "1"],
                ["Resolution / FPS", "1920x1080 at 30"],
                ["Audio sample rate", "48 kHz"],
            ],
        ),
    },
    {
        "title": "Connect YouTube",
        "intro": "YouTube is the main OBS stream. You only need to do this once per computer.",
        "warning": (
            "Never use Connect Account",
            [
                "In <b>Settings</b> ARROW <b>Stream</b>, OBS offers <b>Connect "
                "Account</b> and <b>Use Stream Key</b>. Always choose "
                "<b>Use Stream Key</b>.",
                "Being signed in to YouTube twice is what freezes OBS 33 on "
                "macOS: a <b>Connect Account</b> sign-in on top of a stream key. The "
                "window stops responding and the only way out is to force quit, "
                "which loses anything you have not saved.",
                "One sign-in, and let it be the stream key. Use <b>Stream Key</b> "
                "only.",
            ],
        ),
        "steps": [
            "In your browser open <b>studio.youtube.com</b> and click <b>Create</b> "
            "ARROW <b>Go live</b>. Choose <b>Now</b> and <b>Streaming software</b>.",
            {
                "text": "Open the <b>Stream</b> tab. At the top of the video preview "
                        "click the <b>Key</b> box and choose <b>Default stream key "
                        "(RTMP, Variable)</b>. Leave the other two alone.",
                "image": "yt-key-dropdown-annotated.png",
                "caption": "YouTube Studio, October 2026 \u2014 layout may change",
            },
            {
                "text": "Click the copy icon beside that box to copy the key. Do not "
                        "click the circular arrow next to it - that resets the key and "
                        "stops anyone already streaming with it.",
                "image": "yt-key-row-annotated.png",
                "caption": "YouTube Studio, October 2026 \u2014 layout may change",
            },
            "In OBS open <b>Settings</b> ARROW <b>Stream</b>. Set <b>Service</b> to "
            "<b>YouTube - RTMPS</b>.",
            "Click <b>Use Stream Key</b>. <b>Do not use Connect Account</b> as "
            "well - signing in to YouTube twice freezes OBS 33 on macOS.",
            "Paste the key into <b>Stream Key</b>, choose <b>Primary YouTube ingest "
            "server</b>, and click <b>OK</b>.",
            "In YouTube Studio turn <b>Dual stream</b> off unless you have been asked "
            "to use it.",
        ],
        "callout": (
            "Title and visibility",
            "Before each broadcast, click <b>Edit</b> on the stream details card to set "
            "the title. Use <b>Private</b> for tests and <b>Public</b> for real "
            "services. Answer the made-for-kids, paid promotion and AI questions with "
            "<b>No</b>.",
        ),
    },
    {
        "title": "Connect Facebook",
        "intro": "Facebook runs through Aitum Multistream as a second output.",
        "steps": [
            "Open <b>facebook.com/live/producer</b>. Under <b>Choose where to post</b>, "
            "pick the profile or Page you were told to use.",
            "Click <b>Set up live video</b>, then choose <b>Streaming software</b>. "
            "Click <b>Don't Allow</b> if your browser asks to use the camera.",
            "Turn on <b>Use persistent stream key</b> if you see it, then click "
            "<b>Copy</b> next to the stream key.",
            "In OBS, open the <b>Aitum Multistream</b> dock, click the gear icon, then "
            "<b>Main Canvas</b> ARROW <b>Add Output</b> ARROW <b>Facebook</b>.",
            "Leave the server as it is, paste the key into <b>Facebook Stream Key</b>, "
            "and click <b>Create Output</b>.",
            "Expand <b>Facebook Output</b>, tick <b>Advanced Settings</b>, and set "
            "<b>Video Encoder</b> to <b>Main Encoder</b>.",
            "On the <b>Audio Settings</b> tab set <b>Audio Track</b> to <b>Track 1</b>, "
            "<b>Bitrate</b> to <b>128 or 160</b>, and untick <b>Allow HE-AAC</b>. Click "
            "<b>OK</b>.",
        ],
        "callout": (
            "Don't click Add Facebook in the dock",
            "Once your output exists, the dock shows a <b>Facebook Output</b> row with "
            "its own <b>Go Live</b> button. The large <b>Add Facebook</b> button creates "
            "a second, duplicate output.",
        ),
    },
    {
        "title": "Run a private test",
        "intro": ("Test after any change and at least once before your first real "
                  "service. Nobody else can see it."),
        "steps": [
            "YouTube Studio: set the title to <b>TEST - do not watch</b> and visibility "
            "to <b>Private</b>.",
            "Facebook Live Producer: set the audience to <b>Only me</b>.",
            "In the Aitum dock click <b>Go Live</b> on YouTube, then <b>Go Live</b> on "
            "<b>Facebook Output</b>.",
            "Wait 10 to 20 seconds until both browser pages show your video.",
            "Click <b>Go Live</b> in YouTube Studio and the blue <b>Go live</b> button "
            "in Facebook.",
            "On your phone (with the Mac muted), open both streams, tap the speaker icon "
            "to unmute, and check sound, picture, and the lower third.",
            "End both broadcasts and stop both outputs in the Aitum dock.",
        ],
        "callout": (
            "Previews start muted",
            "Both YouTube and Facebook previews start with sound off. If you hear "
            "nothing, tap the speaker icon on the player before assuming the audio is "
            "broken.",
        ),
    },
    {
        "title": "Going live for Sabbath",
        "intro": "Use this checklist every week. Start 15 minutes before the service.",
        "steps": [
            "Plug in the Mac, the microphone and the camera. Open OBS.",
            "Speak into the microphone and confirm the <b>Mic/Aux</b> bar moves.",
            "YouTube Studio: <b>Create</b> ARROW <b>Go live</b>. Set the title for "
            "today, visibility <b>Public</b>.",
            "Facebook Live Producer: <b>Set up live video</b> ARROW <b>Streaming "
            "software</b>. Check the audience and add a title.",
            "In the Aitum dock click <b>Go Live</b> on YouTube, then <b>Go Live</b> on "
            "<b>Facebook Output</b>.",
            "When both previews appear, click <b>Go Live</b> in YouTube Studio and "
            "<b>Go live</b> in Facebook.",
            "Confirm YouTube shows <b>LIVE</b> and Facebook shows <b>You're now "
            "live!</b>",
        ],
        "callout": (
            "Order matters",
            "The Aitum buttons send the video. The platform buttons publish it. You need "
            "both, in that order.",
        ),
    },
    {
        "title": "Ending the stream",
        "intro": "End on the platforms first so viewers see a clean finish, then stop OBS.",
        "steps": [
            "YouTube Studio: click <b>End Stream</b> at the top right.",
            "Facebook: click <b>End live video</b> at the bottom left.",
            "In the Aitum dock click <b>Go Live</b> again on each row to stop sending "
            "(the rows go dark).",
            "Wait for OBS to show the live timer stopped before closing it.",
            "Leave the browser tabs alone for a minute while both sites save the "
            "recording.",
        ],
    },
    {
        "title": "Watching stream health",
        "intro": "Check these every 10 to 15 minutes during the service.",
        "table": (
            ["Where", "What to look for", "Good"],
            [
                ["OBS status bar (bottom)", "Dropped frames, bitrate, coloured square",
                 "0 dropped, about 6000 kbps, green"],
                ["OBS ARROW View ARROW Stats", "Dropped frames and CPU usage",
                 "0% dropped, CPU under 60%"],
                ["Aitum dock", "Each output row status",
                 "Both rows active, no red or reconnecting"],
                ["YouTube Studio ARROW Stream health", "Health label and warnings",
                 "Excellent or Good, no warnings"],
                ["Facebook ARROW Dashboard / Event logs", "Disconnects and errors",
                 "No disconnects listed"],
                ["Your phone", "Sound, lip sync, picture",
                 "Clear on both, 10 to 20 s behind"],
            ],
        ),
    },
    {
        "title": "Troubleshooting",
        "intro": "Find the symptom, then try the fix from top to bottom.",
        "table": (
            ["Problem", "Fix"],
            [
                ["OBS closes the moment you go live",
                 "OBS is too old for this macOS. Update to 33.0 or newer (section 2)."],
                ["OBS freezes when connecting YouTube",
                 "You signed in to YouTube twice - Connect Account on top of a stream "
                 "key. Force quit OBS, reopen it, and use Use Stream Key only "
                 "(section 6)."],
                ["The installer says you have a test version of OBS",
                 "You are on a beta or release candidate build. Install the regular "
                 "release of OBS 33.0 or newer, then run the installer again."],
                ["YouTube says No data",
                 "You haven't clicked Go Live on the YouTube row in the Aitum dock, or "
                 "the stream key is wrong. Copy it again."],
                ["Facebook says Connect streaming software",
                 "Click Go Live on the Facebook Output row. If it still fails, re-copy "
                 "the Facebook key into Output Settings with no extra spaces."],
                ["YouTube stuck on Preparing",
                 "Refresh the YouTube Studio page. If still stuck, click Create ARROW "
                 "Go live to open a fresh Control Room."],
                ["No sound on the streams",
                 "Check the Mic/Aux meter moves, the mic is not muted (flashing red "
                 "ring on Yeti X), and OBS has microphone permission in System "
                 "Settings."],
                ["You hear nothing on the Mac",
                 "The player is muted or your Mac output is set to a device with "
                 "nothing plugged in. Check System Settings ARROW Sound ARROW Output."],
                ["Voice sounds distorted",
                 "Turn the microphone gain down so speech peaks at -12 to -6 dB."],
                ["Dropped frames climbing",
                 "Internet is struggling. Use a wired connection, close other apps "
                 "using the internet, or lower the bitrate to 4500."],
                ["Aitum dock missing",
                 "Menu bar ARROW Docks ARROW Aitum Multistream. If it's not listed, "
                 "reinstall the plugin (section 3)."],
            ],
        ),
    },
    {
        "title": "Keeping stream keys safe",
        "intro": ("A stream key works like a password. Anyone who has it can go live on "
                  "your channel or Page."),
        "steps": [
            "Never post, text or email a stream key, and never share a screenshot that "
            "shows one.",
            "If a key may have been seen, reset it. On Facebook click <b>Reset</b> next "
            "to the stream key in Live Producer. On YouTube click the circular arrow "
            "next to the key.",
            "After a reset, paste the new key into OBS: YouTube in <b>Settings</b> ARROW "
            "<b>Stream</b>, Facebook in <b>Aitum</b> ARROW <b>Main Canvas</b> ARROW "
            "<b>Facebook Output</b> ARROW <b>Output Settings</b>.",
            "Run a quick private test (section 8) to confirm the new key works.",
        ],
        "callout": (
            "Tests stay private",
            "Always test with YouTube set to <b>Private</b> and Facebook set to "
            "<b>Only me</b>. Delete test recordings afterward from YouTube Studio "
            "<b>Content</b> or Facebook <b>Activity log</b>.",
        ),
    },
]
