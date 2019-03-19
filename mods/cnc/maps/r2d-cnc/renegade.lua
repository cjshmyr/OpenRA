--[[
	Renegade 2D Lua script by @hamb
	Version: 0.5
	Engine: OpenRA release-20190314
]]

--[[ General ]]
PlayerInfo = { }
TeamInfo = { }
HealthAfterOnDamageEventTable = { } -- HACK: We store damage dealt since last instance, since OnDamage doesn't tell us.
HarvesterWaypoints = { } -- Waypoints used to guide harvesters near their ore field.
PlayerHarvesters = { } -- HACK: We have to repeatedly tell harvesters to stop moving, or they forever FindResources.
TypeNameTable = { } -- HACK: We don't have a nice way of getting an actor's name (e.g. hand -> Hand of Nod), except for this.
CashPerSecond = 2 -- Cash given per second.
CashPerSecondPenalized = 1 -- Cash given per second, with no ref.
PurchaseTerminalActorType = "purchaseterminal"
PurchaseTerminalInfantryActorTypePrefix = "buy.infantry."
PurchaseTerminalVehicleActorTypePrefix = "buy.vehicle."
PurchaseTerminalBeaconActorTypePrefix = "buy.beacon."
HeroItemPlaceBeaconActorTypePrefix = "buy.placebeacon."
NotifyBaseUnderAttackInterval = DateTime.Seconds(30)
BeaconTimeLimit = DateTime.Seconds(30)
RespawnTime = DateTime.Seconds(3)
LocalPlayer = nil -- HACK: Used for nametags.
EnemyNametagsHiddenForTypes = { "stnk" } -- HACK: Used for nametags.

--[[ Mod-specific ]]
Mod = "cnc"
if Mod == "cnc" then
	SpawnAsActorType = "e1"
	AlphaTeamPlayerName = "GDI"
	BetaTeamPlayerName = "Nod"
	NeutralPlayerName = "Neutral"
	ConstructionYardActorTypes = {"fact"}
	RefineryActorTypes = {"proc"}
	PowerplantActorTypes = {"nuk2"}
	RadarActorTypes = {"hq"}
	WarFactoryActorTypes = {"weap","afld"}
	BarracksActorTypes = {"pyle","hand"}
	ServiceDepotActorTypes = {"fix"}
	DefenseActorTypes = {"gtwr","atwr","gun","obli"}
	AiHarvesterActorType = "harv-ai"
	PlayerHarvesterActorType = "harv"
	NotificationMissionStarted = "bombit1.aud"
	NotificationBaseUnderAttack = "baseatk1.aud"
	NotificationMissionAccomplished = "accom1.aud"
	NotificationMissionFailed = "fail1.aud"
	AlphaBeaconType = "ion-sw"
	BetaBeaconType = "nuke-sw"
	BeaconDeploySound = "target3.aud"
	TypeNameTable['fact'] = 'Construction Yard'
	TypeNameTable['proc'] = 'Tiberium Refinery'
	TypeNameTable['nuk2'] = 'Power Plant'
	TypeNameTable['hq'] = 'Communications Center'
	TypeNameTable['weap'] = 'Weapons Factory'
	TypeNameTable['afld'] = 'Airfield'
	TypeNameTable['pyle'] = 'Barracks'
	TypeNameTable['hand'] = 'Hand of Nod'
	TypeNameTable['fix'] = 'Repair Bay'
	TypeNameTable['gtwr'] = 'Guard Tower'
	TypeNameTable['atwr'] = 'Advanced Guard Tower'
	TypeNameTable['gun'] = 'Turret'
	TypeNameTable['obli'] = 'Obelisk'
elseif Mod == "ra" then
	SpawnAsActorType = "e1"
	AlphaTeamPlayerName = "Allies"
	BetaTeamPlayerName = "Soviet"
	NeutralPlayerName = "Neutral"
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
	NotificationMissionStarted = "newopt1.aud"
	NotificationBaseUnderAttack = "baseatk1.aud"
	NotificationMissionAccomplished = "misnwon1.aud"
	NotificationMissionFailed = "misnlst1.aud"
	AlphaBeaconType = "nuke-sw"
	BetaBeaconType = "nuke-sw"
	BeaconDeploySound = "bleep9.aud"
	TypeNameTable['fact'] = 'Construction Yard'
	TypeNameTable['proc'] = 'Ore Refinery'
	TypeNameTable['apwr'] = 'Power Plant'
	TypeNameTable['dome'] = 'Radar Dome'
	TypeNameTable['weap'] = 'War Factory'
	TypeNameTable['barr'] = 'Barracks'
	TypeNameTable['tent'] = 'Barracks'
	TypeNameTable['fix'] = 'Service Depot'
	TypeNameTable['pbox'] = 'Pillbox'
	TypeNameTable['hbox'] = 'Camoflauged Pillbox'
	TypeNameTable['gun'] = 'Turret'
	TypeNameTable['ftur'] = 'Flame Tower'
	TypeNameTable['tsla'] = 'Tesla Coil'
end
AlphaTeamPlayer = Player.GetPlayer(AlphaTeamPlayerName)
BetaTeamPlayer = Player.GetPlayer(BetaTeamPlayerName)
NeutralPlayer = Player.GetPlayer(NeutralPlayerName)

WorldLoaded = function()
	Media.PlaySound(NotificationMissionStarted)

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

	-- Tick interval > 1
	IncrementPlayerCash()
	DistributeGatheredResources()
end

Tick = function()
	-- Tick interval = 1
	IncrementTicksSinceLastBuildingDamage()
	DrawScoreboard()
	DrawNameTags()
	HackyStopNeutralHarvesters()
end

--[[ World Loaded / Gameplay ]]
SetPlayerInfo = function()
	local humanPlayers = Player.GetPlayers(function(p)
		return PlayerIsHuman(p)
	end)

	Utils.Do(humanPlayers, function(p)
		if p.IsLocalPlayer then	LocalPlayer = p	end

		PlayerInfo[p.InternalName] =
		{
			Player = p,
			Team = nil,
			Hero = nil,
			PurchaseTerminal = nil,
			CanBuyConditionToken = -1, -- hero
			HasBeaconConditionToken = -1, -- hero
			BuildingConditionToken = -1, -- pt
			VehicleConditionToken = -1, -- pt
			InfantryConditionToken = -1, -- pt
			RadarConditionToken = -1, -- pt
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
			TicksSinceLastBuildingDamage = NotifyBaseUnderAttackInterval
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
	end)
end

AddPurchaseTerminals = function()
	Utils.Do(PlayerInfo, function(pi)
		-- Hacky, but create all purchase terminals at 0,0.
		-- The side effect is a unit nudging if a purchase is made while standing on it.
		Actor.Create(PurchaseTerminalActorType, true, { Owner = pi.Player, Location = CPos.New(0, 0) })
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
				BuildPurchaseTerminalItem(pi, produced.Type)
			end)
		end
	end)
end

BindBaseEvents = function()
	Utils.Do(TeamInfo, function(ti)
		-- Construction Yard
		Trigger.OnKilled(ti.ConstructionYard, function(self, killer)
			NotifyBuildingDestroyed(self, killer)
			GrantRewardOnKilled(self, killer, "building")
		end)
		Trigger.OnDamaged(ti.ConstructionYard, function(self, attacker)
			ti.ConstructionYard.StartBuildingRepairs()
			NotifyBaseUnderAttack(self)
			GrantRewardOnDamage(self, attacker)
		end)

		-- Refinery
		Trigger.OnKilled(ti.Refinery, function(self, killer)
			NotifyBuildingDestroyed(self, killer)
			GrantRewardOnKilled(self, killer, "building")
		end)
		Trigger.OnDamaged(ti.Refinery, function(self, attacker)
			if not ti.ConstructionYard.IsDead then
				ti.Refinery.StartBuildingRepairs()
			end
			NotifyBaseUnderAttack(self)
			GrantRewardOnDamage(self, attacker)
		end)

		-- Barracks
		Trigger.OnKilled(ti.Barracks, function(self, killer)
			NotifyBuildingDestroyed(self, killer)
			GrantRewardOnKilled(self, killer, "building")

			Utils.Do(ti.Players, function(pi)
				pi.PurchaseTerminal.RevokeCondition(pi.InfantryConditionToken)
			end)
		end)
		Trigger.OnDamaged(ti.Barracks, function(self, attacker)
			if not ti.ConstructionYard.IsDead then
				ti.Barracks.StartBuildingRepairs()
			end
			NotifyBaseUnderAttack(self)
			GrantRewardOnDamage(self, attacker)
		end)

		-- War Factory
		Trigger.OnKilled(ti.WarFactory, function(self, killer)
			NotifyBuildingDestroyed(self, killer)
			GrantRewardOnKilled(self, killer, "building")

			Utils.Do(ti.Players, function(pi)
				pi.PurchaseTerminal.RevokeCondition(pi.VehicleConditionToken)
			end)
		end)
		Trigger.OnDamaged(ti.WarFactory, function(self, attacker)
			if not ti.ConstructionYard.IsDead then
				ti.WarFactory.StartBuildingRepairs()
			end
			NotifyBaseUnderAttack(self)
			GrantRewardOnDamage(self, attacker)
		end)

		-- Radar
		Trigger.OnKilled(ti.Radar, function(self, killer)
			NotifyBuildingDestroyed(self, killer)
			GrantRewardOnKilled(self, killer, "building")

			Utils.Do(ti.Players, function(pi)
				pi.PurchaseTerminal.RevokeCondition(pi.RadarConditionToken)
			end)
		end)
		Trigger.OnDamaged(ti.Radar, function(self, attacker)
			if not ti.ConstructionYard.IsDead then
				ti.Radar.StartBuildingRepairs()
			end
			NotifyBaseUnderAttack(self)
			GrantRewardOnDamage(self, attacker)
		end)

		-- Powerplant
		Trigger.OnKilled(ti.Powerplant, function(self, killer)
			NotifyBuildingDestroyed(self, killer)
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
			NotifyBaseUnderAttack(self)
			GrantRewardOnDamage(self, attacker)
		end)

		-- Service Depot
		Trigger.OnKilled(ti.ServiceDepot, function(self, killer)
			NotifyBuildingDestroyed(self, killer)
			GrantRewardOnKilled(self, killer, "building")
		end)
		Trigger.OnDamaged(ti.ServiceDepot, function(self, attacker)
			if not ti.ConstructionYard.IsDead then
				ti.ServiceDepot.StartBuildingRepairs()
			end
			NotifyBaseUnderAttack(self)
			GrantRewardOnDamage(self, attacker)
		end)

		-- Defenses
		Utils.Do(ti.Defenses, function(building)
			Trigger.OnKilled(building, function(self, killer)
				NotifyBuildingDestroyed(self, killer)
				GrantRewardOnKilled(self, killer, "defense")
			end)
			Trigger.OnDamaged(building, function(self, attacker)
				if not ti.ConstructionYard.IsDead then
					ti.ServiceDepot.StartBuildingRepairs()
				end
				NotifyBaseUnderAttack(self)
				GrantRewardOnDamage(self, attacker)
			end)
		end)

	end)
end

NotifyBuildingDestroyed = function(self, killer)
	DisplayMessage(self.Owner.Name .. " " .. TypeNameTable[self.Type] .. " was destroyed by " .. killer.Owner.Name .. "!")
end

NotifyBaseUnderAttack = function(self)
	local ti = TeamInfo[self.Owner.InternalName]
	if ti.TicksSinceLastBuildingDamage >= NotifyBaseUnderAttackInterval then
		-- Only display a message and play audio to that team
		Utils.Do(ti.Players, function(pi)
			if pi.Player.IsLocalPlayer then
				DisplayMessage(self.Owner.Name .. " " .. TypeNameTable[self.Type] .. " is under attack!")
				Media.PlaySound(NotificationBaseUnderAttack)
			end
		end)

		ti.LastBaseUnderAttackNotificationTick = NotifyBaseUnderAttackInterval
	end

	ti.TicksSinceLastBuildingDamage = 0
end

SpawnHero = function(player)
	local spawnpoint = GetAvailableSpawnPoint(player)
	local hero = Actor.Create(SpawnAsActorType, true, { Owner = player, Location = spawnpoint })

	local pi = PlayerInfo[player.InternalName]
	pi.Hero = hero

	-- Revoke any inventory tokens
	if pi.HasBeaconConditionToken > -1 then
		hero.RevokeCondition(pi.HasBeaconConditionToken)
		pi.HasBeaconConditionToken = -1
	end

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
		if self.Owner.Name == killer.Owner.Name then
			DisplayMessage(self.Owner.Name .. " killed themselves!")
		else
			DisplayMessage(self.Owner.Name .. " was killed by " .. killer.Owner.Name .. "!")
		end

		GrantRewardOnKilled(self, killer, "hero")

		-- Increment K/D
		local selfPi = PlayerInfo[self.Owner.InternalName]
		local killerPi = PlayerInfo[killer.Owner.InternalName]
		if selfPi ~= nil then
			selfPi.Deaths = selfPi.Deaths + 1
		end
		if killerPi ~= nil then
			killerPi.Kills = killerPi.Kills + 1
		end

		Trigger.AfterDelay(RespawnTime, function() SpawnHero(self.Owner) end)
	end)

	Trigger.OnDamaged(hero, function(self, attacker)
		GrantRewardOnDamage(self, attacker)
	end)

	-- Beacons
	Trigger.OnProduction(hero, function(producer, produced)
		local pi = PlayerInfo[hero.Owner.InternalName]
		BuildHeroItem(pi, produced.Type)
	end)
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

			-- New vehicles belong to Neutral (except AI harvesters...)
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

				-- Set passenger state
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
				-- HACK: Beacons may also trip this.
				-- Need to stop assuming that the actor is a hero, etc.
				if actor.Type == AlphaBeaconType or actor.Type == BetaBeaconType then
					return
				end

				if actor.IsDead then
					return
				end

				local pi = PlayerInfo[actor.Owner.InternalName]
				if pi ~= nil then -- A human player
					if pi.Player.Faction == ti.AiPlayer.Faction then -- On same team
						local tokenToRevoke = pi.ProximityEventTokens[building.Type]

						if tokenToRevoke ~= nil then
							pi.Hero.RevokeCondition(tokenToRevoke)
							pi.ProximityEventTokens[building.Type] = -1
						end
					end
				end
			end)

			Trigger.OnEnteredProximityTrigger(building.CenterPosition, WDist.FromCells(3), function(actor)
				-- HACK: Beacons may also trip this.
				-- Need to stop assuming that the actor is a hero, etc.
				if actor.Type == AlphaBeaconType or actor.Type == BetaBeaconType then
					return
				end

				if building.IsDead then -- Building trips its own exit, ignore
					return
				end

				local pi = PlayerInfo[actor.Owner.InternalName]
				if pi ~= nil and pi.PassengerOfVehicle == nil then -- A human player + not in vehicle
					if pi.Player.Faction == ti.AiPlayer.Faction then -- On same team
						pi.ProximityEventTokens[building.Type] = pi.Hero.GrantCondition("canbuy") -- e.g. table['fact'] = token
					end
				end

			end)

		end)
	end)
end

InitializeAiHarvesters = function()
	-- Order all starting harvesters to find resources
	Utils.Do(Map.ActorsInWorld, function (actor)
		-- Hack: cache waypoint location to move harvester to
		if actor.Type == 'waypoint' then HarvesterWaypoints[actor.Owner.Faction] = actor.Location end

		if actor.Type == AiHarvesterActorType and PlayerIsTeamAi(actor.Owner) then
			local wasPurchased = false
			InitializeAiHarvester(actor, wasPurchased)
		end
	end)
end

InitializeAiHarvester = function(harv, wasPurchased)
	if not wasPurchased then
		local waypointLocation = HarvesterWaypoints[harv.Owner.Faction]
		harv.Move(waypointLocation, 3)
	end

	harv.FindResources()

	Trigger.OnKilled(harv, function(self, killer)
		local ti = TeamInfo[self.Owner.InternalName]
		if not ti.WarFactory.IsDead and not ti.Refinery.IsDead then
			ti.WarFactory.Produce(AiHarvesterActorType)
		end
	end)
end

BuildPurchaseTerminalItem = function(pi, actorType)
	local hero = pi.Hero;

	if string.find(actorType, PurchaseTerminalInfantryActorTypePrefix) then
		local type = actorType:gsub(PurchaseTerminalInfantryActorTypePrefix, "") -- strip buy prefix off; assume there's an actor type defined without that prefix.

		-- We don't init the health because it's percentage based.
		local newHero = Actor.Create(type, false, { Owner = pi.Player, Location = hero.Location })
		newHero.Health = hero.Health
		newHero.IsInWorld = true

		pi.Hero = newHero

		-- HACK: Add their current health to damage table
		local actorId = tostring(newHero)
		HealthAfterOnDamageEventTable[actorId] = newHero.Health

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
	elseif string.find(actorType, PurchaseTerminalBeaconActorTypePrefix) then
		local type = actorType:gsub(PurchaseTerminalBeaconActorTypePrefix, "")

		pi.HasBeaconConditionToken = hero.GrantCondition("hasbeacon")
	end
end

BuildHeroItem = function(pi, actorType)
	if string.find(actorType, HeroItemPlaceBeaconActorTypePrefix) then
		local type = actorType:gsub(HeroItemPlaceBeaconActorTypePrefix, "")

		-- Create beacon at current location (hero gets nudged)
		local beacon = Actor.Create(type, true, { Owner = pi.Player, Location = pi.Hero.Location })
		beacon.GrantCondition('beacontimer', BeaconTimeLimit)

		-- TODO: Unhardcode names
		if type == 'ion-sw' then
			DisplayMessage('Ion Cannon Beacon deployed!')
		else
			DisplayMessage('Nuclear Strike Beacon deployed!')
		end

		-- Remove beacon ownership
		pi.Hero.RevokeCondition(pi.HasBeaconConditionToken)
		pi.HasBeaconConditionToken = -1

		-- Notify all players
		Media.PlaySound(BeaconDeploySound)
		Utils.Do(TeamInfo, function(ti)
			Utils.Do(ti.Players, function(pi)
				local pingColor = HSLColor.Red

				if pi.Player.Faction == beacon.Owner.Faction then
					pingColor = HSLColor.Green
				end

				-- Pings may linger after beacon is destroyed.
				Radar.Ping(pi.Player, beacon.CenterPosition, pingColor, BeaconTimeLimit)
			end)
		end)

		Trigger.OnDamage(beacon, function(actor, attacker)
			GrantRewardOnDamage(actor, attacker);
		end)

		Trigger.OnKilled(beacon, function(actor, killer)
			-- Don't display a disarm message if killing self.
			if actor.Owner.InternalName ~= killer.Owner.InternalName then
				GrantRewardOnKilled(actor, killer, "beacon");
				DisplayMessage('Beacon disarmed!')
			end
		end)

		-- Set up warhead
		Trigger.AfterDelay(BeaconTimeLimit, function()
			if beacon.IsInWorld then
				-- Calling .Kill() to force their explosion
				-- A beacon should technically have a projectile come first.
				beacon.Kill()
			end
		end)
	end
end

GrantRewardOnDamage = function(self, attacker)
	--[[
		This is a fun state machine that calculates damage done.
		It can be completely removed if Lua exposes that information.

		We create a table of actor IDs.
		This table stores health of all actors in the world, and changes after the OnDamage event.
	]]
	local actorId = tostring(self) -- returns e.g. "Actor (e1 53)", where the last # is unique.
	local previousHealth = HealthAfterOnDamageEventTable[actorId]

	if previousHealth == nil then
		-- If an actor isn't in the damage table, they haven't taken damage yet
		-- (or they were purchased, in which case we set their current hp there)
		-- Assume previous health was max HP.
		previousHealth = self.MaxHealth
	end

	local currentHealth = self.Health
	HealthAfterOnDamageEventTable[actorId] = currentHealth

	-- Granting points happens below
	local damageTaken = previousHealth - currentHealth

	if damageTaken == 0 then -- No damage taken (can happen)
		return
	elseif self.Owner.InternalName == NeutralPlayerName then -- Ignore attacking neutral units.
		return
	elseif damageTaken > 0 and self.Owner.Faction == attacker.Owner.Faction then -- Ignore self/team when damage is greater than 0.
		return
	elseif self.Owner.InternalName == attacker.Owner.InternalName then -- Ignore self heal/damage in all cases.
		return
	end

	local attackerpi = PlayerInfo[attacker.Owner.InternalName]
	if attackerpi ~= nil then -- Is a player
		-- Points are calculated as a percentage of damage done against a unit's max HP.
		-- If a unit has 5000 health, and the attack dealt 1500, this is 30% (so 30 points).
		-- Percentages are rounded up (23.3% of health as damage rewards 24 points)

		-- If the damage dealt was negative, this is a heal
		damageTaken = math.abs(damageTaken)

		local percentageDamageDealt = (damageTaken / self.MaxHealth) * 100
		local points = percentageDamageDealt
		points = math.ceil(points + 0.5) -- Round up

		attackerpi.Score = attackerpi.Score + points
		attackerpi.Player.Cash = attackerpi.Player.Cash + points
	end
end

GrantRewardOnKilled = function(self, killer, actorCategory)
	if self.Owner.InternalName == NeutralPlayerName then -- Ignore destroying neutral units.
		return
	end
	if self.Owner.Faction == killer.Owner.Faction then -- Ignore self/team.
		return
	end

	local killerpi = PlayerInfo[killer.Owner.InternalName]
	if killerpi ~= nil then -- Is a player
		local points = 0
		if actorCategory == "hero" then	points = 100
		elseif actorCategory == "unit" then	points = 50
		elseif actorCategory == "defense" then points = 200
		elseif actorCategory == "building" then	points = 300
		elseif actorCategory == "beacon" then points = 300
		end

		killerpi.Score = killerpi.Score + points
		killerpi.Player.Cash = killerpi.Player.Cash + points
	end
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

IncrementTicksSinceLastBuildingDamage = function()
	Utils.Do(TeamInfo, function(ti)
		ti.TicksSinceLastBuildingDamage = ti.TicksSinceLastBuildingDamage + 1
	end)
end

DrawScoreboard = function()
	--local scoreboard = "Players\n"
	--Utils.Do(PlayerInfo, function(pi)
		--scoreboard = scoreboard .. "\n" .. pi.Player.Name
	--end)
	Utils.Do(PlayerInfo, function(pi)
		if pi.Player.IsLocalPlayer then
			local scoreboard =
				"\n" .. pi.Player.Name
				.. " -- Score: " .. tostring(pi.Score)
				.. " (K/D: " .. tostring(pi.Kills) .. "/" .. tostring(pi.Deaths) .. ")"
			UserInterface.SetMissionText(scoreboard)
		end
	end)
end

DrawNameTags = function()
	--[[
		This is a hack until WithTextDecoration is used.

		Units that can cloak will never show their nametag to enemies,
		since we can't track that state in Lua.
	]]
	Utils.Do(TeamInfo, function(ti)
		local sameTeam = LocalPlayer.Faction == ti.AiPlayer.Faction

		Utils.Do(ti.Players, function(pi)
			if pi.Hero ~= nil and pi.Hero.IsInWorld then
				-- HACK: Don't show nametags on enemy units with cloak
				local showTag = sameTeam or (not sameTeam and not ArrayContains(EnemyNametagsHiddenForTypes, pi.Hero.Type))

				if showTag then
					local name = pi.Player.Name
					name = name:sub(0,10) -- truncate to 10 chars

					local pos = WPos.New(pi.Hero.CenterPosition.X, pi.Hero.CenterPosition.Y - 1250, 0)
					Media.FloatingText(name, pos, 1, pi.Player.Color)
				end
			end

			if pi.IsPilot then
				-- HACK: Don't show nametags on enemy units with cloak
				local showTag = sameTeam or (not sameTeam and not ArrayContains(EnemyNametagsHiddenForTypes, pi.PassengerOfVehicle.Type))

				if showTag then
					local pos = WPos.New(pi.PassengerOfVehicle.CenterPosition.X, pi.PassengerOfVehicle.CenterPosition.Y - 1250, 0)
					local passengerCount = pi.PassengerOfVehicle.PassengerCount
					local name = pi.Player.Name
					name = name:sub(0,10) -- truncate to 10 chars
					if passengerCount > 1 then
						name = name .. " (+" .. passengerCount - 1 .. ")"
					end
					Media.FloatingText(name, pos, 1, pi.Player.Color)
				end
			end
		end)
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

GetCPosAnnulus = function(baseFootprintCells, expandedFootprintCells)
	-- Used for spawn logic, gets an annulus of two footprints
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