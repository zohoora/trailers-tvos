# Trailers App Architecture Documentation

## Overview

The Trailers app follows the **MVVM (Model-View-ViewModel)** architecture pattern with a clear separation of concerns:

- **Views**: SwiftUI views that render UI and handle user interactions
- **ViewModels**: `@MainActor` classes that manage state and coordinate with services
- **Services**: Actors and classes that handle data fetching, caching, and external integrations
- **Models**: Value types representing domain entities and DTOs

## Concurrency Model

### Actor-Based Services

All network and cache operations use Swift's actor system for thread safety:

```swift
actor NetworkClient {
    // Guaranteed thread-safe access to:
    // - In-flight request tracking
    // - Rate limit backoff state
    // - Request deduplication
}

actor ResponseCache {
    // Thread-safe memory and disk cache operations
}

actor TMDBService {
    // Coordinates NetworkClient and ResponseCache
}
```

### MainActor ViewModels

All ViewModels are marked `@MainActor` to ensure UI state updates happen on the main thread:

```swift
@MainActor
final class ContentGridViewModel: ObservableObject {
    @Published private(set) var state: GridState = .idle
    @Published private(set) var items: [MediaSummary] = []
    // ...
}
```

## State Machines

### Grid State

```
idle
→ loadingInitial
→ loaded(items)
→ loadingNextPage(items)
→ loaded(items)
→ exhausted(items)
↘ error(lastGoodItems?, errorKind)
↘ empty(filtersApplied)
```

### Detail State

```
idle
→ loading
→ loaded(detail, trailers[])
↘ error(partialDetail?, errorKind)
```

## Data Flow

### Content Loading

```
User Action
    │
    ▼
ViewModel Intent (e.g., loadInitial())
    │
    ▼
TMDBService.fetchTrending() or fetchDiscover()
    │
    ├─► Check ResponseCache
    │       │
    │       ├─► Cache Hit → Return cached data
    │       │
    │       └─► Cache Miss → Continue to network
    │
    ▼
NetworkClient.fetch()
    │
    ├─► Build request with auth headers
    ├─► Check for duplicate requests (dedup)
    ├─► Apply rate limit backoff if needed
    ├─► Perform HTTP request
    └─► Decode DTO → Domain Model
    │
    ▼
Update ResponseCache
    │
    ▼
ViewModel updates @Published state
    │
    ▼
SwiftUI View re-renders
```

### Filter Changes

```
User changes filter
    │
    ▼
FilterViewModel.setGenre(genre)
    │
    ├─► Apply invariants (auto-switch sort if needed)
    └─► Publish FilterChange event
    │
    ▼
ContentGridViewModel receives change
    │
    ├─► Cancel active task
    ├─► Reset pagination
    └─► Call loadInitial() with new filters
```

## Filter Invariants

The `FilterState` struct enforces business rules through immutable transformations:

```swift
struct FilterState {
    func withGenre(_ genre: GenreDisplay?) -> FilterState {
        // Returns new state with genre applied
        // Automatically applies invariants:
        // - Trending + filters → Popularity
        // - Upcoming + Trending/Popularity → Release Date (Newest)
    }
}
```

This ensures invalid state combinations cannot exist.

## Caching Strategy

### Two-Tier Cache

1. **Memory Cache** (NSCache)
   - Fast access
   - Automatically evicted on memory pressure
   - Limited to 100 items / 50MB

2. **Disk Cache** (File System)
   - Persistent across launches
   - Stored in Caches directory
   - SHA256 hashed keys for filesystem safety

### TTL Configuration

| Type | TTL | Rationale |
|------|-----|-----------|
| Genres | 7 days | Rarely change |
| Grid | 5 minutes | Fresh but cacheable |
| Detail | 30 minutes | Moderate freshness |

### Offline Mode

When offline, the cache returns expired entries with the `allowExpired: true` flag, enabling a degraded but functional offline experience.

## Pagination

### Single-Type Pagination

For Movies or TV Shows content type:
- Simple page counter
- Request next page when focus within 3 rows of end
- Debounced by 300ms

### "All" Mode Merge Algorithm

When showing both movies and TV:

1. Maintain separate buffers for movies and TV
2. Fetch pages independently
3. Merge using selected sort comparator
4. Tie-breakers: popularity → type (movies first) → ID

```swift
// Merge comparator
static func compare(_ a: MediaSummary, _ b: MediaSummary, sort: SortOption) -> Bool {
    // Primary: sort field
    // Tie-breaker 1: popularity desc
    // Tie-breaker 2: movies before TV
    // Tie-breaker 3: ID ascending
}
```

## Network Resilience

### Rate Limiting

- Initial backoff: 1 second
- Max backoff: 30 seconds
- Max retries: 5
- Exponential backoff on 429 responses

### Request Deduplication

Same URL requests within 500ms share the same Task, preventing duplicate network calls during rapid user interactions.

### Concurrency Limiting

Maximum 4 concurrent network requests to stay within TMDB rate limits.

## Accessibility

### VoiceOver

- All interactive elements have accessibility labels
- Poster format: "{Title}, {Year}, rated {Score} out of 10, {Movie|TV}"
- Filter change announcements debounced by 500ms

### Reduce Motion

- Focus animations disabled
- Border highlight used instead of scale effect

## Testing Strategy

### Unit Tests

- **FilterState**: Invariant enforcement
- **DTO Decoding**: JSON parsing including edge cases
- **DateUtils**: Date range calculations
- **Video Ranking**: Trailer priority algorithm

### UI Tests

- D-pad navigation
- Focus management
- State transitions

## Error Handling

### Network Errors

| Error | Handling |
|-------|----------|
| 401 | Show config error screen |
| 403 | Show access denied |
| 404 | Remove item from grid |
| 429 | Exponential backoff with countdown |
| 5xx | Retry with backoff, fallback to cache |

### Graceful Degradation

- Missing poster: Show placeholder with title
- Missing date: Show "TBA"
- Missing rating: Show "★ -"
- Detail load failure: Show partial info from grid summary

## Dependencies

### Required

- SwiftUI (Apple)
- Foundation (Apple)
- OSLog (Apple)
- Network (Apple)
- CryptoKit (Apple)

### Optional

- Nuke/NukeUI (Image loading optimization)
