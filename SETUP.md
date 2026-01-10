# Trailers tvOS App - Setup Guide

This document provides step-by-step instructions to set up the Trailers tvOS app in Xcode.

## Prerequisites

- macOS 14.0 or later
- Xcode 15.0 or later
- Apple TV (HD or 4K) for device testing, or tvOS Simulator
- TMDB API account with Read Access Token

## Step 1: Create Xcode Project

1. Open Xcode
2. File → New → Project
3. Select **tvOS** → **App**
4. Configure project:
   - Product Name: `Trailers`
   - Team: Select your team
   - Organization Identifier: `com.personal` (or your identifier)
   - Interface: **SwiftUI**
   - Language: **Swift**
5. Click **Create**

## Step 2: Configure Minimum Deployment

1. Select the project in the navigator
2. Select the **Trailers** target
3. Go to **General** tab
4. Set **Minimum Deployments** → tvOS to **17.0**

## Step 3: Add Swift Package Dependencies

### Nuke (Optional but Recommended)

1. File → Add Package Dependencies
2. Enter URL: `https://github.com/kean/Nuke`
3. Select **Up to Next Major Version**: `12.0.0`
4. Click **Add Package**
5. Select both `Nuke` and `NukeUI`
6. Click **Add Package**

## Step 4: Configure API Token

### Create Config.xcconfig

1. Create a new file in the project root named `Config.xcconfig`
2. Add the following content:

```xcconfig
// Configuration settings for Trailers app
// DO NOT COMMIT THIS FILE TO VERSION CONTROL

// TMDB API Configuration
// Get your token from: https://www.themoviedb.org/settings/api
TMDB_READ_ACCESS_TOKEN = your_read_access_token_here
```

### Link Configuration File

1. Select the project in the navigator
2. Select the project (not target) in the editor
3. Go to **Info** tab
4. Under **Configurations**, expand **Debug** and **Release**
5. Set both to use `Config.xcconfig`

### Add to Info.plist

1. Select the project in the navigator
2. Select the **Trailers** target
3. Go to **Info** tab
4. Add a new row:
   - Key: `TMDB_READ_ACCESS_TOKEN`
   - Type: String
   - Value: `$(TMDB_READ_ACCESS_TOKEN)`

### Add to .gitignore

Create or update `.gitignore`:

```gitignore
# Configuration files with secrets
Config.xcconfig
*.xcconfig

# Xcode
DerivedData/
*.xcuserstate

# macOS
.DS_Store
```

## Step 5: Add Source Files

Copy all files from the `Trailers/` directory into your Xcode project:

1. In Xcode, right-click on the **Trailers** folder in the navigator
2. Select **Add Files to "Trailers"**
3. Navigate to the source files
4. Select all folders: `App`, `Core`, `Models`, `Services`, `ViewModels`, `Views`
5. Ensure "Copy items if needed" is checked
6. Ensure "Create groups" is selected
7. Click **Add**

## Step 6: Add Test Files

1. Create a new test target if not present:
   - File → New → Target
   - Select **tvOS** → **Unit Testing Bundle**
   - Product Name: `TrailersTests`

2. Create UI Test target:
   - File → New → Target
   - Select **tvOS** → **UI Testing Bundle**
   - Product Name: `TrailersUITests`

3. Add test files to respective targets

## Step 7: Configure Build Settings

### Enable Strict Concurrency

1. Select the project
2. Select the **Trailers** target
3. Go to **Build Settings**
4. Search for "Strict Concurrency"
5. Set to **Complete**

### Enable All Warnings

1. Search for "warnings"
2. Set **Treat Warnings as Errors** to **Yes** for Release

## Step 8: Add TMDB Attribution Assets

1. Create an asset for TMDB logo:
   - Download TMDB logo from their branding page
   - Add to Assets.xcassets as `tmdb-logo`

## Step 9: Build and Run

### Simulator

1. Select **Apple TV 4K (3rd generation)** simulator
2. Press **Cmd+R** to build and run

### Device

1. Connect Apple TV to your Mac via USB-C or ensure on same network
2. Enable Developer Mode on Apple TV:
   - Settings → Remotes and Devices → Remote App and Devices
3. Add Apple TV to Xcode:
   - Window → Devices and Simulators
   - Connect via network or USB
4. Select your Apple TV from the device dropdown
5. Press **Cmd+R** to build and run

## Step 10: Run Tests

### Unit Tests

```bash
Cmd+U
```

Or via command line:
```bash
xcodebuild test \
  -scheme Trailers \
  -destination 'platform=tvOS Simulator,name=Apple TV 4K (3rd generation)'
```

### UI Tests

```bash
xcodebuild test \
  -scheme TrailersUITests \
  -destination 'platform=tvOS Simulator,name=Apple TV 4K (3rd generation)'
```

## Troubleshooting

### "API configuration error" on launch

- Verify `Config.xcconfig` exists and contains valid token
- Verify Info.plist has `TMDB_READ_ACCESS_TOKEN` key
- Clean build folder (Cmd+Shift+K) and rebuild

### "No such module" errors

- Verify all source files are added to target
- Clean build folder and rebuild
- Check file target membership in File Inspector

### Simulator shows black screen

- Ensure minimum deployment is tvOS 17.0
- Reset simulator: Device → Erase All Content and Settings

### Device deployment fails every 7 days

- Free Apple Developer accounts require re-deployment weekly
- Consider upgrading to paid Apple Developer Program ($99/year)

## Project Configuration Summary

| Setting | Value |
|---------|-------|
| Deployment Target | tvOS 17.0 |
| Swift Version | 5.9 |
| Interface | SwiftUI |
| Architecture | arm64 |
| Strict Concurrency | Complete |

## File Structure After Setup

```
TrailerApp/
├── Trailers.xcodeproj/
├── Config.xcconfig           (NOT in version control)
├── .gitignore
├── README.md
├── SETUP.md
└── Trailers/
    ├── App/
    ├── Core/
    ├── Models/
    ├── Services/
    ├── ViewModels/
    ├── Views/
    ├── Resources/
    │   └── Assets.xcassets/
    └── Tests/
        ├── Unit/
        └── UI/
```
