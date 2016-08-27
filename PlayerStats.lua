--- Player Stats Addon
local InScript = false;

function PlayerStats()
	InScript = true;
	print("Initializing Player Stats");
	RequestTimePlayed();
end

local pst_frame = CreateFrame("Frame");
pst_frame:RegisterEvent("TIME_PLAYED_MSG");

pst_frame:SetScript("OnEvent",
function(self,event,...) 

	 if event == "TIME_PLAYED_MSG" and (InScript) then
		print("Your play time on this character is <" ..  select(1, ...) .. "> seconds");
	end
end);
