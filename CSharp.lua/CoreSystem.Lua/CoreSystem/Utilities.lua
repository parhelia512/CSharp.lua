--[[
Copyright 2017 YANG Huan (sy.yanghuan@gmail.com).

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

  http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
--]]

local System = System
local throw = System.throw
local define = System.define
local trunc = System.trunc
local ArgumentNullException = System.ArgumentNullException
local fromMilliseconds = System.TimeSpan.FromMilliseconds

local select = select
local type = type
local os = os
local clock = os.clock
local tostring = tostring

define("System.Environment", {
  Exit = os.exit,
  getStackTrace = debug.traceback,

  getTickCount = function ()
    return trunc(clock() * 1000)
  end
})

local Lazy = {
  created = false,

  __ctor__ = function (this, ...)
    local n = select("#", ...)
    if n == 0 then
    elseif n == 1 then
      local valueFactory = ...
      if valueFactory == nil then
        throw(ArgumentNullException("valueFactory"))
      elseif type(valueFactory) ~= "boolean" then
        this.valueFactory = valueFactory
      end
    elseif n == 2 then
      local valueFactory = ...
      if valueFactory == nil then
        throw(ArgumentNullException("valueFactory"))
      end
      this.valueFactory = valueFactory
    end
  end,

  getIsValueCreated = function (this)
    return this.created
  end,

  getValue = function (this)
    if not this.created then
      local valueFactory = this.valueFactory
      if valueFactory then
        this.value = valueFactory()
        this.valueFactory = nil
      else
        this.value = this.__genericT__()
      end
      this.created = true
    end
    return this.value
  end,

  ToString = function (this)
    if this.created then
      return this.value:ToString()
    end
    return "Value is not created."
  end
}

define("System.Lazy", function (T)
  return { 
    __genericT__ = T 
  }
end, Lazy)

local function getPrecision(seconds)
  local s = tostring(seconds)
  local i = s:find("%.")
  if i then
    return #s - i
  end
  return 0
end

local ticker, frequency
local time = System.config.time
if time then
  local p1, p2 = getPrecision(time()), getPrecision(clock())
  if p1 > p2 then
    ticker = time
    frequency = 10 ^ p1
  else
    ticker = clock
    frequency = 10 ^ p2
  end
else
  local p = getPrecision(clock())
  ticker = clock
  frequency = 10 ^ p
end

local function getRawElapsedTicks(this)
  local timeElapsed = this.elapsed
  if this.running then
    local currentTimeStamp = ticker()
    local elapsedUntilNow  = currentTimeStamp - this.startTimeStamp
    timeElapsed = timeElapsed + elapsedUntilNow
  end
  return timeElapsed
end

local Stopwatch
Stopwatch = define("System.Stopwatch", {
  elapsed = 0,
  running = false,
  IsHighResolution = false,
  Frequency = frequency,
  
  StartNew = function ()
    local t = Stopwatch()
    t:Start()
    return t
  end,

  GetTimestamp = function ()
    return trunc(ticker() * frequency)
  end,

  Start = function (this)
    if not this.running then
      this.startTimeStamp = ticker()
      this.running = true
    end
  end,

  Stop = function (this)
    if this.running then
      local endTimeStamp = ticker()
      local elapsedThisPeriod = endTimeStamp - this.startTimeStamp
      local elapsed = this.elapsed + elapsedThisPeriod
      this.running = false
      if elapsed < 0 then
        -- os.clock may be return negative value
        elapsed = 0
      end
      this.elapsed = elapsed
    end
  end,

  Reset = function (this)
    this.elapsed = 0
    this.running = false
    this.startTimeStamp = 0
  end,

  Restart = function (this)
    this.elapsed = 0
    this.startTimeStamp = ticker()
    this.running = true
  end,

  getIsRunning = function (this)
    return this.running
  end,

  getElapsed = function (this)
    return fromMilliseconds(getRawElapsedTicks(this))
  end,

  getElapsedMilliseconds = function (this)
    return trunc(getRawElapsedTicks(this) * 1000)
  end,

  getElapsedTicks = function (this)
    return trunc(getRawElapsedTicks(this) * frequency)
  end
})