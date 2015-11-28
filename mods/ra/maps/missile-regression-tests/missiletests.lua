WorldLoaded = function()
	DisplayMessage("Missile range tests")
	
	local testcamera = Map.NamedActor("testcamera")
	Camera.Position = testcamera.CenterPosition
	
	Trigger.AfterDelay(2 * 25, E3AirTests)	
	Trigger.AfterDelay(6 * 25, DDAirTests)
	Trigger.AfterDelay(10 * 25, E3GroundTests)
	Trigger.AfterDelay(14 * 25, MammothAirTests)
	Trigger.AfterDelay(18 * 25, CtnkGroundTests)
	Trigger.AfterDelay(22 * 25, E3AirFlybyTests)
	Trigger.AfterDelay(26 * 25, DDAirFlybyTests)
	Trigger.AfterDelay(30 * 25, DDSeaTests)
	Trigger.AfterDelay(34 * 25, MammothAirFlybyTests)

end

DisplayMessage = function(message)
	Media.DisplayMessage(message, "Missile Tests")
end

E3AirTests = function()
	DisplayMessage("E3->HELI tests starting")
	for i=1, 5 do RunTest(i) end
end

DDAirTests = function()
	DisplayMessage("DD->HELI tests starting")	
	for i=6, 10 do RunTest(i) end	
end

E3GroundTests = function()
	DisplayMessage("E3->1TNK tests starting")
	for i=11, 15 do	RunTest(i) end	
end

MammothAirTests = function()
	DisplayMessage("4TNK->TRAN tests starting")
	for i=16, 20 do	RunTest(i) end	
end

CtnkGroundTests = function()
	DisplayMessage("CTNK->2TNK tests starting")
	for i=21, 25 do	RunTest(i) end	
end

E3AirFlybyTests = function()
	DisplayMessage("E3->YAK flyby tests starting")
	for i=26, 27 do RunTest(i) end
end

DDAirFlybyTests = function()
	DisplayMessage("DD->YAK flyby tests starting")
	for i=28, 29 do RunTest(i) end
end

DDSeaTests = function()
	DisplayMessage("DD->SEA tests starting")
	for i=30, 37 do RunTest(i) end	
end

MammothAirFlybyTests = function()
	DisplayMessage("4TNK->YAK flyby tests starting")
	for i=38, 39 do RunTest(i) end
end

RunTest = function(testNumber)
	local attacker = Map.NamedActor("test" .. tostring(testNumber) .. "_attacker")
	local target = Map.NamedActor("test" .. tostring(testNumber) .. "_target")
	local wp = Map.NamedActor("test" .. tostring(testNumber) .. "_wp")
	local wp2 = Map.NamedActor("test" .. tostring(testNumber) .. "_wp2")
	target.Move(wp.Location)
	target.Move(wp2.Location)
	Trigger.AfterDelay(25, function() attacker.Attack(target) end)		
end