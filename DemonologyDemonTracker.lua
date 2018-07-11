--[[
The MIT License Copyright (c) 2018 Jacob McPeak. Permission is hereby granted, 
free of charge, to any person obtaining a copy of this software and associated 
documentation files (the "Software"), to deal in the Software without restriction, 
including without limitation the rights to use, copy, modify, merge, publish, 
distribute, sublicense, and/or sell copies of the Software, and to permit persons 
to whom the Software is furnished to do so, subject to the following conditions: 
The above copyright notice and this permission notice shall be included in all copies 
or substantial portions of the Software. THE SOFTWARE IS PROVIDED "AS IS", WITHOUT 
WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES 
OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT 
SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER 
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF 
OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
]]--

local AddonName = "DemonologyDemonTracker";

local BGFrame = CreateFrame("Frame", "DDT_BGFrame", UIParent);

BGFrame:SetMovable(true);
BGFrame:SetClampedToScreen(true);

BGFrame:SetPoint("CENTER", UIParent);
BGFrame:SetSize(300, 360);

BGFrame:RegisterForDrag("LeftButton");
BGFrame:SetScript("OnDragStart", BGFrame.StartMoving);
BGFrame:SetScript("OnDragStop", BGFrame.StopMovingOrSizing);

BGFrame.bgTexture = BGFrame:CreateTexture(nil, "BACKGROUD");
BGFrame.bgTexture:SetColorTexture(0, 0, 0, 0.5);
BGFrame.bgTexture:SetAllPoints(BGFrame);

BGFrame.title = BGFrame:CreateFontString(nil, "OVERLAY");
BGFrame.title:SetFontObject("GameFontHighlight");
BGFrame.title:SetPoint("TOPLEFT", BGFrame, "TOPLEFT", 5, 0);
BGFrame.title:SetText("Moveable Window");

local minionBarParent = BGFrame;
local minionBars = {};
local minionBarCount = 0;
local minionBarFreeList = {};
local minionBarStringFormat = "%.2f";
local squishBarsNextUpdate = false;
local minionYCounter = 0;

local function ConfigOn()
    BGFrame.bgTexture:SetColorTexture(0, 0, 0, 0.5);
    BGFrame.title:Show();
    BGFrame:EnableMouse(true);
end

local function ConfigOff()
    BGFrame.bgTexture:SetColorTexture(0, 0, 0, 0.0);
    BGFrame.title:Hide();
    BGFrame:EnableMouse(false);
end

ConfigOff();

local configToggle = false;

SLASH_DDTCONFIG1 = "/ddt";
SlashCmdList.DDTCONFIG = function()
    if (configToggle) then
        ConfigOff(true);
    else
        ConfigOn();
    end

    configToggle = not configToggle;
end

--[[
    Minion Bar extends Frame:
        index: index into the minionBars array.
        bgTexture: Bar's background texture.
        cdTexture: Bar's background texture.
        cdText: Bar's countdown text.
        minionName: Bar's minion name text.
]]--
local function CreateMinionBar(parent)
    local index = #minionBars + 1;
    minionBars[index] = CreateFrame("Frame", "MinionBar", parent);
    minionBars[index]:SetPoint("RIGHT", parent, "RIGHT", 0, 0);
    minionBars[index]:SetSize(290, 25);

    minionBars[index].bgTexture = minionBars[index]:CreateTexture(nil, "BACKGROUND");
    minionBars[index].bgTexture:SetColorTexture(1, 0, 0);
    minionBars[index].bgTexture:SetPoint("RIGHT", minionBars[index], "RIGHT", 0, 0);
    minionBars[index].bgTexture:SetSize(290, 25);

    minionBars[index].cdTexture = minionBars[index]:CreateTexture(nil, "OVERLAY");
    minionBars[index].cdTexture:SetColorTexture(0, 1, 0);
    minionBars[index].cdTexture:SetPoint("RIGHT", minionBars[index], "RIGHT", 0, 0);
    minionBars[index].cdTexture:SetSize(290, 25);

    minionBars[index].cdText = minionBars[index]:CreateFontString(nil, "OVERLAY");
    minionBars[index].cdText:SetFontObject("GameFontHighlight");
    minionBars[index].cdText:SetPoint("RIGHT", minionBars[index].cdTexture, "RIGHT", 0, 0);

    minionBars[index].minionName = minionBars[index]:CreateFontString(nil, "OVERLAY");
    minionBars[index].minionName:SetFontObject("GameFontHighlight");
    minionBars[index].minionName:SetPoint("LEFT", minionBars[index], "LEFT", 0, 0);

    minionBars[index].index = index;

    return minionBars[index];
end

local function GetMinionBar()
    if(#minionBarFreeList > 0) then
        local index = minionBarFreeList[#minionBarFreeList];
        minionBarFreeList[#minionBarFreeList] = nil;
        minionBars[index]:Show();
        return minionBars[index];
    else
        return CreateMinionBar(minionBarParent);
    end
end

local function ReleaseMinionBar(bar)
    bar:Hide();
    minionBarFreeList[#minionBarFreeList + 1] = bar.index;
end

local function CalculateYOffset(index)
    return -30 * index + 140;
end

local function SquishMinionBars()
    local yIndex = 0;

    for i,v in pairs(minionBars) do
        if(v:IsShown()) then
            v:SetPoint("RIGHT", v:GetParent(), "RIGHT", -5, CalculateYOffset(yIndex));
            yIndex = yIndex + 1;
        end
    end

    minionYCounter = yIndex
end

local minionInfo = {};
function AddMinionInfo(name, lifespan)
    local infoObject = {};
    infoObject.lifespan = lifespan;
    infoObject.strName = name;

    minionInfo[name] = infoObject;
end

-- Temps
AddMinionInfo("Wild Imp", 12);
AddMinionInfo("Dreadstalker", 12);
AddMinionInfo("Darkglare", 12);
AddMinionInfo("Doomguard", 25);
AddMinionInfo("Infernal", 25);

function GetMinionInfo(typeName)
    local info = minionInfo[typeName];

    if (info == nil) then
        print(typeName .. " is not a known minion.");
    else
        return info;
    end
end

local minionCount = 1;
local minionInstanceInfo = {};

local function OnMinionSummon(instanceInfo)
    minionCount = minionCount + 1;

    local bar = GetMinionBar();
    instanceInfo.barIndex = bar.index;

    -- Maybe move UI code
    bar.cdText:SetText(string.format(minionBarStringFormat, instanceInfo.type.lifespan));
    bar.minionName:SetText(instanceInfo.type.strName);

    bar:SetPoint("RIGHT", bar:GetParent(), "RIGHT", -5, CalculateYOffset(minionYCounter));
    minionYCounter = minionYCounter + 1;
end

local function OnMinionUpdate(instanceInfo, currentTime)
    local timeLeft = (instanceInfo.spawnTime + instanceInfo.type.lifespan) - currentTime;
    local bar = minionBars[instanceInfo.barIndex];

    bar.cdText:SetText(string.format(minionBarStringFormat, timeLeft));
    bar.cdTexture:SetSize(290 * timeLeft / instanceInfo.type.lifespan, 25);
end

local function OnMinionDeath(instanceInfo)
    minionCount = minionCount - 1;

    ReleaseMinionBar(minionBars[instanceInfo.barIndex]);
    squishBarsNextUpdate = true;
end

local function CreateMinionInstanceInfo(typeName, UID)
    local info = {};
    info.spawnTime = GetTime();
    info.type = minionInfo[typeName];
    info.unitid = UID;
    return info;
end

local WowEventHandler = {};

function WowEventHandler:COMBAT_LOG_EVENT_UNFILTERED(...)
    local combatEvent = select(2, ...);
    local sourceGUID = select(4, ...);
    local sourceName = select(5, ...);
    local destGUID = select(8, ...);
    local destName = select(9, ...);

    if (combatEvent == "SPELL_SUMMON") then
        if (sourceGUID == UnitGUID("player")) then
            local info = CreateMinionInstanceInfo(destName, destGUID);
            if(not (info.type == nil)) then
                minionInstanceInfo[destGUID] = info;
                OnMinionSummon(minionInstanceInfo[destGUID]);
            end
        end
    end

    if (combatEvent == "SPELL_INSTAKILL" or combatEvent == "UNIT_DIED") then
        if (not (minionInstanceInfo[destGUID] == nil)) then
            OnMinionDeath(minionInstanceInfo[destGUID]);
            minionInstanceInfo[destGUID] = nil;
        end
    end
end

function WowEventHandler:ADDON_LOADED(...)
    local addonName = select(1, ...);
    if (addonName == "HelloWorld") then
    end
end

function BGFrame:Update()
    local currentTime = GetTime();

    for index, value in pairs(minionInstanceInfo) do
        OnMinionUpdate(value, currentTime);

        if (currentTime >= value.spawnTime + value.type.lifespan) then
            OnMinionDeath(minionInstanceInfo[index]);
            minionInstanceInfo[index] = nil;
        end
    end

    if(squishBarsNextUpdate) then
        SquishMinionBars();
        squishBarsNextUpdate = false;
    end
end

BGFrame:SetScript("OnUpdate", BGFrame.Update);
BGFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED");
BGFrame:RegisterEvent("ADDON_LOADED");

BGFrame:SetScript("OnEvent", function(self, event, ...)
    if(not (WowEventHandler[event] == nil)) then
        WowEventHandler[event](WowEventHandler, ...);
    end
end)
