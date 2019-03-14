--[[
Balance:
	Ensure medics/engineers/mechanics get points/score for their weapons.
	Rebalance money rewards.
	Rebalance point rewards.
	Rebalance unit costs?
	Check advanced infantry unit balance.
	Turret dps should be close to tesla.
	Chronotank probably needs teleport cooldown reduction.
	Enable minelayers, add mine limit.
	Enable missing advanced infantry units.
	Enable air units.
	Enable sea units.

Gameplay:
	Recalculate damage done.

	Building under attack notifications.
	Building lost notification (sound).
	Buying vehicles when WF is dead.
	Victory condition on timer or points.
	Better scoreboard (show current rank in the game, team score).

	Add a camera on death, and increment respawn time.
	Add locking to vehicles that aren't yours (so they aren't stolen).
	Better spawn points. Allow players to choose.
	Toggling of nametags, scoreboard (earth 4&7 nametags, stealth2.shp 10&15 scoreboard).
	Fix AI Harvesters to follow a waypoint path after death.
	Only allow purchasing while not mobile? Can remove jittery infantry buying.

Bugs:
	Players can be squished by Neutral units (war factory spawns, leaving harvesters).
	Buying new infantry may result in lower health than expected.
	Possibly? Killing a neutral vehicle owned by the other team may result in money or not.

Refactor:
	Score / points system.
	Harvester waypoints for FindResources.

Lua ideas:
	Expose score.
	Expose better UI (scoreboard, spawning, toggling options).
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
NotifyBaseUnderAttackSecondInterval = DateTime.Seconds(30)

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
DefenseActorTypes = {"pbox","hbox","gun","ftur","tsla"}
AiHarvesterActorType = "harv-ai"
PlayerHarvesterActorType = "harv"

-- [[ Hacks that should be removed ]]
MoveAiHarvestersToRefineryOnDeath = true
HealthAfterOnDamageEventTable = { }

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
			ProximityEventTokens = { },
			HealthAfterLastDamageEvent = -1
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
			Defenses = {},
			LastCheckedResourceAmount = 0,
			LastBaseUnderAttackNotificationTick = 0
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

		if ArrayContains(DefenseActorTypes, actor.Type) then
			local ti = TeamInfo[actor.Owner.InternalName]
			ti.Defenses[#ti.Defenses+1] = actor
		end

		-- Damage hack
		if pcall(function() HealthAfterOnDamageEventTable[tostring(actor)] = actor.Health end) then
			-- Wrapping with pcall handles errors (if an actor has no Health trait, there's an error. Couldn't figure out how to handle this better)
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
			GrantRewardOnKilled(self, killer, "building")
		end)
		Trigger.OnDamaged(ti.ConstructionYard, function(self, attacker)
			ti.ConstructionYard.StartBuildingRepairs()
			GrantRewardOnDamage(self, attacker)
		end)

		-- Refinery
		Trigger.OnKilled(ti.Refinery, function(self, killer)
			DisplayMessage(self.Owner.Name .. " Refinery was destroyed by " .. killer.Owner.Name)
			GrantRewardOnKilled(self, killer, "building")
		end)
		Trigger.OnDamaged(ti.Refinery, function(self, attacker)
			if not ti.ConstructionYard.IsDead then
				ti.Refinery.StartBuildingRepairs()
			end
			GrantRewardOnDamage(self, attacker)
		end)

		-- Barracks
		Trigger.OnKilled(ti.Barracks, function(self, killer)
			DisplayMessage(self.Owner.Name .. " Barracks was destroyed by " .. killer.Owner.Name)
			GrantRewardOnKilled(self, killer, "building")

			Utils.Do(ti.Players, function(pi)
				pi.PurchaseTerminal.RevokeCondition(pi.InfantryConditionToken)
			end)
		end)
		Trigger.OnDamaged(ti.Barracks, function(self, attacker)
			if not ti.ConstructionYard.IsDead then
				ti.Barracks.StartBuildingRepairs()
			end
			GrantRewardOnDamage(self, attacker)
		end)

		-- War Factory
		Trigger.OnKilled(ti.WarFactory, function(self, killer)
			DisplayMessage(self.Owner.Name .. " War Factory was destroyed by " .. killer.Owner.Name)
			GrantRewardOnKilled(self, killer, "building")

			Utils.Do(ti.Players, function(pi)
				pi.PurchaseTerminal.RevokeCondition(pi.VehicleConditionToken)
			end)
		end)
		Trigger.OnDamaged(ti.WarFactory, function(self, attacker)
			if not ti.ConstructionYard.IsDead then
				ti.WarFactory.StartBuildingRepairs()
			end
			GrantRewardOnDamage(self, attacker)
		end)

		-- Radar
		Trigger.OnKilled(ti.Radar, function(self, killer)
			DisplayMessage(self.Owner.Name .. " Radar Dome was destroyed by " .. killer.Owner.Name)
			GrantRewardOnKilled(self, killer, "building")

			Utils.Do(ti.Players, function(pi)
				pi.PurchaseTerminal.RevokeCondition(pi.RadarConditionToken)
			end)
		end)
		Trigger.OnDamaged(ti.Radar, function(self, attacker)
			if not ti.ConstructionYard.IsDead then
				ti.Radar.StartBuildingRepairs()
			end
			GrantRewardOnDamage(self, attacker)
		end)

		-- Powerplant
		Trigger.OnKilled(ti.Powerplant, function(self, killer)
			DisplayMessage(self.Owner.Name .. " Powerplant was destroyed by " .. killer.Owner.Name)
			GrantRewardOnKilled(self, killer, "building")

			if not ti.Radar.IsDead then
				Utils.Do(ti.Players, function(pi)
					pi.PurchaseTerminal.RevokeCondition(pi.RadarConditionToken)
				end)
			end
		end)
		Trigger.OnDamaged(ti.Powerplant, function(self, attacker)
			if not ti.ConstructionYard.IsDead then
				ti.Powerplant.StartBuildingRepairs()
			end
			GrantRewardOnDamage(self, attacker)
		end)

		-- Service Depot
		Trigger.OnKilled(ti.ServiceDepot, function(self, killer)
			DisplayMessage(self.Owner.Name .. " Service Depot was destroyed by " .. killer.Owner.Name)
			GrantRewardOnKilled(self, killer, "building")
		end)
		Trigger.OnDamaged(ti.ServiceDepot, function(self, attacker)
			if not ti.ConstructionYard.IsDead then
				ti.ServiceDepot.StartBuildingRepairs()
			end
			GrantRewardOnDamage(self, attacker)
		end)

		-- Defenses
		Utils.Do(ti.Defenses, function(building)
			Trigger.OnKilled(building, function(self, attacker)
				-- TODO: Message?
				GrantRewardOnKilled(self, killer, "defense")
			end)
			Trigger.OnDamaged(building, function(self, attacker)
				if not ti.ConstructionYard.IsDead then
					ti.ServiceDepot.StartBuildingRepairs()
				end
				GrantRewardOnDamage(self, attacker)
			end)
		end)

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
		GrantRewardOnKilled(self, killer, "unit")

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
		GrantRewardOnDamage(self, attacker)
	end)

	-- Damage hack
	HealthAfterOnDamageEventTable[tostring(hero)] = hero.Health
end

BindVehicleEvents = function()
	Utils.Do(TeamInfo, function(ti)
		Trigger.OnProduction(ti.WarFactory, function(producer, produced)
			-- Bind any events
			Trigger.OnDamaged(produced, function(self, attacker)
				GrantRewardOnDamage(self, attacker)
			end)
			Trigger.OnKilled(produced, function(self, killer)
				GrantRewardOnKilled(self, killer, "unit")
			end)

			-- New vehicles belong to Neutral (except harvesters...)
			if produced.Type ~= AiHarvesterActorType then
				produced.Owner = NeutralPlayer
			else
				local wasPurchased = true
				InitializeAiHarvester(produced, wasPurchased)
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

			-- Damage hack
			HealthAfterOnDamageEventTable[tostring(actor)] = actor.Health
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

						if tokenToRevoke ~= nil then
							pi.PurchaseTerminal.RevokeCondition(tokenToRevoke)
							pi.ProximityEventTokens[building.Type] = -1
						end
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
			local wasPurchased = false
			InitializeAiHarvester(actor, wasPurchased)
		end
	end)
end

InitializeAiHarvester = function(harv, wasPurchased)
	if wasPurchased and MoveAiHarvestersToRefineryOnDeath then
		-- Map-specific hack: In some cases, we need to tell purchased the ore truck to move near the refinery, then find resources.
		-- TODO: Potential crash if this thing dies while this happens. Replace this with a waypoint.
		local ti = TeamInfo[harv.Owner.InternalName]
		harv.Move(ti.Refinery.Location, 5)
	end

	harv.FindResources()

	Trigger.OnKilled(harv, function(self, killer)
		local ti = TeamInfo[self.Owner.InternalName]
		if not ti.WarFactory.IsDead and not ti.Refinery.IsDead then
			ti.WarFactory.Produce(AiHarvesterActorType)
		end
	end)
end

--[[ Ticking ]]
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
			local name = pi.Player.Name
			name = name:sub(0,10) -- truncate to 10 chars

			local pos = WPos.New(pi.Hero.CenterPosition.X, pi.Hero.CenterPosition.Y - 1250, 0)
			Media.FloatingText(name, pos, 1, pi.Player.Color)
		end

		if pi.IsPilot then
			local pos = WPos.New(pi.PassengerOfVehicle.CenterPosition.X, pi.PassengerOfVehicle.CenterPosition.Y - 1250, 0)
			local passengerCount = pi.PassengerOfVehicle.PassengerCount
			local name = pi.Player.Name
			name = name:sub(0,10) -- truncate to 10 chars
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
		local type = actorType:gsub(PurchaseTerminalInfantryActorTypePrefix, "") -- strip buy prefix off, we assume there's an actor without that prefix.

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
		local type = actorType:gsub(PurchaseTerminalVehicleActorTypePrefix, "")

		local ti = pi.Team
		if not ti.WarFactory.IsDead then
			ti.WarFactory.Produce(type)
		end
	end
end

GrantRewardOnDamage = function(self, attacker)
	--[[
		This is a fun state machine that calculates damage done.
		It can be completely removed if Lua exposes that information.

		We create a table of actor IDs.
		This table stores health of all actors in the world, and changes after the OnDamage event.

		TODO:
			When anything in this world is created, we need to run a function that adds or updates this value
			No points on self, team, or neutral unit damage.

			Convert damage dealt into a sensible amount of points (idea: formula of their max health, and % of damage dealt)
			There's an issue where a purchased infantry did not appear in the damage table.
	]]

	local actorId = tostring(self) -- returns e.g. "Actor (e1 53)", where the last # is unique.

	local previousHealth = HealthAfterOnDamageEventTable[actorId]

	if previousHealth == nil then
		DisplayMessage('Error! Fix me! ' .. actorId .. ' was not found in the damage table!')
	else
		local currentHealth = self.Health

		local damageTaken = previousHealth - currentHealth

		HealthAfterOnDamageEventTable[actorId] = currentHealth

		-- Only grant points to players
		local attackerpi = PlayerInfo[attacker.Owner.InternalName]
		if attackerpi ~= nil then

			local percentageDamageDealt = (damageTaken / self.MaxHealth) * 100

			--local points = damageTaken / 100
			DisplayMessage(tostring(percentageDamageDealt))
			local points = percentageDamageDealt

			--DisplayMessage('Damage taken: ' .. tostring(damageTaken) .. ' / points: ' .. tostring(points))

			--attackerpi.Score = attackerpi.Score + points
			--attackerpi.Player.Cash = attackerpi.Player.Cash + points
		end
	end
end

GrantRewardOnKilled = function(self, killer, actorCategory)
	local points = 0
	if actorCategory == "unit" then
		points = 100
	elseif actorCategory == "defense" then
		points = 200
	elseif actorCategory == "building" then
		points = 300
	end

	-- Ignore self/team killing
	if self.Owner.Faction == killer.Owner.Faction then
		return
	end

	local pi = PlayerInfo[killer.Owner.InternalName]

	-- AI might do the killing.
	if pi ~= nil then
		pi.Score = pi.Score + points
		pi.Player.Cash = pi.Player.Cash + points
	end
end

CalculatePoints = function(self, attacker)
	-- Unfortunately there's no way to get damage done in Lua yet.
	-- Instead a bad rock-paper-scissors ish point system has been made.
	local selfArmorType = ''
	local attackerWeaponType = ''
	for i, v in pairs(ArmorTypes) do
		if ArrayContains(v.types, self.Type) then selfArmorType = v.name end
	end
	for i, v in pairs(WeaponTypes) do
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

PlayerIsTeamAi = function(player)
	return player.InternalName == AlphaTeamPlayerName or player.InternalName == BetaTeamPlayerName
end

PlayerIsHuman = function(player)
	return player.IsNonCombatant == false and PlayerIsTeamAi(player) == false
end