---------------------------------------------------------------------------------------------------
-- addons monitor data objects manager
---------------------------------------------------------------------------------------------------

local AMutils = _G.AddonsManagerStuff.AMutils
local AMdata = _G.AddonsManagerStuff.AMdata

local oAM = nil

local AMdataManager = {}

AMdataManager.tAddonsListTmp = {}

local tDate = GameLib.GetLocalTime()
AMdataManager.fRealGameStartTime = GameLib.GetGameTime()
AMdataManager.bUnitPresentAtStart = (GameLib.GetPlayerUnit() ~= nil)
tDate = nil


--- public interface below ---

function AMdataManager:new()
	local o = {}
    setmetatable(o, self)
    self.__index = self
	
	oAM = _G.AddonsManagerStuff.oAM
	
	o:_init()
    return o
end

function AMdataManager:InitializeDataCollection()
	self.tSessions.iTick = self.tSessions.iTick + 1
	self.tSessions.bRequestCleanup = false
	self:CreateSession()
	
	local tAddonNames = self:GetAllAddonUniqueNames()
	AMutils:Log("checking " .. #tAddonNames .. " unique addon names")
	
	local iAddonsFound = 0
	local iAddonsRunning = 0
	for _, sUniqueName in ipairs(tAddonNames) do
		local oAddon = self:AddAddonByUniqueName(sUniqueName)
		
		if oAddon ~= nil then
			iAddonsFound = iAddonsFound + 1
			if oAddon.live.eStatus > AMutils.eStatus.fatal then
				iAddonsRunning = iAddonsRunning + 1
			end
		end
	end
	AMutils:Log(iAddonsFound .. " addons found, " .. iAddonsRunning .. " that are not stopped")
end

function AMdataManager:GetData()
	self:FinishDataCollection()
	
	local tData = {}
	tData.tSessions = self.tSessions
	tData.tSessions.iTick = tostring(tData.tSessions.iTick)
	tData.tAddonsHistory = self.tAddonsHistory
	
	tData.tSessions.onExit = {}
	tData.tSessions.onExit.iComputerTick = tostring(GameLib.GetTickCount())
	tData.tSessions.onExit.fGameTime = tostring(GameLib.GetGameTime())
			
	return tData
end

function AMdataManager:SetData(tData, iAddonVersion)
	self.tSessions = tData.tSessions
	self.tSessions.iTick = tonumber(self.tSessions.iTick)
	self.tAddonsHistory = tData.tAddonsHistory
	
	return {}
end

function AMdataManager:UpdateStatsLive(bFirstExecution)
	self.tSessions.iTick = self.tSessions.iTick + 1
	
	self.tCurrentTotals.fLoadPerFrameMs = 0
	self.tCurrentTotals.fLoadPerSecondMs = 0
	self.tCurrentTotals.fCurrentMemoryKb = 0
	
	for i = 1, #self.tAllAddons do
		local oAddon = self.tAllAddons[i]
		oAddon:UpdateStatsLive(bFirstExecution)
		
		if not self.bGameReady and not bFirstExecution and oAddon.bIsThisAddon then
			AMutils:EventsPush(self.tSessions.qEvents, AMutils.eEvent.gameReady, self.tSessions.iTick, "after " .. string.format("%d", (GameLib.GetGameTime() - self.fRealGameStartTime) * 1000) .. " ms")
			self.bGameReady = true
		end
		
		self.tCurrentTotals.fLoadPerFrameMs = self.tCurrentTotals.fLoadPerFrameMs + oAddon.live.fLoadPerFrameMs
		self.tCurrentTotals.fLoadPerSecondMs = self.tCurrentTotals.fLoadPerSecondMs + oAddon.live.fLoadPerSecondMs
		self.tCurrentTotals.fCurrentMemoryKb = self.tCurrentTotals.fCurrentMemoryKb + oAddon.live.fCurrentMemoryKb
	end
	
	self.tCurrentTotals.fFramesPerSecond = GameLib.GetFrameRate()
	self.tCurrentTotals.fAddonsLoadPercent = self.tCurrentTotals.fFramesPerSecond * self.tCurrentTotals.fLoadPerFrameMs / 10
	self.tCurrentTotals.fGameDateSec = GameLib.GetWorldTimeOfDay()
	self.tCurrentTotals.fSessionTimeSec = math.floor(GameLib.GetGameTime() - tonumber(self.tSessions.fSessionStartTime))
	
	if self.tSessions.bRequestCleanup then
		self:HistoryCleanup()
	end
end


--- private methods below ---
function AMdataManager:_init()
	self.tAddonsHistory = {}
	self.tAllAddons = {}
	self.tCurrentTotals = {}
	
	self.tSessions = {}
	self.tSessions.iTick = 0
	self.tSessions.sAccount = nil
	self.tSessions.sRealm = nil
	self.tSessions.sCharacter = nil
	
	self.bGameReady = false
end

function AMdataManager:FinishDataCollection()
	for i = 1, #self.tAllAddons do
		self.tAllAddons[i]:FinishDataCollection()
	end
end

function AMdataManager:CreateSession()
	local eStartEvent = nil
	local tARC = GameLib.GetAccountRealmCharacter()
	
	if self.tSessions.qEvents == nil then
		eStartEvent = AMutils.eEvent.firstStart
		self.tSessions.qEvents = AMutils:EventsInit()
	elseif tonumber(self.tSessions.onExit.iComputerTick) > GameLib.GetTickCount() then
		eStartEvent = AMutils.eEvent.computerRestart
	elseif tonumber(self.tSessions.onExit.fGameTime) > self.fRealGameStartTime then
		eStartEvent = AMutils.eEvent.gameRestart
	elseif not self.bUnitPresentAtStart then
		eStartEvent = AMutils.eEvent.relog
	else
		eStartEvent = AMutils.eEvent.reloadUI
	end
	self.tSessions.onExit = nil
	
	local sChanges = {}
	if tARC.strCharacter ~= self.tSessions.sCharacter then
		table.insert(sChanges, tARC.strCharacter)
	end
	if tARC.strRealm ~= self.tSessions.sRealm then
		table.insert(sChanges, tARC.strRealm)
	end
	if tARC.strAccount ~= self.tSessions.sAccount then
		table.insert(sChanges, tARC.strAccount)
	end
	if #sChanges ~= 0 then
		sChanges = "logged in as " .. table.concat(sChanges, ", ")
	else
		sChanges = ""
	end
	
	AMutils:EventsPush(self.tSessions.qEvents, eStartEvent, self.tSessions.iTick, sChanges)
	
	self.tSessions.sAccount = tARC.strAccount
	self.tSessions.sRealm = tARC.strRealm
	self.tSessions.sCharacter = tARC.strCharacter
	
	if eStartEvent ~= AMutils.eEvent.reloadUI then
		self.tSessions.fSessionStartTime = tostring(self.fRealGameStartTime)
	end
end

function AMdataManager:HistoryCleanup()
	for i = self.tSessions.qEvents.first, self.tSessions.qEvents.last do
		if tonumber(self.tSessions.qEvents[i].tick) > (self.tSessions.iTick / 10 - oAM.iHistoryCleanupTo) then
			break
		end
		AMutils:QueueShift(self.tSessions.qEvents)
	end
	
	for _, tHistory in pairs(self.tAddonsHistory) do
		if tHistory.qLoadAvg ~= nil and AMutils:QueueCount(tHistory.qLoadAvg) > oAM.iHistoryCleanupTo then
			local iFirstTick = tHistory.qLoadAvg.last - oAM.iHistoryCleanupTo
			for i = tHistory.qEvents.first, tHistory.qEvents.last do
				if tonumber(tHistory.qEvents[i].tick) > iFirstTick then
					break
				end
				AMutils:QueueShift(tHistory.qEvents)
			end
			for i = tHistory.qLoadAvg.first, iFirstTick do
				AMutils:QueueShift(tHistory.qLoadAvg)
				AMutils:QueueShift(tHistory.qLoadMax)
			end
		end
	end
		
	AMutils:Log("history cleanup performed")
	self.tSessions.bRequestCleanup = false
end

function AMdataManager:AddAddonByUniqueName(sUniqueName)
	local tAddonInfo = Apollo.GetAddonInfo(sUniqueName)
	
	if tAddonInfo == nil then
		return nil
	end
	
	if self.tAddonsHistory[sUniqueName] == nil then
		self.tAddonsHistory[sUniqueName] = {}
		self.tAddonsHistory[sUniqueName].tRemaining = {}
		self.tAddonsHistory[sUniqueName].qEvents = AMutils:EventsInit()
	end
	
	local oThisAddon = AMdata:new(sUniqueName, tAddonInfo, self.tAddonsHistory[sUniqueName], self.tSessions)
	table.insert(self.tAllAddons, oThisAddon)
	
	oAM.oAMwindow:BindAddonToLiveGrid(oThisAddon)
	
	return oThisAddon
end

function AMdataManager:GetAddons()
	local strWildstarDir = string.match(Apollo.GetAssetFolder(), "(.-)[\\/][Aa][Dd][Dd][Oo][Nn][Ss]")
	local tAddonXML = XmlDoc.CreateFromFile(strWildstarDir.."\\Addons.xml"):ToTable()
	for k,v in pairs(tAddonXML) do
		if v.__XmlNode == "Addon" then
			if v.Carbine == "1" then
				table.insert(self.tAddonsListTmp, v.Folder)
			else
				local tSubToc = XmlDoc.CreateFromFile(strWildstarDir.."\\Addons\\" ..v.Folder.."\\toc.xml"):ToTable()
				table.insert(self.tAddonsListTmp, tSubToc.Name)
			end
		end
	end
end

function AMdataManager:GetAllAddonUniqueNames()
	self:GetAddons()
	local tNames = {}
	for sUniqueName, _ in pairs(self.tAddonsHistory) do
		tNames[sUniqueName] = true
	end
	for _, sUniqueName in ipairs(self.tAddonsListTmp) do
		tNames[sUniqueName] = true
	end
	
	local tNamesAsValues = {}
	for sUniqueName, _ in pairs(tNames) do
		table.insert(tNamesAsValues, sUniqueName)
	end
	
	return tNamesAsValues
end


_G.AddonsManagerStuff.AMdataManager = AMdataManager

