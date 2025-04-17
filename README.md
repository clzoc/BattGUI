# Power Management Suite

[![Swift](https://img.shields.io/badge/Swift-5.9-orange.svg)]()
[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)

A comprehensive power monitoring solution for macOS featuring:

- 🖥 GUI application with real-time power flow visualization
- 🔋 Detailed battery health analytics
- ⚡️ CLI tools for low-level power monitoring
- 📊 System load statistics collection

![](image/capture0.png)
![](image/capture1.png)

## Architecture Overview

```mermaid
graph TD
    A[Power Management Suite] --> B{GUI Application}
    A --> C{CLI Tools}
    
    B --> D[PowerFlowView]
    B --> E[BatteryMonitor]
    B --> F[SystemStats]
    
    C --> G[power_info]
    C --> H[batt]
    
    D --> I[SwiftUI Views]
    E --> J[IOKit Integration]
    F --> K[System Load Metrics]
    G --> L[SMC Access]
    H --> M[Battery Diagnostics]
```

## Features

### GUI Application
- Real-time power flow visualization
- Battery health monitoring (cycles, capacity, temperature)
- Adapter power input tracking
- System load/power consumption correlation

### CLI Tools
- `power_info`: Low-level SMC access for power metrics
- `batt`: Advanced battery diagnostics (from [charlie0129/batt](https://github.com/charlie0129/batt))

## Requirements

- macOS 13 Ventura or newer
- Xcode 15+
- Administrative privileges for SMC access

## Installation

```bash
# Clone repository
git clone https://github.com/yourusername/power-suite.git
cd power-suite

# Build GUI application
xcodebuild -workspace app.xcodeproj/project.xcworkspace -scheme app

# Build CLI tools
cd systemLoad_Claude
make
```

## Usage

GUI Application:
```bash
open app/build/Release/app.app
```

CLI Monitoring:
```bash
# System power stats
./systemLoad_Claude/power_info -c

# Battery health check
./utility/batt health
```

## Contributing
See [CONTRIBUTING.md](CONTRIBUTING.md) for development setup and guidelines.

## License
GPLv3 (see [LICENSE](LICENSE))