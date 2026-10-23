# Changelog

## 2026-10-23 — Public channel publication

- Published the existing tested Remotec ZTS-500 Thermostat version
  `2026-10-04T21:07:43.284024991` to TylerDurden94’s Edge Drivers.
- Added public installation instructions, source, tests, Apache-2.0 licensing,
  and validation notes in the dedicated ZTS-500 repository.

## 2026-10-04 — Initial tested version

- Added swing, second-stage differential, dead band, filter interval, and
  display brightness settings for the ZTS-500US.
- Added filter percentage/status from actual configuration reports and filter
  reset with device readback.
- Fixed recursive refresh dispatch by calling `default_refresh()`.
- Verified standard reports and filter state on firmware Z.109. Filter reset
  was subsequently confirmed physically on October 5.
