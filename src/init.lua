-- Based on the SmartThings Z-Wave Thermostat Edge driver (Apache-2.0).
-- Copyright 2025 SmartThings, Inc.  ZTS-500 additions copyright 2026.

local capabilities = require "st.capabilities"
local ZwaveDriver = require "st.zwave.driver"
local defaults = require "st.zwave.defaults"
local cc = require "st.zwave.CommandClass"
local Configuration = (require "st.zwave.CommandClass.Configuration")({ version = 1 })
local ThermostatFanMode = (require "st.zwave.CommandClass.ThermostatFanMode")({ version = 3 })
local ThermostatMode = (require "st.zwave.CommandClass.ThermostatMode")({ version = 2 })
local ThermostatSetpoint = (require "st.zwave.CommandClass.ThermostatSetpoint")({ version = 1 })
local constants = require "st.zwave.constants"
local utils = require "st.utils"

local FILTER_INTERVAL = "zts500_filter_interval_hours"
local FILTER_USED = "zts500_filter_used_hours"
local PREFERENCE_BASELINE = "zts500_preference_baseline"
local FILTER_POLL_SECONDS = 24 * 60 * 60

local preferences = {
  temperatureSwing = { parameter = 2, minimum = 1, maximum = 4, default = 2 },
  secondStageDifferential = { parameter = 3, minimum = 1, maximum = 4, default = 2 },
  autoDeadBand = { parameter = 4, minimum = 3, maximum = 6, default = 4 },
  filterIntervalHours = { parameter = 8, minimum = 500, maximum = 4000, default = 500 },
  displayBrightness = { parameter = 11, minimum = 1, maximum = 3, default = 2 },
}

local function get_configuration(device, parameter)
  device:send(Configuration:Get({ parameter_number = parameter }))
end

local function read_zts500_configuration(device)
  for _, parameter in ipairs({ 2, 3, 4, 8, 9, 11 }) do
    get_configuration(device, parameter)
  end
end

local function emit_filter_state(device)
  local interval = device:get_field(FILTER_INTERVAL)
  local used = device:get_field(FILTER_USED)
  if not interval or interval < 500 or interval > 4000 or not used or used < 0 then
    return
  end

  local remaining = math.floor(100 * (interval - used) / interval + 0.5)
  remaining = math.max(0, math.min(100, remaining))
  device:emit_event(capabilities.filterState.filterLifeRemaining({ value = remaining, unit = "%" }))
  device:emit_event(capabilities.filterStatus.filterStatus(used >= interval and "replace" or "normal"))
end

local function configuration_report(driver, device, cmd)
  local parameter = cmd.args.parameter_number
  local value = cmd.args.configuration_value
  if type(value) ~= "number" then
    return
  end

  if parameter == 8 and value >= 500 and value <= 4000 then
    device:set_field(FILTER_INTERVAL, value, { persist = true })
    emit_filter_state(device)
  elseif parameter == 9 and value >= 0 and value <= 9999 then
    device:set_field(FILTER_USED, value, { persist = true })
    emit_filter_state(device)
  end
end

local function reset_filter(driver, device)
  -- The certified ZTS-500US parameter table specifies two-byte values.
  device:send(Configuration:Set({ parameter_number = 7, size = 2, configuration_value = 0 }))
  device.thread:call_with_delay(2, function()
    get_configuration(device, 9)
  end)
end

local function info_changed(driver, device, event, args)
  local old = args and args.old_st_store and args.old_st_store.preferences or {}
  local baseline = device:get_field(PREFERENCE_BASELINE) or {}
  for name, spec in pairs(preferences) do
    local previous = tonumber(old[name]) or baseline[name] or spec.default
    local requested = device.preferences[name]
    local value = tonumber(requested)
    -- Profile defaults are not writes, but a first user change from an unset preference is.
    if previous ~= value
        and value and value % 1 == 0 and value >= spec.minimum and value <= spec.maximum then
      device:send(Configuration:Set({
        parameter_number = spec.parameter,
        size = 2,
        configuration_value = value,
      }))
      get_configuration(device, spec.parameter)
      if spec.parameter == 8 then
        get_configuration(device, 9)
      end
    end
    if value and value % 1 == 0 and value >= spec.minimum and value <= spec.maximum then
      baseline[name] = value
    end
  end
  device:set_field(PREFERENCE_BASELINE, baseline)
end

local function device_init(driver, device)
  local baseline = {}
  for name, spec in pairs(preferences) do
    baseline[name] = tonumber(device.preferences[name]) or spec.default
  end
  device:set_field(PREFERENCE_BASELINE, baseline)
  device:emit_event(capabilities.filterState.supportedFilterCommands({ "resetFilter" }))
  read_zts500_configuration(device)
  device.thread:call_on_schedule(FILTER_POLL_SECONDS, function()
    get_configuration(device, 8)
    get_configuration(device, 9)
  end, "zts500_filter_poll")
end

local function device_added(driver, device)
  if device:supports_capability_by_id(capabilities.thermostatMode.ID)
      and device:is_cc_supported(cc.THERMOSTAT_MODE) then
    device:send(ThermostatMode:SupportedGet({}))
  end
  if device:supports_capability_by_id(capabilities.thermostatFanMode.ID)
      and device:is_cc_supported(cc.THERMOSTAT_FAN_MODE) then
    device:send(ThermostatFanMode:SupportedGet({}))
  end
  device:refresh()
end

local function refresh(driver, device)
  device:default_refresh()
  read_zts500_configuration(device)
end

-- Retain SmartThings' standard thermostat setpoint behavior, including half-degree values.
local function convert_to_device_temp(command_temp, device_scale)
  if command_temp < 40 and device_scale == ThermostatSetpoint.scale.FAHRENHEIT then
    return utils.c_to_f(command_temp)
  elseif command_temp >= 40 and (device_scale == ThermostatSetpoint.scale.CELSIUS or device_scale == nil) then
    return utils.f_to_c(command_temp)
  end
  return command_temp
end

local function set_setpoint_factory(setpoint_type)
  return function(driver, device, command)
    local scale = device:get_field(constants.TEMPERATURE_SCALE)
    local value = convert_to_device_temp(command.args.setpoint, scale)
    local set
    if value % 1 == 0.5 then
      set = ThermostatSetpoint:Set({
        setpoint_type = setpoint_type,
        scale = scale,
        value = value,
        precision = 1,
        size = 2,
      })
    else
      set = ThermostatSetpoint:Set({
        setpoint_type = setpoint_type,
        scale = scale,
        value = utils.round(value),
      })
    end
    device:send_to_component(set, command.component)
    device.thread:call_with_delay(1, function()
      device:send_to_component(ThermostatSetpoint:Get({ setpoint_type = setpoint_type }), command.component)
    end)
  end
end

local driver_template = {
  supported_capabilities = {
    capabilities.temperatureMeasurement,
    capabilities.thermostatHeatingSetpoint,
    capabilities.thermostatCoolingSetpoint,
    capabilities.thermostatOperatingState,
    capabilities.thermostatMode,
    capabilities.thermostatFanMode,
    capabilities.battery,
    capabilities.filterState,
    capabilities.filterStatus,
    capabilities.refresh,
  },
  capability_handlers = {
    [capabilities.thermostatCoolingSetpoint.ID] = {
      [capabilities.thermostatCoolingSetpoint.commands.setCoolingSetpoint.NAME] =
        set_setpoint_factory(ThermostatSetpoint.setpoint_type.COOLING_1),
    },
    [capabilities.thermostatHeatingSetpoint.ID] = {
      [capabilities.thermostatHeatingSetpoint.commands.setHeatingSetpoint.NAME] =
        set_setpoint_factory(ThermostatSetpoint.setpoint_type.HEATING_1),
    },
    [capabilities.filterState.ID] = {
      [capabilities.filterState.commands.resetFilter.NAME] = reset_filter,
    },
    [capabilities.refresh.ID] = {
      [capabilities.refresh.commands.refresh.NAME] = refresh,
    },
  },
  zwave_handlers = {
    [cc.CONFIGURATION] = {
      [Configuration.REPORT] = configuration_report,
    },
  },
  lifecycle_handlers = {
    init = device_init,
    added = device_added,
    infoChanged = info_changed,
  },
  shared_device_thread_enabled = true,
}

defaults.register_for_default_handlers(driver_template, driver_template.supported_capabilities,
  { native_capability_attrs_enabled = true })

ZwaveDriver("remotec_zts500", driver_template):run()
