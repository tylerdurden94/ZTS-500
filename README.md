# Remotec ZTS-500 SmartThings Edge driver

This driver targets the Remotec ZTS-500US (`0x5254/0x0200/0x8170`). It uses
SmartThings' standard Z-Wave thermostat handlers for temperature, heat/cool
setpoints, mode, fan mode, operating state, and battery reporting. The device
profile adds filter life and filter status. Its Settings page exposes swing,
second-stage differential, Auto-mode dead band, filter interval, and display
brightness.

**[Install from TylerDurden94’s Edge Drivers](https://bestow-regional.api.smartthings.com/invite/oDM8Q4Bkgp2L).**

The public channel carries the version tested on a ZTS-500US with firmware
**Z.109**. The code is based on SmartThings' standard thermostat behavior;
Mariano's source code is not included. See [validation and release details](docs/VALIDATION.md)
for what has been verified and what still needs physical testing.

## Install from the public channel

1. Open the channel invitation above and sign in to your Samsung account.
2. Enroll the SmartThings hub that your ZTS-500 is connected to.
3. Choose **Available Drivers** and install **Remotec ZTS-500 Thermostat**.
4. In the SmartThings app, open the thermostat, choose **Driver**, then
   **Select different driver**, and select **Remotec ZTS-500 Thermostat**.
   Menu wording can vary by app version. Keep the name of your previous driver
   so you can switch back if needed.
5. Use **Refresh**, then check temperature, setpoints, mode, and filter status
   against the thermostat. You do not need to exclude or re-pair the device.

This invitation also offers other TylerDurden94 drivers. Install only the ones
you need. A Z-Wave-capable SmartThings hub and the matching ZTS-500US fingerprint
are required; other Remotec models and regional variants have not been tested.

## Configuration mapping

| SmartThings feature | Z-Wave parameter | Values |
| --- | ---: | --- |
| Temperature swing | 2 | 1–4 °F; default 2 °F |
| Second-stage differential | 3 | 1–4 °F; multistage HVAC only |
| Auto-mode dead band | 4 | 3–6 °F; default 4 °F |
| Reset filter button | 7 | write 0 |
| Filter replacement interval | 8 | 500–4000 hours; default 500 |
| Filter usage counter | 9 | read only, 0–9999 hours |
| Display brightness | 11 | 1 dark, 2 medium, 3 bright |

All configuration writes use two-byte values, as listed in the Z-Wave Alliance
certification table. The driver reads the *actual* parameter 8 and 9 values
and calculates remaining life as `max(0, 100 × (interval − used) / interval)`
rounded to the nearest whole percent. Status becomes `replace` at or above
the interval. The filter values are read when the driver starts, when you
Refresh the device, and once per day. A reset writes parameter 7 and then
reads parameter 9; it does not show a successful reset until the device reports
its new count.

Settings defaults reflect factory defaults. On driver assignment, the driver
reads the physical parameters but does not overwrite them. Changing a setting
in the SmartThings app sends that value to the thermostat. If settings were
already changed at the thermostat, the Settings controls may initially show
factory defaults until you select the desired values in the app.

## Build and install your own copy

1. Install the [SmartThings CLI](https://developer.smartthings.com/docs/devices/hub-connected/set-up-dev-env) and sign in.
2. Create a [personal driver channel](https://developer.smartthings.com/docs/devices/hub-connected/driver-channels/) and enroll your hub.
3. In this repository directory run `smartthings edge:drivers:package . --install` and select that personal channel and hub when prompted.
4. In the SmartThings app, open the thermostat, choose **Driver**, then **Select different driver**, and select **Remotec ZTS-500 Thermostat**. The exact menu wording can vary by app version.
5. Use **Refresh**, confirm temperature and setpoint behavior, and check filter life/status. Test swing and filter reset with the thermostat's display as the source of truth.

For updates, package and install again to the same personal channel. Save a
copy of your original driver choice in case you need to switch back.

## Source references

- [Z-Wave Alliance ZTS-500US certification](https://products.z-wavealliance.org/z-wave-product/z-wave-smart-thermostat/) (fingerprint and parameter numbers/sizes)
- [Remotec ZTS-500US manual linked by the certification](https://products.z-wavealliance.org/wp-content/uploads/products/50142/F-BW8170US%20%28ZTS-500US%29%20User_Manual_V1.01_Z-Wave%20validation_20160510.pdf)
- [SmartThings Z-Wave thermostat driver](https://github.com/SmartThingsCommunity/SmartThingsEdgeDrivers/blob/main/drivers/SmartThings/zwave-thermostat/src/init.lua) (Apache-2.0 standard behavior and setpoint handling)
- [SmartThings filterState/filterStatus capabilities](https://developer.smartthings.com/docs/devices/capabilities/capabilities-reference)

## Limits

The Z.109 thermostat reported a 500-hour interval and counter value 500; the
owner confirmed its physical filter reminder matched the driver's Replace
status. Some early ZTS-500 guides describe a month-based interval; the
certification for the fingerprint above, its manual, and this thermostat's
reports use hours. The owner confirmed that resetting the filter countdown
through the driver worked on the physical thermostat. Settings writes passed
mocked Lua 5.3 tests but have not yet been exercised on the physical
thermostat. Reset the filter after cleaning or replacing it. Mobile app layout
remains to be checked by the owner.

## Handler tests

Install the test dependencies with `python -m pip install -r requirements-dev.txt`.
`tests/test_driver.py` runs the actual driver source with mocked SmartThings
and Z-Wave APIs. It requires Python and `lupa`, and uses Lua 5.3. Run it with
`python tests/test_driver.py`. The mock models SmartThings refresh dispatch;
the custom refresh handler calls `default_refresh()` to fetch standard
thermostat state before reading ZTS-500 configuration.

## Support and license

Report problems in [GitHub Issues](https://github.com/tylerdurden94/ZTS-500/issues).
Include the thermostat model, firmware, driver version, and observed behavior.
Remove account details, device identifiers, and tokens from any logs you share.

Licensed under [Apache-2.0](LICENSE). See [third-party notices](THIRD_PARTY_NOTICES.md)
for the upstream SmartThings source attribution.
