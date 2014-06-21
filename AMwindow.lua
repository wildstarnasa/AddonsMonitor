---------------------------------------------------------------------------------------------------
-- addons monitor main window and subwindows
---------------------------------------------------------------------------------------------------

local AMutils = _G.AddonsManagerStuff.AMutils
local AMgrid = nil
local oAM = nil

local AMwindow = {}

AMwindow.iWindowOpacityMin = 20


--- public interface below ---

function AMwindow:new()
	local o = {}
    setmetatable(o, self)
    self.__index = self
	
	oAM = _G.AddonsManagerStuff.oAM
	AMgrid = _G.AddonsManagerStuff.AMgrid
	
	o:_init()
    return o
end

function AMwindow:Toggle(bTurnOn, bShowLivePanel)
	if bTurnOn == nil then
		bTurnOn = not self.bWindowActive
	end
	if bShowLivePanel == nil then
		bShowLivePanel = self.bLivePanelActive
	end
	
	if bTurnOn then
		if bShowLivePanel then
			self:ActivateLivePanel()
		else
			self:ActivateHistoryPanel()
		end
	end
	
	self.wMain:Show(bTurnOn)
	self.bWindowActive = bTurnOn
end

function AMwindow:RefreshLiveWindow()
	if not self.bWindowActive or not self.bLivePanelActive then
		return
	end
	
	self.oLiveGrid:Refresh()
	self:RefreshLiveData()
end

function AMwindow:RefreshHistoryWindow()
	self.oLiveGrid:PPlot_Refresh(0)
	--self.oLiveGrid:RefreshEvents()
end

function AMwindow:GetConfiguration()
	local tConfig = {}
	tConfig.tMainWndPos = {self.wMain:GetAnchorOffsets()}
	tConfig.iWindowOpacity = self.iWindowOpacity
	tConfig.bWindowActive = self.bWindowActive
	tConfig.bLivePanelActive = self.bLivePanelActive
	
	return tConfig
end

function AMwindow:SetConfiguration(tConfig, iAddonVersion)
	self.wMain:SetAnchorOffsets(unpack(tConfig.tMainWndPos))
	self.iWindowOpacity = tConfig.iWindowOpacity
	self:SetWindowOpacity()
	self.wMain:SetText("")
	self:Toggle(tConfig.bWindowActive, tConfig.bLivePanelActive)
	
	return tConfig
end

function AMwindow:GetLiveGridConfiguration()
	return self.oLiveGrid:GetConfiguration()
end

function AMwindow:SetLiveGridConfiguration(tConfig, iAddonVersion)
	return self.oLiveGrid:SetConfiguration(tConfig, iAddonVersion)
end

function AMwindow:BindAddonToLiveGrid(oAMdata)
	self.oLiveGrid:BindItem(oAMdata)
end

function AMwindow:InitializeGridView()
	self.oLiveGrid:InitView()
end


--- private methods below ---

function AMwindow:_init()
	self.bLivePanelActive = true
	self.bWindowActive = false
	self.iWindowOpacity = 100

	self.xXml = XmlDoc.CreateFromFile("AMwindow.xml")
	self.wMain = Apollo.LoadForm(self.xXml, "AddonsMonitor", nil, self)
	self.wFPS = self.wMain:FindChild("FPS"):FindChild("text")
	self.wTpF = self.wMain:FindChild("T/F"):FindChild("text")
	self.wTpFPCT = self.wMain:FindChild("T/FPCT")
	self.wTpS = self.wMain:FindChild("T/S"):FindChild("text")
	self.wMEM = self.wMain:FindChild("MEM"):FindChild("text")
	self.wGameDate = self.wMain:FindChild("GameDate")
	self.wSessionTime = self.wMain:FindChild("SessionTime")
	
	self.oLiveGrid = AMgrid:new(self.wMain, "LiveGrid", true)
end

function AMwindow:RefreshLiveData()
	self.wTpF:SetText(string.format("%.2f", oAM.oAMdataManager.tCurrentTotals.fLoadPerFrameMs))
	self.wTpS:SetText(string.format("%.2f", oAM.oAMdataManager.tCurrentTotals.fLoadPerSecondMs / 1000))
	self.wMEM:SetText(string.format("%.1f", oAM.oAMdataManager.tCurrentTotals.fCurrentMemoryKb / 1024))
	self.wFPS:SetText(string.format("%.0f", oAM.oAMdataManager.tCurrentTotals.fFramesPerSecond))
	self.wTpFPCT:SetText(string.format("%d", oAM.oAMdataManager.tCurrentTotals.fAddonsLoadPercent) .. "%")
	self.wGameDate:SetText(self:FormatGameDate(oAM.oAMdataManager.tCurrentTotals.fGameDateSec))
	self.wSessionTime:SetText(self:FormatSessionTime(oAM.oAMdataManager.tCurrentTotals.fSessionTimeSec))
end

function AMwindow:FormatGameDate(fGameDateSec)
	local iAll = math.floor(fGameDateSec)
	local iMs = math.floor((fGameDateSec - iAll) * 1000)
	local iSec = iAll % 60
	iAll = (iAll - iSec) / 60
	local iMin = iAll % 60
	iAll = (iAll - iMin) / 60
	
	return string.format("%d:%02d:%02d.%03d", iAll, iMin, iSec, iMs)
end

function AMwindow:FormatSessionTime(iAll)
	local iSec = iAll % 60
	iAll = (iAll - iSec) / 60
	local iMin = iAll % 60
	iAll = (iAll - iMin) / 60
	
	if iAll ~= 0 then
		return string.format("%d:%02d:%02d", iAll, iMin, iSec)
	end
	
	return string.format("%02d:%02d", iMin, iSec)
end

function AMwindow:ActivateLivePanel()
	-- TODO
	
	self.bLivePanelActive = true
end

function AMwindow:ActivateHistoryPanel()
	-- TODO
	
	self.bLivePanelActive = false
end

function AMwindow:ButtonExit()
	self:Toggle()
end

function AMwindow:ButtonOpacityPlus()
	self.iWindowOpacity = self.iWindowOpacity + 5
	self:SetWindowOpacity()
end

function AMwindow:ButtonOpacityMinus()
	self.iWindowOpacity = self.iWindowOpacity - 5
	self:SetWindowOpacity()
end

function AMwindow:SetWindowOpacity()
	self.wMain:FindChild("OpacityPlus"):Enable(self.iWindowOpacity < 100)
	self.wMain:FindChild("OpacityMinus"):Enable(self.iWindowOpacity > self.iWindowOpacityMin)
	self.wMain:SetOpacity(self.iWindowOpacity / 100)
end


_G.AddonsManagerStuff.AMwindow = AMwindow

