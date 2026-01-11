# Trailers - tvOS App

A native **tvOS 17+** app that displays a poster grid of movies and TV shows from TMDB, with filtering and sorting capabilities, and plays trailers via an in-app video player.

## Features

### Core Features
- **Poster Grid**: Browse current movies and TV shows in a visually appealing grid layout
- **Filtering**: Filter by content type, genre, release date, and certification
- **Sorting**: Sort by trending, popularity, release date, or rating
- **Detail View**: View full media information including ratings, runtime, cast, and overview
- **Smart Prefetching**: Detail data prefetches on poster focus; trailer URLs prefetch when viewing details
- **Offline Support**: Cached content available when offline
- **Accessibility**: Full VoiceOver support and Reduce Motion compatibility

### Trailer Playback
- **In-App Player**: Native AVPlayer with full Siri Remote support (play/pause, scrub, skip)
- **Local yt-dlp Server**: Python server extracts YouTube stream URLs for direct playback
- **Watch History**: Eye icon indicator on grid shows previously watched trailers
- **Analytics**: Playback events logged for future recommendations

### Additional Features
- **Watchlist**: Save movies/shows to a server-side watchlist with visual indicators
- **Where to Watch**: See streaming availability (Netflix, Disney+, Crave, Prime, etc.) with tappable icons that open the streaming app
- **Multiple Trailers**: Browse and select from all available trailers for a title

## Requirements

- tvOS 17.0+
- Xcode 15.0+
- Swift 5.9+
- Apple TV HD or Apple TV 4K
- TMDB API Key (free)
- Python 3.8+ with yt-dlp (for trailer playback server)

## Getting Started

### 1. Clone the Repository

```bash
git clone https://github.com/yourusername/trailers-tvos.git
cd trailers-tvos
```

### 2. Configure API Key

1. Copy the example config file:
   ```bash
   cp Config.xcconfig.example Config.xcconfig
   ```

2. Edit `Config.xcconfig` and add your TMDB API Key:
   ```xcconfig
   TMDB_API_KEY = your_tmdb_api_key_here
   ```

3. Get your API Key from [TMDB API Settings](https://www.themoviedb.org/settings/api) (it's the "API Key" not the "Read Access Token").

### 3. Set Up the yt-dlp Server

The app requires a local Python server to stream YouTube trailers.

```bash
# Create virtual environment
cd Server
python3 -m venv venv
source venv/bin/activate

# Install dependencies
pip install flask yt-dlp

# Start the server
python yt_server.py
```

The server runs at `http://localhost:8080` and provides:
- `/stream/<video_id>` - Stream YouTube videos
- `/watchlist/*` - Watchlist management
- `/analytics/*` - Playback analytics

### 4. Open in Xcode

```bash
open Trailers.xcodeproj
```

### 5. Build and Run

- Select your Apple TV device or simulator
- Press Cmd+R to build and run

> **Note**: Free Apple Developer accounts require redeploy every 7 days.

## Architecture

### MVVM Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                         Views                                │
│  (SwiftUI: BrowseView, DetailView, PosterCardView, etc.)    │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                      ViewModels                              │
│  (FilterViewModel, ContentGridViewModel, DetailViewModel)    │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                       Services                               │
│  (TMDBService, NetworkClient, ResponseCache, etc.)          │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                        Models                                │
│  Domain: MediaSummary, MediaDetail, Video, FilterState      │
│  DTOs: TMDBMovieListDTO, TMDBTVListDTO, etc.                │
└─────────────────────────────────────────────────────────────┘
```

### Key Components

#### Core
- `Config.swift` - API configuration and constants
- `Constants.swift` - UI strings and layout constants
- `Logging.swift` - OSLog-based logging system
- `DateUtils.swift` - Date formatting and range calculations

#### Models
- `MediaType` - Movie/TV enumeration
- `MediaID` - Unique identifier combining type and ID
- `MediaSummary` - Grid item model
- `MediaDetail` - Full detail model with cast
- `CastMember` - Actor/cast member model
- `Video` - Trailer model with ranking
- `FilterState` - Immutable filter configuration
- `Genre` / `GenreDisplay` - Genre models

#### Services
- `NetworkClient` - Actor-based network client with rate limiting
- `ResponseCache` - Two-tier caching (memory + disk)
- `TMDBService` - High-level TMDB API service (shared singleton for cache coherence)
- `PrefetchService` - Debounced detail prefetching on poster focus
- `TrailerPrefetchService` - Trailer URL prefetch and AVPlayer pre-buffering
- `NetworkMonitor` - NWPathMonitor wrapper
- `ImagePipeline` - Image loading configuration
- `YouTubeLauncher` - YouTube Universal Link handler
- `AnalyticsService` - Playback analytics tracking
- `WatchlistService` - Server-side watchlist management
- `WatchHistoryService` - Local watch history tracking
- `StreamingLauncher` - Deep links to streaming apps

#### ViewModels
- `FilterViewModel` - Filter state and genre management
- `ContentGridViewModel` - Grid state, pagination, merge algorithm
- `DetailViewModel` - Detail loading and trailer selection

#### Views
- `BrowseView` - Main grid screen
- `DetailView` - Media detail screen with watchlist and streaming info
- `TrailerPlayerView` - In-app AVPlayer-based trailer player
- `TrailerSelectorView` - Multiple trailer selection
- `PosterCardView` - Grid poster card with watch history indicator
- `FilterBarView` - Filter controls
- `LoadingFooterView` / `EmptyStateView` - State views

## Filter Business Rules

The app enforces these filter invariants automatically:

1. **Leaving Movies clears certification** - Certification only applies to movies
2. **Trending + filters → Popularity** - Trending endpoint doesn't support filters
3. **Upcoming + Trending/Popularity → Release Date (Newest)** - Better UX for upcoming content

## Caching Strategy

| Content Type | TTL | Strategy |
|-------------|-----|----------|
| Genres | 7 days | Rarely change |
| Grid content | 5 minutes | Fresh but cacheable |
| Detail | 30 minutes | Moderate freshness |

Offline mode returns expired cache entries with an "Offline" badge.

## Prefetching Strategy

The app uses intelligent prefetching to minimize perceived loading times:

### Detail Prefetch
- **Trigger**: When user focuses on a poster in the grid
- **Debounce**: 350ms (prevents rapid navigation spam)
- **Action**: Fetches full detail data from TMDB
- **Result**: Detail view loads instantly when user selects

### Trailer Prefetch
- **Trigger**: When detail view loads
- **Action**: Fetches stream URL from yt-dlp server + creates AVPlayer
- **Pre-buffer**: AVPlayer begins buffering in background
- **TTL**: 1 hour (YouTube URLs expire after ~4 hours)
- **Result**: Trailer playback starts nearly instantly

## API Endpoints Used

### TMDB API
- `/trending/movie/week` - Trending movies
- `/trending/tv/week` - Trending TV shows
- `/trending/all/week` - All trending (filters people)
- `/discover/movie` - Movie discovery with filters
- `/discover/tv` - TV discovery with filters
- `/movie/{id}` - Movie details with videos
- `/tv/{id}` - TV details with videos
- `/movie/{id}/watch/providers` - Streaming availability
- `/tv/{id}/watch/providers` - Streaming availability
- `/genre/movie/list` - Movie genres
- `/genre/tv/list` - TV genres

### Local Server API
- `GET /stream/<video_id>` - Get YouTube stream URL
- `POST /watchlist/add` - Add to watchlist
- `DELETE /watchlist/<type>/<id>` - Remove from watchlist
- `GET /watchlist/check/<type>/<id>` - Check watchlist status
- `POST /analytics/event` - Log playback event
- `POST /analytics/session` - Log session end

## Testing

### Unit Tests

```bash
# Run unit tests
xcodebuild test -scheme Trailers -destination 'platform=tvOS Simulator,name=Apple TV 4K'
```

Tests cover:
- Filter state invariants
- DTO decoding (including people filtering)
- Date utilities and ranges
- Video/trailer ranking algorithm
- Cache TTL behavior

### UI Tests

```bash
# Run UI tests
xcodebuild test -scheme TrailersUITests -destination 'platform=tvOS Simulator,name=Apple TV 4K'
```

Tests cover:
- D-pad navigation (grid ↔ filter bar)
- Empty state focus behavior
- Detail view open/close with focus restoration
- Loading footer focusability
- Reduce Motion behavior

## Accessibility

- All interactive elements have accessibility labels
- Poster card VoiceOver format: "{Title}, {Year}, rated {Score} out of 10, {Movie|TV}"
- Filter change announcements debounced by 500ms
- Reduce Motion: Disables scale/glow animations, uses border highlight

## Attribution

This app uses data from [The Movie Database (TMDB)](https://www.themoviedb.org/).

**"Powered by TMDB"**

## Project Structure

```
Server/
├── yt_server.py          # Flask server for streaming/watchlist/analytics
├── analytics/            # Playback event logs (JSONL)
└── data/                 # Watchlist storage (JSONL)

Trailers/
├── App/
│   └── TrailersApp.swift
├── Core/
│   ├── Config.swift
│   ├── Constants.swift
│   ├── Logging.swift
│   └── DateUtils.swift
├── Models/
│   ├── Domain/
│   │   ├── MediaType.swift
│   │   ├── MediaID.swift
│   │   ├── MediaSummary.swift
│   │   ├── MediaDetail.swift
│   │   ├── Genre.swift
│   │   ├── Video.swift
│   │   ├── FilterState.swift
│   │   └── WatchProvider.swift
│   └── DTO/
│       ├── TMDBPaginatedDTO.swift
│       ├── TMDBMovieListDTO.swift
│       ├── TMDBTVListDTO.swift
│       ├── TMDBTrendingAllDTO.swift
│       ├── TMDBMovieDetailDTO.swift
│       ├── TMDBTVDetailDTO.swift
│       ├── TMDBGenreListDTO.swift
│       ├── TMDBVideoDTO.swift
│       └── TMDBWatchProviderDTO.swift
├── Services/
│   ├── NetworkClient.swift
│   ├── TMDBService.swift
│   ├── ResponseCache.swift
│   ├── PrefetchService.swift
│   ├── TrailerPrefetchService.swift
│   ├── NetworkMonitor.swift
│   ├── ImagePipeline.swift
│   ├── YouTubeLauncher.swift
│   ├── AnalyticsService.swift
│   ├── WatchlistService.swift
│   ├── WatchHistoryService.swift
│   └── StreamingLauncher.swift
├── ViewModels/
│   ├── FilterViewModel.swift
│   ├── ContentGridViewModel.swift
│   └── DetailViewModel.swift
├── Views/
│   ├── Root/
│   │   └── BrowseView.swift
│   ├── Components/
│   │   ├── FilterBarView.swift
│   │   ├── PosterCardView.swift
│   │   └── LoadingFooterView.swift
│   └── Screens/
│       ├── DetailView.swift
│       ├── TrailerPlayerView.swift
│       ├── TrailerSelectorView.swift
│       └── ErrorOverlayView.swift
└── Tests/
    ├── Unit/
    │   ├── FilterStateTests.swift
    │   ├── DTODecodingTests.swift
    │   ├── DateUtilsTests.swift
    │   └── VideoRankingTests.swift
    └── UI/
        └── BrowseViewUITests.swift
```

## License

This project is for personal use only. Not intended for App Store distribution.

## Acknowledgments

- [TMDB](https://www.themoviedb.org/) for the comprehensive movie and TV database
- [Nuke](https://github.com/kean/Nuke) for efficient image loading (optional dependency)
