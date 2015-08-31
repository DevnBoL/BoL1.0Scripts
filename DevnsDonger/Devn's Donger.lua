--[[

---//==================================================\\---
--|| > About Script                                     ||--
---\\==================================================//---

	Script:        Devn's Donger
	Version:       1.05
	Build Date:    2015-08-21
	Author:        Devn

---//==================================================\\---
--|| > Changelog                                        ||--
---\\==================================================//---

	Version 0.01:
		- Private donger release.

	Version 1.00:
		- Public donger release.

	Version 1.01:
		- BetterTS won't target Kog'Maw during his passive anymore.

	Version 1.02:
		- Open sourced the script.
		- Added hitchance sliders for W and E.
		- Added target health slider for upgraded W.
		- Added enemies hit slider for upgraded E.
		- Added SkinManager.
		- Added AutoLevelManager.

	Version 1.03:
		- Fixed a small bug caused from open-sourcing the script.
		- Added defensive and offensive item casting.
		- Fixed ult casting.
		- Fixed predictions (was defaulting to VPrediction before).

	Version 1.04:
		- Changed HPred settings for E a bit.
		- Added W fan percent slider.
		- Fixed R>W casting if Q was ready.
		- Won't load auto-potions if "Devn's Auto-Potions" is loaded.

	Version 1.05:
		- Updated to latest GodLib.
		- Will download GodLib if missing.
		- Changed HPred settings again, E stun should cast more often now.
		- Added hitchance sliders for R spells.
		- Added toggle to wait for R>W.
		- Added toggle to not place Q under enemy turret.
		- Added R>Q cast before zhonyas.
		- Added SummonerManager.

--]]

---//==================================================\\---
--|| > Script Initialization                            ||--
---\\==================================================//---

_G.DevnsDonger_DisableAutoUpdate = false
_G.DevnsDonger_DisableSkins = false
_G.DevnsDonger_DisableLevelSpell = false
_G.DevnsDonger_SkipStatusCheck = true

_G.DevnsDonger_EnableDebugMode = false

if (myHero.charName ~= "Heimerdinger") then return end

if (FileExist(LIB_PATH.."GodLib.lua")) then
	require("GodLib")
	_ENV = _G.SetupGodLib(_ENV)
else
	PrintChat("Downloading GodLib, please don't reload script!")
	DownloadFile("raw.githubusercontent.com/DevnBoL/BoL1.0Scripts/master/GodLib/GodLib.lua", LIB_PATH.."GodLib.lua", function()
		PrintChat("Finsihed downloading GodLib, please reload script!")
	end)
	return
end

---//==================================================\\---
--|| > Script Variables                                 ||--
---\\==================================================//---

_ENV.ScriptName = "Devn's Donger"
_ENV.ScriptFullName = ScriptName.." - The NSFW Inventor"
_ENV.ScriptVariables = "DevnsDonger"
_ENV.CurrentVersion = "1.05"
_ENV.BuildDate = "2015/08/30"
_ENV.LeagueVersion = "5.16"
_ENV.StatusKey = "SFIHNJMLNLH"

_ENV.UpdatePath = DevnGitHub..ScriptVariables

local Config = nil
local Selector = nil
local Readme = nil
local Items = nil

local WaitingForW = false

local Changelogs = { }

AddRequiredLibrary("SxOrbWalk", "http://raw.githubusercontent.com/Superx321/BoL/master/common/SxOrbWalk.lua")
AddRequiredLibrary("VPrediction", "https://raw.githubusercontent.com/SidaBoL/Scripts/master/Common/VPrediction.lua", true)
AddRequiredLibrary("CustomPermaShow", "http://raw.githubusercontent.com/Superx321/BoL/master/common/CustomPermaShow.lua", true)

---//==================================================\\---
--|| > Callback Handlers                                ||--
---\\==================================================//---

Callbacks:Bind("Load", function()
	SetupVariables()
	SetupConfig()
	ShowReadme()
end)
Callbacks:Bind("Tick", function()
	ShowReadme()
	if (myHero.dead) then return end
	UpdateTarget()
	if (IsEvading() or Orbwalker:IsAttacking()) then return end
	Killsteal()
	PerformModes()
end)
Callbacks:Bind("Draw", function()
	DrawPermaShow()
	if (myHero.dead or Config.Drawing.Disabled) then return end
	DrawRanges()
end)

Callbacks:BindItemCast("Hourglass", function()
	if (Config.Misc.RQZhonyas and Spells.R.Ready) then
		local target = Target or Selector:GetTarget(Spells.Q.Range)
		if (target) then
			Spells.R:Cast()
			CastQ(target, true)
		end
	end
end)

---//==================================================\\---
--|| > Main Functions                                   ||--
---\\==================================================//---

function UpdateTarget()
	SetTarget(Selector:GetTarget(Spells.W.Range, 1, nil, Spells.W:GetEnemiesInRange()))
end
function Killsteal()
	local config = Config.Killstealing
	if (not config.Enabled or (config.RecallDisable and Recalling)) then return end
	if (not config.W and not config.E) then return end
	for _, enemy in ipairs(Spells.W:GetEnemiesInRange()) do
		if (config.W and Spells.W.Ready and HaveEnoughMana(config.WMana) and Spells.W:WillKill(enemy) and Spells.W:PredictedCast(enemy)) then break end
		if (config.E and Spells.E.Ready and HaveEnoughMana(config.EMana) and Spells.E:WillKill(enemy) and Spells.E:PredictedCast(enemy)) then break end
	end
end
function PerformModes()
	if (not Target) then return end
	if (KeysConfig.Combo) then ComboMode(Config.Combo) end
	if (KeysConfig.Harass) then HarassMode(Config.Harass) end
end

function ComboMode(config)
	Items:CastOffensive(Target, config)
	if (WaitingForW) then return end
	local upgrade = config.Upgrade
	local useR = (config.R and HaveEnoughMana(config.RMana))
	if (useR and Spells.R.Ready and upgrade.Q and (#GetEnemiesInRange(650) >= upgrade.QEnemies)) then
		Spells.R:Cast()
		CastQ(Target, upgrade.QTurret)
	elseif (config.Q and Spells.Q.Ready and HaveEnoughMana(config.QMana) and (#GetEnemiesInRange(650) > 0)) then
		CastQ(Target, config.QTurret)
	end
	if (Spells.E:InRange(Target) and Spells.E.Ready) then
		local casted = false
		if (useR and Spells.R.Ready and upgrade.E) then
			local castPos, hitchance, hit = GetREPrediction(Target)
			if (castPos and (hitchance >= upgrade.EHitchance) and (hit >= upgrade.EHit)) then
				Spells.R:Cast()
				Spells.RE1:CastAt(castPos)
				casted = true
			end
		end
		if (not casted and config.E and HaveEnoughMana(config.EMana)) then
			CastE(Target, config.EStun, config.EHitchance)
		end
	end
	if (Spells.W:InRange(Target) and Spells.W.Ready) then
		local casted = false
		if (useR and Spells.R.Ready and upgrade.W) then
			if (Spells.RW:WillKill(Target) or HealthUnderPercent(upgrade.WHealth, Target)) then
				local castPos, hitchance = Spells.W:GetPrediction(Target)
				if (castPos and (hitchance >= Hitchances[upgrade.WHitchance])) then
					WaitingForW = true
					casted = true
					Spells.R:Cast()
					DelayAction(function(unit)
						PrintDebug("casting r>w")
						if (unit and IsValid(unit)) then
							PredictedCastW(unit, Hitchance.Low)
							DelayAction(function()
								WaitingForW = false
							end, 0.25)
						else
							WaitingForW = false
						end
					end, 1.01, { Target })
				end
			elseif (upgrade.WWait > 0) then
				if (Spells.RW:CalculateDamage(Target) > GetPredictedHealth(Target, upgrade.WWait)) then
					casted = true
					PrintDebug("WAITING FOR R>W!")
				end
			end
		end
		if (not casted and not WaitingForW and config.W and HaveEnoughMana(config.WMana)) then
			PredictedCastW(Target, config.WHitchance)
		end
	end
end
function HarassMode(config)
	Items:CastOffensive(Target, config)
	if (config.Q and Spells.Q.Ready and HaveEnoughMana(config.QMana) and EnemyIsInRange(650)) then
		CastQ(Target, config.QTurret)
	end
	if (config.E and Spells.E.Ready and HaveEnoughMana(config.EMana) and Spells.E:InRange(Target)) then
		CastE(Target, config.EStun, config.EHitchance)
	end
	if (config.W and Spells.W.Ready and HaveEnoughMana(config.WMana)) then
		PredictedCastW(Target, config.WHitchance)
	end
end

---//==================================================\\---
--|| > Draw Functions                                   ||--
---\\==================================================//---

function DrawPermaShow()
	local config = Config.Drawing
	local title = Format("              {1}", ScriptName)
	if (not config.PermaShow) then
		CustomPermaShow(title, "", false)
		CustomPermaShow("---------------------------------------------------", "", false)
		CustomPermaShow("No Mode Active", "", false)
		CustomPermaShow("Comb Mode:", "", false)
		CustomPermaShow("Harass Mode:", "", false)
	end
	local active = "      Active"
	local color = ParseColor(config.PermaShowColor, true, 150)
	CustomPermaShow(title, "", true)
	CustomPermaShow("---------------------------------------------------", "", true)
	CustomPermaShow("No Mode Active", "", not KeysConfig.Combo and not KeysConfig.Harass)
	CustomPermaShow("Combo Mode:", active, KeysConfig.Combo, color, color)
	CustomPermaShow("Harass Mode:", active, KeysConfig.Harass, color, color)
end
function DrawRanges()
	local config = Config.Drawing
	if (config.Target and Target and IsOnScreen(Target)) then
		DrawCircleAt(Target, 200, config.TargetColor)
	end
	if (config.SelectedTarget and Selector.SelectedTarget and IsOnScreen(Selector.SelectedTarget)) then
		DrawCircleAt(Selector.SelectedTarget, 250, config.SelectedTargetColor)
	end
	if (IsOnScreen(myHero)) then
		if (config.Q and (Spells.Q:GetLevel() > 0)) then DrawCircleAt(myHero, Spells.Q.Range, config.QColor) end
		if (config.W and (Spells.W:GetLevel() > 0)) then DrawCircleAt(myHero, Spells.W.Range, config.WColor) end
		if (config.E and (Spells.E:GetLevel() > 0)) then DrawCircleAt(myHero, Spells.E.Range, config.EColor) end
	end
end

---//==================================================\\---
--|| > Script Setup                                     ||--
---\\==================================================//---

function SetupVariables()
	SetupSpellVariables()
	SetupClassVariables()
	SetupReadmeVariables()
end
function SetupConfig()
	Orbwalker:LoadToConfig(Config)
	LoadKeysToConfig(Config, true, true)
	Selector:LoadToConfig(Config, SelectorMode.LessCastMagic)
	SetupComboConfig()
	SetupHarassConfig()
	SummonerManager(Config)
	Items:LoadDefensiveToConfig(Config)
	SetupKillstealingConfig()
	SetupDrawingConfig()
	SetupMiscConfig()
	Config:Separator()
	Config:Info("Version", CurrentVersion)
	Config:Info("Build Date", BuildDate)
	Config:Info("Tested With LoL", LeagueVersion)
	Config:Info("Author", "Devn")
end
function ShowReadme()
	if (not JustUpdated) then return end
	JustUpdated = false
	Changelogs[2].Title = "Updated to v"..CurrentVersion
	Changelogs[2].CloseCallback = function() Changelogs[2].Title = Format("{1}: Changelog 2", ScriptName) end
	Changelogs[2]:Show()
end

function SetupSpellVariables()
	AddSpell("Q", _Q, "H-28 Turret", 320)
	AddSpell("W", _W, "Hextech Rockets", 1300, 1):SetSkillshot(40, 0.5, 3000, true, SkillshotType.Linear):SetAccuracy(SpellAccuracy.Low):SetDamage(DamageType.Magic, 30, 30, DamageType.Magic, ScalingStat.AbilityPower, 0.45)
	AddSpell("E", _E, "CH Grenade", 925):SetSkillshot(210, 0.5, 1200, false, SkillshotType.Circular):SetDamage(DamageType.Magic, 20, 40, DamageType.Magic, ScalingStat.AbilityPower, 0.6)
	AddSpell("R", _R, "UPGRADE!!!", 600)
	CopySpell("W", "RW", _R):SetDamage(DamageType.Magic, 90, 45, DamageType.Magic, ScalingStat.AbilityPower, 0.45)
	CopySpell("E", "EStun"):SetSkillshot(150, Spells.E.Delay, Spells.E.Speed, Spells.E.Collision, Spells.E.Type):SetAccuracy(SpellAccuracy.Low)
	CopySpell("E", "REStun"):SetSkillshot(300, Spells.E.Delay, Spells.E.Speed, Spells.E.Collision, Spells.E.Type)
	CopySpell("E", "RE1"):SetSkillshot(420, Spells.E.Delay, Spells.E.Speed, Spells.E.Collision, Spells.E.Type)
	CopySpell("E", "RE2"):SetRange(1465):SetSkillshot(430, Spells.E.Delay + 0.25, Spells.E.Speed, Spells.E.Collision, Spells.E.Type)
	CopySpell("E", "RE3"):SetRange(2005):SetSkillshot(440, Spells.E.Delay + 0.3, Spells.E.Speed, Spells.E.Collision, Spells.E.Type)
	AutoTrackSpells()
end
function SetupClassVariables()
	Config = MenuConfig(ScriptVariables, ScriptName)
	Selector = BetterTS()
	Items = ItemManager()
end
function SetupReadmeVariables()
	Readme = DialogBox("Readme")
	Readme:Add(Format("{1} Casting:", Spells.R.Name))
	Readme:Add("Spells are casted in the order Q>E>W. W is only casted if the enemy can be killed by it")
	Readme:Add("or if your target's health is below the set percent during combo mode. Killstealing does")
	Readme:Add("not support ultimate casting as the cooldown is too long in my opinion to be used for")
	Readme:Add("killstealing.")
	Readme:Add()
	Readme:Add(Format("{1} Fan Percent:", Spells.W.Name))
	Readme:Add("-t- 0.0: Cast in front of hero.")
	Readme:Add("-t- 0.5: Cast between you and target.")
	Readme:Add("-t- 1.0: Cast at target.")
	Readme:Add()
	Readme:Add("Bugs/Errors:")
	Readme:Add("If you get any bugs or errors while using this script please take a screenshot (if you")
	Readme:Add("can) and report it to the forum thread!")
	Readme:Add()
	Readme:Add("If you like this script please leave a like on the forum thread and on script status! :D")
	Readme:AddButton("Show Changelog", function()
		Readme:Close()
		Changelogs[1]:Show()
	end, 150)
	table.insert(Changelogs, DialogBox("Changelog 1"))
	Changelogs[1]:Add("Version 0.01:")
	Changelogs[1]:Add("-t- Private donger release.")
	Changelogs[1]:Add()
	Changelogs[1]:Add("Version 1.00:")
	Changelogs[1]:Add("-t- Public donger release.")
	Changelogs[1]:Add()
	Changelogs[1]:Add("Version 1.01:")
	Changelogs[1]:Add("-t- BetterTS won't target Kog'Maw during his passive anymore.")
	Changelogs[1]:Add()
	Changelogs[1]:Add("Version 1.02:")
	Changelogs[1]:Add("-t- Added hitchance sliders for W and E.")
	Changelogs[1]:Add("-t- Added target health slider for upgraded W.")
	Changelogs[1]:Add("-t- Added enemies hit slider for upgraded E.")
	Changelogs[1]:Add("-t- Added SkinManager.")
	Changelogs[1]:Add("-t- Added AutoLevelManager.")
	Changelogs[1]:Add()
	Changelogs[1]:Add("Version 1.03:")
	Changelogs[1]:Add("-t- Fixed a small bug caused from open-sourcing the script.")
	Changelogs[1]:Add("-t- Added defensive and offensive item casting.")
	Changelogs[1]:Add("-t- Fixed ult casting.")
	Changelogs[1]:Add("-t- Fixed predictions (was defaulting to vpred before).")
	Changelogs[1]:Add()
	Changelogs[1]:Add("Version 1.04:")
	Changelogs[1]:Add("-t- Changed HPred settings for E a bit.")
	Changelogs[1]:Add("-t- Added W fan percent slider. (Check Readme)")
	Changelogs[1]:Add("-t- Fixed R>W casting if Q was ready.")
	Changelogs[1]:AddButton("Readme", function()
		Changelogs[1]:Close()
		Readme:Show()
	end)
	Changelogs[1]:AddButton("Next", function()
		Changelogs[1]:Close()
		Changelogs[2]:Show()
	end)
	table.insert(Changelogs, DialogBox("Changelog 2"))
	Changelogs[2]:Add("Version 1.05:")
	Changelogs[2]:Add("-t- Added hitchance sliders for R spells.")
	Changelogs[2]:Add("-t- Added toggle to wait for R>W.")
	Changelogs[2]:AddButton("Previous", function()
		Changelogs[2]:Close()
		Changelogs[1]:Show()
	end, 150)
end

function SetupComboConfig()
	local config = Config:Menu("Combo", "Combo Mode")
	Items:LoadOffensiveToConfig(config)
	local upgrade = config:Menu("Upgrade", Format("{1} Settings", Spells.R.Name))
	upgrade:Toggle("Q", Format("Upgrade {1}", Spells.Q.Name), true)
	upgrade:Toggle("QTurret", "Place out of Enemy Turret", true)
	upgrade:Slider("QEnemies", "Minimum Enemies Near", 2, 1, 5)
	upgrade:Separator()
	upgrade:Toggle("W", Format("Upgrade {1}", Spells.W.Name), true)
	upgrade:Slider("WHealth", "Use When Target Below Percent", 50, 0, 100)
	upgrade:Slider("WWait", "Seconds to Wait", 3, 0, 10)
	upgrade:Slider("WHitchance", "Spell Hitchance", 2, 1, 3)
	upgrade:Separator()
	upgrade:Toggle("E", Format("Upgrade {1}", Spells.E.Name), true)
	upgrade:Slider("EHit", "Minimum Enemies to Hit", 4, 1, 5)
	upgrade:Slider("EHitchance", "Spell Hitchance", 2, 1, 3)
	config:Separator()
	config:Toggle("Q", Format("Use {1}", Spells.Q.Name), true)
	config:Toggle("QTurret", "Place out of Enemy Turret", true)
	config:Slider("QMana", "Minimum Mana Percent", 0, 0, 100)
	config:Separator()
	config:Toggle("W", Format("Use {1}", Spells.W.Name), true)
	config:Slider("WHitchance", "Spell Hitchance", 2, 1, 3)
	config:Slider("WMana", "Minimum Mana Percent", 0, 0, 100)
	config:Separator()
	config:Toggle("E", Format("Use {1}", Spells.E.Name), true)
	config:Toggle("EStun", "Only to Stun", false)
	config:Slider("EHitchance", "Spell Hitchance", 2, 1, 3)
	config:Slider("EMana", "Minimum Mana Percent", 0, 0, 100)
	config:Separator()
	config:Toggle("R", Format("Use {1}", Spells.R.Name), true)
	config:Slider("RMana", "Minimum Mana Percent", 0, 0, 100)
end
function SetupHarassConfig()
	local config = Config:Menu("Harass", "Harass Mode")
	Items:LoadOffensiveToConfig(config, true)
	config:Separator()
	config:Toggle("Q", Format("Use {1}", Spells.Q.Name), true)
	config:Toggle("QTurret", "Place out of Enemy Turret", true)
	config:Slider("QMana", "Minimum Mana Percent", 50, 0, 100)
	config:Separator()
	config:Toggle("W", Format("Use {1}", Spells.W.Name), true)
	config:Slider("WHitchance", "Spell Hitchance", 2, 1, 3)
	config:Slider("WMana", "Minimum Mana Percent", 50, 0, 100)
	config:Separator()
	config:Toggle("E", Format("Use {1}", Spells.E.Name), true)
	config:Toggle("EStun", "Only to Stun", true)
	config:Slider("EHitchance", "Spell Hitchance", 2, 1, 3)
	config:Slider("EMana", "Minimum Mana Percent", 50, 0, 100)
end
function SetupKillstealingConfig()
	local config = Config:Menu("Killstealing", "Killsteal Settings")
	config:Toggle("Enabled", "Enable Killstealing", true)
	config:Toggle("RecallDisable", "Disable While Recalling", false)
	config:Separator()
	config:Toggle("W", Format("Use {1}", Spells.W.Name), true)
	config:Slider("WHitchance", "Spell Hitchance", 2, 1, 3)
	config:Slider("WMana", "Minimum Mana Percent", 0, 0, 100)
	config:Separator()
	config:Toggle("E", Format("Use {1}", Spells.E.Name), true)
	config:Slider("EHitchance", "Spell Hitchance", 2, 1, 3)
	config:Slider("EMana", "Minimum Mana Percent", 0, 0, 100)
end
function SetupDrawingConfig()
	local config = Config:Menu("Drawing", "Drawing Options")
	LoadDrawingToConfig(config)
	config:Separator()
	config:Toggle("PermaShow", "Show PermaShow Menu", true)
	config:ColorBox("PermaShowColor", "PermaShow Color", "Light Gray")
	config:Separator()
	config:Toggle("Target", "Draw Current Target", true)
	config:ColorBox("TargetColor", "Circle Color", "Red")
	config:Separator()
	config:Toggle("SelectedTarget", "Draw Selected Target", true)
	config:ColorBox("SelectedTargetColor", "Circle Color", "Purple")
	config:Separator()
	config:Toggle("Q", Format("Draw {1} Range", Spells.Q.Name), true)
	config:ColorBox("QColor", "Range Circle Color", "Magenta")
	config:Separator()
	config:Toggle("W", Format("Draw {1} Range", Spells.W.Name), true)
	config:ColorBox("WColor", "Range Circle Color")
	config:Separator()
	config:Toggle("E", Format("Draw {1} Range", Spells.E.Name), true)
	config:ColorBox("EColor", "Range Circle Color")
end
function SetupMiscConfig()
	local config = Config:Menu("Misc", "Miscellaneous Settings")
	SkinManager(config, { "Alien Invader {1}", "Blast Zone {1}", "Piltover Customs {1}", "Snowmerdinger", "Hazmat {1}" })
	AutoLevelManager(config, 2, 1)
	config:Separator()
	LoadPredictionToConfig(config)
	config:Separator()
	config:Toggle("RQZhonyas", "Use R>Q Before Zhonyas", true)
	config:Slider("WFan", Format("{1} Fan Percent", Spells.W.Name), 0.5, 0, 1, 1)
	config:Separator()
	config:Toggle("Readme", "Show Readme & Changelog", true):SetCallback(function(value)
		if (not value) then return end
		Config.Misc.Readme = false
		Config.Misc:save()
		local function ChangelogVisible()
			for _, changelog in ipairs(Changelogs) do
				if (changelog.Visible) then
					return true
				end
			end
		end
		if (Readme.Visible or ChangelogVisible()) then return end
		Readme:Show()
	end)
end

---//==================================================\\---
--|| > Misc. Functions                                  ||--
---\\==================================================//---

function CastQ(target, oot)
	local oot = oot or false
	local pos = Spells.Q:VectorTo(target)
	if (oot and IsUnderEnemyTurret(pos)) then
		PrintDebug("Looking for new Q cast position.")
		local distance = GetDistance(pos)
		for i = distance - 15, -distance, -15 do
			local newpos = VectorOut(pos, distance)
			if (not IsUnderEnemyTurret(newpos)) then
				Spells.Q:CastAt(newpos)
				PrintDebug("Found new Q cast position.")
				break
			end
		end
		return
	end
	Spells.Q:CastAt(pos)
end
function CastW(castPos)
	return Spells.W:CastAt(VectorOut(castPos, math.max(Spells.W.Range * Config.Misc.WFan, 600)))
end
function CastE(target, stun, minHitchance)
	if (Spells.EStun:PredictedAoeCast(target, stun and minHitchance or minHitchance - 1)) then return true end
	if (stun) then return false end
	return Spells.E:PredictedAoeCast(target, minHitchance)
end
function PredictedCastW(target, minHitchance)
	local minHitchance = minHitchance or Hitchance.Medium
	local castPos, hitchance = Spells.W:GetPrediction(target)
	if (castPos and (hitchance >= minHitchance)) then
		return CastW(castPos, target)
	end
	return false
end
function GetREPrediction(target)
	local castPos, hitchance, hit = Spells.RE1:GetAoePrediction(target)
	if (not castPos) then
		return castPos, hitchance, hit
	end
	local hit2 = Spells.RE2:GetHit(Spells.RE2:VectorOut(castPos))
	if (#hit2 > 0) then
		hit = hit + #hit2
	end
	local hit3 = Spells.RE3:GetHit(Spells.RE3:VectorOut(castPos))
	if (#hit3 > 0) then
		hit = hit + #hit3
	end
	return castPos, hitchance, hit
end
