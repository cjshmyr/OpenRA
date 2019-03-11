--[[
Todo:
	Disable repairing through build palette.
	Defense stuff.
	Powering off defenses with low power.
	Turret damage increased.
	Minelayer mine damage reduced.
	Only allow purchasing while not mobile? Can remove jittery infantry buying.

	Building under attack notifications.
	Building lost notification (sound).
	Buying vehicles when WF is dead.
	Invulnerability on spawn?
	Better scoreboard (current rank, etc).
	Victory condition on timer or points.

	Add locking to vehicles that aren't yours (so they aren't stolen)
	Score overhaul.
	Score/$ on kill of buildings or units.
	Better spawn points. Allow players to choose.

Bugs:
	Players can be squished by Neutral units (war factory spawns, leaving harvesters).
	Buying new infantry may result in lower health than expected.

Lua ideas:
	Expose score.
	Expose better UI (scoreboard).
	Checking cell occupancy.
	Getting damage values.
	Probably more i've forgotten.
]]

--[[ General ]]
PlayerInfo = { }
TeamInfo = { }
PlayerHarvesters = { } -- Exists due to a hack.
CashPerSecond = 2 -- Cash given per second.
CashPerSecondPenalized = 1 -- Cash given per second, with no ref.
PurchaseTerminalActorType = "purchaseterminal"
PurchaseTerminalInfantryActorTypePrefix = "buy.infantry."
PurchaseTerminalVehicleActorTypePrefix = "buy.vehicle."

--[[ Mod-specific ]]
SpawnAsActorType = "e1"
AlphaTeamPlayerName = "Allies"
BetaTeamPlayerName = "Soviet"
NeutralPlayerName = "Neutral"
AlphaTeamPlayer = Player.GetPlayer(AlphaTeamPlayerName)
BetaTeamPlayer = Player.GetPlayer(BetaTeamPlayerName)
NeutralPlayer = Player.GetPlayer(NeutralPlayerName)
ConstructionYardActorTypes = {"fact"}
RefineryActorTypes = {"proc"}
PowerplantActorTypes = {"apwr"}
RadarActorTypes = {"dome"}
WarFactoryActorTypes = {"weap"}
BarracksActorTypes = {"barr","tent"}
ServiceDepotActorTypes = {"fix"}
BasicDefenseActorTypes = {"ftur","pbox","hbox"}
PoweredDefenseActorTypes = {"tsla","gun"}
AiHarvesterActorType = "harv-ai"
PlayerHarvesterActorType = "harv"

-- [[ Hacks that should be removed ]]
SpawnPointActorType = "waypoint"
armorTypes = {
	{name = 'soft', types = { 'e1', 'e3', 'e6', 'medi', 'mech', 'e2', 'e4' }} ,
	{name = 'medium', types = { 'jeep', 'arty', '1tnk', 'ctnk', 'ftrk', 'ttnk' }},
	{name = 'hard', types = { 'harv', 'mnly', '2tnk', '3tnk', '4tnk', 'harv-ai' }}
}
weaponTypes = {
	{ name = 'heal', types = { 'medi', 'mech' }},
	{ name = 'gun', types = { 'e1', 'e2', 'jeep', 'ftrk' }},
	{ name = 'missile', types = { 'e3', 'ctnk' }},
	{ name = 'smallShell', types = { 'e2', '1tnk' }},
	{ name = 'bigShell', types = { 'arty', '2tnk', '3tnk', '4tnk'}},
	{ name = 'fire', types = { 'e4' }},
	{ name = 'zap', types = { 'ttnk' }}
}

WorldLoaded = function()
	SetPlayerInfo()
	SetTeamInfo()

	AssignTeamBuildings()

	BindBaseEvents()
	BindVehicleEvents()
	BindProximityEvents()

	AddPurchaseTerminals()

	-- Delayed due to interacting with actors that were added on tick 0.
	Trigger.AfterDelay(1, function()
		Utils.Do(PlayerInfo, function(pi) SpawnHero(pi.Player) end)

		BindPurchaseTerminals()

		InitializeAiHarvesters()
	end)

	-- General ticking events
	IncrementPlayerCash()

	DistributeGatheredResources()
end

Tick = function()
	DrawScoreboard()
	DrawNameTags()

	HackyStopNeutralHarvesters()
end

--[[ World loaded ]]
SetPlayerInfo = function()
	local humanPlayers = Player.GetPlayers(function(p)
		return PlayerIsHuman(p)
	end)

	Utils.Do(humanPlayers, function(p)
		PlayerInfo[p.InternalName] =
		{
			Player = p,
			Team = nil,
			Hero = nil,
			PurchaseTerminal = nil,
			CanBuyConditionToken = -1,
			BuildingConditionToken = -1,
			VehicleConditionToken = -1,
			InfantryConditionToken = -1,
			RadarConditionToken = -1,
			Score = 0,
			Kills = 0,
			Deaths = 0,
			PassengerOfVehicle = nil,
			IsPilot = false,
			ProximityEventTokens = { }
		}
	end)
end

SetTeamInfo = function()
	-- Could combine w/ SetPlayerInfo.
	local teams = Player.GetPlayers(function (p) return PlayerIsTeamAi(p) end)

	Utils.Do(teams, function(team)
		local playersOnTeam = { }
		for k, v in pairs(PlayerInfo) do
			if v.Player.Faction == team.Faction then
				playersOnTeam[v.Player.InternalName] = v
			end
		end

		TeamInfo[team.InternalName] = {
			AiPlayer = team,
			Players = playersOnTeam,
			ConstructionYard = nil,
			Refinery = nil,
			Barracks = nil,
			WarFactory = nil,
			Radar = nil,
			Powerplant = nil,
			ServiceDepot = nil,
			BasicDefenses = {},
			PoweredDefenses = {},
			LastCheckedResourceAmount = 0
		}
	end)

	-- Store a reference to the team on the player.
	Utils.Do(TeamInfo, function(ti)
		Utils.Do(ti.Players, function(pi)
			pi.Team = ti
		end)
	end)
end

AssignTeamBuildings = function()
	Utils.Do(Map.ActorsInWorld, function(actor)
		if ArrayContains(ConstructionYardActorTypes, actor.Type) then
			TeamInfo[actor.Owner.InternalName].ConstructionYard = actor
		end

		if ArrayContains(RefineryActorTypes, actor.Type) then
			TeamInfo[actor.Owner.InternalName].Refinery = actor
		end

		if ArrayContains(RadarActorTypes, actor.Type) then
			TeamInfo[actor.Owner.InternalName].Radar = actor
		end

		if ArrayContains(WarFactoryActorTypes, actor.Type) then
			TeamInfo[actor.Owner.InternalName].WarFactory = actor
		end

		if ArrayContains(BarracksActorTypes, actor.Type) then
			TeamInfo[actor.Owner.InternalName].Barracks = actor
		end

		if ArrayContains(PowerplantActorTypes, actor.Type) then
			TeamInfo[actor.Owner.InternalName].Powerplant = actor
		end

		if ArrayContains(ServiceDepotActorTypes, actor.Type) then
			TeamInfo[actor.Owner.InternalName].ServiceDepot = actor
		end

		if ArrayContains(BasicDefenseActorTypes, actor.Type) then
			-- TODO: Add defenses.
			--TeamInfo[actor.Owner.InternalName].BasicDefenseActorTypes = actor
		end

		if ArrayContains(PoweredDefenseActorTypes, actor.Type) then
			-- TODO: Add defenses.
			--TeamInfo[actor.Owner.InternalName].BasicDefenseActorTypes = actor
		end
	end)
end

AddPurchaseTerminals = function()
	Utils.Do(PlayerInfo, function(pi)
		-- Hacky, but create all purchase terminals at 0,0.
		-- The side effect is a unit forcibly moving if a purchase is made, while standing on it.
		local spawnpoint = CPos.New(0, 0)
		Actor.Create(PurchaseTerminalActorType, true, { Owner = pi.Player, Location = spawnpoint })
	end)
end

BindPurchaseTerminals = function()
	Utils.Do(Map.ActorsInWorld, function(actor)
		if actor.Type == PurchaseTerminalActorType then
			local pt = actor
			local pi = PlayerInfo[pt.Owner.InternalName]

			pi.PurchaseTerminal = pt

			-- NOTE: Team conditions should match the faction name.
			pt.GrantCondition(pi.Player.Faction)

			pi.BuildingConditionToken = pt.GrantCondition("building")
			pi.RadarConditionToken = pt.GrantCondition("radar")
			pi.InfantryConditionToken = pt.GrantCondition("infantry")
			pi.VehicleConditionToken = pt.GrantCondition("vehicle")

			Trigger.OnProduction(pt, function(producer, produced)
				-- DisplayMessage(producer.Owner.Name .. " purchased " .. produced.Type)
				BuildPurchaseTerminalItem(pi, produced.Type)
			end)
		end
	end)
end

BindBaseEvents = function()
	-- Mod-agnostic polish fixes:
	-- This should say "Allied" instead of "Allies" for the team name.
	-- Building names shouldn't be hardcoded here.
	Utils.Do(TeamInfo, function(ti)

		-- Construction Yard
		Trigger.OnKilled(ti.ConstructionYard, function(self, killer)
			DisplayMessage(self.Owner.Name .. " Construction Yard was destroyed by " .. killer.Owner.Name)
		end)
		Trigger.OnDamaged(ti.ConstructionYard, function(self, attacker)
			ti.ConstructionYard.StartBuildingRepairs()
			GrantRewardOnHit(self, attacker)
		end)

		-- Refinery
		Trigger.OnKilled(ti.Refinery, function(self, killer)
			DisplayMessage(self.Owner.Name .. " Refinery was destroyed by " .. killer.Owner.Name)
		end)
		Trigger.OnDamaged(ti.Refinery, function(self, attacker)
			if not ti.ConstructionYard.IsDead then
				ti.Refinery.StartBuildingRepairs()
			end
			GrantRewardOnHit(self, attacker)
		end)

		-- Barracks
		Trigger.OnKilled(ti.Barracks, function(self, killer)
			DisplayMessage(self.Owner.Name .. " Barracks was destroyed by " .. killer.Owner.Name)

			Utils.Do(ti.Players, function(pi)
				pi.PurchaseTerminal.RevokeCondition(pi.InfantryConditionToken)
			end)
		end)
		Trigger.OnDamaged(ti.Barracks, function(self, attacker)
			if not ti.ConstructionYard.IsDead then
				ti.Barracks.StartBuildingRepairs()
			end
			GrantRewardOnHit(self, attacker)
		end)

		-- War Factory
		Trigger.OnKilled(ti.WarFactory, function(self, killer)
			DisplayMessage(self.Owner.Name .. " War Factory was destroyed by " .. killer.Owner.Name)

			Utils.Do(ti.Players, function(pi)
				pi.PurchaseTerminal.RevokeCondition(pi.VehicleConditionToken)
			end)
		end)
		Trigger.OnDamaged(ti.WarFactory, function(self, attacker)
			if not ti.ConstructionYard.IsDead then
				ti.WarFactory.StartBuildingRepairs()
			end
			GrantRewardOnHit(self, attacker)
		end)

		-- Radar
		Trigger.OnKilled(ti.Radar, function(self, killer)
			DisplayMessage(self.Owner.Name .. " Radar Dome was destroyed by " .. killer.Owner.Name)

			Utils.Do(ti.Players, function(pi)
				pi.PurchaseTerminal.RevokeCondition(pi.RadarConditionToken)
			end)
		end)
		Trigger.OnDamaged(ti.Radar, function(self, attacker)
			if not ti.ConstructionYard.IsDead then
				ti.Radar.StartBuildingRepairs()
			end
			GrantRewardOnHit(self, attacker)
		end)

		-- Powerplant
		Trigger.OnKilled(ti.Powerplant, function(self, killer)
			DisplayMessage(self.Owner.Name .. " Powerplant was destroyed by " .. killer.Owner.Name)
		end)
		Trigger.OnDamaged(ti.Powerplant, function(self, attacker)
			if not ti.ConstructionYard.IsDead then
				ti.Powerplant.StartBuildingRepairs()
			end
			GrantRewardOnHit(self, attacker)
		end)

		-- Service Depot
		Trigger.OnKilled(ti.ServiceDepot, function(self, killer)
			DisplayMessage(self.Owner.Name .. " Service Depot was destroyed by " .. killer.Owner.Name)
		end)

		Trigger.OnDamaged(ti.ServiceDepot, function(self, attacker)
			if not ti.ConstructionYard.IsDead then
				ti.ServiceDepot.StartBuildingRepairs()
			end
			GrantRewardOnHit(self, attacker)
		end)

		-- TODO: Defenses

	end)
end

SpawnHero = function(player)
	local spawnpoint = GetAvailableSpawnPoint(player)
	local hero = Actor.Create(SpawnAsActorType, true, { Owner = player, Location = spawnpoint })

	PlayerInfo[player.InternalName].Hero = hero

    FocusLocalCameraOnActor(hero)
	BindHeroEvents(hero)
end

GetAvailableSpawnPoint = function(player)
	--[[
		Hacky/funny :)
		Spawn actors around the perimeter of an alive building
		Assumes buildings are shaped as:
			ooo
			ooo
			ooo

		We get the center of the building, expand twice, and only use the annulus (outer ring).
	]]

	-- Instead of random spawns, we could allow players to select a building to spawn on after their first death.

	local pi = PlayerInfo[player.InternalName]
	local ti = pi.Team

	local allBuildings = {
		ti.ConstructionYard, ti.Refinery, ti.Barracks, ti.Radar, ti.Powerplant, ti.ServiceDepot
	}
	local aliveBuildings = { }
	for i, v in ipairs(allBuildings) do
		if not v.IsDead then aliveBuildings[#aliveBuildings+1] = v end
	end

	-- Get the annulus
	local building = Utils.Random(aliveBuildings)
	local loc = building.Location + CVec.New(1, 1)
	local expandedOnce = Utils.ExpandFootprint({loc}, true)
	local expandedTwice = Utils.ExpandFootprint(expandedOnce, true)
	local annulus = GetCPosAnnulus(expandedOnce, expandedTwice)

	-- Pick a random cell, for now don't care about occupancy
	local randomCell = Utils.Random(annulus)

	return randomCell
end

FocusLocalCameraOnActor = function(actor)
	if actor.Owner.IsLocalPlayer then
		Camera.Position = actor.CenterPosition
	end
end

BindHeroEvents = function(hero)
	Trigger.OnKilled(hero, function(self, killer)
		DisplayMessage(killer.Owner.Name .. " killed " .. self.Owner.Name .. "!")

		-- Increment K/D
		local selfPi = PlayerInfo[self.Owner.InternalName]
		local killerPi = PlayerInfo[killer.Owner.InternalName]
		if selfPi ~= nil then
			selfPi.Deaths = selfPi.Deaths + 1
		end
		if killerPi ~= nil then
			killerPi.Kills = killerPi.Kills + 1
		end

		-- Polish idea: notify respawn time, leave a death cam, increase respawn time.
		Trigger.AfterDelay(25, function() SpawnHero(self.Owner) end)
	end)

	Trigger.OnDamaged(hero, function(self, attacker)
		GrantRewardOnHit(self, attacker)
	end)
end

BindVehicleEvents = function()
	Utils.Do(TeamInfo, function(ti)
		Trigger.OnProduction(ti.WarFactory, function(producer, produced)
			-- New vehicles belong to Neutral (except harvesters...)
			if produced.Type ~= AiHarvesterActorType then
				produced.Owner = NeutralPlayer
			else
				InitializeAiHarvester(produced)
			end

			-- Ownership bindings; if someone enters a vehicle with no passengers, they're the owner.
			Trigger.OnPassengerEntered(produced, function(transport, passenger)
				if transport.PassengerCount == 1 then
					transport.Owner = passenger.Owner
				end
				local pi = PlayerInfo[passenger.Owner.InternalName]

				-- Set passenger state
				pi.PassengerOfVehicle = transport

				-- Name tag hack: Setting the driver to display the proper pilot name.
				if transport.PassengerCount == 1 then
					pi.IsPilot = true
				end

				-- Harvester hack: Also adding to list of harvesters.
				if transport.Type == PlayerHarvesterActorType then
					PlayerHarvesters[#PlayerHarvesters+1] = transport
				end
			end)

			-- If it's empty, transfer ownership back to neutral (current engine behavior makes everyone evacuate).
			Trigger.OnPassengerExited(produced, function(transport, passenger)
				if transport.PassengerCount == 0 then
					transport.Owner = NeutralPlayer
				end

				-- Note: This won't stop harvesters. Players can exit them whenever, so we handle that elsewhere.
				transport.Stop()

				local pi = PlayerInfo[passenger.Owner.InternalName]

				pi.PassengerOfVehicle = nil

				-- Name tag hack: Remove pilot info.
				pi.IsPilot = false
			end)
		end)
	end)
end

BindProximityEvents = function()
	Utils.Do(TeamInfo, function(ti)

		local proximityEnabledBuildings = {
			ti.ConstructionYard,
			ti.Refinery,
			ti.Barracks,
			ti.WarFactory,
			ti.Radar,
			ti.Powerplant,
			ti.ServiceDepot
		}

		Utils.Do(proximityEnabledBuildings, function(building)

			-- Fun fact: We declare the exited trigger first, so it always fires first
			-- Spawning a new infantry unit will cause the first one to exit, and the new one to enter
			-- thus the order of token removal/addition is proper

			Trigger.OnExitedProximityTrigger(building.CenterPosition, WDist.FromCells(3), function(actor)
				local pi = PlayerInfo[actor.Owner.InternalName]

				if pi ~= nil then -- A human player
					if pi.Player.Faction == ti.AiPlayer.Faction then -- On same team
						local tokenToRevoke = pi.ProximityEventTokens[building.Type]
						pi.PurchaseTerminal.RevokeCondition(tokenToRevoke)
						pi.ProximityEventTokens[building.Type] = -1
					end
				end
			end)

			Trigger.OnEnteredProximityTrigger(building.CenterPosition, WDist.FromCells(3), function(actor)
				if not building.IsDead then
					local pi = PlayerInfo[actor.Owner.InternalName]

					if pi ~= nil and pi.PassengerOfVehicle == nil then -- A human player + not in vehicle
						if pi.Player.Faction == ti.AiPlayer.Faction then -- On same team
							pi.ProximityEventTokens[building.Type] = pi.PurchaseTerminal.GrantCondition("canbuy") -- e.g. table['fact'] = token
						end
					end
				end
			end)

		end)
	end)
end

InitializeAiHarvesters = function()
	-- Order all starting harvesters to find resources
	Utils.Do(Map.ActorsInWorld, function (actor)
		if actor.Type == AiHarvesterActorType and PlayerIsTeamAi(actor.Owner) then
			InitializeAiHarvester(actor)
		end
	end)
end

InitializeAiHarvester = function(harv)
	harv.FindResources()

	Trigger.OnKilled(harv, function(self, killer)
		local ti = TeamInfo[self.Owner.InternalName]
		if not ti.WarFactory.IsDead then
			ti.WarFactory.Produce(AiHarvesterActorType)
		end
	end)
end

--[[ Ticking ]]
CheckIfInBase = function()
	Utils.Do(TeamInfo, function(ti)
		Utils.Do(PlayerInfo, function(pi)



		end)
	end)
end

IncrementPlayerCash = function()
	Utils.Do(TeamInfo, function(ti)
		Utils.Do(ti.Players, function(pi)
			local cash = CashPerSecond

			if ti.Refinery.IsDead then
				cash = CashPerSecondPenalized
			end

			pi.Player.Cash = pi.Player.Cash + cash
		end)
	end)

	Trigger.AfterDelay(25, IncrementPlayerCash)
end

DistributeGatheredResources = function()
	-- This distributes resources gathered by AI Harvesters or other players.
	Utils.Do(TeamInfo, function(ti)
		if not ti.Refinery.IsDead and ti.LastCheckedResourceAmount ~= ti.AiPlayer.Resources then
			local addedCash = ti.AiPlayer.Resources - ti.LastCheckedResourceAmount

			Utils.Do(ti.Players, function(pi)
				pi.Player.Cash = pi.Player.Cash + addedCash
			end)

			ti.LastCheckedResourceAmount = ti.AiPlayer.Resources
		end
	end)

	Trigger.AfterDelay(5, DistributeGatheredResources)
end

DrawScoreboard = function()
	--local scoreboard = "Players\n"
	--Utils.Do(PlayerInfo, function(pi)
		--scoreboard = scoreboard .. "\n" .. pi.Player.Name
	--end)
	Utils.Do(PlayerInfo, function(pi)
		if pi.Player.IsLocalPlayer then
			local scoreboard =
				pi.Player.Name
				.. " -- Score: " .. tostring(pi.Score)
				.. " (K/D: " .. tostring(pi.Kills) .. "/" .. tostring(pi.Deaths) .. ")"
			UserInterface.SetMissionText(scoreboard)
		end
	end)
end

DrawNameTags = function()
	-- This is a horrible hack until WithTextDecoration is usable.
	Utils.Do(PlayerInfo, function(pi)
		if pi.Hero ~= nil and pi.Hero.IsInWorld then
			local pos = WPos.New(pi.Hero.CenterPosition.X, pi.Hero.CenterPosition.Y - 1250, 0)
			Media.FloatingText(pi.Player.Name, pos, 1, pi.Player.Color)
		end

		if pi.IsPilot then
			local pos = WPos.New(pi.PassengerOfVehicle.CenterPosition.X, pi.PassengerOfVehicle.CenterPosition.Y - 1250, 0)
			local passengerCount = pi.PassengerOfVehicle.PassengerCount
			local name = pi.Player.Name
			if passengerCount > 1 then
				name = name .. " (+" .. passengerCount - 1 .. ")"
			end
			Media.FloatingText(name, pos, 1, pi.Player.Color)
		end
	end)
end

HackyStopNeutralHarvesters = function()
	-- Neutral harvesters will continue to harvest if we leave while en route to deliver ore.
	-- Simply stopping the harvester or asking it to wait will not work, we have to repeatedly tell the harvester to move in place.
	Utils.Do(PlayerHarvesters, function(harv)
		-- TODO: This will forever tick on harvesters that are dead, etc. We never are removing them from the list when whe should.
		if not harv.IsDead and harv.Owner.InternalName == NeutralPlayerName then
			harv.Move(harv.Location)
		end
	end)
end

--[[ Game logic ]]
BuildPurchaseTerminalItem = function(pi, actorType)
	local hero = pi.Hero;

	if string.find(actorType, PurchaseTerminalInfantryActorTypePrefix) then
		local type = StringReplace(actorType, PurchaseTerminalInfantryActorTypePrefix, "") -- strip buy prefix off, we assume there's an actor without that prefix.

		-- We don't init the health because it's percentage based.
		local newHero = Actor.Create(type, false, { Owner = pi.Player, Location = hero.Location })
		newHero.Health = hero.Health
		newHero.IsInWorld = true

		pi.Hero = newHero

		-- Doesn't look that great if moving.
		hero.Stop()
		hero.IsInWorld = false
		hero.Destroy()

		BindHeroEvents(newHero)
	elseif string.find(actorType, PurchaseTerminalVehicleActorTypePrefix) then
		local type = StringReplace(actorType, PurchaseTerminalVehicleActorTypePrefix, "")

		local ti = pi.Team
		if not ti.WarFactory.IsDead then
			ti.WarFactory.Produce(type)
		end
	end
end

GrantRewardOnHit = function(self, attacker)
	-- Ignore self/team damage
	if self.Owner.Faction == attacker.Owner.Faction then
		return
	end

	local pi = PlayerInfo[attacker.Owner.InternalName]

	-- AI might do the attacking.
	if pi ~= nil then
		local points = CalculatePoints(self, attacker)

		pi.Score = pi.Score + points
		pi.Player.Cash = pi.Player.Cash + points
	end
end

CalculatePoints = function(self, attacker)
	-- Unfortunately there's no way to get damage done in Lua yet.
	-- Instead a bad rock-paper-scissors ish point system has been made.
	local selfArmorType = ''
	local attackerWeaponType = ''
	for i, v in pairs(armorTypes) do
		if ArrayContains(v.types, self.Type) then selfArmorType = v.name end
	end
	for i, v in pairs(weaponTypes) do
		if ArrayContains(v.types, attacker.Type) then attackerWeaponType = v.name end
	end

	local points = 5
	if selfArmorType == 'soft' then
		if attackerWeaponType == 'heal' then points = 5
		elseif attackerWeaponType == 'gun' then points = 25
		elseif attackerWeaponType == 'missle' then points = 5
		elseif attackerWeaponType == 'smallShell' then points = 5
		elseif attackerWeaponType == 'bigShell' then points = 5
		elseif attackerWeaponType == 'fire' then points = 25
		elseif attackerWeaponType == 'zap' then points = 100
		end
	elseif selfArmorType == 'medium' then
		if attackerWeaponType == 'heal' then points = 5
		elseif attackerWeaponType == 'gun' then points = 2
		elseif attackerWeaponType == 'missle' then points = 25
		elseif attackerWeaponType == 'smallShell' then points = 25
		elseif attackerWeaponType == 'bigShell' then points = 25
		elseif attackerWeaponType == 'fire' then points = 2
		elseif attackerWeaponType == 'zap' then points = 50
		end
	elseif selfArmorType == 'hard' then
		if attackerWeaponType == 'heal' then points = 5
		elseif attackerWeaponType == 'gun' then points = 1
		elseif attackerWeaponType == 'missle' then points = 25
		elseif attackerWeaponType == 'smallShell' then points = 15
		elseif attackerWeaponType == 'bigShell' then points = 25
		elseif attackerWeaponType == 'fire' then points = 1
		elseif attackerWeaponType == 'zap' then points = 25
		end
	end

	return points
end

--[[ Misc. ]]--
DisplayMessage = function(message)
	Media.DisplayMessage(message, "Console")
end

ArrayContains = function(collection, value)
	for i, v in ipairs(collection) do
		if v == value then
			return true
		end
	end
	return false
end

-- Used for spawn logic, gets an annulus of two footprints
GetCPosAnnulus = function(baseFootprintCells, expandedFootprintCells)
	local result = {}

	for i, v in ipairs(expandedFootprintCells) do
		if not ArrayContains(baseFootprintCells, v) then
			result[#result+1] = v
		end
	end

	return result
end

StringReplace = function(str, matchText, replaceText)
	return str:gsub(matchText, replaceText)
end

PlayerIsTeamAi = function(player)
	return player.InternalName == AlphaTeamPlayerName or player.InternalName == BetaTeamPlayerName
end

PlayerIsHuman = function(player)
	return player.IsNonCombatant == false and PlayerIsTeamAi(player) == false
end