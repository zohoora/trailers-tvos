#!/usr/bin/env python3
"""
YouTube URL Extraction Server for Trailers tvOS App
====================================================

A simple HTTP server that uses yt-dlp to extract direct video URLs from YouTube.
Run this on your local Mac and configure the tvOS app to connect to it.

Now includes comprehensive analytics logging for future recommendation algorithms.

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
import uuid
from functools import lru_cache
from datetime import datetime, timedelta
from pathlib import Path

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

# Analytics logging
ANALYTICS_DIR = Path(SCRIPT_DIR) / "analytics"
ANALYTICS_DIR.mkdir(exist_ok=True)
ANALYTICS_FILE = ANALYTICS_DIR / "viewing_log.jsonl"
SESSIONS_FILE = ANALYTICS_DIR / "sessions.jsonl"


def log_analytics(event_type: str, data: dict):
    """
    Log an analytics event to the JSONL file.

    Events are stored in JSON Lines format (one JSON object per line)
    for easy processing and analysis later.
    """
    event = {
        "timestamp": datetime.now().isoformat(),
        "timestamp_unix": datetime.now().timestamp(),
        "event_type": event_type,
        "day_of_week": datetime.now().strftime("%A"),
        "hour_of_day": datetime.now().hour,
        "source_ip": request.remote_addr if request else None,
        **data
    }

    with open(ANALYTICS_FILE, "a") as f:
        f.write(json.dumps(event) + "\n")

    print(f"[Analytics] {event_type}: {data.get('video_id', data.get('media_title', 'unknown'))}")


def log_session(session_data: dict):
    """Log session information."""
    with open(SESSIONS_FILE, "a") as f:
        f.write(json.dumps(session_data) + "\n")


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
            return {**cached_data, "cache_hit": True}

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
            "cache_hit": False,
            # Additional metadata for analytics
            "channel": info.get("channel"),
            "view_count": info.get("view_count"),
            "like_count": info.get("like_count"),
            "upload_date": info.get("upload_date"),
            "categories": info.get("categories", []),
            "tags": info.get("tags", []),
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
            "log_event": "POST /analytics/event",
            "view_stats": "/analytics/stats",
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

    Additional query params for analytics (all optional):
        session_id: Unique session identifier
        media_id: TMDB media ID
        media_type: "movie" or "tv"
        media_title: Title of the movie/show
        media_year: Release year
        media_genres: Comma-separated genres
        media_rating: TMDB rating
        trailer_type: "Trailer", "Teaser", "Clip", etc.
        trailer_name: Name of the trailer
        is_official: "true" or "false"
        trailer_index: Position in trailer list (0-indexed)
        total_trailers: Total number of trailers available

    Returns:
        JSON with 'url' key or 'error' key
    """
    quality = request.args.get("quality", "best")

    # Validate video_id (basic check)
    if not video_id or len(video_id) < 5 or len(video_id) > 20:
        return jsonify({"error": "Invalid video ID"}), 400

    result = get_video_url(video_id, quality)

    if "error" in result:
        # Log failed request
        log_analytics("stream_error", {
            "video_id": video_id,
            "quality_requested": quality,
            "error": result.get("error"),
            "media_id": request.args.get("media_id"),
            "media_type": request.args.get("media_type"),
            "media_title": request.args.get("media_title"),
        })
        return jsonify(result), 500

    # Log successful stream request with all available metadata
    log_analytics("stream_request", {
        "video_id": video_id,
        "quality_requested": quality,
        "quality_delivered": result.get("quality"),
        "video_title": result.get("title"),
        "video_duration": result.get("duration"),
        "video_channel": result.get("channel"),
        "video_view_count": result.get("view_count"),
        "video_upload_date": result.get("upload_date"),
        "cache_hit": result.get("cache_hit", False),
        # Media metadata from app
        "session_id": request.args.get("session_id"),
        "media_id": request.args.get("media_id"),
        "media_type": request.args.get("media_type"),
        "media_title": request.args.get("media_title"),
        "media_year": request.args.get("media_year"),
        "media_genres": request.args.get("media_genres"),
        "media_rating": request.args.get("media_rating"),
        "trailer_type": request.args.get("trailer_type"),
        "trailer_name": request.args.get("trailer_name"),
        "is_official": request.args.get("is_official") == "true",
        "trailer_index": request.args.get("trailer_index"),
        "total_trailers": request.args.get("total_trailers"),
    })

    return jsonify(result)


@app.route("/analytics/event", methods=["POST"])
def log_event():
    """
    Log a playback event from the app.

    Expected JSON body:
    {
        "event": "play_start" | "play_end" | "play_pause" | "play_resume" | "skip" | "replay",
        "session_id": "uuid",
        "video_id": "youtube_id",
        "media_id": "tmdb_id",
        "media_type": "movie" | "tv",
        "media_title": "Title",
        "media_year": 2024,
        "media_genres": ["Action", "Adventure"],
        "media_rating": 8.5,
        "trailer_type": "Trailer",
        "trailer_name": "Official Trailer",
        "is_official": true,
        "trailer_index": 0,
        "total_trailers": 3,
        "video_duration": 150,  // total video length in seconds
        "watch_time": 45,       // how long they watched in seconds
        "watch_percentage": 30, // percentage of video watched
        "playback_position": 45, // current position in seconds
        "quality": 1080,
        "volume": 1.0,
        "playback_rate": 1.0,
    }
    """
    try:
        data = request.get_json()
        if not data:
            return jsonify({"error": "No JSON data provided"}), 400

        event_type = data.get("event", "unknown")

        # Calculate additional metrics
        if data.get("video_duration") and data.get("watch_time"):
            data["completion_rate"] = round(
                (data["watch_time"] / data["video_duration"]) * 100, 2
            )

        # Determine engagement level
        watch_pct = data.get("watch_percentage", 0)
        if watch_pct >= 90:
            data["engagement_level"] = "completed"
        elif watch_pct >= 50:
            data["engagement_level"] = "high"
        elif watch_pct >= 25:
            data["engagement_level"] = "medium"
        elif watch_pct >= 10:
            data["engagement_level"] = "low"
        else:
            data["engagement_level"] = "skipped"

        log_analytics(f"playback_{event_type}", data)

        return jsonify({"status": "logged", "event": event_type})

    except Exception as e:
        print(f"[Error] Failed to log event: {e}")
        return jsonify({"error": str(e)}), 500


@app.route("/analytics/session", methods=["POST"])
def start_session():
    """
    Register a new viewing session.

    Expected JSON body:
    {
        "device_id": "unique_device_identifier",
        "app_version": "1.0.0",
        "os_version": "tvOS 17.0",
        "device_model": "Apple TV 4K",
    }

    Returns:
    {
        "session_id": "generated_uuid",
        "started_at": "iso_timestamp"
    }
    """
    try:
        data = request.get_json() or {}

        session_id = str(uuid.uuid4())
        started_at = datetime.now().isoformat()

        session_data = {
            "session_id": session_id,
            "started_at": started_at,
            "device_id": data.get("device_id"),
            "app_version": data.get("app_version"),
            "os_version": data.get("os_version"),
            "device_model": data.get("device_model"),
            "source_ip": request.remote_addr,
        }

        log_session(session_data)
        log_analytics("session_start", session_data)

        return jsonify({
            "session_id": session_id,
            "started_at": started_at
        })

    except Exception as e:
        print(f"[Error] Failed to start session: {e}")
        return jsonify({"error": str(e)}), 500


@app.route("/analytics/stats")
def get_stats():
    """
    Get basic analytics statistics.
    """
    try:
        stats = {
            "total_events": 0,
            "unique_videos": set(),
            "unique_media": set(),
            "events_by_type": {},
            "engagement_levels": {},
            "genres_watched": {},
            "media_types": {"movie": 0, "tv": 0},
            "qualities_requested": {},
            "hourly_distribution": {str(h): 0 for h in range(24)},
            "daily_distribution": {},
        }

        if ANALYTICS_FILE.exists():
            with open(ANALYTICS_FILE, "r") as f:
                for line in f:
                    try:
                        event = json.loads(line)
                        stats["total_events"] += 1

                        event_type = event.get("event_type", "unknown")
                        stats["events_by_type"][event_type] = stats["events_by_type"].get(event_type, 0) + 1

                        if event.get("video_id"):
                            stats["unique_videos"].add(event["video_id"])

                        if event.get("media_id"):
                            stats["unique_media"].add(f"{event.get('media_type')}_{event['media_id']}")

                        if event.get("engagement_level"):
                            level = event["engagement_level"]
                            stats["engagement_levels"][level] = stats["engagement_levels"].get(level, 0) + 1

                        if event.get("media_genres"):
                            genres = event["media_genres"]
                            if isinstance(genres, str):
                                genres = genres.split(",")
                            for genre in genres:
                                genre = genre.strip()
                                stats["genres_watched"][genre] = stats["genres_watched"].get(genre, 0) + 1

                        if event.get("media_type") in stats["media_types"]:
                            stats["media_types"][event["media_type"]] += 1

                        if event.get("quality_requested"):
                            q = str(event["quality_requested"])
                            stats["qualities_requested"][q] = stats["qualities_requested"].get(q, 0) + 1

                        if event.get("hour_of_day") is not None:
                            h = str(event["hour_of_day"])
                            stats["hourly_distribution"][h] = stats["hourly_distribution"].get(h, 0) + 1

                        if event.get("day_of_week"):
                            d = event["day_of_week"]
                            stats["daily_distribution"][d] = stats["daily_distribution"].get(d, 0) + 1

                    except json.JSONDecodeError:
                        continue

        # Convert sets to counts
        stats["unique_videos"] = len(stats["unique_videos"])
        stats["unique_media"] = len(stats["unique_media"])

        return jsonify(stats)

    except Exception as e:
        print(f"[Error] Failed to get stats: {e}")
        return jsonify({"error": str(e)}), 500


@app.route("/analytics/export")
def export_analytics():
    """
    Export all analytics data as JSON array.
    """
    try:
        events = []
        if ANALYTICS_FILE.exists():
            with open(ANALYTICS_FILE, "r") as f:
                for line in f:
                    try:
                        events.append(json.loads(line))
                    except json.JSONDecodeError:
                        continue

        return jsonify({
            "total_events": len(events),
            "exported_at": datetime.now().isoformat(),
            "events": events
        })

    except Exception as e:
        print(f"[Error] Failed to export: {e}")
        return jsonify({"error": str(e)}), 500


# =============================================================================
# WATCHLIST ENDPOINTS
# =============================================================================

WATCHLIST_DIR = Path(SCRIPT_DIR) / "data"
WATCHLIST_DIR.mkdir(exist_ok=True)
WATCHLIST_FILE = WATCHLIST_DIR / "watchlist.jsonl"


def get_watchlist_items(device_id: str) -> dict:
    """
    Get current watchlist state for a device.
    Returns dict of media_key -> entry for items currently on watchlist.
    Processes add/remove actions to compute final state.
    """
    items = {}

    if WATCHLIST_FILE.exists():
        with open(WATCHLIST_FILE, "r") as f:
            for line in f:
                try:
                    entry = json.loads(line)
                    if entry.get("device_id") == device_id:
                        key = f"{entry['media_type']}_{entry['media_id']}"
                        if entry.get("action") == "add":
                            items[key] = entry
                        elif entry.get("action") == "remove":
                            items.pop(key, None)
                except json.JSONDecodeError:
                    continue

    return items


def log_watchlist_action(action: str, data: dict):
    """Log a watchlist action (add/remove) to the JSONL file."""
    event = {
        "timestamp": datetime.now().isoformat(),
        "timestamp_unix": datetime.now().timestamp(),
        "action": action,
        "source_ip": request.remote_addr if request else None,
        **data
    }

    with open(WATCHLIST_FILE, "a") as f:
        f.write(json.dumps(event) + "\n")

    print(f"[Watchlist] {action}: {data.get('media_title', data.get('media_id', 'unknown'))}")


@app.route("/watchlist/add", methods=["POST"])
def watchlist_add():
    """
    Add an item to the watchlist.

    POST JSON body:
    {
        "media_id": 123,
        "media_type": "movie" or "tv",
        "media_title": "Movie Title",
        "device_id": "device-uuid"
    }
    """
    try:
        data = request.get_json()
        if not data:
            return jsonify({"error": "No JSON data provided"}), 400

        # Validate required fields
        required = ["media_id", "media_type", "device_id"]
        for field in required:
            if field not in data:
                return jsonify({"error": f"Missing required field: {field}"}), 400

        if data.get("media_type") not in ["movie", "tv"]:
            return jsonify({"error": "media_type must be 'movie' or 'tv'"}), 400

        # Log the add action
        log_watchlist_action("add", data)

        return jsonify({
            "status": "added",
            "media_id": data["media_id"],
            "media_type": data["media_type"]
        })

    except Exception as e:
        print(f"[Error] Failed to add to watchlist: {e}")
        return jsonify({"error": str(e)}), 500


@app.route("/watchlist/<media_type>/<int:media_id>", methods=["DELETE"])
def watchlist_remove(media_type: str, media_id: int):
    """
    Remove an item from the watchlist.

    Query params:
        device_id: Device identifier
    """
    try:
        device_id = request.args.get("device_id")
        if not device_id:
            return jsonify({"error": "device_id query parameter required"}), 400

        if media_type not in ["movie", "tv"]:
            return jsonify({"error": "media_type must be 'movie' or 'tv'"}), 400

        # Log the remove action
        log_watchlist_action("remove", {
            "media_id": media_id,
            "media_type": media_type,
            "device_id": device_id
        })

        return jsonify({
            "status": "removed",
            "media_id": media_id,
            "media_type": media_type
        })

    except Exception as e:
        print(f"[Error] Failed to remove from watchlist: {e}")
        return jsonify({"error": str(e)}), 500


@app.route("/watchlist/check/<media_type>/<int:media_id>")
def watchlist_check(media_type: str, media_id: int):
    """
    Check if an item is on the watchlist.

    Query params:
        device_id: Device identifier
    """
    try:
        device_id = request.args.get("device_id")
        if not device_id:
            return jsonify({"error": "device_id query parameter required"}), 400

        if media_type not in ["movie", "tv"]:
            return jsonify({"error": "media_type must be 'movie' or 'tv'"}), 400

        items = get_watchlist_items(device_id)
        key = f"{media_type}_{media_id}"
        is_on_watchlist = key in items

        return jsonify({
            "is_on_watchlist": is_on_watchlist,
            "media_id": media_id,
            "media_type": media_type
        })

    except Exception as e:
        print(f"[Error] Failed to check watchlist: {e}")
        return jsonify({"error": str(e)}), 500


@app.route("/watchlist/list")
def watchlist_list():
    """
    List all items on the watchlist.

    Query params:
        device_id: Device identifier
    """
    try:
        device_id = request.args.get("device_id")
        if not device_id:
            return jsonify({"error": "device_id query parameter required"}), 400

        items = get_watchlist_items(device_id)

        # Format items for response
        watchlist_items = []
        for entry in items.values():
            watchlist_items.append({
                "media_id": entry.get("media_id"),
                "media_type": entry.get("media_type"),
                "media_title": entry.get("media_title"),
                "added_at": entry.get("timestamp")
            })

        return jsonify({
            "total_items": len(watchlist_items),
            "device_id": device_id,
            "items": watchlist_items
        })

    except Exception as e:
        print(f"[Error] Failed to list watchlist: {e}")
        return jsonify({"error": str(e)}), 500


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
    parser.add_argument("--port", type=int, default=8080, help="Port to listen on (default: 8080)")
    args = parser.parse_args()

    local_ip = get_local_ip()

    print("=" * 60)
    print("  Trailers YouTube Server")
    print("=" * 60)
    print(f"\n  Local access:   http://127.0.0.1:{args.port}/")
    print(f"  Network access: http://{local_ip}:{args.port}/")
    print(f"\n  Configure your tvOS app with: {local_ip}")
    print(f"\n  Analytics stored in: {ANALYTICS_DIR}")
    print("\n  Press Ctrl+C to stop the server")
    print("=" * 60 + "\n")

    app.run(host=args.host, port=args.port, debug=False)
