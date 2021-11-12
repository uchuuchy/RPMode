--[[	RPMode Alpha 3.
	Author: Seagale
	Last update: December 2nd, 2006.
]]

IRP_VERSION = "Alpha 3";
BINDING_HEADER_IRP_TOGGLE = "RPMode";
RPMode = {
	PlayerName = UnitName("player"),
	RealmName = GetRealmName(),
	RPMode = 0,
	PlayerAFK = 0
};
RPModeSettings = {};
RPModeCharacterInfo = {};
RPModeFriendlist = {};
RPModeInfoboxBlocks = {};

function RPMode.OnLoad()
	RPModeMainFrame:RegisterEvent("VARIABLES_LOADED");
	
	RPModeMainFrame:RegisterEvent("CHAT_MSG_SYSTEM");
	RPModeMainFrame:RegisterEvent("CHAT_MSG_CHANNEL");
	
	RPModeMainFrame:RegisterEvent("UPDATE_MOUSEOVER_UNIT");
	RPModeMainFrame:RegisterEvent("PLAYER_TARGET_CHANGED");
end

function RPMode.PrintMessage(message)
	PREFIX = "|c002BAB31RPMode:|r ";
	DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. message);
end

function RPMode.OnEvent(event)
	if (event == "VARIABLES_LOADED") then
		RPMode.PrintMessage(IRP_STRING_LOADED);
		RPMode.InitialiseDefaultSettings();
		RPMode.InitialiseSlashCommands();
		RPMode.InitialiseUnitPopupMenus();
		RPMode.InitialiseStaticPopups();
		RPMode.InitialiseDefaultCharacterInfo();
		RPModeDatabaseHandler.InitialiseDatabase();
		RPModeDatabaseHandler.PurgePlayers();
	elseif (event == "CHAT_MSG_SYSTEM") then
		if (arg1 == string.format(MARKED_AFK_MESSAGE, DEFAULT_AFK_MESSAGE) or arg1 == MARKED_AFK) then
			RPMode.PlayerAFK = 1;
		elseif (arg1 == CLEARED_AFK) then
			RPMode.PlayerAFK = 0;
		end
	elseif (event == "CHAT_MSG_CHANNEL") then
		if (string.lower(arg9) == string.lower(RPModeSettings["COMM_CHANNEL"])) then
			arg1 = string.gsub(arg1, string.format(SLURRED_SPEECH, ""), "");
			if (RPModeSettings["COMM_PROTOCOL"] == 1) then -- RPMode protocol
				--TODO: Route messages to RPMode protocol handler.
			elseif (RPModeSettings["COMM_PROTOCOL"] == 2) then -- flagRSP protocol
				RPModeflagRSPHandler.ParseChatMessage(arg1,arg2);
			end
		end
	elseif (event == "UPDATE_MOUSEOVER_UNIT") then
		if (RPModeSettings["MODIFY_TOOLTIP"] == 1 and UnitIsPlayer("mouseover")) then
			RPModeTooltipHandler.ProcessTooltip();
			RPModeTooltipHandler.DestroyTooltip();
			RPModeTooltipHandler.ConstructTooltip();
		end
	elseif (event == "PLAYER_TARGET_CHANGED") then
		if (UnitName("target") ~= nil and UnitIsPlayer("target") and RPModeInfoboxHandler.InfoboxChange and not UnitAffectingCombat("player") and RPModeInfoboxBlocks[UnitName("target")] == nil) then
			RPModeInfoboxHandler.SetPlayer(UnitName("target"));
		elseif (RPModeInfoboxHandler.InfoboxChange) then
			RPModeInfobox:Hide();
		end
	end
end

function RPMode.UnitPopup_OnClick()
	local button = this.value;
	if (button == "IRP_TOGGLE") then
		RPMode.ToggleMainFrame();
	elseif (button == "IRP_FLAGRSP_NORPSTATUS") then
		RPMode.ChangeRPStatus(0);
	elseif (button == "IRP_FLAGRSP_OOC") then
		RPMode.ChangeRPStatus(1);
	elseif (button == "IRP_FLAGRSP_IC") then
		RPMode.ChangeRPStatus(2);
	elseif (button == "IRP_FLAGRSP_ICFFA") then
		RPMode.ChangeRPStatus(3);
	elseif (button == "IRP_FLAGRSP_STORYTELLER") then
		RPMode.ChangeRPStatus(4);
	elseif (button == "IRP_FIND") then
		StaticPopup_Show("IRP_CHARACTERLOOKUP");
	elseif (button == "IRP_TOGGLEINFOBOX") then
		if (RPModeInfoboxBlocks[UnitName("target")] ~= nil) then -- blocked
			RPModeInfoboxBlocks[UnitName("target")] = nil;
			if (not RPModeInfobox:IsVisible()) then RPModeInfoboxHandler.SetPlayer(UnitName("target")); end
		else -- not blocked
			RPModeInfoboxBlocks[UnitName("target")] = true;
			if (RPModeInfoboxHandler.InfoboxPlayer == UnitName("target")) then RPModeInfobox:Hide(); RPModeInfoboxHandler.Clear(); end
		end
	end
	RPMode.UnitPopup_OnClick_Old();
end

function RPMode.ChangeRPStatus(newstatus)
	RPModeCharacterInfo["RPSTATUS"] = newstatus;
	if (newstatus == 0) then
		RPMode.PrintMessage(string.format(IRP_STRING_STATUSCHANGED, IRP_STRING_MENU_NORPSTATUS));
	elseif (newstatus == 1) then
		RPMode.PrintMessage(string.format(IRP_STRING_STATUSCHANGED, IRP_STRING_RSP_OOC_TOOLTIP));
	elseif (newstatus == 2) then
		RPMode.PrintMessage(string.format(IRP_STRING_STATUSCHANGED, IRP_STRING_RSP_IC_TOOLTIP));
	elseif (newstatus == 3) then
		RPMode.PrintMessage(string.format(IRP_STRING_STATUSCHANGED, IRP_STRING_RSP_ICFFA_TOOLTIP));
	elseif (newstatus == 4) then
		RPMode.PrintMessage(string.format(IRP_STRING_STATUSCHANGED, IRP_STRING_RSP_STORYTELLER_TOOLTIP));
	end
	RPModeflagRSPHandler.PostHigh();
end

RPMode.UnitPopup_OnClick_Old = UnitPopup_OnClick;
UnitPopup_OnClick = RPMode.UnitPopup_OnClick;

function RPMode.OnUpdate(elapsed)
	if (RPModeSettings["COMM_PROTOCOL"] == 2) then
	
		if (GetTime() > RPModeflagRSPHandler.LastPostLow + RPModeflagRSPHandler.PostInterval) then
			RPModeflagRSPHandler.PostLow();
			RPModeflagRSPHandler.LastPostLow = GetTime();
		end
		
		if (GetTime() > RPModeflagRSPHandler.LastPostHigh + RPModeflagRSPHandler.PostIntervalHigh) then
			RPModeflagRSPHandler.PostHigh();
			RPModeflagRSPHandler.LastPostHigh = GetTime();
		end
		
		if (GetTime() > RPModeInfoboxHandler.LastUpdate + RPModeInfoboxHandler.UpdateInterval) then
			RPModeInfoboxHandler.Update();
			RPModeInfoboxHandler.LastUpdate = GetTime();
		end
		
		RPModeChatHandler.ExecuteQueue();
	end
end

function RPMode.HandleMinimapDropdown()
	local id = this:GetID();
	if (id == 2) then
		RPMode.ToggleMainFrame();
	elseif (id == 3) then
		RPMode.ChangeRPStatus(1)
	elseif (id == 4) then
		RPMode.ChangeRPStatus(2)
	elseif (id == 5) then
		RPMode.ChangeRPStatus(3)
	elseif (id == 6) then
		RPMode.ChangeRPStatus(4)
	elseif (id == 7) then
		RPMode.ChangeRPStatus(0)
	elseif (id == 8) then
		StaticPopup_Show("IRP_CHARACTERLOOKUP");
	end
end

function RPMode.InitialiseMinimapDropdown()
	local info = {};
	info.func = RPMode.HandleMinimapDropdown;
	
	info.isTitle = 1;
	info.text = "RPMode";
	UIDropDownMenu_AddButton(info);
	
	info.isTitle = nil;
	info.disabled = nil;
	info.text = IRP_STRING_MENU_TOGGLE;
	UIDropDownMenu_AddButton(info);
	
	if (RPModeSettings["COMM_PROTOCOL"] == 2) then --flagRSP protocol
		info.text = IRP_STRING_RSP_OOC_TOOLTIP;
		info.checked = RPModeCharacterInfo["RPSTATUS"] == 1;
		UIDropDownMenu_AddButton(info);
		
		info.text = IRP_STRING_RSP_IC_TOOLTIP;
		info.checked = RPModeCharacterInfo["RPSTATUS"] == 2;
		UIDropDownMenu_AddButton(info);
		
		info.text = IRP_STRING_RSP_ICFFA_TOOLTIP;
		info.checked = RPModeCharacterInfo["RPSTATUS"] == 3;
		UIDropDownMenu_AddButton(info);
		
		info.text = IRP_STRING_RSP_STORYTELLER_TOOLTIP;
		info.checked = RPModeCharacterInfo["RPSTATUS"] == 4;
		UIDropDownMenu_AddButton(info);
		
		info.text = IRP_STRING_MENU_NORPSTATUS;
		info.checked = RPModeCharacterInfo["RPSTATUS"] == 0;
		UIDropDownMenu_AddButton(info);
	end
	
	info.text = IRP_STRING_MENU_FIND;
	info.checked = nil;
	UIDropDownMenu_AddButton(info);
end
function RPMode.HandleCheckbox()
	if (this:GetName() == "RPModeSettingsModifyTooltip") then
		if (this:GetChecked() == nil) then
			RPModeSettings["MODIFY_TOOLTIP"] = 0;
		else
			RPModeSettings["MODIFY_TOOLTIP"] = 1;
		end
	elseif (this:GetName() == "RPModeSettingsHideUnknown") then
		if (this:GetChecked() == nil) then
			RPModeSettings["HIDE_UNKNOWN_PLAYERS"] = 0;
		else
			RPModeSettings["HIDE_UNKNOWN_PLAYERS"] = 1;
		end
	elseif (this:GetName() == "RPModeSettingsRelativeLevels") then
		if (this:GetChecked() == nil) then
			RPModeSettings["SHOW_RELATIVE_LEVELS"] = 0;
		else
			RPModeSettings["SHOW_RELATIVE_LEVELS"] = 1;
		end
	end
end

function RPMode.HandleGuildDropdown()
	UIDropDownMenu_SetSelectedID(RPModeSettingsGuildNames, this:GetID());
	RPModeSettings["SHOW_GUILDS"] = UIDropDownMenu_GetSelectedID(RPModeSettingsGuildNames);
end


function RPMode.InitialiseGuildDropdown()
	local info = {};
	info.func = RPMode.HandleGuildDropdown;
	
	info.text = IRP_STRING_ALWAYS_SHOW_GUILDS;
	info.checked = RPModeSettings["SHOW_GUILDS"] == 1;
	UIDropDownMenu_AddButton(info);

	info.text = IRP_STRING_NEVER_SHOW_GUILDS;
	info.checked = RPModeSettings["SHOW_GUILDS"] == 2;
	UIDropDownMenu_AddButton(info);

	info.text = IRP_STRING_KNOWN_SHOW_GUILDS;
	info.checked = RPModeSettings["SHOW_GUILDS"] == 3;
	UIDropDownMenu_AddButton(info);
end

function RPMode.HandlePvPDropdown()
	UIDropDownMenu_SetSelectedID(RPModeSettingsPvPRanks, this:GetID());
	RPModeSettings["SHOW_RANKS"] = UIDropDownMenu_GetSelectedID(RPModeSettingsPvPRanks);
end


function RPMode.InitialisePvPDropdown()
	local info = {};
	info.func = RPMode.HandlePvPDropdown;
	
	info.text = IRP_STRING_ALWAYS_SHOW_PVP;
	info.checked = RPModeSettings["SHOW_RANKS"] == 1;
	UIDropDownMenu_AddButton(info);

	info.text = IRP_STRING_NEVER_SHOW_PVP;
	info.checked = RPModeSettings["SHOW_RANKS"] == 2;
	UIDropDownMenu_AddButton(info);

	info.text = IRP_STRING_KNOWN_SHOW_PVP;
	info.checked = RPModeSettings["SHOW_RANKS"] == 3;
	UIDropDownMenu_AddButton(info);
end

function RPMode.RPModeSettingsChangeChannel_OnClick()
	RPModeSettings["COMM_PROTOCOL"] = UIDropDownMenu_GetSelectedID(RPModeSettingsCommProtocol);
	if (RPModeSettings["COMM_CHANNEL"] ~= RPModeSettingsCommChannel:GetText()) then LeaveChannelByName(RPModeSettings["COMM_CHANNEL"]); end
	RPModeSettings["COMM_CHANNEL"] = RPModeSettingsCommChannel:GetText();
	JoinChannelByName(RPModeSettings["COMM_CHANNEL"]);
	ChatFrame_RemoveChannel(ChatFrame1, RPModeSettings["COMM_CHANNEL"]);
end

function RPMode.RPModeSettingsJoinChannel_OnClick()
	JoinChannelByName(RPModeSettings["COMM_CHANNEL"]);
	ChatFrame_RemoveChannel(ChatFrame1, RPModeSettings["COMM_CHANNEL"]);
end

function RPMode.HandleProtocolDropdown()
	UIDropDownMenu_SetSelectedID(RPModeSettingsCommProtocol, this:GetID());
	if (this:GetID() == 1) then
		RPModeSettingsCommChannel:SetText("immersioncomm");
	elseif (this:GetID() == 2) then
		RPModeSettingsCommChannel:SetText("xtensionxtooltip2");
	end
end


function RPMode.InitialiseProtocolDropdown()
	local info = {};
	info.func = RPMode.HandleProtocolDropdown;
	
	info.text = "RPMode";
	info.checked = RPModeSettings["COMM_PROTOCOL"] == 1;
	UIDropDownMenu_AddButton(info);

	info.text = "flagRSP";
	info.checked = RPModeSettings["COMM_PROTOCOL"] == 2;
	UIDropDownMenu_AddButton(info);
end

function RPMode.HandleNameDropdown()
	if (this:GetID() ~= UIDropDownMenu_GetSelectedID(RPModeCharacterNameKind)) then
		UIDropDownMenu_SetSelectedID(RPModeCharacterNameKind, this:GetID());
		RPModeCharacterRevert:Enable();
	end
end

function RPMode.RPModeCharacterRevert_OnClick()
	RPMode.RefreshCharacterInfoTab();
end

function RPMode.EncodeDescription(desc)
	return string.gsub(string.gsub(string.gsub(desc, "<", "\\%("), ">", "\\%)"), "\n", "\\l");
end

function RPMode.DecodeDescription(desc)
	return string.gsub(string.gsub(string.gsub(desc, "\\%(", "<"), "\\%)", ">"), "\\l", "\n");
end

function RPMode.SaveCharacterInfo()
	
	if (RPModeCharacterInfo["EXTRANAME1"] ~= RPModeCharacterName:GetText()) then
		if (RPModeCharacterName:GetText() == "") then
			RPMode.PrintMessage(IRP_STRING_NAMECLEARED);
		else
			RPMode.PrintMessage(string.format(IRP_STRING_NAMECHANGED, RPModeCharacterName:GetText()));
		end
		RPModeCharacterInfo["EXTRANAME1"] = RPModeCharacterName:GetText();
	end
	
	local nametype = UIDropDownMenu_GetSelectedID(RPModeCharacterNameKind);
	if (nametype == 1 and RPModeCharacterInfo["NAMETYPE"] ~= 1) then -- changed to first name
		RPModeCharacterInfo["NAMETYPE"] = 1;
		RPMode.PrintMessage(IRP_STRING_NAMEFIRST);
	elseif (nametype == 2 and RPModeCharacterInfo["NAMETYPE"] ~= 0) then -- changed to last name
		RPModeCharacterInfo["NAMETYPE"] = 0;
		RPMode.PrintMessage(IRP_STRING_NAMELAST);
	end -- don't care about the rest
	
	
	if (RPModeCharacterInfo["TITLE"] ~= RPModeCharacterTitle:GetText()) then
		if (RPModeCharacterTitle:GetText() == "" or RPModeCharacterTitle:GetText() == nil) then
			RPMode.PrintMessage(IRP_STRING_TITLECLEARED);
		else
			RPMode.PrintMessage(string.format(IRP_STRING_TITLECHANGED, RPModeCharacterTitle:GetText()));
		end
		RPModeCharacterInfo["TITLE"] = RPModeCharacterTitle:GetText();
	end
	
	if (RPModeSettings["COMM_PROTOCOL"] == 2) then 
		if (RPModeCharacterInfo["DESCMETA"] == nil or RPModeCharacterInfo["DESCMETA"] == "") then RPModeCharacterInfo["DESCMETA"] = 0; end
		if (RPMode.EncodeDescription(RPModeCharacterDescription:GetText()) ~= RPModeCharacterInfo["DESCRIPTION"]) then
			if (RPModeCharacterDescription:GetText() == "" or RPModeCharacterDescription:GetText() == nil) then
				RPModeCharacterInfo["DESCMETA"] = 0;
				RPModeCharacterInfo["DESCRIPTION"] = "";
				RPMode.PrintMessage(IRP_STRING_DESCRIPTIONCLEARED);

			else
				RPModeCharacterInfo["DESCMETA"] = RPModeCharacterInfo["DESCMETA"] + 1;
				RPModeCharacterInfo["DESCRIPTION"] = RPMode.EncodeDescription(RPModeCharacterDescription:GetText());
				RPMode.PrintMessage(IRP_STRING_DESCRIPTIONCHANGED);
			end
			RPModeflagRSPHandler.LastDescPost = 0;
		end
		if (RPModeCharacterInfo["RPSTYLE"] ~= UIDropDownMenu_GetSelectedID(RPModeCharacterRPStyle)-1) then
			RPModeCharacterInfo["RPSTYLE"] = UIDropDownMenu_GetSelectedID(RPModeCharacterRPStyle)-1;
			RPMode.PrintMessage(string.format(IRP_STRING_STYLECHANGED, UIDropDownMenu_GetText(RPModeCharacterRPStyle)));
		end
		RPModeflagRSPHandler.PostLow(); 
		RPModeflagRSPHandler.PostHigh(true);
	end
end

function RPMode.InitialiseNameDropdown()
	local info = {};
	info.func = RPMode.HandleNameDropdown;
	
	info.text = IRP_STRING_CHARACTER_FIRST;
	info.value = 1;
	info.checked = RPModeCharacterInfo["NAMETYPE"] == 1;
	UIDropDownMenu_AddButton(info);

	info.text = IRP_STRING_CHARACTER_LAST;
	info.value = 0;
	info.checked = RPModeCharacterInfo["NAMETYPE"] == 0;
	UIDropDownMenu_AddButton(info);
end

function RPMode.HandleRPStyleDropdown()
	if (this:GetID() ~= UIDropDownMenu_GetSelectedID(RPModeCharacterRPStyle)) then
		UIDropDownMenu_SetSelectedID(RPModeCharacterRPStyle, this:GetID());
		RPModeCharacterRevert:Enable();
	end
end


function RPMode.InitialiseRPStyleDropdown()
	if (RPModeSettings["COMM_PROTOCOL"] == 2) then
		local info = {};
		info.func = RPMode.HandleRPStyleDropdown;
		
		info.text = IRP_STRING_RSP_NORP;
		info.value = 0;
		info.checked = RPModeCharacterInfo["RPSTYLE"] == info.value;
		UIDropDownMenu_AddButton(info);
	
		info.text = IRP_STRING_RSP_RP;
		info.value = 1;
		info.checked = RPModeCharacterInfo["RPSTYLE"] == info.value;
		UIDropDownMenu_AddButton(info);
		
		info.text = IRP_STRING_RSP_CASUALRP;
		info.value = 2;
		info.checked = RPModeCharacterInfo["RPSTYLE"] == info.value;
		UIDropDownMenu_AddButton(info);
		
		info.text = IRP_STRING_RSP_FULLTIMERP;
		info.value = 3;
		info.checked = RPModeCharacterInfo["RPSTYLE"] == info.value;
		UIDropDownMenu_AddButton(info);
		
		info.text = IRP_STRING_RSP_BEGINNERRP;
		info.value = 4;
		info.checked = RPModeCharacterInfo["RPSTYLE"] == info.value;
		UIDropDownMenu_AddButton(info);
	end
end

function RPMode.InitialiseDefaultSettings()
	if (RPModeSettings["COMM_CHANNEL"] == nil) then 
		RPModeSettings["COMM_CHANNEL"] = "xtensionxtooltip2";
	end
	if (RPModeSettings["COMM_PROTOCOL"] == nil) then 
		RPModeSettings["COMM_PROTOCOL"] = 2;
	end
	if (RPModeSettings["MODIFY_TOOLTIP"] == nil) then 
		RPModeSettings["MODIFY_TOOLTIP"] = 1;
	end
	if (RPModeSettings["HIDE_UNKNOWN_PLAYERS"] == nil) then 
		RPModeSettings["HIDE_UNKNOWN_PLAYERS"] = 0;
	end
	if (RPModeSettings["SHOW_GUILDS"] == nil) then 
		RPModeSettings["SHOW_GUILDS"] = 1;
	end
	if (RPModeSettings["SHOW_RANKS"] == nil) then 
		RPModeSettings["SHOW_RANKS"] = 1;
	end
	if (RPModeSettings["SHOW_RELATIVE_LEVELS"] == nil) then
		RPModeSettings["SHOW_RELATIVE_LEVELS"] = 0;
	end
	if (RPModeSettings["SHOW_MINIMAP_ICON"] ~= nil) then
		RPModeMinimapIcon:Show();
	end
end

function RPMode.InitialiseDefaultCharacterInfo()
	if (RPModeCharacterInfo["RPSTYLE"] == nil) then 
		RPModeCharacterInfo["RPSTYLE"] = 0;
	end
	if (RPModeCharacterInfo["RPSTATUS"] == nil) then 
		RPModeCharacterInfo["RPSTATUS"] = 0;
	end
	if (RPModeCharacterInfo["TITLE"] == nil) then 
		RPModeCharacterInfo["TITLE"] = "";
	end
	if (RPModeCharacterInfo["EXTRANAME1"] == nil) then 
		RPModeCharacterInfo["EXTRANAME1"] = "";
	end
	if (RPModeCharacterInfo["NAMETYPE"] == nil) then 
		RPModeCharacterInfo["NAMETYPE"] = 0;
	end
	if (RPModeCharacterInfo["DESCMETA"] == nil) then 
		RPModeCharacterInfo["DESCMETA"] = 0;
	end
	if (RPModeCharacterInfo["DESCRIPTION"] == nil) then
		RPModeCharacterInfo["DESCRIPTION"] = "";
	end
end

function RPMode.InitialiseSlashCommands()
	SLASH_RPModeTOGGLE1 = "/RPMode";
	SLASH_RPModeTOGGLE2 = "/irp";
	SlashCmdList["RPModeTOGGLE"] = RPMode.HandleSlashCommands;
end

function RPMode.InitialiseStaticPopups()
	StaticPopupDialogs["IRP_CHARACTERLOOKUP"] = {
		text = IRP_STRING_CHARACTERLOOKUP_TEXT,
		button1 = IRP_STRING_CHARACTERLOOKUP_FIND,
		button2 = CANCEL,
		OnAccept = function()
			RPMode.FindCharacter(getglobal(this:GetParent():GetName().."EditBox"):GetText());
		end,
		EditBoxOnEnterPressed = function()
			RPMode.FindCharacter(getglobal(this:GetParent():GetName().."EditBox"):GetText());
		end,		
		timeout = 0,
		whileDead = 1,
		hideOnEscape = 1,
		hasEditBox = 1
	};
end

function RPMode.FindCharacter(nametyped)
	if (nametyped ~= "" and nametyped ~= nil) then
		for name in pairs(RPModeDatabase[RPMode.RealmName]) do
			if (string.find(string.lower(name), string.lower(nametyped)) ~= nil or string.find(string.lower(RPModeDatabaseHandler.GetPlayerName(name)), string.lower(nametyped)) ~= nil) then
				if (not RPModeInfoboxHandler.SetPlayer(name)) then 
					UIErrorsFrame:AddMessage(string.format(IRP_STRING_CHARACTERLOOKUP_NOINFO, nametyped),1,0,0);
				else
					RPModeInfoboxHandler.InfoboxChange = false;
				end
				return nil;
			end
		end
		UIErrorsFrame:AddMessage(string.format(IRP_STRING_CHARACTERLOOKUP_NOMATCH, nametyped),1,0,0);
	end
end

function RPMode.InitialiseUnitPopupMenus()
	UnitPopupButtons["IRP_MENU"] = { text = "RPMode", dist = 0, nested = 1 };
	UnitPopupButtons["IRP_TOGGLE"] = { text = IRP_STRING_MENU_TOGGLE, dist = 0 };
	UnitPopupButtons["IRP_FIND"] = { text = IRP_STRING_MENU_FIND, dist = 0 };
	UnitPopupButtons["IRP_TOGGLEINFOBOX"] = { text = IRP_STRING_MENU_TOGGLEINFOBOX, dist = 0};
	if (RPModeSettings["COMM_PROTOCOL"] == 2) then --flagRSP protocol
		UnitPopupButtons["IRP_FLAGRSP_OOC"] = { text = IRP_STRING_RSP_OOC_TOOLTIP, dist = 0 };
		UnitPopupButtons["IRP_FLAGRSP_IC"] = { text = IRP_STRING_RSP_IC_TOOLTIP, dist = 0 };
		UnitPopupButtons["IRP_FLAGRSP_ICFFA"] = { text = IRP_STRING_RSP_ICFFA_TOOLTIP, dist = 0 };
		UnitPopupButtons["IRP_FLAGRSP_STORYTELLER"] = { text = IRP_STRING_RSP_STORYTELLER_TOOLTIP, dist = 0 };
		UnitPopupButtons["IRP_FLAGRSP_NORPSTATUS"] = { text = IRP_STRING_MENU_NORPSTATUS, dist = 0 };
		UnitPopupMenus["IRP_MENU"] = { "IRP_TOGGLE", "IRP_FLAGRSP_OOC", "IRP_FLAGRSP_IC", "IRP_FLAGRSP_ICFFA", "IRP_FLAGRSP_STORYTELLER", "IRP_FLAGRSP_NORPSTATUS", "IRP_FIND" };
	end
	table.insert(UnitPopupMenus["SELF"],table.getn(UnitPopupMenus["SELF"]),"IRP_MENU");
	table.insert(UnitPopupMenus["PLAYER"],table.getn(UnitPopupMenus["PLAYER"]),"IRP_TOGGLEINFOBOX");
	table.insert(UnitPopupMenus["PARTY"],table.getn(UnitPopupMenus["PARTY"]),"IRP_TOGGLEINFOBOX");
	table.insert(UnitPopupMenus["RAID"],table.getn(UnitPopupMenus["RAID"]),"IRP_TOGGLEINFOBOX");
end

function RPMode.HandleSlashCommands(command)
	if (command == "") then
		RPMode.ToggleMainFrame();
	elseif (string.lower(command) == "rpmode") then
		RPMode.ToggleRPMode();
	elseif (string.lower(command) == "help") then
		RPModeMainFrame:Show()
		RPMode.ShowHelp();
	elseif (string.lower(command) == "character") then
		RPModeMainFrame:Show()
		RPMode.ShowCharacterInfo();
	elseif (string.lower(command) == "settings") then
		RPModeMainFrame:Show()
		RPMode.ShowSettings();
	elseif (string.lower(command) == "toggleicon") then
		if (RPModeMinimapIcon:IsVisible()) then
			RPModeMinimapIcon:Hide();
			RPModeSettings["SHOW_MINIMAP_ICON"] = nil;
		else
			RPModeMinimapIcon:Show();
			RPModeSettings["SHOW_MINIMAP_ICON"] = true;
		end
	elseif (string.lower(command) == "owntooltip") then
		RPModeTooltipHandler.ShowOwnTooltip();
	elseif (string.lower(command) == "moverpbutton") then
		if (not RPModeRPModeButton.Draggable) then
			RPModeRPModeButton:RegisterForDrag("LeftButton");
			RPModeRPModeButton.Draggable = true;
		else
			RPModeRPModeButton:RegisterForDrag("");
			RPModeRPModeButton.Draggable = nil;
		end
	elseif (string.lower(string.sub(command, 1, 4)) == "find") then
		if (string.sub(command, 6, string.len(command)) ~= "") then
			RPMode.FindCharacter(string.sub(command, 6, string.len(command)));
		else
			StaticPopup_Show ("IRP_CHARACTERLOOKUP");
		end
	end 
end

function RPMode.ToggleMainFrame()
	if (RPModeMainFrame:IsVisible()) then
		RPModeMainFrame:Hide();
	else
		RPModeMainFrame:Show();
	end 
end

function RPMode.ShowHelp()
	RPModeFriendFrame:Hide();
	RPModeCharacterFrame:Hide();
	RPModeSettingsFrame:Hide();
	RPModeHelpFrame:Show();
end

function RPMode.ShowSettings()
	RPModeFriendFrame:Hide();
	RPModeCharacterFrame:Hide();
	RPModeHelpFrame:Hide();
	if (not RPModeSettingsFrame:IsVisible()) then
		RPMode.RefreshSettingsTab();
	end
	RPModeSettingsFrame:Show();
end

function RPMode.RefreshSettingsTab()
	RPModeSettingsModifyTooltip:SetChecked(RPModeSettings["MODIFY_TOOLTIP"]);
	RPModeSettingsHideUnknown:SetChecked(RPModeSettings["HIDE_UNKNOWN_PLAYERS"]);
	RPModeSettingsRelativeLevels:SetChecked(RPModeSettings["SHOW_RELATIVE_LEVELS"]);
	RPModeSettingsCommChannel:ClearFocus();
	RPModeSettingsCommChannel:SetText(RPModeSettings["COMM_CHANNEL"]);
end

function RPMode.RefreshCharacterInfoTab()
	RPModeCharacterDescription:SetText(RPMode.DecodeDescription(RPModeCharacterInfo["DESCRIPTION"]));
	RPModeCharacterName:SetText(RPModeCharacterInfo["EXTRANAME1"]);
	RPModeCharacterTitle:SetText(RPModeCharacterInfo["TITLE"]);
	
	HideDropDownMenu(1);
	UIDropDownMenu_Initialize(RPModeCharacterRPStyle, RPMode.InitialiseRPStyleDropdown);
	UIDropDownMenu_SetSelectedID(RPModeCharacterRPStyle,RPModeCharacterInfo["RPSTYLE"] + 1,false);
	UIDropDownMenu_SetWidth(240, RPModeCharacterRPStyle);
	
	UIDropDownMenu_Initialize(RPModeCharacterNameKind, RPMode.InitialiseNameDropdown);
	if (RPModeCharacterInfo["NAMETYPE"] == 0) then UIDropDownMenu_SetSelectedID(RPModeCharacterNameKind, 2); else UIDropDownMenu_SetSelectedID(RPModeCharacterNameKind, 1); end
	UIDropDownMenu_SetWidth(55, RPModeCharacterNameKind);
	
	RPModeCharacterRevert:Disable()
end

function RPMode.ShowCharacterInfo()
	RPModeFriendFrame:Hide();
	RPModeSettingsFrame:Hide();
	RPModeHelpFrame:Hide();
	if (not RPModeCharacterFrame:IsVisible()) then
		RPMode.RefreshCharacterInfoTab();
	end
	RPModeCharacterFrame:Show();
end

function RPMode.ShowFriendList()
	--[[RPModeSettingsFrame:Hide();
	RPModeHelpFrame:Hide();
	RPModeCharacterFrame:Hide();
	RPModeFriendFrame:Show();]]
end

function RPMode.ShowTooltip()

end

function RPMode.BindFrameToWorldFrame(frame)
	local scale = UIParent:GetEffectiveScale();
	frame:SetParent(WorldFrame);
	frame:SetScale(scale);
end

function RPMode.BindFrameToUIParent(frame)
	frame:SetParent(UIParent);
	frame:SetScale(1);
end

function RPMode.ToggleRPMode()
	if (RPMode.RPMode == 0) then
		RPMode.EnableRPMode();
	else
		RPMode.DisableRPMode();
	end
end

function RPMode.EnableRPMode()
	RPMode.BindFrameToWorldFrame(GameTooltip);
	RPMode.BindFrameToWorldFrame(ChatFrameEditBox);
	RPMode.BindFrameToWorldFrame(ChatFrameMenuButton);
	RPMode.BindFrameToWorldFrame(ChatMenu);
	RPMode.BindFrameToWorldFrame(EmoteMenu);
	RPMode.BindFrameToWorldFrame(LanguageMenu);
	RPMode.BindFrameToWorldFrame(VoiceMacroMenu);
	--RPMode.BindFrameToWorldFrame(RPModeInfobox);
	for i = 1, 7 do
		RPMode.BindFrameToWorldFrame(getglobal("ChatFrame" .. i));
		RPMode.BindFrameToWorldFrame(getglobal("ChatFrame" .. i .. "Tab"));
		RPMode.BindFrameToWorldFrame(getglobal("ChatFrame" .. i .. "TabDockRegion"));
	end
	RPMode.RPMode = 1;
	CloseAllWindows();
	UIParent:Hide();
end

function RPMode.DisableRPMode()
	RPMode.BindFrameToUIParent(GameTooltip);
	GameTooltip:SetFrameStrata("TOOLTIP");
	RPMode.BindFrameToUIParent(ChatFrameEditBox);
	ChatFrameEditBox:SetFrameStrata("DIALOG");
	RPMode.BindFrameToUIParent(ChatFrameMenuButton);
	ChatFrameMenuButton:SetFrameStrata("DIALOG");
	RPMode.BindFrameToUIParent(ChatMenu);
	ChatMenu:SetFrameStrata("DIALOG");
	RPMode.BindFrameToUIParent(EmoteMenu);
	EmoteMenu:SetFrameStrata("DIALOG");
	RPMode.BindFrameToUIParent(LanguageMenu);
	LanguageMenu:SetFrameStrata("DIALOG");
	RPMode.BindFrameToUIParent(VoiceMacroMenu);
	VoiceMacroMenu:SetFrameStrata("DIALOG");
	--RPMode.BindFrameToUIParent(RPModeInfobox);
	for i = 1, 7 do
		RPMode.BindFrameToUIParent(getglobal("ChatFrame" .. i));
		RPMode.BindFrameToUIParent(getglobal("ChatFrame" .. i .. "Tab"));
		RPMode.BindFrameToUIParent(getglobal("ChatFrame" .. i .. "TabDockRegion"));
	end
	RPMode.RPMode = 0;
	UIParent:Show();
end