-- TODO:
-- Swarm mode with RedNet, 4 turtles a chunk
-- Wireless mode
-- Reverse mode (mines to the left instead of the right)
-- Instead of doing 180 on next layer, try to math your way into using 90s instead (would be faster)
-- Compress and document functions
-- Check for chest, if not there then stop
-- Speed things up with turtle.back() (although you have to check for blocks)
-- Work in the nether

-- Smart Fast Mining Turtle Quarry v1 by
-- Local positioning offsets:
-- X = Front/Back
-- Y = Left/Right
-- xDir: 1 = Facing front, -1 = Facing back, 0 = Not going in that direction
-- yDir: 1 = Facing right, -1 = Facing left, 0 = Not going in that direction
-- NOTE: Z is height because source engine
local xOffset, yOffset, zOffset, xDir, yDir, lowestLayer = 0, 0, 0, 1, 0, 0
local xChestOffset, yChestOffset, zChestOffset = -1, 0, 0
local flipSides = false

-- User input
local oresOnly = false
local numSizeX = 16
local numSizeY = 16
local keepStoneDirtGravel = false
local layerOffset = 0

-- Save functions
function saveTable()
	local settingsTable = {}
	settingsTable.xOffset = xOffset
	settingsTable.yOffset = yOffset
	settingsTable.zOffset = zOffset
	settingsTable.xDir = xDir
	settingsTable.yDir = yDir
	settingsTable.oresOnly = oresOnly
	settingsTable.keepStoneDirtGravel = keepStoneDirtGravel
	settingsTable.numSizeX = numSizeX
	settingsTable.numSizeY = numSizeY
	settingsTable.layerOffset = layerOffset
	settingsTable.lowestLayer = lowestLayer
	settingsTable.xChestOffset = xChestOffset
	settingsTable.yChestOffset = yChestOffset
	settingsTable.zChestOffset = zChestOffset
	
	local file = fs.open("chunkQuarry.save", "w")
	file.write(textutils.serialize(settingsTable))
	file.close()
end

function loadTable()
	local file = fs.open("chunkQuarry.save", "r")
	local data = file.readAll()
	file.close()
	
	local settingsTable = {}
	settingsTable = textutils.unserialize(data)
	xOffset = settingsTable.xOffset
	yOffset = settingsTable.yOffset
	zOffset = settingsTable.zOffset
	xDir = settingsTable.xDir
	yDir = settingsTable.yDir
	oresOnly = settingsTable.oresOnly
	numSizeX = settingsTable.numSizeX
	numSizeY = settingsTable.numSizeY
	keepStoneDirtGravel = settingsTable.keepStoneDirtGravel
	layerOffset = settingsTable.layerOffset
	lowestLayer = settingsTable.lowestLayer
	xChestOffset = settingsTable.xChestOffset
	yChestOffset = settingsTable.yChestOffset
	zChestOffset = settingsTable.zChestOffset
end

-- Not really home but a chest
function goHome(keepFuel)
	gotoPos(0, 0, 0, 0, 0, false)
	gotoPos(xChestOffset, yChestOffset, zChestOffset + 1, 0, 0, true)
	depositItems(keepFuel)
end

-- Only call this after goHome()
function goBackToPos(x, y, z, xWantDir, yWantDir)
	gotoPos(0, 0, 0, 0, 0, false)
	gotoPos(x, y, z, xWantDir, yWantDir, true)
end

function fastSelect(slot)
	if turtle.getSelectedSlot() ~= slot then
		turtle.select(slot)
	end
end

-- Should be fixed
local disableFuelCheck = false
function checkFuel(disableGoHome)
	if disableFuelCheck then
		return true
	end
	
	-- Calculate distance to home plus a little bit to make sure we make it
	local totalDistanceToHome = (math.abs(xOffset) + math.abs(yOffset) + math.abs(zOffset)
		+ math.abs(xChestOffset) + math.abs(yChestOffset) + math.abs(zChestOffset)) + 1
	if turtle.getFuelLevel() <= totalDistanceToHome then
		print("Refueling.")
		for i = 1, 16 do
			if turtle.getItemCount(i) > 0 then
				fastSelect(i)
				
				if turtle.refuel() then
					print("Done refueling.")
					return true
				end
			end
		end
		
		print("Failed to Refuel.")
		if not disableGoHome then
			print("Going home.")
			disableFuelCheck = true
			goHome(false)
			disableFuelCheck = false
			print("Done going home.")
		end
		return false
	end
	
	return true
end

function depositItems(keepFuel)
	print("Depositing items.")
	for i = 1, 16 do
		if turtle.getItemCount(i) > 0 then
			fastSelect(i)
			
			if keepFuel and turtle.refuel(0) then
				print("Kept a slot of fuel.")
				keepFuel = false
			else
				turtle.dropDown()
			end
		end
	end
	print("Done depositing.")
end

function compressInventory()
	local compressedInventory = false
	for i = 1, 15 do
		if turtle.getItemSpace(i) > 0 then
			local data1 = turtle.getItemDetail(i)
			if data1 then
				for i2 = i + 1, 16 do
					local data2 = turtle.getItemDetail(i2)
					if data2 and data1.name == data2.name and turtle.compareTo(i2) then
						print("Compressing inventory.")
						compressedInventory = true
						
						fastSelect(i2)
						turtle.transferTo(i)
						if turtle.getItemSpace(i) <= 0 then
							break
						end
					end
				end
			end
		end
	end
	return compressedInventory
end

function inventoryFull()
	local slotsEmpty = 0
	for i = 1, 16 do
		if turtle.getItemCount(i) == 0 then
			slotsEmpty = slotsEmpty + 1
			if slotsEmpty > 1 then
				-- Exit if there's 2 or more empty slots
				return false
			end
		end
	end
	
	-- Else if there's less than 2 slots empty do stuff
	if compressInventory() and not inventoryFull() then
		return false
	end
	
	print("Slots are full.")
	return true
end

-- TODO : Ask user for blacklist
local blacklistedItems = {
	["minecraft:cobblestone"] = true,
	["minecraft:gravel"] = true,
	["minecraft:dirt"] = true,
	["minecraft:netherrack"] = true
}
local inventoryFullCount = 0
function checkInventory()
	if not inventoryFull() then
		return
	end
	
	if not keepStoneDirtGravel then
		if inventoryFullCount < 3 then
			print("Dropping blacklisted items.")
			for i = 1, 16 do
				local data = turtle.getItemDetail(i)
				if data and blacklistedItems[data.name] then
					fastSelect(i)
					turtle.dropDown()
				end
			end
			
			inventoryFullCount = inventoryFullCount + 1
			if not inventoryFull() then
				print("Done dropping blacklisted items.")
				return 
			else
				print("Failed to drop blacklisted items.")
			end
		else
			inventoryFullCount = 0
			print("Inventory counter exceeded.")
		end
	end
	
	print("Inventory is full, depositing.")
	local xOld, yOld, zOld, xDirOld, yDirOld = xOffset, yOffset, zOffset, xDir, yDir
	goHome(true)
	goBackToPos(xOld, yOld, zOld, xDirOld, yDirOld)
	print("Done depositing.")
end

-- This is the main reason why things are slow, couldn't find a faster detect method
function checkForOres()
	if oresOnly then
		local needCheckInventory = false
		local inspectSuccess, inspectData = turtle.inspectUp()
		if inspectSuccess and string.find(inspectData.name, "ore") then 
			turtle.digUp()
			needCheckInventory = true
		end
		
		inspectSuccess, inspectData = turtle.inspectDown()
		if inspectSuccess and string.find(inspectData.name, "ore") then 
			turtle.digDown()
			needCheckInventory = true
		end
		
		if needCheckInventory then
			checkInventory()
		end
	else
		turtle.digUp()
		turtle.digDown()
		checkInventory()
	end
end

-- Movement functions, dig if there's anything in our way
function tryTurn180()
	tryTurnRight()
	tryTurnRight()
end

function tryTurnLeft()
	turtle.turnLeft()
	local xDirOld, yDirOld = xDir, yDir
	
	xDir = yDirOld
	yDir = -xDirOld
	saveTable()
end

function tryTurnRight()
	turtle.turnRight()
	local xDirOld, yDirOld = xDir, yDir
	
	xDir = -yDirOld
	yDir = xDirOld
	saveTable()
end

function tryForward(dist)
	if not checkFuel(false) then
		return false
	end
	
	for i = 1, dist or 1 do
		while not turtle.forward() do
			if not turtle.dig() and turtle.detect() then
				print("Error going forward.")
				return false
			end
		end
		
		xOffset = xOffset + xDir
		yOffset = yOffset + yDir
		saveTable()
	end
end

function tryUp(dist)
	if not checkFuel(false) then
		return false
	end
	
	for i = 1, dist or 1 do
		while not turtle.up() do
			if not turtle.digUp() and turtle.detectUp() then
				print("Error going up.")
				return false
			end
		end
		
		zOffset = zOffset + 1
		saveTable()
	end
end

function tryDown(dist)
	if not checkFuel(false) then
		return false
	end
	
	for i = 1, dist or 1 do
		while not turtle.down() do
			if not turtle.digDown() and turtle.detectDown() then
				print("Error going down.")
				return false
			end
		end
		
		zOffset = zOffset - 1
		if zOffset < lowestLayer then
			lowestLayer = zOffset
		end
		saveTable()
	end
end

function rotateTo(xWantDir, yWantDir)
	if xDir == xWantDir and yDir == yWantDir then
		return
	end
	
	if xDir ~= 0 and xWantDir ~= 0 or yDir ~= 0 and yWantDir ~= 0 then
		tryTurn180()
		return
	end
	
	if xDir ~= 0 then
		if (yWantDir - xDir) == 0 then
			tryTurnRight()
		else
			tryTurnLeft()
		end
	else
		if (xWantDir - yDir) == 0 then
			tryTurnLeft()
		else
			tryTurnRight()
		end
	end
end

function gotoPosX(x)
	if xOffset > x then
		rotateTo(-1, 0)
		tryForward(math.abs(x - xOffset))
	elseif xOffset < x then
		rotateTo(1, 0)
		tryForward(math.abs(x - xOffset))
	end
end

function gotoPosY(y)
	if yOffset > y then		
		rotateTo(0, -1)
		tryForward(math.abs(y - yOffset))
	elseif yOffset < y then
		rotateTo(0, 1)
		tryForward(math.abs(y - yOffset))
	end
end

function gotoPosZ(z)
	if zOffset > z then
		tryDown(math.abs(z - zOffset))
	elseif zOffset < z then
		tryUp(math.abs(z - zOffset))
	end
end

function gotoPos(x, y, z, xWantDir, yWantDir, reverse)
	print("Moving to:", x, y, z, xWantDir, yWantDir)
	
	if reverse then
		gotoPosZ(z)
		gotoPosX(x)
		gotoPosY(y)
	else
		gotoPosY(y)
		gotoPosX(x)
		gotoPosZ(z)
	end
	
	if xWantDir ~= 0 or yWantDir ~= 0 then
		rotateTo(xWantDir, yWantDir)
	end
	print("Done moving to position.")
end

-- NOTE: Stupid LUA using 1 as starting index not 0
function getUserInput()
	print("Args:")
	print("<length> Length (front/back of the turtle) in whole numbers")
	print("<width> Width (left/right of the turtle) in whole numbers")
	print("<oresOnly> Discard stone, etc. 1 for yes, 0 for no")
	print("<layerOffset> How many layers multiplied by 3 to skip")
	
	local userInput = read()
	local tArgs = {}
	for v in userInput:gmatch("%w+") do
		table.insert(tArgs, tonumber(v))
	end
	
	if #tArgs > 0 then
		if #tArgs > 4 or tArgs[1] <= 0 or (#tArgs >= 2 and tArgs[2] <= 0) or
		(#tArgs >= 3 and tArgs[3] < 0) or (#tArgs >= 3 and tArgs[3] > 1) or (#tArgs >= 4 and tArgs[4] < 0) then
			term.clear()
			getUserInput()
		else
			numSizeX = math.floor(tArgs[1])
			if #tArgs >= 2 then
				numSizeY = math.floor(tArgs[2])
			else
				numSizeY = numSizeX
			end
			if #tArgs >= 3 then
				oresOnly = tArgs[3] == 1
			end
			if #tArgs >= 4 then
				layerOffset = math.floor(tArgs[4])
			end
		end
	end
	
	print("Enter chest offset (x y z). Z is up & down for turtle code, not Y.")
	userInput = read()
	tArgs = {}
	for v in userInput:gmatch("[%-%w]+") do
		table.insert(tArgs, tonumber(v))
	end
	
	if #tArgs == 3 then
		xChestOffset = tArgs[1]
		yChestOffset = tArgs[2]
		zChestOffset = tArgs[3]
	end
end

-- Main (Smart Fast Mining Turtle Quarry v1)
term.clear()
print("===Turtle Mining Quarry===")
if not os.getComputerLabel() then
	print("You have not set a label yet!")
	return
elseif not checkFuel(true) then
	print("Out of Fuel!")
	return
end

local createNewSave = true
if fs.exists("chunkQuarry.save") then
	print("Press any key in 5s to create new save.")
	parallel.waitForAny(
		function()
			local ev
			repeat
				ev = coroutine.yield()
			until ev == 'key'
		end,
		function()
			sleep(5)
			createNewSave = false
			print("Resuming from save.")
		end)
end

if createNewSave == true then
	getUserInput()
	saveTable()
	
	-- Move into position
	tryDown(layerOffset * 3 + 2)
else
	loadTable()
	goHome(true)
	goBackToPos(0, 0, lowestLayer, 1, 0)
end

print("Current settings:")
print("numSizeX:", numSizeX)
print("numSizeY:", numSizeY)
print("oresOnly:", oresOnly)
print("layerOffset:", layerOffset)
print("xChestOffset:", xChestOffset)
print("yChestOffset:", yChestOffset)
print("zChestOffset:", zChestOffset)

local currentNumSizeX = numSizeX
local currentNumSizeY = numSizeY
while true do
	print("Day", os.day(), textutils.formatTime(os.time(), true), "Fuel:", turtle.getFuelLevel())
	
	for i = 1, currentNumSizeY do
		for l = 2, currentNumSizeX do
			if not checkFuel(false) then
				print("Out of fuel.")
				return
			end
			
			checkForOres()
			tryForward()
		end
		
		checkForOres()
		if i ~= currentNumSizeY then
			if (i % 2 == 1) == flipSides then
				tryTurnLeft()
				tryForward()
				tryTurnLeft()
			else
				tryTurnRight()
				tryForward()
				tryTurnRight()
			end
		end
		
		-- Decrease this counter
		if inventoryFullCount > 0 then
			inventoryFullCount = inventoryFullCount - 1
		end
	end
	
	local inspectSuccess, inspectData = turtle.inspectDown()
	if inspectSuccess and inspectData.name == "minecraft:bedrock" then
		print("Found bedrock, returning home.")
		break
	end
	
	print("Moving to next layer.")
	tryDown(3)
	
	if xDir == 1 then
		if yOffset == 0 then
			tryTurnRight()
		else
			tryTurnLeft()
		end
	elseif xDir == -1 then
		if yOffset == 0 then
			tryTurnLeft()
		else
			tryTurnRight()
		end
	elseif yDir == 1 then
		if xOffset == 0 then
			tryTurnLeft()
		else
			tryTurnRight()
		end
	elseif yDir == -1 then
		if xOffset == 0 then
			tryTurnRight()
		else
			tryTurnLeft()
		end
	end
	
	if currentNumSizeY % 2 == 1 then
		flipSides = not flipSides
		print("Flip:", flipSides)
	end
	
	local tempNumSizeX = currentNumSizeX
	currentNumSizeX = currentNumSizeY
	currentNumSizeY = tempNumSizeX
end

goHome(false)
fs.delete("chunkQuarry.save")
fs.delete("startup.lua")
print("Completed Mining.")