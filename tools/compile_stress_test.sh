#!/bin/bash
# Compile the stress test with Qt

set -euo pipefail

cd "$(dirname "$0")"

echo "Compiling database stress test..."

# Find Qt installation
if pkg-config --exists Qt6Core; then
    QT_CFLAGS=$(pkg-config --cflags Qt6Core Qt6Sql)
    QT_LIBS=$(pkg-config --libs Qt6Core Qt6Sql)
else
    echo "Error: Qt6 development packages not found"
    echo "Please install: sudo apt install qt6-base-dev libqt6sql6-dev"
    exit 1
fi

g++ -std=c++23 -O3 -DNDEBUG \
    $QT_CFLAGS \
    -o stress_test \
    stress_test.cpp \
    $QT_LIBS

echo "Stress test compiled successfully: tools/stress_test"
echo "Run with: ./tools/stress_test"