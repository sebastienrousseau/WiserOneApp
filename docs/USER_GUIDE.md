# The Wiser One - User Guide

Welcome to The Wiser One! This guide will help you make the most of your daily wisdom companion.

## What is The Wiser One?

The Wiser One is a minimalist desktop application that delivers daily nuggets of wisdom through your system tray. It's designed to inspire deeper thought and personal growth with every interaction.

## Getting Started

### Installation

#### Download Pre-built Binaries

Visit the [Releases page](https://github.com/sebastienrousseau/WiserOneApp/releases) and download the appropriate version for your platform:

- **Linux**: `wiserone-linux-x64.tar.gz`
- **macOS**: `wiserone-macos-x64.dmg`
- **Windows**: `wiserone-windows-x64.zip`

#### Linux Installation
```bash
# Extract the archive
tar -xzf wiserone-linux-x64.tar.gz

# Install system-wide (optional)
sudo cp usr/bin/wiserone /usr/local/bin/
sudo cp usr/share/applications/com.wiserone.WiserOne.desktop /usr/share/applications/
sudo cp usr/share/icons/hicolor/256x256/apps/com.wiserone.WiserOne.png /usr/share/icons/hicolor/256x256/apps/

# Update desktop database
sudo update-desktop-database

# Run the application
wiserone
```

#### macOS Installation
1. Open the downloaded `.dmg` file
2. Drag "The Wiser One" to your Applications folder
3. Launch from Applications or Spotlight (⌘+Space, type "Wiser One")

#### Windows Installation
1. Extract the `.zip` file to your desired location
2. Run `WiserOne.exe`
3. (Optional) Create a shortcut on your Desktop or Start Menu

### First Launch

When you first launch The Wiser One:

1. **System Tray Icon**: Look for the Wiser One logo in your system tray/notification area
2. **Initial Quote**: Click the tray icon to see your first quote
3. **Auto-start**: The app will remember your preference and can start with your system

## Using The Wiser One

### Basic Operations

#### Viewing Quotes

1. **Click the tray icon** to open the quote menu
2. **Read the quote** - Each quote includes the text and author
3. **Get a new quote** - Click "Refresh" (🔄) for a different quote

#### Menu Options

Right-click the tray icon to access:

- **Current Quote** - Displays the selected quote and author
- **Refresh** (🔄) - Load a new random quote
- **Visit Website** (🌐) - Open wiserone.com in your browser
- **About** (ℹ️) - View application information
- **Quit** - Close the application

### Quote System

#### How Quotes Work

- **Random Selection**: Each refresh selects a truly random quote
- **Monthly Collections**: Quotes are organized by month for seasonal relevance
- **Variety**: Over 1000+ carefully curated quotes from diverse sources
- **Categories**: Quotes span wisdom, inspiration, motivation, and reflection

#### Quote Sources

Our collection includes wisdom from:
- **Philosophers**: Ancient and modern thinkers
- **Authors**: Renowned writers and poets
- **Leaders**: Historical figures and innovators
- **Spiritual Teachers**: Various traditions and cultures

### Customization

#### Theme Support

The Wiser One automatically adapts to your system theme:

- **Dark Mode**: Icon and UI adjust for dark themes
- **Light Mode**: Optimized for light system themes
- **Automatic**: Changes when you switch system themes

#### Language Support

The Wiser One supports 15 languages:

- English, Français, Español, Deutsch, Português
- 简体中文, 日本語, 한국어, Русский, Italiano
- العربية, עברית, हिंदी, Nederlands, Bahasa Indonesia

Language is automatically detected from your system locale.

### Integration Features

#### System Integration

- **System Tray**: Lives quietly in your notification area
- **Auto-start**: Option to launch with your system (coming soon)
- **Click-through**: Access quotes without disrupting your workflow
- **Minimal Resource Usage**: Designed for always-on operation

#### Website Integration

- **Logo Click**: Click the Wiser One logo to visit wiserone.com
- **Extended Content**: Access additional wisdom and insights online
- **Community**: Connect with other users seeking wisdom

## Keyboard Shortcuts

When the quote popup is open:

- **Esc** - Close the quote popup
- **Space** - Refresh to get a new quote
- **Enter** - Visit the website

## Advanced Usage

### Quote Popup Window

The quote popup offers an immersive experience:

#### Features
- **Clean Design**: Distraction-free quote presentation
- **Logo Display**: Beautiful SVG logo with crisp scaling
- **Action Buttons**: Quick access to refresh, website, and settings
- **Smart Positioning**: Appears near your cursor for convenience

#### Interaction
- **Click Logo**: Opens wiserone.com
- **Click Outside**: Closes the popup
- **Button Bar**: Use refresh, website, or about buttons
- **Auto-close**: Automatically closes when focus is lost

### Error Logging

The Wiser One logs errors to help with troubleshooting:

- **Log Location**: `~/Documents/appLog.txt`
- **Content**: Timestamps, error descriptions, and context
- **Privacy**: Only technical errors logged, no personal data

## Troubleshooting

### Common Issues

#### Application Won't Start

**Symptoms**: Double-click does nothing, no tray icon appears

**Solutions**:
1. Check if your system supports system tray icons
2. Try running from terminal to see error messages:
   ```bash
   # Linux/macOS
   ./wiserone

   # Windows (Command Prompt)
   WiserOne.exe
   ```
3. Ensure Qt6 runtime libraries are available

#### No Tray Icon Visible

**Symptoms**: Application runs but no icon in system tray

**Possible Causes**:
- Desktop environment doesn't support tray icons
- Tray area is hidden or collapsed
- Application failed to register tray icon

**Solutions**:
- **GNOME**: Install "AppIndicator and KStatusNotifierItem Support" extension
- **KDE**: Check system tray settings in System Settings
- **Windows**: Check if tray icons are hidden (show hidden icons)
- **macOS**: Look in the menu bar (top right)

#### Quotes Not Loading

**Symptoms**: Empty quotes or error messages

**Solutions**:
1. Check the error log at `~/Documents/appLog.txt`
2. Restart the application
3. Ensure application files weren't corrupted during installation

#### High Memory Usage

**Symptoms**: Application using excessive RAM

**Investigation**:
1. Check with system monitor (Task Manager, Activity Monitor, htop)
2. Normal usage should be under 50MB
3. If higher, restart the application

### Platform-Specific Issues

#### Linux

**Wayland Compositor Issues**:
```bash
# Try forcing X11
GDK_BACKEND=x11 ./wiserone
```

**AppImage Issues**:
```bash
# Make executable
chmod +x WiserOne-x86_64.AppImage
./WiserOne-x86_64.AppImage
```

#### macOS

**Gatekeeper Warnings**:
1. Right-click the app → "Open"
2. Or: System Preferences → Security & Privacy → Allow the app

**Menu Bar Hidden**:
- Check if you've hidden menu bar icons
- Look in "Control Center" → Menu Bar

#### Windows

**Antivirus Blocking**:
- Add WiserOne.exe to antivirus exceptions
- Check Windows Defender exclusions

**Missing DLLs**:
- Install Visual C++ Redistributable 2022
- Ensure all Qt6 DLLs are present

## Performance and Battery

### Resource Usage

The Wiser One is designed for minimal impact:

- **CPU**: Near-zero when idle, brief spikes during quote loading
- **Memory**: ~25-50MB RAM usage
- **Disk**: Small SQLite database for quotes (~2MB)
- **Network**: Only when accessing website features

### Battery Life

Optimizations for laptop users:

- **Intelligent Polling**: Reduces background activity
- **Event-Driven**: Only active when you interact
- **No Timers**: No periodic quote updates (user-initiated only)

## Privacy and Security

### Data Collection

The Wiser One respects your privacy:

- **No Analytics**: No usage tracking or statistics sent
- **No Network**: Quotes loaded from local database
- **No Personal Data**: No access to personal files or information

### Local Storage

Data stored on your device:

- **Quotes Database**: Local SQLite file with curated quotes
- **Error Log**: Technical errors only (no personal content)
- **Settings**: Application preferences (theme, position)

### Security Features

- **Read-Only Quotes**: Quote database is read-only during runtime
- **Sandboxed**: Application has minimal system permissions
- **Signed Binaries**: Official releases are code-signed (macOS/Windows)

## Accessibility

### Visual Accessibility

- **High Contrast**: Supports system high-contrast modes
- **Scalable Text**: Respects system font size settings
- **Color Blind Friendly**: Uses system color schemes

### Motor Accessibility

- **Large Click Targets**: Buttons sized for easy clicking
- **Keyboard Navigation**: Full keyboard support in popup
- **No Time Pressure**: No auto-advancing content

### Screen Readers

- **Accessible Text**: All UI elements properly labeled
- **Semantic Structure**: Proper heading hierarchy
- **Focus Management**: Logical tab order

## Getting Help

### Community Support

- **GitHub Discussions**: Ask questions and share tips
- **Issue Tracker**: Report bugs and request features
- **Wiki**: Community-contributed guides and tips

### Self-Help Resources

1. **Check the error log**: `~/Documents/appLog.txt`
2. **Try restarting**: Many issues resolve with a restart
3. **Update**: Ensure you're using the latest version
4. **Search Issues**: Someone might have faced the same problem

### Reporting Issues

When reporting a problem, include:

1. **Version**: The Wiser One version number (from About dialog)
2. **Platform**: Your operating system and version
3. **Steps**: How to reproduce the issue
4. **Error Log**: Relevant entries from `appLog.txt`
5. **Screenshots**: If applicable

## Updates and Releases

### Automatic Updates

Currently, updates are manual:

1. Check the [Releases page](https://github.com/sebastienrousseau/WiserOneApp/releases)
2. Download the latest version for your platform
3. Replace the old installation
4. Restart the application

### Release Schedule

- **Feature Releases**: Major updates every few months
- **Bug Fixes**: As needed for critical issues
- **Security Updates**: Immediate for security concerns

### What's Next

Planned features for future releases:

- **Auto-start Options**: Launch with system startup
- **Quote Favorites**: Save quotes you love
- **Custom Collections**: Import your own quotes
- **Notification Reminders**: Optional daily quote notifications
- **Export Features**: Share quotes easily

---

*Thank you for using The Wiser One! May wisdom guide your daily journey.*

Designed by Sebastien Rousseau — Engineered with Euxis