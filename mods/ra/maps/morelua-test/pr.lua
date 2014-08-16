WorldLoaded = function()
	Media.DisplayMessage("Demo of new Lua functions")	
	
	local mammoth = Map.NamedActor("mammoth")
	
	-- Actor.Type
	Media.DisplayMessage("(1/6) Type of mammoth tank nearby is: " .. mammoth.Type)
	
	-- Player.PlayerName
	Media.DisplayMessage("(2/6) The owner of this mammoth tank is: " .. mammoth.Owner.PlayerName)
	
	-- WRange + ActorsInCircle stuff
	Media.DisplayMessage("(3/6) WRANGE TESTS")
	
	--ctor (+range property)
	local range = WRange.New(5 * 1024)
	local range2 = WRange.New(2 * 1024)
	Media.DisplayMessage("Created a new range (5*1024): " .. tostring(range.Range))
	
	--add
	local added = range + range2
	Media.DisplayMessage("Addition (5*1024 + 2*1024): " .. tostring(added.Range))
	
	--sub
	local sub = range - range2
	Media.DisplayMessage("Subtraction (5*1024 - 2*1024): " .. tostring(sub.Range))

	--equals
	local range3 = WRange.New(5 * 1024)
	local range4 = WRange.New(10 * 1024)
	
	local equals1 = range == range3
	local equals2 = range == range4
	
	Media.DisplayMessage("Equality - (5*1024) == (5*1024): " ..tostring(equals1))
	Media.DisplayMessage("Equality - (5*1024) == (10*1024): " ..tostring(equals2))
	
	-- Guard
	local lighttank = Map.NamedActor("light")
	Media.DisplayMessage("(4/6) Telling the mammoth tank to guard the light tank")
	mammoth.Guard(lighttank)
	
	-- Map.NamedActor
	Media.DisplayMessage("(5/6) Destroying the medium tank, doing a Map.NamedActor check before and after")
	
	mediumtank = Map.NamedActor("medium")
	
	if mediumtank == nil then
		Media.DisplayMessage("failed test 5 a")
	else
		Media.DisplayMessage("PASS: medium tank is alive")
	end

	Trigger.AfterDelay(25 * 3, WaitTests)
end

WaitTests = function()

	-- Map.NamedActor part 2
	mediumtank.Destroy()
	-- wait some more so we can pick up on it being destroyed
	
	Trigger.AfterDelay(25 * 3, WaitTests2)
end	

WaitTests2 = function()
	mediumtank = Map.NamedActor("medium")
	
	if mediumtank == nil then
		Media.DisplayMessage("PASS: medium tank is destroyed")
	else
		Media.DisplayMessage("failed test 5 b")
	end

	-- ActorsInCircle
	local radius = WRange.New(7 * 1024)
	Media.DisplayMessage("(6/6) Finding actors in circle around the mammoth tank specifying radius (7*1024), should only be 4tnk and 1tnk")
	local searchOrigin = mammoth.CenterPosition
	local searchResult = Map.ActorsInCircle(searchOrigin, radius)
	
	for i, actor in ipairs(searchResult) do
		Media.DisplayMessage("actor found in circle: " .. tostring(actor.Type))
	end
end