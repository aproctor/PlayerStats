--- Player Stats Addon
local pst = {};
local pst_frame = CreateFrame("Frame");
pst_frame:RegisterEvent("ADDON_LOADED");
pst_frame:RegisterEvent("TIME_PLAYED_MSG");

--- All events will be reflected to pst
pst_frame:SetScript("OnEvent",
function(self,event,...) 
	if pst[event] and type(pst[event]) == "function" then
		return pst[event](pst,...)
	end
end)


--- Event Methods

function pst:ADDON_LOADED(...)
	local addon = ...
	if addon == "PlayerStats" then
		pst:InitializeData();
		-- pst:ReloadData();

		-- Load up player time, gold and other stats
		RequestTimePlayed();
	end
end

function pst:TIME_PLAYED_MSG(...)
	local seconds = select(1,...)
	print("You play time on this character is <" ..  seconds .. "> seconds");

	pst_character_data["seconds_played"] = seconds;
	pst_global_data["players"][pst_character_data["player_name"]] = pst_character_data;

	pst:PrintPlayerDetails();
end



--- Commands

function pst:PrintPlayerDetails()
	print("Player details:");
	local total_time = 0
	for key,value in pairs(pst_global_data["players"]) do
		print("  " .. key .. " - " .. value["realm"] .. ": ".. human_readable_time(value["seconds_played"]));
		total_time = total_time + value["seconds_played"];
	end	
	print("Account Wide Time Played: " .. human_readable_time(total_time));
end

function pst:PrintRealmDetails()
	print("Realm details:");
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
		print(key .. " - " .. human_readable_time(value));		
	end
end


function pst:ReloadData()
	print("Cleaning up Player stats data");
	pst_global_data = null
	pst_character_data = null
	pst:InitializeData();
end


--- Private methods

function pst:InitializeData()
	-- Initialize global data
	if(pst_global_data == null) then
		print("Initializing global data");
		pst_global_data = {}
		pst_global_data["players"] = {}			
	end

	-- Initialize character data
	if(pst_character_data == null or pst:PlayerDataStale()) then
		local player_name = UnitName("player");
		pst_character_data = {}
		pst_character_data["player_name"] = player_name;
		pst_character_data["realm"] = GetRealmName();
		pst_character_data["seconds_played"] = 0;

		pst_global_data["players"][player_name] = pst_character_data;
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

