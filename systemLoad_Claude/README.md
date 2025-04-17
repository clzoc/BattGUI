# Power Consumption Monitor for macOS

A standalone command-line tool to monitor the current power consumption of your Mac.

## Overview

This tool extracts the power consumption monitoring functionality from the Power Monitor Tool by SAP SE and provides it as a simple, standalone executable. It accesses the System Management Controller (SMC) to read the current power consumption in watts.

## Features

- Display current power consumption in watts
- Continuous monitoring with customizable interval
- Multiple output formats (standard, verbose with timestamp, raw)
- Simple command-line interface

## Requirements

- macOS (tested on macOS Monterey and later)
- Administrative privileges may be required to access the SMC

## Usage

```
./PowerConsumption [options]
```

### Options

- `-h`: Display help message
- `-c`: Continuous monitoring (press Ctrl+C to stop)
- `-i <seconds>`: Interval between measurements in seconds (default: 1, requires -c)
- `-r`: Raw output (just the number, no text)
- `-v`: Verbose output with timestamp

### Examples

1. Get current power consumption:
   ```
   ./PowerConsumption
   ```

2. Get current power consumption with timestamp:
   ```
   ./PowerConsumption -v
   ```

3. Monitor power consumption continuously with 5-second intervals:
   ```
   ./PowerConsumption -c -i 5
   ```

4. Get raw output (useful for scripts):
   ```
   ./PowerConsumption -r
   ```

## Building from Source

```
clang -o PowerConsumption PowerConsumption.m -framework Foundation -framework IOKit
```

## License

This tool is based on code from the Power Monitor Tool by SAP SE, which is licensed under the Apache License, Version 2.0.

## Acknowledgments

- SAP SE for the original Power Monitor Tool
- Apple for providing access to the SMC through IOKit
