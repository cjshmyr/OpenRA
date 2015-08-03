-- Player vars
Players = { }
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
	{ "WAVEUNIT", 5 },
	{ "WAVEUNIT", 10 }
}
WaveInProgress = false

WorldLoaded = function()
	DisplayMessage("hamb's TD Test!")
		
	local player1 = Player.GetPlayer("Multi0")
	local player2 = Player.GetPlayer("Multi1")
	local player3 = Player.GetPlayer("Multi2")
	local player4 = Player.GetPlayer("Multi3")
	
	if player1 then Players[#Players + 1] = 1 end
	if player2 then Players[#Players + 1] = 2 end
	if player3 then Players[#Players + 1] = 3 end
	if player4 then Players[#Players + 1] = 4 end
	
	DisplayMessage("Starting game in 2 seconds!")
	Trigger.AfterDelay(2 * 25, StartGame)
	
	
	Trigger.OnKilled(DefendMe, GameOver)
	
	-- HSLColor.New(0, 255, 128)
	-- TODO: Get floatingtext to work!
end

StartGame = function()
	DisplayMessage("Game is now started!")	
	AdvanceWave()
end

GameOver = function()
	DisplayMessage("Game over!")
end

Tick = function()
	
end

-- Wave functions
AdvanceWave = function()
	DisplayMessage("Wave starting")
	
	CurrentWave = CurrentWave + 1
	local wave = Waves[CurrentWave]
	local unitType = wave[1]
	local amount = wave[2]
	
	-- create an array of units to spawn
	local waveUnits = { }	
	for i = 1, amount do
		waveUnits[#waveUnits + 1] = unitType
	end
	
	-- spawn 'em and move 'em
	local n = 0
	local spawnInterval = 25
	Utils.Do(waveUnits, 
		function(unitType)		
			local a = Actor.Create(unitType, false, { Owner = Creeps, Location = a_Spawner1.Location })
			Trigger.AfterDelay(n * spawnInterval, function() MoveWaveUnit(a) end)		
			n = n + 1
		end
	)
end

MoveWaveUnit = function(unit)
	unit.IsInWorld = true
	local waypoints = Player1WavePath -- Assume player 1 for now
	for i, waypoint in ipairs(waypoints) do
		unit.Move(waypoint.Location, 2)
	end	
	unit.Attack(DefendMe)
end

-- Helpers
DisplayMessage = function(message)
	Media.DisplayMessage(message, "TD")
end