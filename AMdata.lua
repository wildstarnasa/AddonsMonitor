---------------------------------------------------------------------------------------------------
-- addons monitor single addon data object
---------------------------------------------------------------------------------------------------

local AMutils = _G.AddonsManagerStuff.AMutils

local oAM = nil

local AMdata = {}

AMdata.sThisAddonName = "AddonsMonitor"

AMdata.iDataRetentionSec = 120
AMdata.fTotalLoadTreshold = 0.01
AMdata.iTotalCallsTreshold = 10
AMdata.iMaxStatsTresholdShort = 5


--- public interface below ---

function AMdata:new(sUniqueName, tAddonInfo, tHistory, tSessions)
	local o = {}
    setmetatable(o, self)
    self.__index = self
	
	oAM = _G.AddonsManagerStuff.oAM
	
	o:_init(sUniqueName, tAddonInfo, tHistory, tSessions)
    return o
end

function AMdata:UpdateStatsLive()
	if self.live.eStatus <= AMutils.eStatus.error then
		return
	end
	self:UpdateStats(Apollo.GetAddonInfo(self.sUniqueName))
end

function AMdata:FinishDataCollection()
	self:SaveRemainingData()
end


--- private methods below ---

function AMdata:_init(sUniqueName, tAddonInfo, tHistory, tSessions)
	self.tHistory = tHistory
	
	self.tSessions = tSessions -- that's just a reference from AMdataManager, do not modify
	
	self.sName = tAddonInfo.strName
	self.sUniqueName = sUniqueName
	self.sAuthor = tAddonInfo.strAuthor
	self.iApiVersion = tAddonInfo.nAPIVersion
	
	self.bIsThisAddon = (self.sThisAddonName == sUniqueName)
	self.bIsCarbine = tAddonInfo.bCarbine
	self.bHasConfig = tAddonInfo.bHasConfigure
	self.bIgnoreApiVersion = tAddonInfo.bIgnoreVersion
	
	self.tLastModified = {}
	self.tLastModified.iTimestamp = self:ConvertCrbDateToTS(tAddonInfo.strLastModified)
	self.tLastModified.sFormatted = os.date("%Y-%m-%d %H:%M", self.tLastModified.iTimestamp)
	
	self.live = {}
	self.live.ePreviousStatus = nil
	self.live.eStatus = nil
	
	self.live.bBelowTreshold = (self.tHistory.qLoadAvg == nil)
	
	self.short = {}
	self.short.qLoadHistory = AMutils:QueueInitMoved(self.tSessions.iTick)
	
	self.short.fLoadTotalMs = 0
	self.short.fLoad10Ms = 0
		
	self.fMaxLoadThisSecondMs = 0
	self.fMaxMemoryKb = 0
	self.fLoadTotalSec = 0
	self.iCallsTotal = 0
	
	self:UpdateStats(tAddonInfo)
end

function AMdata:UpdateStats(tAddonInfo)
	self:UpdateStatsCurrent(tAddonInfo)
	
	if not self.live.bBelowTreshold then
		self:UpdateStatsShortPeriod(tAddonInfo)
		self:UpdateStatsHistory()
	end
end

function AMdata:UpdateStatsCurrent(tAddonInfo)
	self.live.bStatusChanged = (self.live.eStatus ~= tAddonInfo.eStatus)
	self.live.eStatus = tAddonInfo.eStatus
	
	self.live.fLoadPerFrameMs = tAddonInfo.fCallTimePerFrame * 1000
	self.live.fLoadPerSecondMs = tAddonInfo.fCallTimePerSecond * 1000
	self.live.fCurrentMemoryKb = tAddonInfo.nMemoryUsage / 1024
	
	if self.live.bBelowTreshold then
		if tAddonInfo.eStatus == AMutils.eStatus.ok and tAddonInfo.fTotalTime < self.fTotalLoadTreshold and tAddonInfo.nTotalCalls < self.iTotalCallsTreshold then
			return
		end
		
		self.short.qLoadHistory = AMutils:QueueInitMoved(self.tSessions.iTick)
		self.live.bBelowTreshold = false
	end
	
	if self.live.bStatusChanged and self.live.eStatus ~= AMutils.eStatus.ok and self.live.eStatus ~= AMutils.eStatus.off then
		AMutils:EventsPush(self.tHistory.qEvents, AMutils.eEvent.statusChange, self.tSessions.iTick, "status changed to " .. AMutils:GetStatusName(self.live.eStatus))
	end
	
	self.live.tErrors = tAddonInfo.arErrors
	
	self.live.fLoadThisSecondMs = (tAddonInfo.fTotalTime - self.fLoadTotalSec) * 1000
	self.live.iCallsThisSecond = tAddonInfo.nTotalCalls - self.iCallsTotal
	
	self.fLoadTotalSec = tAddonInfo.fTotalTime
	self.iCallsTotal = tAddonInfo.nTotalCalls
	self.fMaxTimeOfCallMs = tAddonInfo.fLongestCall * 1000
end

function AMdata:UpdateStatsShortPeriod(tAddonInfo)
	if self.short.qLoadHistory.last >= self.iMaxStatsTresholdShort then
		local x = self.live.fLoadThisSecondMs
		if self.fMaxLoadThisSecondMs < x then self.fMaxLoadThisSecondMs = x end
		local x = self.live.fCurrentMemoryKb
		if self.fMaxMemoryKb < x then self.fMaxMemoryKb = x end
	end
	
	local iValuesCount = AMutils:QueueCount(self.short.qLoadHistory)
	
	self.short.fLoad10Ms = self.short.fLoad10Ms + self.live.fLoadThisSecondMs
	self.short.fLoadTotalMs = self.short.fLoadTotalMs + self.live.fLoadThisSecondMs
	
	if iValuesCount >= 10 then
		self.short.fLoad10Ms = self.short.fLoad10Ms - self.short.qLoadHistory[self.short.qLoadHistory.last - 9]
	end
	if iValuesCount == self.iDataRetentionSec then
		self.short.fLoadTotalMs = self.short.fLoadTotalMs - AMutils:QueueShift(self.short.qLoadHistory)
	end
		
	AMutils:QueuePush(self.short.qLoadHistory, self.live.fLoadThisSecondMs)
	
	if iValuesCount < 10 then
		self.short.fLoadAvg10Ms = self.short.fLoad10Ms / (iValuesCount + 1)
	else
		self.short.fLoadAvg10Ms = self.short.fLoad10Ms / 10
	end
	self.short.fLoadAvgMs = self.short.fLoadTotalMs / AMutils:QueueCount(self.short.qLoadHistory)
end

function AMdata:UpdateStatsHistory()
	local iEndAt = self.tSessions.iTick
	if iEndAt % oAM.iHistoryGroupSeconds ~= 0 then
		return
	end
	
	if self.tHistory.qLoadAvg == nil then
		self.tHistory.qLoadAvg = AMutils:QueueInit()
		self.tHistory.qLoadMax = AMutils:QueueInit()
	end
	
	local iStartAt = iEndAt - 9
	local fLoadSum = 0
	local fLoadMax = 0
	local iTotalSeconds = (iEndAt - iStartAt + 1)
	
	-- adding data remaining from the previous session
	if iStartAt < self.short.qLoadHistory.first then
		iStartAt = self.short.qLoadHistory.first
		iTotalSeconds = (iEndAt - iStartAt + 1)
		
		if #self.tHistory.tRemaining ~= 0 then
			for _, fTmpLoadCurrent in ipairs(self.tHistory.tRemaining) do
				fLoadSum = fLoadSum + fTmpLoadCurrent
				if fLoadMax < fTmpLoadCurrent then
					fLoadMax = fTmpLoadCurrent
				end
				iTotalSeconds = iTotalSeconds + 1
			end
		end
		self.tHistory.tRemaining = {}
	end
	
	-- iTotalSeconds should always be 10 unless this is the very beginning of collecting data
	
	for i = iStartAt, iEndAt do
		local fLoadCurrent = self.short.qLoadHistory[i]
		fLoadSum = fLoadSum + fLoadCurrent
		if fLoadMax < fLoadCurrent then
			fLoadMax = fLoadCurrent
		end
	end
	
	--for i = 1, 10 do
		AMutils:QueuePush(self.tHistory.qLoadAvg, fLoadSum / iTotalSeconds)
		AMutils:QueuePush(self.tHistory.qLoadMax, fLoadMax)
	--end
	
	if AMutils:QueueCount(self.tHistory.qLoadAvg) > oAM.iHistoryCleanupAt then
		self.tSessions.bRequestCleanup = true
	end
end

function AMdata:SaveRemainingData()
	local iToSave = self.tSessions.iTick % oAM.iHistoryGroupSeconds
	if iToSave == 0 then
		return
	end
	
	local iEndAt = self.short.qLoadHistory.last
	local iStartAt = math.max(self.short.qLoadHistory.first, iEndAt - iToSave + 1)
	
	for i = iStartAt, iEndAt do
		table.insert(self.tHistory.tRemaining, self.short.qLoadHistory[i])
	end
end

function AMdata:ConvertCrbDateToTS(sDate)
	local x = {}
	for s in string.gmatch(sDate, "%d+") do
		table.insert(x, s)
	end
	return os.time({year=x[3], month=x[1], day=x[2], hour=x[4], min=x[5]})
end

_G.AddonsManagerStuff.AMdata = AMdata

