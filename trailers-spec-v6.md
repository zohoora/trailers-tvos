# Trailers (tvOS) - Implementation Specification (v6.0, “god-tier”)

**Source:** This document is a rewrite and strict superset of your v5 spec, intended to be directly handed to an AI coding agent to build the entire app end-to-end. It preserves the original product intent, core UI, filtering/sorting model, and YouTube playback flow while removing ambiguity and adding missing edge cases, state machines, and build instructions.  \
(See v5 summary/objectives/target platform for baseline intent.) 

---

## 0. One-Sentence Product Definition

A native **tvOS 17+** app that shows a **poster grid** of **movies and TV shows** from **TMDB**, lets the user **filter and sort**, and plays the selected title’s **YouTube trailer** by launching the **YouTube tvOS app** via **Universal Links**.

---

## 1. Goals, Non‑Goals, Constraints

### 1.1 Goals (MUST)
1. Fast browsing of current content, optimized for the “10‑foot” TV UI.
2. Robust filters and sorts, applied immediately.
3. One‑tap trailer playback via the YouTube tvOS app.
4. Smooth focus navigation, no “focus dead ends”.
5. Rate-limit safe, resilient to network errors, cancellable requests.
6. “Personal use only” build, sideload via Xcode.

### 1.2 Non‑Goals (MUST NOT)
- No search feature.
- No account, watchlist, favourites, or sync.
- No analytics, tracking, ads.
- No in-app video playback (no WebView embed player).
- No trailer availability badge on the grid.
- No App Store distribution considerations beyond baseline best practices.

### 1.3 Hard Constraints (MUST)
- **tvOS 17.0+**
- Swift 5.9+
- SwiftUI-first UI
- Must work with Apple TV HD and Apple TV 4K
- Must operate within TMDB rate limits (documented by TMDB, rate limiting applies).
- Must behave sensibly when YouTube app is not installed.

---

## 2. User Flows

### 2.1 Primary Flow
1. Launch app → grid loads default content.
2. User navigates grid with D-pad.
3. User presses Select on a poster → detail screen opens.
4. Detail fetches trailers (and ratings) once.
5. User presses “Play in YouTube” → YouTube opens.

### 2.2 Filter Flow
1. User moves focus to Filter Bar (Up from first row).
2. User changes Content Type, Sort, Genre, Date Range, or Certification.
3. Grid cancels prior requests, resets pagination, scrolls to top, reloads.

### 2.3 Pagination Flow
1. User scrolls down.
2. When user reaches “prefetch threshold” (3 rows remaining), next page fetch starts.
3. Footer shows “Loading more…”, remains focusable.
4. When page arrives, items append. If last page, pagination stops.

---

## 3. UX + UI Specification

### 3.1 App Shell
- Root screen is a single “Browse” experience (no tabs).
- Navigation is push-style (grid → detail).
- Use `NavigationStack` (SwiftUI) with a single path.

### 3.2 Layout Overview
```
┌──────────────────────────────────────────────────────────────────┐
│ Filter Bar: [Type] [Sort] [Genre] [Date] [Cert*]   [↻ Refresh]  │
├──────────────────────────────────────────────────────────────────┤
│ Poster Grid (LazyVGrid)                                          │
│   Row 1: 4-5 posters                                              │
│   Row 2: 4-5 posters                                              │
│   ...                                                             │
│   Footer: “Loading more…” (focusable)                             │
└──────────────────────────────────────────────────────────────────┘

* Certification shown only when Type = Movies.
```

### 3.3 Poster Card (Grid Item)
**Visual**
- Poster image, aspect 2:3, corner radius 12pt
- Focus state: scale up to 1.08x and add subtle glow, unless Reduce Motion is enabled.

**Text (on-card overlay or below card, choose one, must be consistent)**
- Title (max 1 line, truncating tail)
- Year (from release date or first air date)
- Score: “★ 7.8” (one decimal)
- Small badge: MOVIE or TV (or icons)

**Fallbacks**
- Missing poster: show branded placeholder with title text.
- Missing date: year shows “TBA”.
- Missing score: show “★ -”.

### 3.4 Filter Bar
**Position:** fixed at top.

**Focus rules**
- D-pad Up from first grid row moves focus into filter bar.
- D-pad Down from filter bar returns to last focused grid item.
- When empty state appears, focus MUST move to “Clear All Filters”.

**Controls**
1. Content Type: All, Movies, TV Shows
2. Sort: Trending, Popularity, Release Date (Newest), Release Date (Oldest), Rating (Highest), Rating (Lowest)
3. Genre: single select, All Genres clears
4. Release Date Range: Upcoming, This Month, Last 30 Days, Last 90 Days, This Year, All Time
5. Certification: Movies only, US ratings, exact match (G, PG, PG-13, R, NC-17), All Certifications clears
6. Refresh button: forces network refresh, bypasses cache

**Inline State Display**
- Display compact pill text like: `[All • Trending • Action] [2 filters]`
- Active filter count counts genre, certification, and non-AllTime date range.

### 3.5 Sort and Filter Interaction Rules (Hard Rules)
These rules MUST be enforced at the state level (not only in UI).
1. If Sort = Trending AND any filter is active (genre, certification, date range), then:
   - Sort MUST auto-switch to Popularity
   - UI MUST reflect Popularity selected
   - VoiceOver announces the change
2. If Date Range = Upcoming AND Sort is Trending or Popularity, then:
   - Sort MUST auto-switch to Release Date (Newest)
   - UI MUST reflect Release Date (Newest)

### 3.6 Detail Screen
**Layout**
- Backdrop image with gradient overlay (fallback: #1a1a1a)
- Left: poster
- Right: title, tagline, metadata, score, overview

**Fields**
- Title
- Tagline (if present)
- Release date (formatted “March 15, 2025”)
- Runtime:
  - Movies: “2h 15m”
  - TV: “45 min/episode” (use first episode runtime if multiple)
- Genres: “Action, Adventure, Sci-Fi”
- Certification:
  - Movies: US rating, else “NR”
  - TV: US rating, else “NR”
- Score: “7.8/10 (1,234 votes)”
- Overview: focusable scroll region
- Trailer line: “YouTube • Official Trailer • 1080p” (only if trailer exists)

**Actions**
- Primary button: “Play in YouTube”
  - Disabled if no YouTube trailer, label becomes “No Trailer Available”
- If multiple YouTube trailers:
  - Show selector list, sorted by trailer ranking rules (Appendix C)
- Close:
  - Menu/Back button support
  - Visible Close button (for accessibility)

**TMDB attribution**
- Show “Powered by TMDB” logo (bottom-right).
- Provide a context menu action on the logo: “Open TMDB” (opens tmdb.org).

### 3.7 Playback
- Open trailer using Universal Link:
  - `https://www.youtube.com/watch?v={videoKey}`
- tvOS will route to the YouTube app if installed.
- If YouTube is not installed, tvOS will open a limited web view.
- App does not auto-return after playback, user switches back manually.

### 3.8 Accessibility (UI-level requirements)
- All interactive elements have accessibility labels.
- Poster card VoiceOver format:
  - “{Title}, {Year}, rated {Score} out of 10, {Movie|TV}”
- Filter change announcements debounced by 500ms to avoid chatter.
- Respect Reduce Motion:
  - Disable scale/glow focus animations, use border highlight instead.

---

## 4. Architecture Overview

### 4.1 Layering (MUST)
- Views (SwiftUI): render state, no networking.
- ViewModels (MVVM): state machines, user intents, coordinate loads.
- Services: TMDB client, caching, network monitor, image pipeline.
- Models:
  - DTOs for decoding raw TMDB responses
  - Domain models for UI consumption

### 4.2 Concurrency Model (MUST)
- All ViewModels are `@MainActor`.
- Network + cache coordination is done in an `actor` to guarantee thread safety.
- Every user-triggered reload has a cancellation token, old tasks must be cancelled on state changes.

### 4.3 Key State Machines
#### 4.3.1 Grid State
```
idle
→ loadingInitial
→ loaded(items)
→ loadingNextPage(items)
→ loaded(items)
→ exhausted(items)    (no more pages)
↘ error(lastGoodItems?, errorKind)
↘ empty(filtersApplied)
```

#### 4.3.2 Detail State
```
idle
→ loading
→ loaded(detail, trailers[])
↘ error(partialDetail?, errorKind)
```

---

## 5. Data Models

### 5.1 Domain Models (UI-facing)

#### 5.1.1 Identifiers
- `MediaType`: `.movie` or `.tv`
- `MediaID`: `{ type: MediaType, id: Int }`, used everywhere for dedupe and routing.

#### 5.1.2 MediaSummary (Grid Item)
Fields:
- `id: MediaID`
- `title: String`
- `posterPath: String?`
- `backdropPath: String?`
- `overview: String` (may be empty)
- `releaseDate: Date?`
- `yearText: String` (derived, “2025” or “TBA”)
- `voteAverage: Double?` (nil if missing)
- `voteCount: Int?`
- `genreIDs: [Int]`
- `popularity: Double?`

#### 5.1.3 MediaDetail (Detail Screen)
Fields:
- `summary: MediaSummary` (or `id`, then computed)
- `tagline: String?`
- `runtimeMinutes: Int?` (movie)
- `episodeRuntimeMinutes: Int?` (tv)
- `genres: [Genre]` (name + id)
- `certification: String` (“PG-13”, “NR”)
- `videos: [Video]` (raw list for ranking)

#### 5.1.4 Video (Trailer)
Fields:
- `id: String`
- `key: String` (YouTube ID)
- `name: String`
- `site: String` (must equal “YouTube” to be playable)
- `size: Int?` (e.g., 1080)
- `type: String` (“Trailer”, “Teaser”, etc)
- `official: Bool`
- `publishedAt: Date?`

Computed:
- `isYouTube`
- `youtubeURL`

### 5.2 DTO Models (TMDB decoding)
Use DTOs that match TMDB JSON shape. Use `JSONDecoder.keyDecodingStrategy = .convertFromSnakeCase`.

**Important:** `/trending/all/*` returns **people** as well as movies and tv. The decoder MUST tolerate unknown media types and skip them.

Recommended DTO approach:
- `TrendingAllDTO` with `results: [TrendingAllResultDTO]`
- `TrendingAllResultDTO` is an enum:
  - `.movie(TMDBMovieListDTO)`
  - `.tv(TMDBTVListDTO)`
  - `.unsupported` (person or unknown)

Implementation detail:
- decode `media_type` first, then decode into the appropriate DTO, else return `.unsupported` instead of throwing.

### 5.3 Genre
- Domain: `Genre { id: Int, name: String }`
- Fetch:
  - `/genre/movie/list`
  - `/genre/tv/list`
- Cache to disk.

### 5.4 Filter State
Store as a single struct, mutated only via intent methods to enforce invariants.

Fields:
- `contentType: all | movies | tvShows`
- `sort: trending | popularity | releaseDateNewest | releaseDateOldest | ratingHighest | ratingLowest`
- `genre: Genre?`
- `dateRange: upcoming | thisMonth | last30Days | last90Days | thisYear | allTime`
- `certification: String?` (movies only)

Derived:
- `hasActiveFilters`
- `activeFilterCount`

Rules:
- Leaving Movies clears certification.
- Genre must be validated against available genre lists, if invalid it clears.
- Sort interaction rules apply after every mutation.

---

## 6. TMDB API Integration

### 6.1 Authentication
Use **TMDB v4 Read Access Token** in the Authorization header:
- `Authorization: Bearer {TMDB_READ_ACCESS_TOKEN}`
- `Accept: application/json`

Store token in build configuration (xcconfig), never commit secrets.

### 6.2 Endpoints Used
**Trending**
- `/trending/movie/week`
- `/trending/tv/week`
- `/trending/all/week` (must ignore people)

**Discover**
- `/discover/movie`
- `/discover/tv`

**Details**
- `/movie/{id}?append_to_response=release_dates,videos`
- `/tv/{id}?append_to_response=content_ratings,videos`

**Genres**
- `/genre/movie/list`
- `/genre/tv/list`

### 6.3 Endpoint Routing Rules (MUST)
Given FilterState:
1. If `sort == trending` AND `hasActiveFilters == false`:
   - If `contentType == movies`: trending/movie
   - If `contentType == tvShows`: trending/tv
   - If `contentType == all`: trending/all, then drop non movie/tv results
2. Else:
   - Use discover endpoint(s) with mapped sort_by and filters
   - If `contentType != all`: call only one discover endpoint
   - If `contentType == all`: call both discover endpoints and merge (Section 8)

### 6.4 Discover Query Parameter Mapping
Common:
- `page`
- `sort_by` mapped from app Sort
- `with_genres` if genre selected (IDs differ movie vs tv, see Section 7)
- Date range:
  - Movies: `primary_release_date.gte`, `primary_release_date.lte`
  - TV: `first_air_date.gte`, `first_air_date.lte`
- Rating sorts:
  - `vote_count.gte = 50` for ratingHighest and ratingLowest
- Movies only:
  - `certification_country=US`
  - `certification={selected}`
  - `region=US`
  - `include_adult=false`

### 6.5 Dates for API
TMDB date filters expect `YYYY-MM-DD` strings.
- Compute boundaries in the user’s local time zone.
- Convert boundaries to `YYYY-MM-DD` by extracting local calendar components, do not format in UTC.

Date range definitions:
- Upcoming: tomorrow (start of day) through today + 365 days (start of day), inclusive
- This Month: start of current month through end of current month, inclusive
- Last 30 Days: start of day (today - 30) through start of today, inclusive
- Last 90 Days: start of day (today - 90) through start of today, inclusive
- This Year: Jan 1 through Dec 31 of current year, inclusive
- All Time: omit date constraints

If a media item has a missing date:
- Exclude it from date-filtered results (TMDB does this implicitly in many cases, still treat as excluded in domain logic).
- In date sorts, nil dates sort after all dated items for Newest, and before all dated items for Oldest.

### 6.6 Detail Fetch, Certification Extraction
Detail calls MUST be single requests using append_to_response.

- Movies:
  - Extract US certification from `release_dates.results` where `iso_3166_1 == "US"`.
  - Choose the first non-empty certification, using this priority for release type if present: Theatrical (3) > Theatrical limited (2) > Digital (4) > Physical (5) > TV (6) > Premiere (1).
  - If none found, certification = “NR”.

- TV:
  - Extract US rating from `content_ratings.results` where `iso_3166_1 == "US"`.
  - If missing, “NR”.

### 6.7 Trailer Extraction and Ranking
- Use `videos.results`.
- Filter: `site == "YouTube"`.
- If none, show “No Trailer Available”.
- Rank using Appendix C.

---

## 7. Genre Mapping in “All” Mode

When Content Type = All and using discover endpoints:
- Fetch both movie and tv genre lists at launch (or first use).
- Show a unified genre picker by name.
- When a genre is selected, map by exact name match (case-insensitive) to:
  - movie genre id (if exists)
  - tv genre id (if exists)
- If a genre exists for one type but not the other, still allow it, but only query the type(s) where it exists.

Hardcoded overrides (only if exact name mismatch is known):
- Action: movie 28, tv 10759
- Sci-Fi: movie 878, tv 10765
- War: movie 10752, tv 10768

If mapping fails unexpectedly:
- Log the mismatch.
- Fail gracefully, return results from the type that has a valid mapping, do not crash.

---

## 8. Pagination + “All” Mode Merge Algorithm

### 8.1 General Pagination Rules
- Page size is 20 per TMDB response.
- Initial load:
  1. Fetch Page 1
  2. After success, fetch Page 2 (prefetch), sequentially
- Next page trigger:
  - Trigger when focused item is within 3 rows of the end of loaded content.
  - Debounce trigger by 300ms.

Stop conditions:
- Respect `total_pages`.
- When at last page, transition state to `exhausted`.

Deduping:
- Deduplicate by `MediaID` across pages and across types.

### 8.2 “All” Mode, Discover Merge
When `contentType == all` and using discover endpoints, implement a streaming merge:
- Maintain:
  - `movieBuffer: [MediaSummary]`
  - `tvBuffer: [MediaSummary]`
  - `moviePage`, `tvPage`
  - `movieExhausted`, `tvExhausted`
- Each buffer is kept at or above a target lookahead (default 40 items).
- Fetch concurrently as needed, but cap total concurrent requests globally (Section 9).

Merge selection:
- Repeatedly pick head element from buffers using the selected sort comparator.
- Comparator rules:
  - Primary: chosen sort field
  - Tie-breaker 1: popularity desc (if available)
  - Tie-breaker 2: MediaType (movie before tv, deterministic)
  - Tie-breaker 3: id asc

Nil handling:
- For descending sorts, nil values sort last.
- For ascending sorts, nil values sort first.

When one type exhausts:
- Continue returning items from remaining buffer/type only.

### 8.3 Buffer Growth Limits
To keep implementation simple and safe:
- Keep at most 500 MediaSummary items in memory for the current session.
- On memory warning, clear non-essential caches (image memory cache), do not drop visible items.

---

## 9. Networking, Caching, Rate Limits

### 9.1 Network Client (actor, MUST)
Implement `NetworkClient` as an `actor` responsible for:
- Building requests
- Applying auth headers
- Enforcing concurrency limit (max 4 in-flight)
- Request deduplication (same URL within 500ms returns same Task)
- Backoff on 429
- Returning typed decoded DTOs

### 9.2 Caching (MUST)
Implement `ResponseCache` with:
- Memory cache: `NSCache`
- Disk cache: files in `Caches/APIResponseCache/`
- Each entry stores:
  - `storedAt: Date`
  - `payload: Data` (raw JSON or encoded DTO)

TTLs:
- Genres: 7 days (refresh automatically if older)
- Grid (trending/discover): 5 minutes
- Detail: 30 minutes

Cache key:
- Canonical string:
  - `endpoint|contentType|sort|genreMovieID|genreTVID|cert|dateRange|page|language|region`
- Hash to filename (SHA256) to avoid filesystem issues.

Refresh button:
- Bypass cache for the current query and update cache with fresh result.

Offline:
- If network unavailable, return cached results even if expired, show “Offline, showing cached results”.

### 9.3 Error Handling (HTTP)
- 401: configuration error, show setup screen with API token instructions, no retry.
- 403: access denied, no retry.
- 404: content not found, remove item from grid if encountered in detail fetch.
- 429: exponential backoff, start 1s, max 30s, max 5 retries, show countdown.
- 5xx: retry with backoff, fallback to cached.

### 9.4 Network Reachability
- Use `NWPathMonitor` to show a small “Offline” badge.
- Reachability is advisory, do not prevent requests, it only changes UI messaging.

---

## 10. Implementation Details (File-by-File)

### 10.1 Project Structure
```
Trailers/
  App/
    TrailersApp.swift
  Core/
    Config.swift
    Constants.swift
    Logging.swift
    DateUtils.swift
  Models/
    Domain/
      MediaType.swift
      MediaID.swift
      MediaSummary.swift
      MediaDetail.swift
      Genre.swift
      Video.swift
      FilterState.swift
    DTO/
      TMDBPaginatedDTO.swift
      TMDBMovieListDTO.swift
      TMDBTVListDTO.swift
      TMDBTrendingAllDTO.swift
      TMDBMovieDetailDTO.swift
      TMDBTVDetailDTO.swift
      TMDBGenreListDTO.swift
      TMDBVideoDTO.swift
  Services/
    NetworkClient.swift
    TMDBService.swift
    ResponseCache.swift
    NetworkMonitor.swift
    ImagePipeline.swift
    YouTubeLauncher.swift
  ViewModels/
    FilterViewModel.swift
    ContentGridViewModel.swift
    DetailViewModel.swift
  Views/
    Root/
      BrowseView.swift
    Components/
      FilterBarView.swift
      PosterCardView.swift
      LoadingFooterView.swift
      EmptyStateView.swift
    Screens/
      DetailView.swift
      TrailerSelectorView.swift
      ErrorOverlayView.swift
  Tests/
    Unit/
    UI/
```

### 10.2 Responsibilities
- `TMDBService`: maps FilterState to endpoint calls, returns domain models.
- `NetworkClient`: fetch + decode DTOs, enforce rate limits and dedupe.
- `ResponseCache`: read/write, TTL checks.
- `ContentGridViewModel`: owns grid state machine, pagination, cancellations.
- `FilterViewModel`: owns FilterState and validation, emits changes.
- `DetailViewModel`: loads detail, extracts certification and trailers.
- `YouTubeLauncher`: builds URL and opens it.

---

## 11. ViewModel Contracts (Explicit)

### 11.1 FilterViewModel
State:
- `filterState: FilterState`
- `movieGenres: [Genre]`, `tvGenres: [Genre]`, `unifiedGenres: [GenreDisplay]`

Intents:
- `setContentType(...)`
- `setSort(...)`
- `setGenre(...)`
- `setDateRange(...)`
- `setCertification(...)`
- `clearAllFilters()`

Each intent MUST:
- Update state
- Apply invariants (Section 5.4, 3.5)
- Publish a `FilterChange` event to grid VM

### 11.2 ContentGridViewModel
State:
- `gridState: GridState`
- `items: [MediaSummary]`
- `lastFocusedID: MediaID?`
- `isRefreshing: Bool`

Intents:
- `loadInitial()`
- `loadNextPageIfNeeded(focusedIndex: Int)`
- `refresh()`
- `applyFilters(filterState: FilterState)`

Rules:
- Only one “active load task” at a time.
- On applyFilters:
  - cancel active task(s)
  - reset pagination counters
  - clear items
  - set state loadingInitial
  - load page 1 then prefetch page 2
- Pagination MUST be idempotent:
  - If already loading next page, ignore repeated triggers.

### 11.3 DetailViewModel
State:
- `detailState: DetailState`
- `selectedTrailer: Video?`

Intents:
- `load(id: MediaID)`
- `selectTrailer(video: Video)`
- `playSelectedTrailer()`

Rules:
- When load starts, cancel prior detail task.
- If detail fetch fails, show partial info from grid summary.

---

## 12. Testing (Must Be Automatable)

### 12.1 Unit Tests (Minimum)
- DTO decoding:
  - trending/all skips people without failing decode
  - movie list decode
  - tv list decode
  - detail decode includes videos and rating containers
- Filter invariants:
  - leaving Movies clears certification
  - Trending + filters auto-switches to Popularity
  - Upcoming + Trending/Popularity auto-switches to Release Date Newest
- Merge algorithm:
  - correct ordering for popularity and date sorts
  - nil date handling
  - one buffer exhausted
  - stable deterministic ordering
- Cache:
  - TTL expiry behavior
  - refresh bypass
  - offline uses stale cache

### 12.2 UI Tests (Minimum)
- D-pad navigation grid ↔ filter bar
- Empty state focus on “Clear All Filters”
- Detail view opens and closes, focus restored to same poster
- Loading footer is focusable
- Reduce Motion changes focus behavior (snapshot or functional)

---

## 13. Build and Run Instructions (Sideload)

1. Create new Xcode project:
   - App, tvOS, SwiftUI, Swift
2. Set minimum tvOS to 17.0
3. Add Swift Package dependencies:
   - Nuke
   - NukeUI (if using LazyImage)
4. Add `Config.xcconfig` (not committed) containing:
   - `TMDB_READ_ACCESS_TOKEN = <token>`
5. In Info.plist, add:
   - `TMDB_READ_ACCESS_TOKEN` key from build settings
6. Build and run to Apple TV device via Xcode.

Note:
- Free Apple Developer accounts require redeploy every 7 days.

---

## 14. Appendix A: Sort Mapping Table
- Trending: use trending endpoints only when no filters and sort=Trending
- Popularity: `sort_by=popularity.desc`
- Release Date Newest:
  - movies: `sort_by=primary_release_date.desc`
  - tv: `sort_by=first_air_date.desc`
- Release Date Oldest:
  - movies: `sort_by=primary_release_date.asc`
  - tv: `sort_by=first_air_date.asc`
- Rating Highest: `sort_by=vote_average.desc` + `vote_count.gte=50`
- Rating Lowest: `sort_by=vote_average.asc` + `vote_count.gte=50`

---

## 15. Appendix B: Trailer Ranking Rules
Given YouTube videos only:
1. Prefer `official == true`
2. Prefer `type` in this order: Trailer, Teaser, Clip, Featurette, Behind the Scenes
3. Prefer name containing “Official Trailer” (case-insensitive)
4. Prefer highest `size`
5. Prefer newest `publishedAt`
6. Tie-breaker: stable by `id`

---

## 16. Appendix C: QA Checklist (Manual)
- Launch loads content within 2 seconds on typical network
- Scrolling remains smooth with 100+ items
- Filters apply immediately, no stale results
- No crashes when trending/all returns people
- Detail shows “NR” when rating missing
- YouTube launch works
- Offline shows cached content with badge
- Reduce Motion respected
- VoiceOver announcements correct and not spammy
