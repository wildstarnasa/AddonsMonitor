---------------------------------------------------------------------------------------------------
-- addons monitor grid windows
---------------------------------------------------------------------------------------------------

local AMutils = _G.AddonsManagerStuff.AMutils
local AMdata = nil
local PixiePlot = nil

local oAM = nil

local AMgrid = {}

AMgrid.eAlign = {}
AMgrid.eAlign.left = ""
AMgrid.eAlign.center = "Center"
AMgrid.eAlign.right = "Right"

--- public interface below ---

function AMgrid:new(wParent, sGridName)
	local o = {}
    setmetatable(o, self)
    self.__index = self
	
	AMdata = _G.AddonsManagerStuff.AMdata
	PixiePlot = _G.AddonsManagerStuff.PixiePlot
	oAM = _G.AddonsManagerStuff.oAM
	
	o:_init(wParent, sGridName)
	return o
end

function AMgrid:GetConfiguration()
	local tConfig = {}
	
	tConfig.tChartPos = {}
	tConfig.tChartPos[1] = {self.wChart[1]:GetAnchorOffsets()}
	tConfig.tChartPos[0] = {self.wChart[0]:GetAnchorOffsets()}
	tConfig.iVScrollPos = self.wGrid:GetVScrollPos()
	tConfig.iHScrollPos = self.wGrid:GetHScrollPos()
	tConfig.iSortColumn = self.iSortColumn
	tConfig.bIsSortAscending = self.bIsSortAscending
	tConfig.sSelectedItemName = self.sSelectedItemName
	
	return tConfig
end

function AMgrid:SetConfiguration(tConfig, iAddonVersion)
	self.wChart[1]:SetAnchorOffsets(unpack(tConfig.tChartPos[1]))
	self.wChart[0]:SetAnchorOffsets(unpack(tConfig.tChartPos[0]))
	self.tInitialConfig.iVScrollPos = tConfig.iVScrollPos
	self.tInitialConfig.iHScrollPos = tConfig.iHScrollPos
	self.iSortColumn = tConfig.iSortColumn
	self.bIsSortAscending = tConfig.bIsSortAscending
	self.sSelectedItemName = tConfig.sSelectedItemName
	
	return tConfig
end

function AMgrid:BindItem(oItem)
	if oItem.live.eStatus == AMutils.eStatus.off then
		return
	end
	
	self.iItemsCount = self.iItemsCount + 1
	self.tItems[oItem.sUniqueName] = oItem
	self:AddItemToGrid(oItem)
end

function AMgrid:Refresh()
	for iPos = 1, self.iItemsCount do
		self:RefreshItem(iPos)
	end
	
	--self:RefreshEvents()
	
	self:PPlot_Refresh(1)
	
	if self.sSelectedItemName and self.tItems[self.sSelectedItemName].tSessions.iTick % oAM.iHistoryGroupSeconds == 0 then
		self:PPlot_Refresh(0)
	end
	
	self:FixGridAfterRefresh()
	
	if self.bFirstRefresh then
		self.bFirstRefresh = false
	end
end

function AMgrid:InitView()
	self.wGrid:SetVScrollPos(self.tInitialConfig.iVScrollPos)
	self.wGrid:SetHScrollPos(self.tInitialConfig.iHScrollPos)
	if self.sSelectedItemName ~= nil and self.tItems[self.sSelectedItemName] == nil then
		self.sSelectedItemName = nil
	end
end


--- private methods below ---

function AMgrid:_init(wParent, sGridName)
	self.wMain = Apollo.LoadForm("AMgrid.xml", "Grids", wParent, self)
	self.wChart = {}
	self.wChart[1] = self.wMain:FindChild("LiveChart")
	self.wChart[0] = self.wMain:FindChild("HistoryChart")
	self.wGrid = self.wMain:FindChild(sGridName)
	--self.wEvents = self.wMain:FindChild("EventsGrid")
	
	--self.qGlobalEvents = nil
	
	self:PPlot_Init()
		
	self.tInitialConfig = {}
	self.tInitialConfig.iVScrollPos = 0
	self.tInitialConfig.iHScrollPos = 0
	
	self.iItemsCount = 0
	self.tItems = {}
	
	self.sSelectedItemName = nil
	self.iSortColumn = nil
	self.bIsSortAscending = nil
	
	self.bFirstRefresh = true
	self.bSortChanging = false
	
	self.tFields = {}
	self.tFields.status = 1
	self.tFields.name = 2
	self.tFields.mspf = 3
	self.tFields.tps = 4
	self.tFields.l10 = 5
	self.tFields.load = 6
	self.tFields.tmax = 7
	self.tFields.ttotal = 8
	self.tFields.calls = 9
	self.tFields.cmax = 10
	self.tFields.memory = 11
	self.tFields.memmax = 12
	self.tFields.updated = 13
	self.tFields.cfg = 14
	self.tFields.api = 15
	self.tFields.author = 16
	self.tFields.errors = 17
	
	self.tFieldsDesc = {
		[self.tFields.mspf] = true,
		[self.tFields.tps] = true,
		[self.tFields.l10] = true,
		[self.tFields.load] = true,
		[self.tFields.tmax] = true,
		[self.tFields.ttotal] = true,
		[self.tFields.calls] = true,
		[self.tFields.cmax] = true,
		[self.tFields.memory] = true,
		[self.tFields.memmax] = true,
		[self.tFields.errors] = true
	}
	
	self.tFieldsDynamicUpdate = {
		[self.tFields.status] = true,
		[self.tFields.mspf] = true,
		[self.tFields.tps] = true,
		[self.tFields.l10] = true,
		[self.tFields.load] = true,
		[self.tFields.tmax] = true,
		[self.tFields.ttotal] = true,
		[self.tFields.calls] = true,
		[self.tFields.cmax] = true,
		[self.tFields.memory] = true,
		[self.tFields.memmax] = true,
		[self.tFields.errors] = true
	}
end

function AMgrid:AddItemToGrid(oItem)
	local iPos = self.wGrid:AddRow("")
	
	--if self.qGlobalEvents == nil then
		--self.qGlobalEvents = oItem.tSessions.qEvents
	--end
	
	if self.sSelectedItemName == oItem.sUniqueName then
		self.wGrid:SetCurrentRow(iPos)
	end
	
	-- name
	local sName = oItem.sName
	local sColor = "white"
	if oItem.bIsThisAddon then
		sColor = "cyan"
	elseif oItem.bIsCarbine then
		sColor = "gray"
	end
	if sName ~= oItem.sUniqueName then
		sName = sName .. "/" .. oItem.sUniqueName
	end
	self.wGrid:SetCellDoc(iPos, self.tFields.name, self:ColorMe(sColor, sName))
	self.wGrid:SetCellSortText(iPos, self.tFields.name, string.lower(sName))
	self.wGrid:SetCellLuaData(iPos, self.tFields.name, oItem.sUniqueName)
	
	-- configuration dialog
	if oItem.bHasConfig then
		self.wGrid:SetCellText(iPos, self.tFields.cfg, "+")
	else
		self.wGrid:SetCellSortText(iPos, self.tFields.cfg, "x")
	end
	
	-- api version
	local sApiVersion = oItem.iApiVersion
	local sApiVersionSort = sApiVersion
	if oItem.bIgnoreApiVersion then
		sApiVersion = "~" .. sApiVersion
		sApiVersionSort = sApiVersionSort .. "~"
	end
	self.wGrid:SetCellText(iPos, self.tFields.api, sApiVersion)
	self.wGrid:SetCellSortText(iPos, self.tFields.api, sApiVersionSort)
	
	-- last modified date
	self.wGrid:SetCellText(iPos, self.tFields.updated, oItem.tLastModified.sFormatted)
	
	-- author
	local sColorMe = ""
	local sSort = ""
	if not oItem.bIsCarbine then
		sColorMe = self:ColorMe("white", oItem.sAuthor)
		sSort = string.upper(oItem.sAuthor)
	else
		sColorMe = self:ColorMe("gray", "CRB")
		sSort = "a"
	end
	self.wGrid:SetCellSortText(iPos, self.tFields.author, sSort)
	self.wGrid:SetCellDoc(iPos, self.tFields.author, sColorMe)
end

function AMgrid:RefreshItem(iPos)
	local oItem = self.tItems[self.wGrid:GetCellLuaData(iPos, self.tFields.name)]
	
	-- status
	local eStatus = oItem.live.eStatus
	if eStatus ~= oItem.live.ePreviousStatus then
		oItem.live.ePreviousStatus = eStatus
		local sColorMe
		if eStatus == AMutils.eStatus.ok then
			sColorMe = self:ColorMe("green", "", self.eAlign.center)
		elseif eStatus == AMutils.eStatus.warning then
			sColorMe = self:ColorMe("yellow", "warn", self.eAlign.center)
		elseif eStatus == AMutils.eStatus.error then
			sColorMe = self:ColorMe("red", "error", self.eAlign.center)
		elseif eStatus == AMutils.eStatus.fatal then
			sColorMe = self:ColorMe("red", "fatal" , self.eAlign.center)
		else
			sColorMe = self:ColorMe("white", "???", self.eAlign.center)
		end
		self.wGrid:SetCellDoc(iPos, self.tFields.status, sColorMe)
		self.wGrid:SetCellSortText(iPos, self.tFields.status, eStatus)
	end
	
	-- treshold control
	if oItem.live.bBelowTreshold then
		if self.bFirstRefresh then
			self.wGrid:SetCellText(iPos, self.tFields.ttotal, "    < " .. AMdata.fTotalLoadTreshold)
			self.wGrid:SetCellText(iPos, self.tFields.calls, "< " .. AMdata.iTotalCallsTreshold)
			self.wGrid:SetCellSortText(iPos, self.tFields.calls, "         ")
		end
		return
	end
	
	-- ms per frame
	self.wGrid:SetCellText(iPos, self.tFields.mspf, string.format("%6.3f", oItem.live.fLoadPerFrameMs))
	
	-- time per second
	self.wGrid:SetCellText(iPos, self.tFields.tps, string.format("%5.1f", oItem.live.fLoadPerSecondMs))
	
	-- avg load over 10 seconds
	self.wGrid:SetCellText(iPos, self.tFields.l10, string.format("%5.1f", oItem.short.fLoadAvg10Ms))
	
	-- avg load (live monitoring period)
	self.wGrid:SetCellText(iPos, self.tFields.load, string.format("%5.1f", oItem.short.fLoadAvgMs))
	
	-- max time per second
	self.wGrid:SetCellText(iPos, self.tFields.tmax, string.format("%5.1f", oItem.fMaxLoadThisSecondMs))
	
	-- total time
	self.wGrid:SetCellText(iPos, self.tFields.ttotal, string.format("%7.2f", oItem.fLoadTotalSec))
	
	-- memory usage
	self.wGrid:SetCellText(iPos, self.tFields.memory, string.format("%6d", oItem.live.fCurrentMemoryKb))
	
	-- memory max usage
	self.wGrid:SetCellText(iPos, self.tFields.memmax, string.format("%6d", oItem.fMaxMemoryKb))
	
	-- total calls
	self.wGrid:SetCellText(iPos, self.tFields.calls, oItem.iCallsTotal)
	self.wGrid:SetCellSortText(iPos, self.tFields.calls, string.format("%9d", oItem.iCallsTotal))
	
	-- max time of a single call
	self.wGrid:SetCellText(iPos, self.tFields.cmax, string.format("%6.1f", oItem.fMaxTimeOfCallMs))
	
	-- errors
	self.wGrid:SetCellText(iPos, self.tFields.errors, table.concat(oItem.live.tErrors, " | "))
end

function AMgrid:ColorMe(sColor, sText, eAlign)
	local sFormat = '<P'
	if eAlign == self.eAlign.center or eAlign == self.eAlign.right then
		sFormat = sFormat .. ' Align="' .. eAlign .. '"'
	end
	sFormat = sFormat .. ' Font="CRB_Pixel" TextColor="%s">%s</P>'
	
	return string.format(sFormat, sColor, sText)
end

function AMgrid:FixGridAfterRefresh()
	-- re-sort
	if self.iSortColumn ~= nil and (self.bFirstRefresh or (not self.bSortChanging and self.tFieldsDynamicUpdate[self.iSortColumn] ~= nil)) then
		self.wGrid:SetSortColumn(self.iSortColumn, self.bIsSortAscending)
	end
	
	-- re-select
	if self.sSelectedItemName == nil then
		return
	end
	
	local iSelectedPos = self.wGrid:GetCurrentRow()
	if iSelectedPos == nil or self.wGrid:GetCellLuaData(iSelectedPos, self.tFields.name) == self.sSelectedItemName then
		return
	end
	
	for iPos = 1, self.iItemsCount do
		if self.wGrid:GetCellLuaData(iPos, self.tFields.name) == self.sSelectedItemName then
			self.wGrid:SetCurrentRow(iPos)
			return
		end
	end
end

function AMgrid:OnGridClickStart()
	self.bSortChanging = true
end

function AMgrid:OnGridClick()
	local iSortColumn = self.wGrid:GetSortColumn()
	local bIsSortAscending = self.wGrid:IsSortAscending()
	if iSortColumn == nil then
		bIsSortAscending = nil
	end
	
	if self.iSortColumn == iSortColumn and self.bIsSortAscending == bIsSortAscending then
		self.bSortChanging = false
		return
	end
	
	if self.iSortColumn ~= iSortColumn and self.tFieldsDesc[iSortColumn] ~= nil then
		self.wGrid:SetSortColumn(iSortColumn, false)
		bIsSortAscending = false
	end
		
	self.iSortColumn = iSortColumn
	self.bIsSortAscending = bIsSortAscending
	self.bSortChanging = false
	
	self:FixGridAfterRefresh()
end
	
function AMgrid:OnGridSelChange(_, _, iPos)
	self.bSortChanging = false
	local sItemName = nil
	
	if iPos ~= nil then
		sItemName = self.wGrid:GetCellLuaData(iPos, self.tFields.name)
	end
	
	if sItemName == self.sSelectedItemName then
		return
	end
	
	self.sSelectedItemName = sItemName
	
	self:PPlot_ChangeItem(self:PPlot_ShouldDraw(1), 1)
	self:PPlot_Refresh(1)
	
	self:PPlot_ChangeItem(self:PPlot_ShouldDraw(0), 0)
	self:PPlot_Refresh(0)
	--self:RefreshEvents()
end

function AMgrid:RefreshEvents()
	self.wEvents:DeleteAll()
	
	for i = self.qGlobalEvents.first, self.qGlobalEvents.last do
		local tEvent = self.qGlobalEvents[i]
		
		if tEvent.type ~= AMutils.eEvent.reloadUI and tEvent.type ~= AMutils.eEvent.gameReady then
			self.wEvents:AddRow(string.format("(%s) %s, %s", tEvent.tick, AMutils:GetEventName(tEvent.type), tEvent.text or ""))
		end
	end
	
	if self.sSelectedItemName ~= nil then
		local qEvents = self.tItems[self.sSelectedItemName].tHistory.qEvents
		if qEvents.last ~= 0 then
			for i = qEvents.first, qEvents.last do
				self.wEvents:AddRow(string.format("(%s) %s, %s", qEvents[i].tick, AMutils:GetEventName(qEvents[i].type), qEvents[i].text or ""))
			end
		end
	end
end

function AMgrid:ButtonHideLiveGraph()
	--if self.wChart[0]:IsShown() then
	--	self.wChart[1]:Show(false)
	--else
		self.wGrid:SetCurrentRow(0)
		self:OnGridSelChange()
	--end
end

function AMgrid:ButtonHideHistoryGraph()
	--if self.wChart[1]:IsShown() then
	--	self.wChart[0]:Show(false)
	--else
		self.wGrid:SetCurrentRow(0)
		self:OnGridSelChange()
	--end
end

function AMgrid:OnHistoryGraphResized()
	-- this fires too often!
end

function AMgrid:PPlot_Init()
	self.PPlot = {}
	self.PPlot[1] = PixiePlot(self.wChart[1])
	self.PPlot[0] = PixiePlot(self.wChart[0])
	
	self.PPlot_bIsDrawn = {}
	self.PPlot_bIsDrawn[1] = false
	self.PPlot_bIsDrawn[0] = false
	
	local tOptions = {
		fYLabelMargin = 45,
		fXLabelMargin = 30,
		bDrawXValueLabels = true,
		bDrawYValueLabels = true,
		nXValueLabels = 6,
		nXLabelDecimals = 1,
		nYValueLabels = 5,
		nYLabelDecimals = 1,
		bDrawXGridLines = true,
		bDrawYGridLines = true,
		bDrawXAxis = false,
		bDrawYAxis = false,
		bDrawSymbol = false,
		fLineWidth = 2,
		strLabelFont = "CRB_Pixel"
	}
		
	for name, value in pairs(tOptions) do
		self.PPlot[1]:SetOption(name, value)
		self.PPlot[0]:SetOption(name, value)
	end
	
	self.PPlot[1]:SetOption("aPlotColors", {"white"})
	self.PPlot[0]:SetOption("aPlotColors", {"white", "99f97306"})
	self.PPlot[0]:SetOption("xValueFormatter", function (fValue) return self:PPlot_HoursFormatter(fValue) end)
end

function AMgrid:PPlot_HoursFormatter(fValue)
	fValue = math.floor(-fValue)
	return string.format("-%d:%02d", math.floor(fValue / 60), fValue % 60)
end

function AMgrid:PPlot_ChangeItem(bShow, iLive)
	self.PPlot[iLive]:RemoveAllDataSets()
	
	if not bShow then
		self.wChart[iLive]:Show(false)
		self.PPlot_bIsDrawn[iLive] = false
		return
	end
	
	self.PPlot[iLive]:SetYMin(0)
	
	if iLive == 1 then
		self.PPlot[iLive]:SetXInterval(1/60)
		self.PPlot[iLive]:AddDataSet({
			xEnd = 0,
			values = self.tItems[self.sSelectedItemName].short.qLoadHistory
		})
	else
		self.PPlot[iLive]:SetXInterval(1/6)
		self.PPlot[iLive]:AddDataSet({
			xEnd = 0,
			values = self.tItems[self.sSelectedItemName].tHistory.qLoadAvg
		})
		self.PPlot[iLive]:AddDataSet({
			xEnd = 0,
			values = self.tItems[self.sSelectedItemName].tHistory.qLoadMax
		})
	end
		
	self.wChart[iLive]:Show(true)
	self.PPlot_bIsDrawn[iLive] = true
end

function AMgrid:PPlot_Refresh(iLive)
	if self.sSelectedItemName == nil then
		return
	end
	
	if not self.PPlot_bIsDrawn[iLive] then
		if not self:PPlot_ShouldDraw(iLive) then
			return
		end
		self:PPlot_ChangeItem(true, iLive)
	end
	
	self.PPlot[iLive]:Redraw()
end

function AMgrid:PPlot_ShouldDraw(iLive)
	if self.sSelectedItemName == nil then
		return false
	end
	
	if iLive == 1 then
		return AMutils:QueueCount(self.tItems[self.sSelectedItemName].short.qLoadHistory) ~= 0
	else
		return self.tItems[self.sSelectedItemName].tHistory.qLoadAvg ~= nil
	end
end


_G.AddonsManagerStuff.AMgrid = AMgrid

