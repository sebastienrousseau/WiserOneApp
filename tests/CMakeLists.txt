find_package(Qt6 REQUIRED COMPONENTS Test Concurrent Sql Gui Widgets Svg SvgWidgets)

# Code coverage configuration
option(ENABLE_COVERAGE "Enable code coverage" OFF)
if(ENABLE_COVERAGE)
    if(CMAKE_CXX_COMPILER_ID MATCHES "GNU|Clang")
        add_compile_options(--coverage -O0 -fno-inline -fno-inline-small-functions -fno-default-inline)
        add_link_options(--coverage)
        message(STATUS "Code coverage enabled")
    endif()
endif()

# Common test dependencies
set(TEST_COMMON_SOURCES
    ${CMAKE_SOURCE_DIR}/src/ErrorLogger.cpp
)

# Include mocks directory for test doubles
set(TEST_INCLUDE_DIRS
    ${CMAKE_SOURCE_DIR}/src
    ${CMAKE_SOURCE_DIR}/src/interfaces
    ${CMAKE_CURRENT_SOURCE_DIR}/mocks
)

# QuoteManager tests
add_executable(tst_quotemanager
    tst_quotemanager.cpp
    ${CMAKE_SOURCE_DIR}/src/QuoteManager.cpp
    ${TEST_COMMON_SOURCES}
)

target_include_directories(tst_quotemanager PRIVATE
    ${TEST_INCLUDE_DIRS}
)

target_link_libraries(tst_quotemanager PRIVATE
    Qt6::Core
    Qt6::Test
    Qt6::Sql
)

add_test(NAME QuoteManagerTest COMMAND tst_quotemanager)

# ErrorLogger tests
add_executable(tst_errorlogger
    tst_errorlogger.cpp
    ${CMAKE_SOURCE_DIR}/src/ErrorLogger.cpp
)

target_include_directories(tst_errorlogger PRIVATE
    ${TEST_INCLUDE_DIRS}
)

target_link_libraries(tst_errorlogger PRIVATE
    Qt6::Core
    Qt6::Test
    Qt6::Concurrent
)

add_test(NAME ErrorLoggerTest COMMAND tst_errorlogger)

# Application tests
add_executable(tst_application
    tst_application.cpp
    ${CMAKE_SOURCE_DIR}/src/Application.cpp
    ${CMAKE_SOURCE_DIR}/src/TrayIcon.cpp
    ${CMAKE_SOURCE_DIR}/src/QuoteManager.cpp
    ${CMAKE_SOURCE_DIR}/src/QuoteProviderFactory.cpp
    ${CMAKE_SOURCE_DIR}/src/AboutDialog.cpp
    ${CMAKE_SOURCE_DIR}/src/NotificationManager.cpp
    ${CMAKE_SOURCE_DIR}/src/QuoteScheduler.cpp
    ${TEST_COMMON_SOURCES}
)

target_include_directories(tst_application PRIVATE
    ${TEST_INCLUDE_DIRS}
)

target_link_libraries(tst_application PRIVATE
    Qt6::Core
    Qt6::Test
    Qt6::Gui
    Qt6::Widgets
    Qt6::Svg
    Qt6::Sql
)

add_test(NAME ApplicationTest COMMAND tst_application)

# AboutDialog tests
add_executable(tst_aboutdialog
    tst_aboutdialog.cpp
    ${CMAKE_SOURCE_DIR}/src/AboutDialog.cpp
    ${CMAKE_SOURCE_DIR}/src/QuoteScheduler.cpp
)

target_include_directories(tst_aboutdialog PRIVATE
    ${TEST_INCLUDE_DIRS}
)

target_link_libraries(tst_aboutdialog PRIVATE
    Qt6::Core
    Qt6::Test
    Qt6::Gui
    Qt6::Widgets
    Qt6::Svg
    Qt6::SvgWidgets
)

add_test(NAME AboutDialogTest COMMAND tst_aboutdialog)

# Integration tests
add_executable(test_cross_platform
    integration/test_cross_platform.cpp
    ${CMAKE_SOURCE_DIR}/src/QuoteManager.cpp
    ${CMAKE_SOURCE_DIR}/src/QuoteWidget.cpp
    ${CMAKE_SOURCE_DIR}/src/Application.cpp
    ${CMAKE_SOURCE_DIR}/src/TrayIcon.cpp
    ${CMAKE_SOURCE_DIR}/src/AboutDialog.cpp
    ${CMAKE_SOURCE_DIR}/src/QuoteProviderFactory.cpp
    ${CMAKE_SOURCE_DIR}/src/NotificationManager.cpp
    ${CMAKE_SOURCE_DIR}/src/QuoteScheduler.cpp
    ${TEST_COMMON_SOURCES}
)

target_include_directories(test_cross_platform PRIVATE
    ${TEST_INCLUDE_DIRS}
)

target_link_libraries(test_cross_platform PRIVATE
    Qt6::Core
    Qt6::Test
    Qt6::Gui
    Qt6::Widgets
    Qt6::Svg
    Qt6::SvgWidgets
    Qt6::Sql
    Qt6::Concurrent
)

add_test(NAME CrossPlatformIntegrationTest COMMAND test_cross_platform)

# MockQuoteProvider tests (test infrastructure verification)
add_executable(tst_mockquoteprovider
    tst_mockquoteprovider.cpp
)

target_include_directories(tst_mockquoteprovider PRIVATE
    ${TEST_INCLUDE_DIRS}
)

target_link_libraries(tst_mockquoteprovider PRIVATE
    Qt6::Core
    Qt6::Test
)

add_test(NAME MockQuoteProviderTest COMMAND tst_mockquoteprovider)
