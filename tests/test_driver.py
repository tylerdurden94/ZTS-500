from pathlib import Path
import unittest
from lupa.lua53 import LuaRuntime

STUBS = r'''
local function capability(id)
  local c = {ID=id, commands=setmetatable({}, {__index=function(t,k)
    local v={NAME=k}; rawset(t,k,v); return v end})}
  return setmetatable(c, {__index=function(t,k)
    return function(value) return {cap=id, attr=k, value=value} end end})
end
package.preload['st.capabilities']=function() return setmetatable({}, {__index=function(t,k)
  local c=capability(k); rawset(t,k,c); return c end}) end
package.preload['st.zwave.driver']=function() return function(name,t)
  template=t; return {run=function() end} end end
package.preload['st.zwave.defaults']=function() return {register_for_default_handlers=function(t,c,o)
  registered_defaults=true; assert(o.native_capability_attrs_enabled) end} end
package.preload['st.zwave.CommandClass']=function() return {
  CONFIGURATION=112, THERMOSTAT_MODE=64, THERMOSTAT_FAN_MODE=68} end
for _, name in ipairs({'Configuration','ThermostatFanMode','ThermostatMode','ThermostatSetpoint'}) do
  local class_name=name
  package.preload['st.zwave.CommandClass.'..name]=function() return function(version)
    local c={REPORT=6,scale={CELSIUS=0,FAHRENHEIT=1},setpoint_type={COOLING_1=2,HEATING_1=1}}
    for _, method in ipairs({'Get','Set','SupportedGet'}) do
      local method_name=method
      c[method]=function(self,args) return {class=class_name,method=method_name,args=args} end
    end
    return c
  end end
end
package.preload['st.zwave.constants']=function() return {TEMPERATURE_SCALE='temperature_scale'} end
package.preload['st.utils']=function() return {
  c_to_f=function(v) return v*9/5+32 end,
  f_to_c=function(v) return (v-32)*5/9 end,
  round=function(v) return math.floor(v+0.5) end} end
function new_device()
  local d={preferences={},fields={},events={},sent={},timers={},refresh_count=0}
  function d:get_field(k) return self.fields[k] end
  function d:set_field(k,v) self.fields[k]=v end
  function d:emit_event(e) table.insert(self.events,e) end
  function d:send(c) table.insert(self.sent,c) end
  function d:send_to_component(c,comp) c.component=comp; self:send(c) end
  function d:refresh() template.capability_handlers.refresh.refresh(nil,self) end
  function d:default_refresh() self.refresh_count=self.refresh_count+1 end
  function d:supports_capability_by_id(id) return true end
  function d:is_cc_supported(id) return true end
  d.thread={call_with_delay=function(_,seconds,callback)
    table.insert(d.timers,{seconds=seconds,callback=callback}) end,
    call_on_schedule=function(_,seconds,callback,name)
    table.insert(d.timers,{seconds=seconds,callback=callback,name=name}) end}
  return d
end
function report(d,p,v)
  template.zwave_handlers[112][6](nil,d,{args={parameter_number=p,configuration_value=v}})
end
function changed(d,old)
  template.lifecycle_handlers.infoChanged(nil,d,nil,{old_st_store={preferences=old}})
end
'''

class DriverTests(unittest.TestCase):
    def setUp(self):
        self.lua = LuaRuntime(unpack_returned_tuples=True)
        self.lua.execute(STUBS)
        self.lua.execute((Path(__file__).resolve().parent.parent / 'src/init.lua').read_text(encoding='utf-8'))

    def check(self, source):
        self.lua.execute(source)

    def test_filter_reports_in_either_order_and_actual_interval(self):
        self.check('''d=new_device(); report(d,9,350); assert(#d.events==0)
          report(d,8,1000); assert(d.events[1].value.value==65)
          assert(d.events[2].value=='normal')
          d=new_device(); report(d,8,500); report(d,9,350)
          assert(d.events[1].value.value==30)''')

    def test_filter_expiry_invalid_reports_and_zero(self):
        self.check('''d=new_device(); report(d,8,1000); report(d,9,1000)
          assert(d.events[1].value.value==0 and d.events[2].value=='replace')
          report(d,9,9999); assert(d.events[3].value.value==0)
          local count=#d.events; report(d,9,-1); report(d,8,6)
          assert(#d.events==count)
          report(d,9,0); assert(d.events[#d.events-1].value.value==100)
          assert(d.events[#d.events].value=='normal')''')

    def test_reset_waits_for_device_readback(self):
        self.check('''d=new_device(); template.capability_handlers.filterState.resetFilter(nil,d)
          assert(#d.sent==1 and #d.events==0)
          assert(d.sent[1].args.parameter_number==7 and d.sent[1].args.size==2)
          assert(d.sent[1].args.configuration_value==0)
          d.timers[1].callback(); assert(d.sent[2].method=='Get')
          assert(d.sent[2].args.parameter_number==9)''')

    def test_settings_defaults_dont_write_and_first_user_change_does(self):
        self.check('''d=new_device(); template.lifecycle_handlers.init(nil,d); d.sent={}
          d.preferences.temperatureSwing='2'; changed(d,{})
          assert(#d.sent==0)
          d.preferences.temperatureSwing='3'; changed(d,{})
          assert(#d.sent==2 and d.sent[1].method=='Set')
          assert(d.sent[1].args.parameter_number==2 and d.sent[1].args.configuration_value==3)
          assert(d.sent[1].args.size==2)''')

    def test_invalid_settings_do_not_send(self):
        self.check('''d=new_device(); d.preferences.filterIntervalHours=499
          changed(d,{filterIntervalHours=500}); assert(#d.sent==0)
          d.preferences.temperatureSwing='4.5'; changed(d,{temperatureSwing='2'})
          assert(#d.sent==0)''')

    def test_filter_interval_change_and_normal_refresh(self):
        self.check('''d=new_device(); d.preferences.filterIntervalHours=1000
          changed(d,{filterIntervalHours=500}); assert(#d.sent==3)
          assert(d.sent[1].args.parameter_number==8 and d.sent[3].args.parameter_number==9)
          template.capability_handlers.refresh.refresh(nil,d)
          assert(d.refresh_count==1 and #d.sent==9)''')

    def test_standard_half_degree_setpoint_and_poll(self):
        self.check('''assert(registered_defaults); d=new_device()
          d.fields.temperature_scale=0
          template.capability_handlers.thermostatHeatingSetpoint.setHeatingSetpoint(nil,d,
            {args={setpoint=20.5},component='main'})
          assert(d.sent[1].args.value==20.5 and d.sent[1].args.precision==1)
          assert(d.sent[1].args.setpoint_type==1)
          d.timers[1].callback(); assert(d.sent[2].method=='Get')''')

if __name__ == '__main__':
    unittest.main()
