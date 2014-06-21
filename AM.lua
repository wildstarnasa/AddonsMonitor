-----------------------------------------------------------------------------------------------
-- Client Lua Script for AddonsMonitor
-----------------------------------------------------------------------------------------------
 
local iAddonVersion = 5

---------------------------------------------------------------------------------------------------
-- addons monitor main class
---------------------------------------------------------------------------------------------------

local AMutils = _G.AddonsManagerStuff.AMutils
local AMdataManager = _G.AddonsManagerStuff.AMdataManager
local AMwindow = _G.AddonsManagerStuff.AMwindow
local AMgrid = _G.AddonsManagerStuff.AMgrid
local AMpanel = _G.AddonsManagerStuff.AMpanel
 
local AM = {}

AM.fRefreshInterval = 1
AM.iHistoryGroupSeconds = 10


--- public interface below ---
 
function AM:new()
    local o = {}
    setmetatable(o, self)
    self.__index = self
	o:_init()
	return o
end

function AM:Toggle(bTurnOn, bShowLivePanel)
	self.oAMwindow:Toggle(bTurnOn, bShowLivePanel)
end


--- private methods below ---

function AM:_init()
	self.bDataLoaded = false
	self.bSettingsLoaded = false
	self.iHistoryCleanupToMin = 240 -- 4 hours
	self.iHistoryCleanupTo = nil
	self.iHistoryCleanupAt = nil
end

function AM:OnLoad()
	self.oAMpanel = AMpanel:new()
	self.oAMwindow = AMwindow:new()
	self.oAMdataManager = AMdataManager:new()
	
	Apollo.RegisterSlashCommand("addons_monitor", "OnToggleFromSlash", self)
	Apollo.RegisterSlashCommand("am_max", "OnSetMaxHistory", self)
	
	Apollo.RegisterTimerHandler("AddonsMonitor_LiveRefreshInterval", "OnLiveRefreshInterval", self)
end

function AM:OnSave(eLevel)
	local tSettings = {}
	tSettings.iAddonVersion = iAddonVersion

	if eLevel == GameLib.CodeEnumAddonSaveLevel.General then
		tSettings.tData = self.oAMdataManager:GetData()
		tSettings.iHistoryCleanupToMin = self.iHistoryCleanupToMin
		return tSettings
	end
	
	if eLevel == GameLib.CodeEnumAddonSaveLevel.Account then
		tSettings.tAMwindowConfig = self.oAMwindow:GetConfiguration()
		tSettings.tAMpanelConfig = self.oAMpanel:GetConfiguration()
		tSettings.tAMgridLiveConfig = self.oAMwindow:GetLiveGridConfiguration()
		return tSettings
	end
	
	return nil
end

function AM:OnRestore(eLevel, tConfig)
	if eLevel == GameLib.CodeEnumAddonSaveLevel.General then
		self.oAMdataManager:SetData(tConfig.tData, tConfig.iAddonVersion)
		if tConfig.iHistoryCleanupToMin then
			self.iHistoryCleanupToMin = tConfig.iHistoryCleanupToMin
		end
		self.bDataLoaded = true
		self:Initialize()
		return
	end
	
	if eLevel == GameLib.CodeEnumAddonSaveLevel.Account then
		self.oAMwindow:SetConfiguration(tConfig.tAMwindowConfig, tConfig.iAddonVersion)
		self.oAMpanel:SetConfiguration(tConfig.tAMpanelConfig, tConfig.iAddonVersion)
		self.oAMwindow:SetLiveGridConfiguration(tConfig.tAMgridLiveConfig, tConfig.iAddonVersion)
		self.bSettingsLoaded = true
		self:Initialize()
		return
	end
end

function AM:Initialize()
	if not self.bDataLoaded or not self.bSettingsLoaded then
		return
	end
	

	self:UpdateHistoryValues()
	
	self.oAMdataManager:InitializeDataCollection()
	self.oAMwindow:InitializeGridView()
	
	Apollo.CreateTimer("AddonsMonitor_LiveRefreshInterval", self.fRefreshInterval, true)
	self:OnLiveRefreshInterval(true)
end

function AM:OnToggleFromSlash()
	self:Toggle()
end

function AM:OnSetMaxHistory(sCommand, sValue)
	local iValue = tonumber(sValue)
	
	self.iHistoryCleanupToMin = iValue
	self:UpdateHistoryValues()
	RequestReloadUI()
end

function AM:UpdateHistoryValues()
	local iGroupsPerMinute = 60 / self.iHistoryGroupSeconds
	if self.iHistoryCleanupToMin < 30 then
		self.iHistoryCleanupToMin = 30
	end
	self.iHistoryCleanupTo = self.iHistoryCleanupToMin * iGroupsPerMinute
	if self.iHistoryCleanupToMin < 60 then
		self.iHistoryCleanupAt = self.iHistoryCleanupTo + iGroupsPerMinute
	else
		self.iHistoryCleanupAt = self.iHistoryCleanupTo + 10 * iGroupsPerMinute
	end
end

function AM:OnLiveRefreshInterval(bIsFirst)
	self.oAMdataManager:UpdateStatsLive(bIsFirst == true)
	
	self.oAMwindow:RefreshLiveWindow()
	if bIsFirst then
		self.oAMwindow:RefreshHistoryWindow()
	end
end

_G.AddonsManagerStuff.oAM = AM:new()
Apollo.RegisterAddon(_G.AddonsManagerStuff.oAM)

