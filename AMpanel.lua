---------------------------------------------------------------------------------------------------
-- addons monitor dev panel
---------------------------------------------------------------------------------------------------
 
local AMutils = _G.AddonsManagerStuff.AMutils
local oAM = nil

local AMpanel = {}


--- public interface below ---

function AMpanel:new()
	local o = {}
    setmetatable(o, self)
    self.__index = self
	
	oAM = _G.AddonsManagerStuff.oAM
	
	o:_init()
    return o
end

function AMpanel:GetConfiguration()
	local tConfig = {}
	
	tConfig.tMainWndPos = {self.wMain:GetAnchorOffsets()}
	tConfig.bIsHorizontal = self.bIsHorizontal
	
	return tConfig
end

function AMpanel:SetConfiguration(tConfig, iAddonVersion)
    self.bIsHorizontal = tConfig.bIsHorizontal
	self:SetOrientation()
	self.wMain:SetAnchorOffsets(unpack(tConfig.tMainWndPos))
	
	if self.bIsHorizontal and self.wMain:GetWidth() ~= 147 then
		self.wMain:SetAnchorOffsets(tConfig.tMainWndPos[1], tConfig.tMainWndPos[2], tConfig.tMainWndPos[1] + 147, tConfig.tMainWndPos[4])
	elseif not self.bIsHorizontal and self.wMain:GetHeight() ~= 147 then
		self.wMain:SetAnchorOffsets(tConfig.tMainWndPos[1], tConfig.tMainWndPos[2], tConfig.tMainWndPos[3], tConfig.tMainWndPos[2] + 147)
	end
	
	return tConfig
end


--- private methods below ---

function AMpanel:_init()
	self.wMain = Apollo.LoadForm("AMpanel.xml", "DevPanel", nil, self)
	
	Apollo.LoadSprites("AMpanel_Sprites.xml")
	self.wMain:FindChild("OpenAddonsMonitor"):SetSprite("sprAddonsMonitorLive")
	self.wMain:FindChild("OpenRover"):SetSprite("sprRover")
	self.wMain:FindChild("OpenGeminiProfiler"):SetSprite("sprGeminiProfiler")
	self.wMain:FindChild("OpenGeminiConsole"):SetSprite("sprGeminiConsole")
	self.wMain:FindChild("OpenGeminiEditor"):SetSprite("sprGeminiEditor")
	
	self.bIsHorizontal = true
end

function AMpanel:OnRequestChangeOrientation()
	self.bIsHorizontal = not self.bIsHorizontal
	self:SetOrientation()
end

function AMpanel:SetOrientation()
	local iWidth = self.wMain:GetWidth()
	local iHeight = self.wMain:GetHeight()
	local bIsHorzNow = (iWidth > iHeight)
	
	if (bIsHorzNow and self.bIsHorizontal) or (not bIsHorzNow and not self.bIsHorizontal) then
		return
	end
	
	local iLeft, iTop = self.wMain:GetAnchorOffsets()
	self.wMain:SetAnchorOffsets(iLeft, iTop, iLeft + iHeight, iTop + iWidth)
	
	for _, wChild in pairs(self.wMain:GetChildren()) do
		local iLeft, iTop, iRight, iBottom = wChild:GetAnchorOffsets()
		wChild:SetAnchorOffsets(iTop, iLeft, iBottom, iRight)
	end
end

function AMpanel:ButtonHoverOn(wCurrent)
	wCurrent:SetBGColor("xkcdBrightCyan")
end

function AMpanel:ButtonHoverOff(wCurrent)
	wCurrent:SetBGColor("xkcdAcidGreen")
end

function AMpanel:ButtonClickStart(wCurrent)
	wCurrent:SetBGColor("xkcdLightBlue")
end

function AMpanel:ButtonClickEnd(wCurrent)
	local sName = wCurrent:GetName()
	
	wCurrent:SetBGColor("xkcdBrightCyan")
		
	if sName == "OpenAddonsMonitor" then
		oAM:Toggle()
	elseif sName == "OpenRover" then
		Apollo.FindWindowByName("RoverForm"):Show(not Apollo.FindWindowByName("RoverForm"):IsShown())
	elseif sName == "OpenGeminiProfiler" then
		Apollo.FindWindowByName("GeminiProfilerWindow"):Show(not Apollo.FindWindowByName("GeminiProfilerWindow"):IsShown())
	elseif sName == "OpenGeminiConsole" then
		Event_FireGenericEvent("GeminiConsole_ButtonClick")
	elseif sName == "OpenGeminiEditor" then
		Apollo.FindWindowByName("GeminiEditorMain"):Show(not Apollo.FindWindowByName("GeminiEditorMain"):IsShown())
	end
	
	self.wMain:ToFront()
end


_G.AddonsManagerStuff.AMpanel = AMpanel

