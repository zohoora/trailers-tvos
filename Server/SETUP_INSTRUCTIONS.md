# Trailers Server Setup Instructions

## For AI Assistant

This is a Python Flask server that streams YouTube trailers to an Apple TV app using yt-dlp.

## Quick Setup (Run These Commands)

```bash
# 1. Navigate to the server directory
cd ~/trailers-server  # or wherever you extracted the zip

# 2. Create virtual environment
python3 -m venv venv
source venv/bin/activate

# 3. Install dependencies
pip install flask yt-dlp

# 4. Create required directories
mkdir -p analytics data

# 5. Start the server
python3 yt_server.py
```

## What the Server Does

- **Port**: 5000 (configurable with `--port`)
- **Binds to**: 0.0.0.0 (all interfaces)
- Extracts direct video URLs from YouTube using yt-dlp
- Caches URLs for 4 hours (they expire)
- Stores watchlist and analytics data locally

## Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/` | GET | Health check |
| `/stream/<video_id>` | GET | Get YouTube stream URL |
| `/watchlist/add` | POST | Add to watchlist |
| `/watchlist/<type>/<id>` | DELETE | Remove from watchlist |
| `/watchlist/check/<type>/<id>` | GET | Check if in watchlist |
| `/analytics/event` | POST | Log playback event |

## After Starting

1. Note the IP address printed (e.g., `http://192.168.1.100:5000`)
2. The Apple TV app needs this IP configured in `Config.xcconfig`:
   ```
   YOUTUBE_SERVER_URL = http://YOUR_IP:5000
   ```

## Running in Background

```bash
# Option 1: nohup
nohup python3 yt_server.py > server.log 2>&1 &

# Option 2: screen
screen -S ytserver
python3 yt_server.py
# Ctrl+A, D to detach

# Option 3: tmux
tmux new -s ytserver
python3 yt_server.py
# Ctrl+B, D to detach
```

## Troubleshooting

- **"yt-dlp not found"**: Run `pip install yt-dlp`
- **Videos not playing**: Update yt-dlp with `pip install -U yt-dlp`
- **Connection refused**: Check firewall allows port 5000
- **URL errors**: YouTube may have changed, update yt-dlp

## Files

- `yt_server.py` - Main server script
- `analytics/` - Playback logs (auto-created)
- `data/` - Watchlist storage (auto-created)
