--- Player Stats Addon
local pst = {};
local pst_frame = CreateFrame("Frame");
pst_frame:RegisterEvent("PLAYER_LOGIN");
pst_frame:RegisterEvent("TIME_PLAYED_MSG");
pst_frame:RegisterEvent("UNIT_INVENTORY_CHANGED");

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
	
	pst_character_data["seconds_played"] = seconds;
	pst_global_data["players"][pst_character_data["guid"]] = pst_character_data;
end

function pst:UNIT_INVENTORY_CHANGED(...)
	pst:UpdateIlvls();
end

function pst:handle_slashes(message)
	local command, args = message:match("^(%S*)%s*(.-)$");

	local known_commands = {};
	known_commands["gold"] = "Shows the total gold from all known characters on the current realm";
	known_commands["time"] = "Shows the total time played on all known characters";
	known_commands["gear"] = "Shows the equipped and in bags ilvl of characters on the current realm";
	known_commands["reload"] = "Resets all data, useful when upgrading pst versions if data is corrupted."
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
	end
end


--- Commands

function pst:PrintPlayerDetails()
	DEFAULT_CHAT_FRAME:AddMessage("Time Played:");
	local total_time = 0
	for key,value in pairs(pst_global_data["players"]) do
		DEFAULT_CHAT_FRAME:AddMessage("  " .. value["player_name"] .. " - " .. value["realm"] .. ": ".. human_readable_time(value["seconds_played"]));
		total_time = total_time + value["seconds_played"];
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

	for key,value in pairs(pst_global_data["players"]) do
		rarity = "FFFFFFFF" -- default to common
		if(value["realm"] == current_realm) then			
			if(value["bags_ilvl"]) then
				if(value["equipped_ilvl"] > 400) then
					rarity = "FFA335EE" -- epic
				elseif(value["bags_ilvl"] > 350) then
					rarity = "FF0070DD" -- rare					
				end
				DEFAULT_CHAT_FRAME:AddMessage(("  %s - |c%s%.2f |r(%.2f)"):format(value["player_name"], rarity, value["bags_ilvl"], value["equipped_ilvl"]));
			end
		end
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


function pst:ReloadData()
	DEFAULT_CHAT_FRAME:AddMessage("Cleaning up Player stats data");
	pst_global_data = null
	pst_character_data = null
	pst:InitializeData();	
end


--- Private methods

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
