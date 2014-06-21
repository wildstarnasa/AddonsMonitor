---------------------------------------------------------------------------------------------------
-- addons monitor utility functions
---------------------------------------------------------------------------------------------------
 
local AMutils = {}

AMutils.bDebug = false

function AMutils:new()
	local o = {}
    setmetatable(o, self)
    self.__index = self
    return o
end


--- addon load statuses ---

AMutils.eStatus = {}
AMutils.eStatus.ok = 7
AMutils.eStatus.warning = 6
AMutils.eStatus.error = 5
AMutils.eStatus.loaded = 4 -- ??
AMutils.eStatus.fatal = 3
AMutils.eStatus.off = 2
AMutils.eStatus.invalid = 1 -- ??

function AMutils:GetStatusName(eStatus)
	if eStatus == self.eStatus.ok then
		return "ok"
	elseif eStatus == self.eStatus.warning then
		return "warning"
	elseif eStatus == self.eStatus.error then
		return "error"
	elseif eStatus == self.eStatus.loaded then
		return "loaded"
	elseif eStatus == self.eStatus.fatal then
		return "fatal"
	elseif eStatus == self.eStatus.off then
		return "off"
	elseif eStatus == self.eStatus.invalid then
		return "invalid"
	else
		return " !! unrecognised: " .. eStatus .. " !! "
	end
end


--- logger ---

function AMutils:Log(sText)
	if not self.bDebug then
		return
	end
	
	Print(sText)
end


--- events implementation ---

AMutils.eEvent = {}

-- generic events
AMutils.eEvent.firstStart = 1
AMutils.eEvent.reloadUI = 2
AMutils.eEvent.relog = 3
AMutils.eEvent.gameRestart = 4
AMutils.eEvent.computerRestart = 5
AMutils.eEvent.gameReady = 6

-- per-addon events
AMutils.eEvent.statusChange = 8

function AMutils:EventsInit()
	return self:QueueInit()
end

function AMutils:EventsPush(list, eEvent, iTick, sText)
	local tEventInfo = {}
	tEventInfo.type = eEvent
	tEventInfo.tick = tostring(iTick)
	if sText ~= nil and sText ~= "" then
		tEventInfo.text = sText
	end
	self:QueuePush(list, tEventInfo)
end

function AMutils:EventsPop(list)
	return self:QueuePop(list)
end

function AMutils:GetEventName(eEvent)
	if eEvent == self.eEvent.firstStart then
		return "first start"
	elseif eEvent == self.eEvent.reloadUI then
		return "reload ui"
	elseif eEvent == self.eEvent.relog then
		return "relog"
	elseif eEvent == self.eEvent.gameRestart then
		return "game restart"
	elseif eEvent == self.eEvent.computerRestart then
		return "computer restart"
	elseif eEvent == self.eEvent.gameReady then
		return "game ready"
	elseif eEvent == self.eEvent.statusChange then
		return "status change"
	else
		return " !! unrecognised: " .. eEvent .. " !! "
	end
end


--- queue implementation (http://www.lua.org/pil/11.4.html) ---

function AMutils:QueuePush(list, value)
	local last = list.last + 1
	list.last = last
	list[last] = value
end

function AMutils:QueuePop(list)
	local last = list.last
	if list.first > last then error("the queue is empty, cannot pop") end
	local value = list[last]
	list[last] = nil -- to allow garbage collection
	list.last = last - 1
	return value
end

function AMutils:QueueShift(list)
	local first = list.first
	if first > list.last then error("the queue is empty, cannot shift") end
	local value = list[first]
	list[first] = nil -- to allow garbage collection
	list.first = first + 1
	return value
end

function AMutils:QueueCount(list)
	return (list.last - list.first + 1)
end

function AMutils:QueueInit()
	return {first = 1, last = 0}
end

function AMutils:QueueInitMoved(next)
	return {first = next, last = next - 1}
end


_G.AddonsManagerStuff = _G.AddonsManagerStuff or {}
_G.AddonsManagerStuff.AMutils = AMutils:new()

