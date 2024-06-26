--- Player Stats Addon
local pst = {};
local pst_frame = CreateFrame("Frame");
pst_frame:RegisterEvent("PLAYER_LOGIN");
pst_frame:RegisterEvent("TIME_PLAYED_MSG");
pst_frame:RegisterEvent("UNIT_INVENTORY_CHANGED");
pst_frame:RegisterEvent("PLAYER_LEVEL_UP");

--- All events will be reflected to pst
pst_frame:SetScript("OnEvent",
function(self,event,...)
	if pst[event] and type(pst[event]) == "function" then
		return pst[event](pst,...)
	end
end)


--- Event Methods

function pst:PLAYER_LOGIN(...)
	pst:InitializeData();

	 -- make sure we don't overwrite default if someone decides to use same name
	if not SlashCmdList["PLAYERSTATS"] then
			SlashCmdList["PLAYERSTATS"] = function(msg)
			   pst:handle_slashes(msg);
			end -- end function
			SLASH_PLAYERSTATS1 = "/pst";
	end
end

function pst:TIME_PLAYED_MSG(...)
	local seconds = select(1,...)
	local second_this_level = select(2,...)

	pst_character_data["seconds_played"] = seconds;

	if(pst_level_data == null) then
		DEFAULT_CHAT_FRAME:AddMessage("No level data found, creating new table");
		pst_level_data = {};
	end
	pst_level_data[tonumber(UnitLevel("player"))] = second_this_level;

	pst_global_data["players"][pst_character_data["guid"]] = pst_character_data;

	pst.last_played_check = time();
end

function pst:UNIT_INVENTORY_CHANGED(...)
	pst:UpdateIlvls();
end

function pst:PLAYER_LEVEL_UP(...)
	local level = select(1,...)
	local last_level = level - 1
	DEFAULT_CHAT_FRAME:AddMessage("Level up! " .. last_level .. " -> " .. level);
	if(pst_level_data[last_level] ~= null) then
		local time_delta = time() - pst.last_played_check;
		local last_played_record = pst_level_data[last_level];
		DEFAULT_CHAT_FRAME:AddMessage("Level " .. last_level .. " time_delta " .. time_delta .. " last /played record " .. last_played_record);
		pst_level_data[last_level] = pst_level_data[last_level] + time_delta;
	else
		DEFAULT_CHAT_FRAME:AddMessage("No previous level data found!");
	end

	RequestTimePlayed();
end

function pst:handle_slashes(message)
	local command, args = message:match("^(%S*)%s*(.-)$");

	local known_commands = {};
	known_commands["gold"] = "Shows the total gold from all known characters on the current realm";
	known_commands["time"] = "Shows the total time played on all known characters";
	known_commands["gear"] = "Shows the equipped and in bags ilvl of characters on the current realm";
	known_commands["reload"] = "Resets all data, useful when upgrading pst versions if data is corrupted."
	known_commands["io"] = "Shows Dungeon score"
	known_commands["help"] = "Shows this message";

	if(command == "" or command == "help") then
		DEFAULT_CHAT_FRAME:AddMessage("Player Stats usage:");
		for k,v in pairs(known_commands) do
			DEFAULT_CHAT_FRAME:AddMessage("/pst " .. k .. " - " .. v);
		end
	elseif(command == "time" or command == "t") then
		self.PrintPlayerDetails();
	elseif (command == "gold" or command == "g") then
		self.PrintGoldTotals();
	elseif (command == "reload") then
		self.ReloadData();
	elseif (command == "gear") then
		self.PrintItemLevels();
	elseif (command == "io") then
		self.PrintIo();
	elseif (command == "graph") then
		self.ShowPlayerGraph();
	end
end


--- Commands

function pst:PrintPlayerDetails()
	DEFAULT_CHAT_FRAME:AddMessage("Time Played:");
	local total_time = 0
	for key,value in pairs(pst_global_data["players"]) do
		DEFAULT_CHAT_FRAME:AddMessage("  " .. value["player_name"] .. " - " .. value["realm"] .. ": ".. human_readable_time(value["seconds_played"]));
		seconds = value["seconds_played"] or 0
		total_time = total_time + seconds;
	end
	DEFAULT_CHAT_FRAME:AddMessage("Total Time Played: " .. human_readable_time(total_time));
end

function pst:PrintGoldTotals()
	local current_realm = pst_character_data["realm"];
	local total_realm_gold = 0;
	DEFAULT_CHAT_FRAME:AddMessage("Gold on all " .. current_realm .. " characters:")

	for key,value in pairs(pst_global_data["players"]) do
		if(value["realm"] == current_realm) then
			DEFAULT_CHAT_FRAME:AddMessage("  " .. value["player_name"] .. " - " .. value["realm"] .. ": ".. human_readable_gold(value["gold"]));
			total_realm_gold = total_realm_gold + value["gold"];
		end
	end
	DEFAULT_CHAT_FRAME:AddMessage("Total gold on " .. current_realm .. ": " .. human_readable_gold(total_realm_gold));
end

function pst:PrintItemLevels()
	local current_realm = pst_character_data["realm"];
	DEFAULT_CHAT_FRAME:AddMessage("Character iLevels on " .. current_realm);

	local min_value = 99999;
	local max_value = 0;
	local realm_players = {};

	for key,value in pairs(pst_global_data["players"]) do
		rarity = "FFFFFFFF" -- default to common
		if(value["realm"] == current_realm) then
			local ival = value["bags_ilvl"];
			if(ival) then
				if(ival > max_value) then
					max_value = ival;
				end
				if(ival < min_value) then
					min_value = ival;
				end
				table.insert(realm_players, value);
			end
		end
	end
	--TODO use min level and max level to set auto thresholds of gear rarity?
	table.sort(realm_players, function (v1, v2) return v1["bags_ilvl"] < v2["bags_ilvl"] end);
	for key,value in pairs(realm_players) do
		local ival = value["bags_ilvl"];
		if(ival > 120) then
			rarity = "FFA335EE" -- epic
		elseif(ival > 110) then
			rarity = "FF0070DD" -- rare
		end
		DEFAULT_CHAT_FRAME:AddMessage(("  %s - |c%s%.2f |r(%.2f)"):format(value["player_name"], rarity, value["bags_ilvl"], value["equipped_ilvl"]));
	end
end

function pst:PrintRealmDetails()
	DEFAULT_CHAT_FRAME:AddMessage("Realm details:");
	local realms = {}
	for key,value in pairs(pst_global_data["players"]) do
		realm = value["realm"]
		if(realms[realm] == null) then
			realms[realm] = value["seconds_played"];
		else
			realms[realm] = realms[realm] + value["seconds_played"];
		end
	end
	for key,value in pairs(realms) do
		DEFAULT_CHAT_FRAME:AddMessage(key .. " - " .. human_readable_time(value));
	end
end

function pst:PrintIo()
	local current_realm = pst_character_data["realm"];
	local min_value = 99999;
	local max_value = 0;
	local realm_players = {};

	DEFAULT_CHAT_FRAME:AddMessage("Characters io on " .. current_realm);

	for key,value in pairs(pst_global_data["players"]) do
		rarity = "FFFFFFFF" -- default to common
		if(value["realm"] == current_realm) then
			local io_val= value["io"];
			if(io_val) then
				if(io_val > max_value) then
					max_value = io_val;
				end
				if(io_val < min_value) then
					min_value = io_val;
				end
				table.insert(realm_players, value);
			end
		end
	end

	table.sort(realm_players, function (v1, v2) return v1["io"] < v2["io"] end);
	for key,value in pairs(realm_players) do
		local io_val = value["io"];
		rarity = C_ChallengeMode.GetDungeonScoreRarityColor(io_val):GenerateHexColor()
		DEFAULT_CHAT_FRAME:AddMessage(("  %s - |c%s%i"):format(value["player_name"], rarity, value["io"]));
	end
end


function pst:ReloadData()
	DEFAULT_CHAT_FRAME:AddMessage("Cleaning up Player stats data");
	pst_global_data = null
	pst_character_data = null
	pst:InitializeData();
end

function pst:ShowPlayerGraph()
    local player_name = pst_character_data["player_name"];
    local gold = pst_character_data["gold"];
    local equipped_ilvl = pst_character_data["equipped_ilvl"];

    -- Create a new window
    local frame = CreateFrame("Frame", "PlayerInfoWindow", UIParent, "UIPanelDialogTemplate");
    frame:SetSize(800, 500);
    frame:SetPoint("CENTER");
    frame:SetMovable(true);
    frame:EnableMouse(true);
    frame:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then
            self:StartMoving();
        end
    end);
    frame:SetScript("OnMouseUp", frame.StopMovingOrSizing);
    frame:SetScript("OnHide", frame.StopMovingOrSizing);

    -- Add player name label
    local playerNameLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight");
    playerNameLabel:SetPoint("TOPLEFT", 16, -10);
    playerNameLabel:SetText(player_name .. " (" .. equipped_ilvl .. ")");

	local Graph = LibStub("LibGraph-2.0")
	-- CreateGraphLine(name, parent, relative, relativeTo, offsetX, offsetY, Width, Height)
	local g = Graph:CreateGraphLine("TestLineGraph", frame, "TOPLEFT", "TOPLEFT", 10, -75, 780, 400)

	g:SetXAxis(0, 1)
	g:SetYAxis(0, 1)
	g:SetGridSpacing(5, 15)
	g:SetGridColor({0.5, 0.5, 0.5, 0.5})
	g:SetAxisDrawing(true, true)
	g:SetAxisColor({1.0, 1.0, 1.0, 1.0})
	g:SetAutoScale(true)
	g:SetYLabels("Left");


	local level_times = pst:GetNormalizedLevelData()

	g:AddFilledDataSeries(level_times, {0.0, 1.0, 0.0, 0.5})
	g:AddDataSeries(level_times, {0.0, 1.0, 0.0, 0.8})

    frame:Show();
end


--- Private methods

function pst:GetNormalizedLevelData()
	local level_data = pst_level_data;
	-- level_data = pst:CreateFakeLevelData();

	local level_times = {}
	local max_time = 0
	local max_level = 1

	local min_level = 70
	local max_level = 1

	-- loop through all values in level_data and find max time
	for i, value in pairs(level_data) do
		if value > max_time then
			max_time = value
		end
		if min_level == null or min_level > i then
			min_level = i
		end
		if i > max_level then
			max_level = i
		end
		-- DEFAULT_CHAT_FRAME:AddMessage("Level " .. i .. " time: " .. value);
	end
	--DEFAULT_CHAT_FRAME:AddMessage("Min level: " .. min_level .. " Max level: " .. max_level);

	-- from min_level to max_level, create a data point for each level normalized to 0-1
	for i = min_level, max_level do
		if level_data[i] then
			--local data_point = {(i-min_level)/(max_level-min_level), level_data[i]/max_time}
			local data_point = {i, level_data[i]/60}
			level_times[i] = data_point
		end
	end

	return level_times;
end

function pst:CreateFakeLevelData()
	local data = {}
	for i=1, 70 do
		data[i] = 60 * 30 + 2 * i + math.random(1, 10);
	end
	return data;
end

function pst:InitializeData()
	-- Initialize global data
	if(pst_global_data == null) then
		pst_global_data = {}
		pst_global_data["players"] = {}
	end

	-- Initialize character data
	local player_name = UnitName("player");

	if(pst_character_data == null or pst:PlayerDataStale()) then
		pst_character_data = {}
		pst_character_data["seconds_played"] = 0;
	end

	local guid = UnitGUID("player");
	local bagsLvl, equippedLvl = GetAverageItemLevel()


	pst_character_data["guid"]  = guid;
	pst_character_data["player_name"] = player_name;
	pst_character_data["realm"] = GetRealmName();
	pst_character_data["gold"] = GetMoney();
	pst_character_data["faction"] = UnitFactionGroup("player");
	pst_character_data["equipped_ilvl"] = equippedLvl;
	pst_character_data["bags_ilvl"] = bagsLvl;
	pst_character_data["io"] = C_ChallengeMode.GetOverallDungeonScore()

	pst_global_data["players"][guid] = pst_character_data;

	RequestTimePlayed();
end

function pst:UpdateIlvls()
	if(pst_character_data) then
		local guid = UnitGUID("player");
		local bagsLvl, equippedLvl = GetAverageItemLevel()

		pst_character_data["seconds_played"] = seconds;

		pst_character_data["equipped_ilvl"] = equippedLvl;
		pst_character_data["bags_ilvl"] = bagsLvl;

		pst_global_data["players"][pst_character_data["guid"]] = pst_character_data;
	end
end

function pst:PlayerDataStale()
	local expected_fields = {"player_name", "realm", "seconds_played"};
	for i,field in ipairs(expected_fields) do
		if(pst_character_data[field] == null) then
			return true;
		end
	end

	return false;
end

--- Util Methods

function human_readable_time(seconds)
  if(seconds == nil) then
  	return "nil"
  end
  days = math.floor (seconds / 3600 / 24);
  seconds = seconds - (days * 3600 * 24);
  hours = math.floor (seconds / 3600);
  seconds = seconds - (hours * 3600);
  minutes = math.floor (seconds / 60);
  seconds = math.floor (seconds - (minutes * 60));

  buffer = {};
  if(days > 0) then
  	table.insert(buffer, days .. "d");
  end
  if(hours > 0 or days > 0) then
  	table.insert(buffer, hours .. "h");
  end
  table.insert(buffer, minutes .. "m");

  return table.concat(buffer, " ");
end

function human_readable_gold(copper)
	gold = math.floor (copper / 100 / 100)
	copper = copper - gold * 100 * 100
	silver = math.floor (copper / 100)
	copper = copper - silver * 100

	buffer = {};
	if(gold > 1000000) then
		table.insert(buffer, (round(gold / 100000) / 10) .. " M");
	elseif(gold > 1000) then
		table.insert(buffer, (round(gold / 100) / 10) .. " K");
	elseif(gold > 0) then
		table.insert(buffer, gold);
	end
	-- table.insert(buffer, silver .. "S");
	-- table.insert(buffer, copper .. "C");

	return table.concat(buffer, " ");
end

function round(x)
  return x>=0 and math.floor(x+0.5) or math.ceil(x-0.5)
end
