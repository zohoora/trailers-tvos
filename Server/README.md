# YouTube Server for Trailers tvOS App

A simple Python server that uses yt-dlp to extract direct video URLs from YouTube, enabling in-app trailer playback on tvOS.

## Requirements

- Python 3.8+
- yt-dlp
- Flask

## Quick Start

1. **Install dependencies:**
   ```bash
   pip3 install yt-dlp flask
   ```

2. **Run the server:**
   ```bash
   cd Server
   python3 yt_server.py
   ```

3. **Note your Mac's IP address** (displayed when server starts)

4. **Configure the tvOS app:**

   Option A: Edit `Config.xcconfig`:
   ```
   YOUTUBE_SERVER_URL = http://YOUR_MAC_IP:5000
   ```

   Option B: Edit `Config.swift` directly:
   ```swift
   return "http://YOUR_MAC_IP:5000"
   ```

5. **Build and run the app** on your Apple TV

## Server Endpoints

| Endpoint | Description |
|----------|-------------|
| `GET /` | Health check and usage info |
| `GET /stream/<video_id>` | Get direct video URL |
| `GET /stream/<video_id>?quality=720` | Get video with specific quality |
| `GET /clear-cache` | Clear the URL cache |

### Quality Options

- `best` - Highest available quality (default)
- `1080` - Up to 1080p
- `720` - Up to 720p
- `480` - Up to 480p
- `worst` - Lowest quality

## Example Usage

```bash
# Get video stream URL
curl http://localhost:5000/stream/dQw4w9WgXcQ

# Get 720p stream
curl "http://localhost:5000/stream/dQw4w9WgXcQ?quality=720"
```

Response:
```json
{
  "url": "https://...",
  "title": "Rick Astley - Never Gonna Give You Up",
  "duration": 212,
  "quality": 720
}
```

## Running as a Background Service

### Using launchd (macOS)

Create `~/Library/LaunchAgents/com.trailers.ytserver.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.trailers.ytserver</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/bin/python3</string>
        <string>/path/to/trailers-tvos/Server/yt_server.py</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/tmp/ytserver.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/ytserver.err</string>
</dict>
</plist>
```

Then load it:
```bash
launchctl load ~/Library/LaunchAgents/com.trailers.ytserver.plist
```

## Troubleshooting

### "Connection refused" on Apple TV

1. Make sure the server is running
2. Check your Mac's firewall allows incoming connections on port 5000
3. Verify your Mac's IP hasn't changed
4. Ensure both devices are on the same network

### "yt-dlp not found"

```bash
pip3 install yt-dlp
```

Or update if already installed:
```bash
pip3 install -U yt-dlp
```

### Videos not playing

yt-dlp may need updating to handle YouTube changes:
```bash
pip3 install -U yt-dlp
```

## Network Notes

- The server binds to `0.0.0.0` by default (all interfaces)
- Use `--host 127.0.0.1` to restrict to localhost only
- Default port is 5000, change with `--port XXXX`
