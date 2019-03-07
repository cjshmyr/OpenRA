--[[
TODO:
	A score system.
	A purchasing system.
	Better spawn points.
	Respawn timer.
	Invulnerability area?
	Add a series of tests (check for req'd actors, checkbox in lobby maybe)
	Engineer stuff
	Score / Kills / Death

BUGS:
	Players can be squished by Neutral units (war factory spawns, leaving harvesters).
	Purchase terminals are placed where the spawning actor is. Should place at 0,0 (less haccky but whatever)

REFACTOR:
	???
]]

--[[ General ]]
PlayerInfo = { }
TeamInfo = { }
PlayerHarvesters = { } -- Exists due to a hack.
CashPerSecond = 4 -- Cash given per second.
CashPerSecondPenalized = 2 -- Cash given per second, with no ref.
PurchaseTerminalActorType = "purchaseterminal"
PurchaseTerminalInfantryActorTypePrefix = "buy.infantry."
PurchaseTerminalVehicleActorTypePrefix = "buy.vehicle."
SpawnAsActorType = "e1"

--[[ Mod-specific ]]
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
SpawnPointActorType = "hackyspawn"

WorldLoaded = function()
	SetPlayerInfo()
	SetTeamInfo()

	AssignTeamBuildings()

	BindBaseEvents()
	BindVehicleEvents()
	BindBaseFootprintEvents()

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
		return PlayerIsHuman(p) -- p.IsNonCombatant == false and PlayerIsTeamAi(p.InternalName) == false
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
			IsPilot = false
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
			LastCheckedResourceAmount = 0,
			BuildingFootprintEnteredTrigger = -1,
			BuildingFootprintExitedTrigger = -1
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
		local spawnpoint = Map.NamedActor(SpawnPointActorType)
		Actor.Create(PurchaseTerminalActorType, true, { Owner = pi.Player, Location = spawnpoint.Location })
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
			BindBaseFootprintEvents()
		end)
		Trigger.OnDamaged(ti.ConstructionYard, function(self, attacker)
			ti.ConstructionYard.StartBuildingRepairs()
		end)

		-- Refinery
		Trigger.OnKilled(ti.Refinery, function(self, killer)
			DisplayMessage(self.Owner.Name .. " Refinery was destroyed by " .. killer.Owner.Name)
			BindBaseFootprintEvents()
		end)
		Trigger.OnDamaged(ti.Refinery, function(self, attacker)
			if not ti.ConstructionYard.IsDead then
				ti.Refinery.StartBuildingRepairs()
			end
		end)

		-- Barracks
		Trigger.OnKilled(ti.Barracks, function(self, killer)
			DisplayMessage(self.Owner.Name .. " Barracks was destroyed by " .. killer.Owner.Name)
			BindBaseFootprintEvents()

			Utils.Do(ti.Players, function(pi)
				pi.PurchaseTerminal.RevokeCondition(pi.InfantryConditionToken)
			end)
		end)
		Trigger.OnDamaged(ti.Barracks, function(self, attacker)
			if not ti.ConstructionYard.IsDead then
				ti.Barracks.StartBuildingRepairs()
			end
		end)

		-- War Factory
		Trigger.OnKilled(ti.WarFactory, function(self, killer)
			DisplayMessage(self.Owner.Name .. " War Factory was destroyed by " .. killer.Owner.Name)
			BindBaseFootprintEvents()

			Utils.Do(ti.Players, function(pi)
				pi.PurchaseTerminal.RevokeCondition(pi.VehicleConditionToken)
			end)
		end)
		Trigger.OnDamaged(ti.WarFactory, function(self, attacker)
			if not ti.ConstructionYard.IsDead then
				ti.WarFactory.StartBuildingRepairs()
			end
		end)

		-- Radar
		Trigger.OnKilled(ti.Radar, function(self, killer)
			DisplayMessage(self.Owner.Name .. " Radar Dome was destroyed by " .. killer.Owner.Name)
			BindBaseFootprintEvents()

			Utils.Do(ti.Players, function(pi)
				pi.PurchaseTerminal.RevokeCondition(pi.RadarConditionToken)
			end)
		end)
		Trigger.OnDamaged(ti.Radar, function(self, attacker)
			if not ti.ConstructionYard.IsDead then
				ti.Radar.StartBuildingRepairs()
			end
		end)

		-- Powerplant
		Trigger.OnKilled(ti.Powerplant, function(self, killer)
			DisplayMessage(self.Owner.Name .. " Powerplant was destroyed by " .. killer.Owner.Name)
			BindBaseFootprintEvents()
		end)
		Trigger.OnDamaged(ti.Powerplant, function(self, attacker)
			if not ti.ConstructionYard.IsDead then
				ti.Powerplant.StartBuildingRepairs()
			end
		end)

		-- Service Depot
		Trigger.OnKilled(ti.ServiceDepot, function(self, killer)
			DisplayMessage(self.Owner.Name .. " Service Depot was destroyed by " .. killer.Owner.Name)
			BindBaseFootprintEvents()
		end)

		Trigger.OnDamaged(ti.ServiceDepot, function(self, attacker)
			if not ti.ConstructionYard.IsDead then
				ti.ServiceDepot.StartBuildingRepairs()
			end
		end)

	end)
end

SpawnHero = function(player)
	local spawnpoint = Map.NamedActor(SpawnPointActorType)
	local hero = Actor.Create(SpawnAsActorType, true, { Owner = player, Location = spawnpoint.Location })

	hero.AddTag("hero")

	PlayerInfo[player.InternalName].Hero = hero

    FocusLocalCameraOnActor(hero)
	BindHeroEvents(hero)
end

FocusLocalCameraOnActor = function(actor)
	if actor.Owner.IsLocalPlayer then
		Camera.Position = actor.CenterPosition
	end
end

BindHeroEvents = function(hero)
	Trigger.OnKilled(hero, function(self, killer)
		DisplayMessage(killer.Owner.Name .. " killed " .. self.Owner.Name)
		SpawnHero(self.Owner)
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

				-- Harvester hack: Also adding to list of harvesters.
				if transport.Type == PlayerHarvesterActorType then
					PlayerHarvesters[#PlayerHarvesters+1] = transport
				end

				PlayerInfo[passenger.Owner.InternalName].PassengerOfVehicle = transport

				-- Name tag hack: Setting the driver to display the proper pilot name.
				if transport.PassengerCount == 1 then
					PlayerInfo[passenger.Owner.InternalName].IsPilot = true
				end
			end)

			-- If it's empty, transfer ownership back to neutral (current engine behavior makes everyone evacuate).
			Trigger.OnPassengerExited(produced, function(transport, passenger)
				if transport.PassengerCount == 0 then
					transport.Owner = NeutralPlayer
				end

				-- Note: This won't stop harvesters. Players can exit them whenever, so we handle that elsewhere.
				transport.Stop()

				PlayerInfo[passenger.Owner.InternalName].PassengerOfVehicle = nil

				-- Name tag hack: Remove pilot info.
				PlayerInfo[passenger.Owner.InternalName].IsPilot = false
			end)
		end)
	end)
end

BindBaseFootprintEvents = function()
	--[[
		Outstanding bugs:

		Doesn't account for team yet.
	]]

	Utils.Do(TeamInfo, function(ti)

		-- HACK: If we're killing a building, we have to manually clear the token for entering/exiting again.
		Utils.Do(ti.Players, function(pi)
			if pi.PurchaseTerminal ~= nil then -- nil on world load, in which we don't care.
				pi.PurchaseTerminal.RevokeCondition(pi.CanBuyConditionToken)
				pi.CanBuyConditionToken = -1
			end
		end)

		local purchaseTerminalEnabledBuildings = {
			ti.ConstructionYard,
			ti.Refinery,
			ti.Barracks,
			ti.WarFactory,
			ti.Radar,
			ti.Powerplant
		}

		local footprintCells = { }

		Utils.Do(purchaseTerminalEnabledBuildings, function(building)
			if not building.IsDead then
				--[[
					Hacky and dumb.
					(Usual) building footprint:
						ooo
						ooo
						ooo

					Location gives the top left.
					Increment X/Y by one, and expand footprint twice (incl. diagonal) to get adjacency.
					Won't be perfect for other sizes, but good enough.
				]]
				local loc = building.Location + CVec.New(1, 1)
				local expandedLoc = Utils.ExpandFootprint({loc}, true)
				expandedLoc = Utils.ExpandFootprint(expandedLoc, true)

				Utils.Do(expandedLoc, function(cell)
					footprintCells[#footprintCells +1] = cell
				end)
			end
		end)

		local onEnteredTrigger = Trigger.OnEnteredFootprint(footprintCells, function(actor, id)
			if actor.HasTag("hero") then
				local pi = GetPlayerInfoForActor(actor)

				-- Hacky: Only set the token if there isn't one (there may already be a token if we're purchasing an infantry)
				if pi.CanBuyConditionToken < 0 then
					DisplayMessage("Adding!")
					pi.CanBuyConditionToken = pi.PurchaseTerminal.GrantCondition("canbuy")
				end
			end
		end)

		local onExitedTrigger = Trigger.OnExitedFootprint(footprintCells, function(actor, id)
			if actor.IsInWorld then
				if actor.HasTag("hero") then
					DisplayMessage("Revoking!")
					local pi = GetPlayerInfoForActor(actor)

					pi.PurchaseTerminal.RevokeCondition(pi.CanBuyConditionToken)
					pi.CanBuyConditionToken = -1
				end
			end
		end)

		-- Remove any previous footprints
		Trigger.RemoveFootprintTrigger(ti.BuildingFootprintEnteredTrigger)
		Trigger.RemoveFootprintTrigger(ti.BuildingFootprintExitedTrigger)

		ti.BuildingFootprintEnteredTrigger = onEnteredTrigger
		ti.BuildingFootprintExitedTrigger = onExitedTrigger

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
			local scoreboard = "Player: " .. pi.Player.Name
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
		newHero.AddTag("hero")

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

StringReplace = function(str, matchText, replaceText)
	return str:gsub(matchText, replaceText)
end

PlayerIsTeamAi = function(player)
	return player.InternalName == AlphaTeamPlayerName or player.InternalName == BetaTeamPlayerName
end

PlayerIsHuman = function(player)
	return player.IsNonCombatant == false and PlayerIsTeamAi(player) == false
end

-- Returns the PlayerInfo for an actor. Otherwise nil if they aren't player owned.
GetPlayerInfoForActor = function(actor)
	-- Exit early on AI
	if not PlayerIsHuman(actor.Owner) then
		return nil
	end

	-- Hand rolled loop to exit early
	for i, pi in pairs(PlayerInfo) do
		if pi.Hero ~= nil and pi.Player.InternalName == actor.Owner.InternalName then
			return pi
		end
	end

	return nil
end