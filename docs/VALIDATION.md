# Release and validation

## Public channel release — October 23, 2026

- Channel: **TylerDurden94’s Edge Drivers**
- [Channel invitation](https://bestow-regional.api.smartthings.com/invite/oDM8Q4Bkgp2L)
- Channel ID: `36c02108-d699-4e4b-bed9-d019f5d3af9a`
- Driver: **Remotec ZTS-500 Thermostat**
- Driver ID: `31553cdc-639a-4ab5-ab61-8641af784d7b`
- Driver version: `2026-10-04T21:07:43.284024991`
- Package key: `remotec-zts-500-thermostat`
- Supported fingerprint: `0x5254/0x0200/0x8170` (Remotec ZTS-500US)

This release assigns the existing tested driver version to the public channel.
The October 23 publication does not change its runtime code. These are public
distribution identifiers, not credentials or identifiers for an owner's devices.

## Physical testing

Testing on a ZTS-500US with firmware reported as Z.109 established:

- Standard temperature, mode, fan, operating state, and heating/cooling
  setpoint reports reached SmartThings.
- Configuration reports used two-byte values and returned swing 2 °F,
  second-stage differential 2 °F, dead band 4 °F, filter interval 500 hours,
  used counter 500 hours, and brightness 3.
- Filter life 0% and Replace matched the physical thermostat's reminder.
- Refresh completed and returned thermostat and configuration reports without
  recursive dispatch or a runtime error after the refresh fix.
- On October 5, the owner confirmed that filter reset worked on the thermostat.

Settings writes passed mocked tests but have not been physically exercised.
Mobile app layout and other firmware or regional variants remain unverified.

## Automated checks

On October 23, all seven tests in `tests/test_driver.py` passed using Lua 5.3
through `lupa`, and the official SmartThings CLI successfully built the package.
Tests exercise the actual driver source with mocked SmartThings and Z-Wave APIs:

- Filter report order, percentages, expiration, invalid reports, and zero usage.
- Reset command size/value and delayed readback without premature success.
- Settings defaults, first changes, bounds, and interval readback.
- Refresh dispatch through `default_refresh()`.
- Standard half-degree thermostat setpoint behavior.

These tests do not reproduce the full SmartThings runtime. The physical
observations above cover the tested hub/device path.
