# WiserOne Performance Baseline Report
Generated: Wed 11 Feb 23:52:21 GMT 2026

## Binary Analysis
```
Binary size: 224K
Strip status: not stripped
Binary info: build-release/wiserone: ELF 64-bit LSB pie executable, x86-64, version 1 (GNU/Linux), dynamically linked, interpreter /lib64/ld-linux-x86-64.so.2, BuildID[sha1]=36a7bf5c7dbc9634cd58d004d9803d582fff217d, for GNU/Linux 3.2.0, not stripped
```

## Memory Analysis
Valgrind not available - skipping memory leak detection

## Startup Performance
```
Startup time measurements (5 runs):
Run 1: 112.46 ms
Run 2: 109.21 ms
Run 3: 107.33 ms
Run 4: 107.21 ms
Run 5: 106.59 ms
Average: 108.56 ms
```

✅ **Startup time budget: PASS** (< 500ms)

## Build Configuration
```
CMake build type:
CMAKE_BUILD_TYPE:STRING=Release

Compiler flags:
CMAKE_CXX_FLAGS:STRING=
CMAKE_CXX_FLAGS_DEBUG:STRING=-g
CMAKE_CXX_FLAGS_MINSIZEREL:STRING=-Os -DNDEBUG
```

## Dependencies
```
Dynamic libraries:
	linux-vdso.so.1 (0x000070d8a6d6a000)
	libQt6SvgWidgets.so.6 => /lib/x86_64-linux-gnu/libQt6SvgWidgets.so.6 (0x000070d8a6d13000)
	libQt6Sql.so.6 => /lib/x86_64-linux-gnu/libQt6Sql.so.6 (0x000070d8a6cc8000)
	libQt6Svg.so.6 => /lib/x86_64-linux-gnu/libQt6Svg.so.6 (0x000070d8a6c69000)
	libQt6Widgets.so.6 => /lib/x86_64-linux-gnu/libQt6Widgets.so.6 (0x000070d8a6400000)
	libQt6Gui.so.6 => /lib/x86_64-linux-gnu/libQt6Gui.so.6 (0x000070d8a5c00000)
	libQt6Core.so.6 => /lib/x86_64-linux-gnu/libQt6Core.so.6 (0x000070d8a5600000)
	libstdc++.so.6 => /lib/x86_64-linux-gnu/libstdc++.so.6 (0x000070d8a5200000)
	libgcc_s.so.1 => /lib/x86_64-linux-gnu/libgcc_s.so.1 (0x000070d8a6c39000)
	libc.so.6 => /lib/x86_64-linux-gnu/libc.so.6 (0x000070d8a4e00000)
...
Total libraries: 52
```

## Binary Size Breakdown
```
   text	   data	    bss	    dec	    hex	filename
 167739	   8376	    200	 176315	  2b0bb	build-release/wiserone
```

## Performance Budget Status
| Metric | Current | Budget | Status |
|--------|---------|--------|--------|
| Startup Time | 108.561000 ms | < 500 ms | ✅ PASS |
| Binary Size | 1 MB | < 5 MB | ✅ PASS |
| Debug Symbols | Present | Stripped | ❌ FAIL |

