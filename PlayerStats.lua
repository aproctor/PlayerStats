--- Player Stats Addon
function PlayerStats()
	InScript = true;
	print("Initializing Player Stats");
end

local pst = {};

function pst.LogPlayerStats() 
	print "i'll log stats here"
end

local pst_frame = CreateFrame("Frame");
pst_frame:RegisterEvent("TIME_PLAYED_MSG");

pst_frame:SetScript("OnEvent", function(self,event,...) 
	 if event == "TIME_PLAYED_MSG" then
		print("Your play time on this character is <" ..  select(1, ...) .. "> seconds");
	end
end);
