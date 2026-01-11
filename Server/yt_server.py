#!/usr/bin/env python3
"""
YouTube URL Extraction Server for Trailers tvOS App
====================================================

A simple HTTP server that uses yt-dlp to extract direct video URLs from YouTube.
Run this on your local Mac and configure the tvOS app to connect to it.

Requirements:
    pip3 install yt-dlp flask

Usage:
    python3 yt_server.py

    Or with custom port:
    python3 yt_server.py --port 8080

    Or bind to all interfaces (for network access):
    python3 yt_server.py --host 0.0.0.0

The server will be available at:
    http://YOUR_MAC_IP:5000/stream/<video_id>

Example:
    http://192.168.1.100:5000/stream/dQw4w9WgXcQ
"""

import argparse
import json
import os
import subprocess
import sys
from functools import lru_cache
from datetime import datetime, timedelta

try:
    from flask import Flask, jsonify, request
except ImportError:
    print("Flask not installed. Installing...")
    subprocess.check_call([sys.executable, "-m", "pip", "install", "flask"])
    from flask import Flask, jsonify, request

# Find yt-dlp executable (check venv first, then system PATH)
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
VENV_YTDLP = os.path.join(SCRIPT_DIR, "venv", "bin", "yt-dlp")

if os.path.exists(VENV_YTDLP):
    YTDLP_PATH = VENV_YTDLP
    print(f"Using venv yt-dlp: {YTDLP_PATH}")
else:
    # Try system PATH
    import shutil
    YTDLP_PATH = shutil.which("yt-dlp")
    if not YTDLP_PATH:
        print("yt-dlp not found. Installing to venv...")
        subprocess.check_call([sys.executable, "-m", "pip", "install", "yt-dlp"])
        YTDLP_PATH = VENV_YTDLP if os.path.exists(VENV_YTDLP) else "yt-dlp"
    else:
        print(f"Using system yt-dlp: {YTDLP_PATH}")

app = Flask(__name__)

# Simple cache for video URLs (they expire, so cache for 1 hour max)
url_cache = {}
CACHE_DURATION = timedelta(hours=1)


def get_video_url(video_id: str, quality: str = "best") -> dict:
    """
    Extract direct video URL from YouTube using yt-dlp.

    Args:
        video_id: YouTube video ID
        quality: Quality preference (best, 1080, 720, 480, worst)

    Returns:
        dict with 'url' and 'title' keys, or 'error' key on failure
    """
    # Check cache
    cache_key = f"{video_id}_{quality}"
    if cache_key in url_cache:
        cached_time, cached_data = url_cache[cache_key]
        if datetime.now() - cached_time < CACHE_DURATION:
            print(f"[Cache Hit] {video_id}")
            return cached_data

    youtube_url = f"https://www.youtube.com/watch?v={video_id}"

    # Build format selector based on quality preference
    if quality == "best":
        format_selector = "best[ext=mp4]/best"
    elif quality == "1080":
        format_selector = "best[height<=1080][ext=mp4]/best[height<=1080]/best"
    elif quality == "720":
        format_selector = "best[height<=720][ext=mp4]/best[height<=720]/best"
    elif quality == "480":
        format_selector = "best[height<=480][ext=mp4]/best[height<=480]/best"
    else:
        format_selector = "worst[ext=mp4]/worst"

    try:
        # Run yt-dlp to get video info
        result = subprocess.run(
            [
                YTDLP_PATH,
                "-f", format_selector,
                "-j",  # JSON output
                "--no-playlist",
                "--no-warnings",
                youtube_url
            ],
            capture_output=True,
            text=True,
            timeout=30
        )

        if result.returncode != 0:
            error_msg = result.stderr.strip() or "Unknown error"
            print(f"[Error] yt-dlp failed for {video_id}: {error_msg}")
            return {"error": error_msg}

        # Parse JSON output
        info = json.loads(result.stdout)

        video_url = info.get("url")
        if not video_url:
            # Sometimes the URL is in requested_formats
            formats = info.get("requested_formats", [])
            if formats:
                # Prefer format with both video and audio
                for fmt in formats:
                    if fmt.get("acodec") != "none" and fmt.get("vcodec") != "none":
                        video_url = fmt.get("url")
                        break
                if not video_url:
                    video_url = formats[0].get("url")

        if not video_url:
            return {"error": "No video URL found"}

        response_data = {
            "url": video_url,
            "title": info.get("title", "Unknown"),
            "duration": info.get("duration"),
            "thumbnail": info.get("thumbnail"),
            "quality": info.get("height", "unknown"),
        }

        # Cache the result
        url_cache[cache_key] = (datetime.now(), response_data)

        print(f"[OK] {video_id} -> {info.get('height', '?')}p")
        return response_data

    except subprocess.TimeoutExpired:
        print(f"[Error] Timeout for {video_id}")
        return {"error": "Request timed out"}
    except json.JSONDecodeError as e:
        print(f"[Error] JSON parse error for {video_id}: {e}")
        return {"error": "Failed to parse video info"}
    except Exception as e:
        print(f"[Error] Exception for {video_id}: {e}")
        return {"error": str(e)}


@app.route("/")
def index():
    """Health check and usage info."""
    return jsonify({
        "status": "ok",
        "service": "Trailers YouTube Server",
        "usage": {
            "stream": "/stream/<video_id>",
            "stream_with_quality": "/stream/<video_id>?quality=720",
        },
        "qualities": ["best", "1080", "720", "480", "worst"],
    })


@app.route("/stream/<video_id>")
def stream(video_id: str):
    """
    Get direct video URL for a YouTube video.

    Args:
        video_id: YouTube video ID (e.g., dQw4w9WgXcQ)
        quality: Optional query param (best, 1080, 720, 480, worst)

    Returns:
        JSON with 'url' key or 'error' key
    """
    quality = request.args.get("quality", "best")

    # Validate video_id (basic check)
    if not video_id or len(video_id) < 5 or len(video_id) > 20:
        return jsonify({"error": "Invalid video ID"}), 400

    result = get_video_url(video_id, quality)

    if "error" in result:
        return jsonify(result), 500

    return jsonify(result)


@app.route("/clear-cache")
def clear_cache():
    """Clear the URL cache."""
    url_cache.clear()
    return jsonify({"status": "cache cleared"})


def get_local_ip():
    """Get the local IP address of this machine."""
    import socket
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        ip = s.getsockname()[0]
        s.close()
        return ip
    except Exception:
        return "127.0.0.1"


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="YouTube URL Extraction Server")
    parser.add_argument("--host", default="0.0.0.0", help="Host to bind to (default: 0.0.0.0)")
    parser.add_argument("--port", type=int, default=5000, help="Port to listen on (default: 5000)")
    args = parser.parse_args()

    local_ip = get_local_ip()

    print("=" * 60)
    print("  Trailers YouTube Server")
    print("=" * 60)
    print(f"\n  Local access:   http://127.0.0.1:{args.port}/")
    print(f"  Network access: http://{local_ip}:{args.port}/")
    print(f"\n  Configure your tvOS app with: {local_ip}")
    print("\n  Press Ctrl+C to stop the server")
    print("=" * 60 + "\n")

    app.run(host=args.host, port=args.port, debug=False)
