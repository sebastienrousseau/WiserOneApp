# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: 2024-2026 WiserOne

cmake_minimum_required(VERSION 3.16)

# Read version from VERSION file
file(READ "${CMAKE_CURRENT_SOURCE_DIR}/VERSION" PROJECT_VERSION_RAW)
string(STRIP "${PROJECT_VERSION_RAW}" PROJECT_VERSION)

project(WiserOne
    VERSION ${PROJECT_VERSION}
    DESCRIPTION "Daily nuggets of wisdom in a clean, minimalist design"
    HOMEPAGE_URL "https://wiserone.com"
    LANGUAGES CXX
)

# =============================================================================
# Build Configuration
# =============================================================================

set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_AUTOUIC ON)

# Export compile commands for IDE support
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

# Include standard install directories
include(GNUInstallDirs)

# =============================================================================
# Compiler Flags
# =============================================================================

# Warning flags with CI support (warnings as errors)
if(CMAKE_CXX_COMPILER_ID MATCHES "GNU|Clang")
    add_compile_options(
        -Wall
        -Wextra
        -Wpedantic
        -Wconversion
        -Wsign-conversion
        -Wcast-qual
        -Wformat=2
        -Wundef
        -Werror=return-type
        -Wno-unused-parameter
    )

    # CI Mode: Enable warnings as errors when CXXFLAGS contains -Werror
    # or when explicitly requested via CI_MODE
    if(DEFINED ENV{CI} OR "$ENV{CXXFLAGS}" MATCHES "-Werror" OR CI_MODE)
        add_compile_options(-Werror)
        message(STATUS "CI Mode: Warnings as errors enabled")
    endif()
endif()

if(MSVC)
    add_compile_options(
        /W4
        /permissive-
        /Zc:__cplusplus
    )

    # CI Mode: Enable warnings as errors for MSVC
    if(DEFINED ENV{CI} OR "$ENV{CXXFLAGS}" MATCHES "/WX" OR CI_MODE)
        add_compile_options(/WX)
        message(STATUS "CI Mode: Warnings as errors enabled (MSVC)")
    endif()
endif()

# Release optimizations and security hardening
if(CMAKE_BUILD_TYPE STREQUAL "Release")
    if(CMAKE_CXX_COMPILER_ID MATCHES "GNU|Clang")
        add_compile_options(-O3 -DNDEBUG)
        # Security hardening
        add_compile_options(
            -fstack-protector-strong
            -D_FORTIFY_SOURCE=2
        )
        if(NOT APPLE)
            add_link_options(
                -Wl,-z,relro
                -Wl,-z,now
                -Wl,-z,noexecstack
            )
        endif()
    endif()
    if(MSVC)
        add_compile_options(/O2 /GL)
        add_link_options(/LTCG)
    endif()
endif()

# =============================================================================
# Dependencies
# =============================================================================

find_package(Qt6 REQUIRED COMPONENTS Core Widgets Svg SvgWidgets Sql)
find_package(Qt6 OPTIONAL_COMPONENTS LinguistTools)

# =============================================================================
# Translations
# =============================================================================

if(Qt6LinguistTools_FOUND)
    # Generate .qm files from .ts sources
    set(TS_FILES
        ${CMAKE_SOURCE_DIR}/translations/wiserone_en.ts
        ${CMAKE_SOURCE_DIR}/translations/wiserone_fr.ts
        ${CMAKE_SOURCE_DIR}/translations/wiserone_es.ts
        ${CMAKE_SOURCE_DIR}/translations/wiserone_de.ts
        ${CMAKE_SOURCE_DIR}/translations/wiserone_pt.ts
        ${CMAKE_SOURCE_DIR}/translations/wiserone_zh_CN.ts
        ${CMAKE_SOURCE_DIR}/translations/wiserone_ja.ts
        ${CMAKE_SOURCE_DIR}/translations/wiserone_ko.ts
        ${CMAKE_SOURCE_DIR}/translations/wiserone_ru.ts
        ${CMAKE_SOURCE_DIR}/translations/wiserone_it.ts
        ${CMAKE_SOURCE_DIR}/translations/wiserone_ar.ts
        ${CMAKE_SOURCE_DIR}/translations/wiserone_he.ts
        ${CMAKE_SOURCE_DIR}/translations/wiserone_hi.ts
        ${CMAKE_SOURCE_DIR}/translations/wiserone_nl.ts
        ${CMAKE_SOURCE_DIR}/translations/wiserone_id.ts
    )

    set_source_files_properties(${TS_FILES} PROPERTIES
        OUTPUT_LOCATION ${CMAKE_SOURCE_DIR}/translations
    )
    qt6_add_translation(QM_FILES ${TS_FILES})
else()
    # Use pre-compiled .qm files
    message(STATUS "Qt6LinguistTools not found, using pre-compiled translations")
    file(GLOB QM_FILES ${CMAKE_SOURCE_DIR}/translations/*.qm)
endif()

# =============================================================================
# Source Files
# =============================================================================

set(SOURCES
    src/main.cpp
    src/Application.cpp
    src/TrayIcon.cpp
    src/QuoteWidget.cpp
    src/QuoteManager.cpp
    src/ErrorLogger.cpp
    src/AboutDialog.cpp
)

set(HEADERS
    src/Application.h
    src/TrayIcon.h
    src/QuoteWidget.h
    src/QuoteManager.h
    src/ErrorLogger.h
    src/AboutDialog.h
)

# Platform-specific sources
if(WIN32)
    set(PLATFORM_SOURCES resources/windows/wiserone.rc)
elseif(APPLE)
    set(PLATFORM_SOURCES resources/macos/AppIcon.icns)
    set_source_files_properties(resources/macos/AppIcon.icns PROPERTIES
        MACOSX_PACKAGE_LOCATION "Resources"
    )
endif()

# =============================================================================
# Executable
# =============================================================================

add_executable(WiserOne
    ${SOURCES}
    ${HEADERS}
    ${PLATFORM_SOURCES}
    ${QM_FILES}
    resources/resources.qrc
    translations/translations.qrc
)

target_link_libraries(WiserOne PRIVATE
    Qt6::Core
    Qt6::Widgets
    Qt6::Svg
    Qt6::SvgWidgets
    Qt6::Sql
)

# Add version info to the binary
target_compile_definitions(WiserOne PRIVATE
    APP_VERSION="${PROJECT_VERSION}"
    APP_NAME="${PROJECT_NAME}"
)

# =============================================================================
# Platform-Specific Configuration
# =============================================================================

if(APPLE)
    set_target_properties(WiserOne PROPERTIES
        MACOSX_BUNDLE TRUE
        MACOSX_BUNDLE_BUNDLE_NAME "The Wiser One"
        MACOSX_BUNDLE_BUNDLE_VERSION ${PROJECT_VERSION}
        MACOSX_BUNDLE_SHORT_VERSION_STRING ${PROJECT_VERSION}
        MACOSX_BUNDLE_GUI_IDENTIFIER "com.wiserone.app"
        MACOSX_BUNDLE_ICON_FILE "AppIcon.icns"
        MACOSX_BUNDLE_INFO_PLIST ${CMAKE_SOURCE_DIR}/resources/macos/Info.plist.in
    )
elseif(WIN32)
    set_target_properties(WiserOne PROPERTIES
        WIN32_EXECUTABLE TRUE
        OUTPUT_NAME "WiserOne"
    )
elseif(UNIX)
    set_target_properties(WiserOne PROPERTIES
        OUTPUT_NAME "wiserone"
    )
endif()

# =============================================================================
# Installation
# =============================================================================

if(UNIX AND NOT APPLE)
    # Linux installation following freedesktop standards
    install(TARGETS WiserOne
        RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
    )

    # Desktop file
    install(FILES resources/linux/com.wiserone.WiserOne.desktop
        DESTINATION ${CMAKE_INSTALL_DATADIR}/applications
    )

    # App icons for hicolor theme
    foreach(SIZE 16 32 128 256 512)
        install(FILES resources/icons/icon-${SIZE}.png
            DESTINATION ${CMAKE_INSTALL_DATADIR}/icons/hicolor/${SIZE}x${SIZE}/apps
            RENAME com.wiserone.WiserOne.png
        )
    endforeach()

    # Symbolic icon for system tray
    install(FILES resources/icons/icon-symbolic.svg
        DESTINATION ${CMAKE_INSTALL_DATADIR}/icons/hicolor/symbolic/apps
        RENAME com.wiserone.WiserOne-symbolic.svg
    )

    # Scalable icon
    install(FILES resources/linux/com.wiserone.WiserOne.svg
        DESTINATION ${CMAKE_INSTALL_DATADIR}/icons/hicolor/scalable/apps
        OPTIONAL
    )

    # AppStream metainfo
    install(FILES resources/linux/com.wiserone.WiserOne.metainfo.xml
        DESTINATION ${CMAKE_INSTALL_DATADIR}/metainfo
        OPTIONAL
    )

elseif(APPLE)
    install(TARGETS WiserOne BUNDLE DESTINATION .)

elseif(WIN32)
    install(TARGETS WiserOne RUNTIME DESTINATION .)
endif()

# =============================================================================
# Testing
# =============================================================================

option(BUILD_TESTING "Build unit tests" ON)
if(BUILD_TESTING)
    enable_testing()
    add_subdirectory(tests)
endif()

# =============================================================================
# Summary
# =============================================================================

message(STATUS "")
message(STATUS "The Wiser One ${PROJECT_VERSION}")
message(STATUS "  C++ Standard: ${CMAKE_CXX_STANDARD}")
message(STATUS "  Build Type: ${CMAKE_BUILD_TYPE}")
message(STATUS "  Qt Version: ${Qt6_VERSION}")
message(STATUS "  Install Prefix: ${CMAKE_INSTALL_PREFIX}")
message(STATUS "")
