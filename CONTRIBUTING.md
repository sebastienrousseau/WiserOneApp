# Contributing to The Wiser One

Welcome! We're thrilled that you're interested in contributing to The Wiser One.

## How to Contribute

### Feedback & Bug Reports

- Submit issues at [GitHub Issues][issues]
- Use descriptive titles that clearly summarize the issue
- Provide detailed descriptions and steps to reproduce bugs

### Code Contributions

1. Fork the repository
2. Clone: `git clone https://github.com/sebastienrousseau/WiserOneApp`
3. Create a feature branch: `git checkout -b feat/your-feature`
4. Make your changes in the `src/` folder
5. Run tests: `ctest --output-on-failure`
6. Submit a pull request

---

## Coding Standards

### Language Standard

- **C++23** is required (GCC 13+, Clang 17+, MSVC 19.36+)
- Use modern C++ features: `std::expected`, `std::optional`, `constexpr`, ranges
- Enable warnings: `-Wall -Wextra -Wpedantic`

### Code Style

#### Formatting

Run `clang-format` before committing (configuration in `.clang-format`):
```bash
clang-format -i src/*.cpp src/*.h
```

- Line length: 100 characters maximum
- Indentation: 4 spaces (no tabs)
- Braces: K&R style for control statements, Allman for functions/classes

#### Naming Conventions

| Element | Convention | Example |
|---------|------------|---------|
| Classes/Structs | PascalCase | `QuoteManager` |
| Functions/Methods | camelCase | `getRandomQuote()` |
| Variables | camelCase | `quoteText` |
| Member Variables | m_ prefix | `m_quotes` |
| Constants | UPPER_CASE | `ICON_SIZE` |
| Enums | PascalCase | `QuoteError::FileNotFound` |
| Namespaces | lowercase | `wiserone::utils` |

#### Include Order

```cpp
// SPDX-License-Identifier: MIT

#include "QuoteManager.h"  // 1. Corresponding header

#include "ErrorLogger.h"   // 2. Project headers

#include <QString>         // 3. Qt headers
#include <QVector>

#include <expected>        // 4. Standard library
#include <string_view>
```

### Documentation

#### File Headers

Every source file must have an SPDX license identifier:
```cpp
// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2024-2026 WiserOne
```

#### Doxygen Comments

Use Doxygen for public APIs:
```cpp
/**
 * @brief Get a random quote from the collection
 * @return Reference to a randomly selected Quote
 */
[[nodiscard]] const Quote& getRandomQuote();
```

### Error Handling

#### Use `std::expected` for Recoverable Errors

```cpp
[[nodiscard]] std::expected<Quote, QuoteError> tryGetQuote();
```

#### Avoid Exceptions

Use `std::expected` or `std::optional` instead of throwing exceptions.

### Modern C++ Guidelines

#### Prefer

- `std::string_view` over `const char*`
- `std::expected` over error codes
- `constexpr` for compile-time computation
- `[[nodiscard]]` for important return values
- `noexcept` for functions that cannot fail
- Smart pointers over raw pointers
- Range-based for loops

#### Avoid

- Raw `new`/`delete`
- C-style casts
- Macros (use `constexpr`)
- Global mutable state
- `using namespace` in headers

### Qt-Specific Guidelines

#### String Handling

```cpp
// Good
auto str = QStringLiteral("Hello");
auto view = QStringView(u"World");

// Avoid
auto str = QString("Hello");  // Runtime conversion
```

#### Memory Management

- Qt widgets: parent-child ownership
- Non-widget objects: `std::unique_ptr`

#### Signals and Slots

```cpp
// Good - compile-time checked
connect(sender, &Sender::signal, receiver, &Receiver::slot);

// Avoid - runtime string lookup
connect(sender, SIGNAL(signal()), receiver, SLOT(slot()));
```

### Testing

- Use Qt Test framework
- Test file naming: `tst_<classname>.cpp`
- Aim for >80% code coverage

```cpp
void TestClass::testMethod()
{
    // Arrange
    auto input = createInput();

    // Act
    auto result = obj.method(input);

    // Assert
    QCOMPARE(result, expected);
}
```

### Git Workflow

#### Commit Messages

Follow [Conventional Commits][commits]:
```
feat(quotes): add monthly rotation
fix(tray): resolve icon visibility on dark theme
refactor(logger): use std::expected for error handling
docs: update contributing guidelines
test: add QuoteManager unit tests
```

#### Branch Naming

- `feat/description` - new features
- `fix/description` - bug fixes
- `refactor/description` - code improvements

### Building

```bash
mkdir build && cd build
cmake .. -DCMAKE_PREFIX_PATH=/path/to/Qt6
cmake --build . -j$(nproc)
ctest --output-on-failure
```

### Static Analysis

```bash
# Format check
clang-format --dry-run -Werror src/*.cpp src/*.h

# Lint
clang-tidy src/*.cpp -- -std=c++23 $(pkg-config --cflags Qt6Core Qt6Widgets)
```

---

[issues]: https://github.com/sebastienrousseau/WiserOneApp/issues
[commits]: https://www.conventionalcommits.org/
