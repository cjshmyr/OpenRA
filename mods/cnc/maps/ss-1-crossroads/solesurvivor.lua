-- Code changes
-- 1) Better random spawn selection (random location on map) - perhaps based on Teleport's logic
-- 2) Better ability to get a list of players -- make GetPlayers to allow a nil
-- 3) Player to also return internal name, or is this pointless?
-- 4) Ability to get local player, so we can do camera and scoreboard

-- YAML changes
-- Add periods after tooltips for the dinos

-- todos:
-- cloaking the spawn flare (so others don't see it)
-- victory
-- better spawn logic
-- knowledge of granted upgrades
-- ai!
-- radar?
-- more crates?
-- SS had flavor text for events (kills)

Players = {}
SpawnPoints = {}

WorldLoaded = function()
	DisplayMessage("Welcome to Sole Survivor!")
	
	CacheSpawnPoints()
	
	BuildPlayerList()
	
	for i, player in ipairs(Players) do	
		SpawnPlayer(player)
	end
	
	if Map.IsSinglePlayer then
		DisplayMessage("that's sad... you're alone!")
		DisplayMessage("how about a friend?")		
		SpawnPlayer(Player.GetPlayer("Hunter0"))		
	end
end

CacheSpawnPoints = function()
	-- could also use GetActorsByType for neutral
	Utils.Do(Map.NamedActors, function(actor)
		if actor.Type == "waypoint" then		
			SpawnPoints[#SpawnPoints + 1] = actor
		end
	end)
end

BuildPlayerList = function()
	Players = Player.GetPlayers(function(self) return self.IsNonCombatant == false end)
end

Tick = function()
	IncrementAllPlayerCash()	
	-- local allmapactors = Map.ActorsInBox(Map.TopLeft, Map.BottomRight, function(self) return self.Type == "crate" end)
	-- Utils.Do(allmapactors, function(actor)	
		-- Trigger.OnKilled(actor, function() DisplayMessage("i'm murdered! :(") end)
	-- end)
end

-- todo: not sure if this will cause trouble with simultaneously earned bounties
LastCashTick = 1
IncrementAllPlayerCash = function()
	-- give players $10 every 10 seconds
	if LastCashTick >= DateTime.Seconds(10) then		
		for i, player in ipairs(Players) do
			player.Cash = player.Cash + 10
		end
		LastCashTick = 0
	else
		LastCashTick = LastCashTick + 1
	end
end

SpawnPlayer = function(player)
	local spawnpoint = ChooseRandomSpawnPoint()		
	local spawner = Actor.Create("UnitChooser", true, { Owner = player, Location = spawnpoint.Location })
	
	-- *ai behavior*
	-- we have to build before applying the trigger for some reason.
	-- also wait a bit (probably just 1 tick) before making him build a unit
	Trigger.AfterDelay(DateTime.Seconds(2), function()
	
		if player.InternalName == "Hunter0" then
			-- pick something to build
			DisplayMessage("Hunter0 is building something...")
			spawner.Build({"e1"}, function(unit) 
				-- get a list of crates nearby, grab closest?
				
				-- looking in a 20 cell radius...
				local searchRadius = WDist.New(20 * 1024)
				local nearbycrates = Map.ActorsInCircle(unit[1].CenterPosition, searchRadius, nil)
				
				DisplayMessage("located this many actors nearby:" .. tostring(#nearbycrates))
				
				Utils.Do(nearbycrates, function(actor)

					-- do i really need to do this for distance
					local from = unit[1].Location;
					local to = actor.Location;					
					local dist = math.sqrt((from.X - to.X) ^ 2 + (from.Y - to.Y) ^ 2)
					
					DisplayMessage(actor.Type .. " - distance:" .. tostring(dist))
					
					
				end)
			end)
		end
		
	end)
	-- *end ai behavior*
	
	if player.InternalName ~= "Hunter0" then
		Trigger.OnProduction(spawner, UnitWasProduced)
		if player.IsLocalPlayer then
			Camera.Position = spawnpoint.CenterPosition
		end
	end
end

-- todo: ensure people don't get the same spawn (may not matter since we cloak units)
ChooseRandomSpawnPoint = function()
	local spawnpoint = Utils.Random(SpawnPoints)
	return spawnpoint
end

-- todo: not sure if players see a spawning unit as uncloaked before they appear
UnitWasProduced = function(spawner, unit)
	Trigger.OnKilled(unit, function() UnitWasKilled(unit) end)
	spawner.Destroy()
	
	-- grant then remove stealth upgrade after 15sec
	unit.GrantUpgrade("spawnstealth")
	Trigger.AfterDelay(DateTime.Seconds(15), function() unit.RevokeUpgrade("spawnstealth") end)
		
	-- AI behavior only
	-- if unit.InternalName == "Hunter0" then
		-- DisplayMessage("Hunter0 is beginning to move around...")
		-- unit.Hunt()
	-- end
end

UnitWasKilled = function(unit)
	SpawnPlayer(unit.Owner)
end

DisplayMessage = function(message)
	Media.DisplayMessage(message, "SS")
end

-- phony scoreboard stuff
DrawScoreboard = function()
	-- amazing hacks for 1024x768 scoreboard!
	local scoreboard = "Players" .. RepeatString(" ", 225)
	
	Utils.Do(Players, function(player)	
		scoreboard = scoreboard .. "\n" .. player.Name
	end)
	
	UserInterface.SetMissionText(scoreboard)
end

-- for some reason string.rep isn't a thing
RepeatString = function(str, amount)
	local ret = str
	for i=1, amount do
		ret = ret .. str
	end
	return ret
end