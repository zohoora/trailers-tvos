# Trailers - tvOS App

A native **tvOS 17+** app that displays a poster grid of movies and TV shows from TMDB, with filtering and sorting capabilities, and plays trailers via the YouTube tvOS app.

## Features

- **Poster Grid**: Browse current movies and TV shows in a visually appealing grid layout
- **Filtering**: Filter by content type, genre, release date, and certification
- **Sorting**: Sort by trending, popularity, release date, or rating
- **Detail View**: View full media information including ratings, runtime, and overview
- **YouTube Integration**: Play trailers directly in the YouTube app via Universal Links
- **Offline Support**: Cached content available when offline
- **Accessibility**: Full VoiceOver support and Reduce Motion compatibility

## Requirements

- tvOS 17.0+
- Xcode 15.0+
- Swift 5.9+
- Apple TV HD or Apple TV 4K
- TMDB API Key (free)

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

### 3. Open in Xcode

```bash
open Trailers.xcodeproj
```

### 4. Build and Run

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
- `MediaDetail` - Full detail model
- `Video` - Trailer model with ranking
- `FilterState` - Immutable filter configuration
- `Genre` / `GenreDisplay` - Genre models

#### Services
- `NetworkClient` - Actor-based network client with rate limiting
- `ResponseCache` - Two-tier caching (memory + disk)
- `TMDBService` - High-level TMDB API service
- `NetworkMonitor` - NWPathMonitor wrapper
- `ImagePipeline` - Image loading configuration
- `YouTubeLauncher` - YouTube Universal Link handler

#### ViewModels
- `FilterViewModel` - Filter state and genre management
- `ContentGridViewModel` - Grid state, pagination, merge algorithm
- `DetailViewModel` - Detail loading and trailer selection

#### Views
- `BrowseView` - Main grid screen
- `DetailView` - Media detail screen
- `TrailerSelectorView` - Multiple trailer selection
- `PosterCardView` - Grid poster card
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

## API Endpoints Used

- `/trending/movie/week` - Trending movies
- `/trending/tv/week` - Trending TV shows
- `/trending/all/week` - All trending (filters people)
- `/discover/movie` - Movie discovery with filters
- `/discover/tv` - TV discovery with filters
- `/movie/{id}` - Movie details with videos
- `/tv/{id}` - TV details with videos
- `/genre/movie/list` - Movie genres
- `/genre/tv/list` - TV genres

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
│   │   └── FilterState.swift
│   └── DTO/
│       ├── TMDBPaginatedDTO.swift
│       ├── TMDBMovieListDTO.swift
│       ├── TMDBTVListDTO.swift
│       ├── TMDBTrendingAllDTO.swift
│       ├── TMDBMovieDetailDTO.swift
│       ├── TMDBTVDetailDTO.swift
│       ├── TMDBGenreListDTO.swift
│       └── TMDBVideoDTO.swift
├── Services/
│   ├── NetworkClient.swift
│   ├── TMDBService.swift
│   ├── ResponseCache.swift
│   ├── NetworkMonitor.swift
│   ├── ImagePipeline.swift
│   └── YouTubeLauncher.swift
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
