# The Wiser One - API Reference

This document provides comprehensive API documentation for all public classes, methods, and types in The Wiser One application.

## Architecture Overview

The Wiser One follows a modular architecture:

- **Application** - Main application lifecycle controller
- **TrayIcon** - System tray integration and menu management
- **QuoteManager** - Quote database and retrieval logic
- **QuoteWidget** - Popup quote display window
- **AboutDialog** - Application information dialog
- **ErrorLogger** - Thread-safe error logging system

## Core Classes

### Application

Main application controller that manages the lifecycle and coordinates components.

```cpp
#include "Application.h"

// Basic usage
Application app(parent);
if (app.initialize()) {
    qDebug() << "Application initialized successfully";
} else {
    qWarning() << "Failed to initialize application";
}
```

#### Public Methods

**`bool initialize()`**
- Initializes the application and shows the tray icon
- Returns: `true` if successful, `false` if tray unavailable
- Must be called before the application is usable

**`std::expected<void, AppError> tryInitialize()`**
- Initializes with detailed error information
- Returns: `Expected<void>` on success, `AppError` on failure
- Use when you need specific error details

```cpp
auto result = app.tryInitialize();
if (!result) {
    QString error = Application::errorMessage(result.error());
    qCritical() << "Init failed:" << error;
}
```

**`bool isInitialized() const noexcept`**
- Check if the application was successfully initialized
- Returns: `true` if ready for use

**`static QString errorMessage(AppError error) noexcept`**
- Convert error enum to human-readable message
- Parameter: `error` - The AppError to describe
- Returns: Descriptive error string

#### Error Types

```cpp
enum class AppError {
    TrayUnavailable,  // System tray is not available
    TrayShowFailed    // Failed to show tray icon
};
```

#### Signals

**`void initialized()`** - Emitted when initialization succeeds
**`void initializationFailed(const QString& reason)`** - Emitted when initialization fails

### QuoteManager

Manages quotes using SQLite for fast random access, optimized for large collections.

```cpp
#include "QuoteManager.h"

QuoteManager manager;
Quote quote = manager.getRandomQuote();
if (quote.isValid()) {
    qDebug() << quote.text << "by" << quote.author;
}
```

#### Public Methods

**`Quote getRandomQuote()`**
- Get a random quote from the database
- Returns: A randomly selected quote, or fallback if none available
- Never returns invalid quote (always has fallback)

**`QuoteResult tryGetRandomQuote()`**
- Get a random quote with error information
- Returns: `Expected<Quote, QuoteError>` with detailed error info
- Use when you need to handle specific error conditions

```cpp
auto result = manager.tryGetRandomQuote();
if (result) {
    qDebug() << "Quote:" << result->text;
} else {
    qWarning() << "Failed to get quote";
}
```

**`QuoteResult getRandomQuoteByCategory(const QString& category)`**
- Get a random quote from a specific category
- Parameter: `category` - Category name to filter by
- Returns: `Expected<Quote, QuoteError>`

**`bool hasQuotes() const`**
- Check if the database has any quotes
- Returns: `true` if quotes are available

**`std::int64_t quoteCount() const`**
- Get total number of quotes in the database
- Returns: Number of quotes (cached for performance)

**`QStringList categories() const`**
- Get all available categories
- Returns: List of unique category names

#### Quote Structure

```cpp
struct Quote {
    std::int64_t id{0};    // Unique database ID
    QString text;          // Quote text content
    QString author;        // Quote author name
    QString category;      // Category classification

    bool isValid() const noexcept;  // Check if quote has content
    bool operator==(const Quote&) const = default;  // Comparison
};
```

#### Error Types

```cpp
enum class QuoteError {
    DatabaseError,   // Database connection or query failed
    EmptyCollection  // No quotes found in database
};
```

### TrayIcon

System tray icon manager that handles the tray icon, context menu, and quote display.

```cpp
#include "TrayIcon.h"

// Check availability first
if (!TrayIcon::isAvailable()) {
    qWarning() << "System tray not available";
    return;
}

auto trayIcon = std::make_unique<TrayIcon>(parent);
if (trayIcon->show()) {
    qDebug() << "Tray icon shown successfully";
}
```

#### Public Methods

**`bool show()`**
- Show the tray icon in the system tray
- Returns: `true` if successfully shown, `false` if tray unavailable
- Must be called after construction

**`static bool isAvailable() noexcept`**
- Check if system tray is available on this platform
- Returns: `true` if system tray is supported and available
- Always check before creating TrayIcon instance

**`static bool isDarkThemeStatic()`**
- Check if the system is using dark theme
- Returns: `true` if dark theme detected, `false` for light theme
- Uses platform-specific APIs for detection

#### Signals

**`void quoteDisplayed(const QString& quote, const QString& author)`**
- Emitted when a quote is displayed in the menu

**`void websiteRequested()`**
- Emitted when user clicks "Visit Website"

**`void quitRequested()`**
- Emitted when user clicks "Quit"

### ErrorLogger

Thread-safe singleton logger for error tracking.

```cpp
#include "ErrorLogger.h"

// Basic usage
ErrorLogger::instance().log(__FILE__, __func__, "Something went wrong");

// With error handling
auto result = ErrorLogger::instance().tryLog(__FILE__, __func__, "Critical error");
if (!result) {
    qCritical() << "Failed to write to log file";
}
```

#### Public Methods

**`static ErrorLogger& instance() noexcept`**
- Get the singleton instance
- Returns: Reference to the singleton ErrorLogger
- Thread-safe lazy initialization

**`void log(const QString& file, const QString& method, const QString& error)`**
- Log an error message with timestamp
- Parameters: source file, method name, error description
- Thread-safe operation

**`void log(QStringView file, QStringView method, const QString& error)`**
- Performance-optimized version for string literals
- Parameters: source file view, method view, error description

**`std::expected<void, LogError> tryLog(...)`**
- Log with result indicating success/failure
- Returns: `Expected<void, LogError>`
- Use when you need to handle logging failures

**`QString logFilePath() const noexcept`**
- Get the log file path
- Returns: Absolute path to `~/Documents/appLog.txt`

**`std::expected<void, LogError> clearLog()`**
- Clear the log file contents
- Returns: `Expected<void, LogError>`

#### Error Types

```cpp
enum class LogError {
    FileOpenFailed,  // Could not open log file
    WriteFailed      // Could not write to log file
};
```

## Usage Examples

### Complete Application Setup

```cpp
#include <QApplication>
#include "Application.h"

int main(int argc, char *argv[])
{
    QApplication qtApp(argc, argv);

    Application app;

    // Connect to application signals
    QObject::connect(&app, &Application::initialized, []() {
        qDebug() << "App ready!";
    });

    QObject::connect(&app, &Application::initializationFailed,
                    [](const QString& reason) {
        qCritical() << "Failed to start:" << reason;
        QApplication::quit();
    });

    // Initialize and run
    if (!app.initialize()) {
        return 1;
    }

    return qtApp.exec();
}
```

### Error Handling Patterns

```cpp
// Pattern 1: Simple error logging
void someFunction() {
    if (somethingWrong) {
        ErrorLogger::instance().log(__FILE__, __func__,
                                   "Operation failed");
        return;
    }
}

// Pattern 2: Expected-based error handling
std::expected<Quote, QuoteError> getQuoteSafely(QuoteManager& manager) {
    auto result = manager.tryGetRandomQuote();
    if (!result) {
        ErrorLogger::instance().log(__FILE__, __func__,
                                   "Failed to get quote");
        return std::unexpected(result.error());
    }
    return result.value();
}

// Pattern 3: Application error handling
void initializeApp(Application& app) {
    auto result = app.tryInitialize();
    if (!result) {
        QString message = Application::errorMessage(result.error());
        ErrorLogger::instance().log(__FILE__, __func__, message);

        switch (result.error()) {
        case AppError::TrayUnavailable:
            // Show main window instead
            showMainWindow();
            break;
        case AppError::TrayShowFailed:
            // Retry or fallback
            retryWithDelay();
            break;
        }
    }
}
```

### Quote Management Examples

```cpp
// Get quotes by category
QuoteManager manager;
auto quotes = manager.getRandomQuoteByCategory("inspiration");
if (quotes) {
    displayQuote(quotes.value());
}

// Check database status
if (!manager.hasQuotes()) {
    qWarning() << "No quotes available";
} else {
    qDebug() << "Database has" << manager.quoteCount() << "quotes";
    qDebug() << "Categories:" << manager.categories().join(", ");
}

// Safe quote retrieval
Quote getQuoteWithFallback(QuoteManager& manager) {
    auto result = manager.tryGetRandomQuote();
    if (result) {
        return result.value();
    }

    // Fallback quote
    return Quote{
        .id = -1,
        .text = "The journey of a thousand miles begins with one step.",
        .author = "Lao Tzu",
        .category = "wisdom"
    };
}
```

## Build Integration

### CMake Usage

The project uses CMake with C++23. Required dependencies:

```cmake
find_package(Qt6 REQUIRED COMPONENTS Core Widgets Svg SvgWidgets)
target_link_libraries(your_target Qt6::Core Qt6::Widgets Qt6::Svg Qt6::SvgWidgets)
```

### Compilation Requirements

- **C++23** compatible compiler (GCC 13+, Clang 17+, MSVC 19.36+)
- **Qt6** 6.2+ with required modules
- **CMake** 3.16+

## Thread Safety

- **ErrorLogger**: Fully thread-safe with mutex protection
- **QuoteManager**: Single-threaded use recommended
- **Application/TrayIcon**: Must be used on main GUI thread
- **Qt Components**: Follow Qt's thread-safety rules

## Performance Characteristics

- **Quote retrieval**: O(1) random access via SQLite
- **Database**: Lazy loading, single quote per query
- **Memory**: Minimal footprint, no large collections in memory
- **Startup**: Fast initialization with embedded database

---

*This API documentation was generated for The Wiser One v0.0.2*

Designed by Sebastien Rousseau — Engineered with Euxis