-- TODO: How can we make it clear what buildings have what upgrades?
-- TODO: There's a funny hack for the state machine below?

-- Player vars
Players = { }
Player1 = Player.GetPlayer("Multi0")
Player2 = Player.GetPlayer("Multi1")
Player3 = Player.GetPlayer("Multi2")
Player4 = Player.GetPlayer("Multi3")
Ally = Player.GetPlayer("Ally")
Creeps = Player.GetPlayer("Creeps")

-- Actor vars
Player1WavePath = { a_Spawner1, a_Path1, a_PathConverge, a_PathConverge2 }
Player2WavePath = { a_Spawner2, a_Path2, a_PathConverge, a_PathConverge2 }
Player3WavePath = { a_Spawner3, a_Path3, a_PathConverge, a_PathConverge2 }
Player4WavePath = { a_Spawner4, a_Path4, a_PathConverge, a_PathConverge2 }
DefendMe = a_DefendMe

-- Wave vars
CurrentWave = 0
Waves = 
{
	{ "WAVEUNIT", 2 },
	{ "WAVEUNIT", 2 }
}
WaveInProgress = false

WorldLoaded = function()
	DisplayMessage("hamb's TD Test!")
		
	if Player1 then Players[#Players + 1] = 1 end
	if Player2 then Players[#Players + 1] = 2 end
	if Player3 then Players[#Players + 1] = 3 end
	if Player4 then Players[#Players + 1] = 4 end
	
	Trigger.OnKilled(DefendMe, GameOver)
	
	DisplayMessage("Starting game in 2 seconds!")
	Trigger.AfterDelay(2 * 25, function() WaveInProgress = true	end)	
end

GameOver = function()
	DisplayMessage("Game over!")
end

AllWavesCleared = function()
	DisplayMessage("You win, hooray!")
end

Tick = function()
	if WaveInProgress and Creeps.HasNoRequiredUnits() then
	
		if CurrentWave > 0 then
			DisplayMessage("Wave " .. tostring(CurrentWave) .. " complete!")
		end
		
		WaveInProgress = false
		
		if CurrentWave == #Waves then
			DisplayMessage("You win! Yay!")
		else			
			AdvanceWave()
		end	
	end

	--NOTE: This will blow up when the game ends
	-- Media.FloatingText("hello", DefendMe.CenterPosition, 1)
	-- HSLColor.New(0, 255, 128)
end

-- Wave functions
AdvanceWave = function()
	CurrentWave = CurrentWave + 1
	
	DisplayMessage("Wave " .. tostring(CurrentWave) .. " starting!")
	
	local wave = Waves[CurrentWave]
	local unitType = wave[1]
	local amount = wave[2]
	
	-- create an array of units to spawn
	local waveUnits = { }	
	for i = 1, amount do
		waveUnits[#waveUnits + 1] = unitType
	end
	
	-- perform this for each player
	for i, playerN in ipairs(Players) do

		-- get player's waypoints
		local waypoints = _G["Player" .. tostring(playerN) .. "WavePath"]
		local spawner = waypoints[1] -- assume spawn is the first item in wave path
		
		-- spawn 'em and move 'em
		local n = 0
		local spawnInterval = 25
		Utils.Do(waveUnits, 
			function(unitType) 				
				local a = Actor.Create(unitType, false, { Owner = Creeps, Location = spawner.Location })
				
				Trigger.AfterDelay(n * spawnInterval, 
					function()
						a.IsInWorld = true;
						for i, waypoint in ipairs(waypoints) do
							a.Move(waypoint.Location, 2)
						end
						a.Attack(DefendMe)
					end					
				)
				n = n + 1
			end
		)
	end
	
	-- HACK: delay the state machine by a tick
	Trigger.AfterDelay(25, function() WaveInProgress = true end)
end

-- Helpers
DisplayMessage = function(message)
	Media.DisplayMessage(message, "TD")
end

-- Towers:
-- plug Vulcan - small AOE damage, can attack air
-- plug Rocket - AOE damage, cannot attack air
-- Tractor tower (aka Laser Tower) - tractor beam to slow units
--  (aka Nod SAM)
-- EMP - temorary disable
-- 