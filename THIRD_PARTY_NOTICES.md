# Third-party notices

This driver is based on the SmartThings Z-Wave thermostat driver:

- Copyright 2025 SmartThings, Inc.
- License: Apache License, Version 2.0 (included in [LICENSE](LICENSE)).
- [Upstream source](https://github.com/SmartThingsCommunity/SmartThingsEdgeDrivers/blob/main/drivers/SmartThings/zwave-thermostat/src/init.lua).

ZTS-500 additions copyright 2026. The local changes add device-specific
configuration preferences, filter monitoring/reset, and refresh handling.
Runtime imports use SmartThings Edge libraries provided by the hub.
This project is not affiliated with or endorsed by SmartThings or Remotec.

The development dependency `lupa` (MIT) is installed separately and is not
included in the driver package.
