local Config = nil
local LastTick = nil
local LastMove = 1

function OnLoad()
	Config = scriptConfig("Devn's Anti-AFK", "DevnsAntiAFK")
	Config:addParam("Enabled", "Enable Anti-AFK", SCRIPT_PARAM_ONOFF, false)
	Config:addParam("Delay", "Delay Between Moving (Seconds)", SCRIPT_PARAM_SLICE, 40, 10, 60)
	Config:addParam("Distance", "Distance to Move", SCRIPT_PARAM_SLICE, 250, 200, 500)
	PrintChat("<font color=\"#8183F7\">Devn's Anti-AFK:</font> <font color=\"#BEF781\">Loaded successfully!</font>")
end

function OnTick()
	if (not Config.Enabled) then return end
	if (LastTick and (GetInGameTimer() < LastTick + Config.Delay)) then return end
	LastTick = GetInGameTimer()
	local posX = myHero.x + (Config.Distance * LastMove)
	local posZ = myHero.z + (Config.Distance * LastMove)
	myHero:MoveTo(posX, posZ)
	LastMove = LastMove * -1
end
