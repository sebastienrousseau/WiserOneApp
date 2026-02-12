find_package(Qt6 REQUIRED COMPONENTS Test Concurrent Sql Gui Widgets Svg)

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

# QuoteManager tests
add_executable(tst_quotemanager
    tst_quotemanager.cpp
    ${CMAKE_SOURCE_DIR}/src/QuoteManager.cpp
    ${TEST_COMMON_SOURCES}
)

target_include_directories(tst_quotemanager PRIVATE
    ${CMAKE_SOURCE_DIR}/src
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
    ${CMAKE_SOURCE_DIR}/src
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
    ${TEST_COMMON_SOURCES}
)

target_include_directories(tst_application PRIVATE
    ${CMAKE_SOURCE_DIR}/src
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
)

target_include_directories(tst_aboutdialog PRIVATE
    ${CMAKE_SOURCE_DIR}/src
)

target_link_libraries(tst_aboutdialog PRIVATE
    Qt6::Core
    Qt6::Test
    Qt6::Gui
    Qt6::Widgets
)

add_test(NAME AboutDialogTest COMMAND tst_aboutdialog)
