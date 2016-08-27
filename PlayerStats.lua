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

		pst:PrintPlayerDetails();
	end
end

function pst:TIME_PLAYED_MSG(...)
	local seconds = select(1,...)
	print("You play time on this character is <" ..  seconds .. "> seconds");

	pst_character_data["seconds_played"] = seconds;
	pst_global_data["players"][pst_character_data["player_name"]] = pst_character_data;
end



--- Commands

function pst:PrintPlayerDetails()
	print("Player details:");
	local total_time = 0
	for key,value in pairs(pst_global_data["players"]) do
		print(key .. " - " .. value["realm"] .. ": ".. value["seconds_played"]);
		total_time = total_time + value["seconds_played"];
	end	
	print("Total time played: " .. total_time);
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
	if(pst_character_data == null) then
		local player_name = UnitName("player");
		pst_character_data = {}
		pst_character_data["player_name"] = player_name;
		pst_character_data["realm"] = GetRealmName();
		pst_character_data["seconds_played"] = 0;

		pst_global_data["players"][player_name] = pst_character_data;
	end
end






