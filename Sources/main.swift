// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
//  main.swift
//  The Wiser One
//
//  Created by Sebastien Rousseau on 27/01/2024.
//

import Cocoa

/// Gets reference to shared application instance
let app = NSApplication.shared

/// Creates the application delegate instance
let delegate = AppDelegate()

/// Sets delegate to receive app events and control app lifecycle
app.delegate = delegate

/// Runs application by starting the runloop
/// This call will not return until app terminates
/// Apps on macOS require a runloop unlike command line tools
app.run()
