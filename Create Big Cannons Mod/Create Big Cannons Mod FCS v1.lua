local reader = peripheral.find("blockReader")
local desiredPitch = 0 --Range = -30, 60
local desiredYaw = 180 --Range = -360, 360
local pitchAngleTolerance = 0.001 --2RPM = 0.000002
local yawAngleTolerance = 0.001 --4RPM = 00002
local lastPitch = 0
local lastYaw = 0

--Projectile
local initialVelocity = 8.0 --m/s
local gravity = 0.05 --m/tick^2
local inertia = 0.99 --multiplier
local inertiaLn = math.log(inertia)
local gravityInertia = gravity * inertia

--Cannon Positions
local cannonPivotX = -276.5
local cannonPivotY = 60.5
local cannonPivotZ = -28.5

local cannonExitX = -276.5
local cannonExitY = 59.75 --Seems like there's a -0.75 offset
local cannonExitZ = -44.5 --Also seems like it has other offsets, needs more testing

--Target Position
local targetX = -153
local targetY = 46
local targetZ = -271

-- Cannon Offsets
local cannonOffsetLength = 0.0
local cannonOffsetHeight = 0.0
local cannonYawOffset = 0.0

--[[
function toAngles(vStart, vEnd)
  local deltaVector = vEnd - vStart
  local len = math.sqrt(deltaVector.x * deltaVector.x + deltaVector.z * deltaVector.z)
  local x = math.deg(math.atan2(deltaVector.y, len))
  local y = math.deg(math.atan2(-deltaVector.x, deltaVector.z))
  return vector.new(x, y, 0.0)
end
]]--

function calculateSignal(delta)
  return math.min(math.max(math.ceil(math.log10(delta) / math.log10(0.5)), 1), 15)
end

function normalizeAngle(angle)
  local returnAngle = math.fmod(angle, 360)
  if returnAngle > 180.0 then
    returnAngle = returnAngle - 360.0
  elseif returnAngle < -180.0 then
    returnAngle = returnAngle + 360.0
  end
  return returnAngle
end

function wolframGetTimeGivenX(x, offsetX, initialVelX)
  return math.log((x - offsetX) * inertiaLn / initialVelX + 1.0) / inertiaLn
end

function wolframGetYDelta(ticks, initialVelY)
	local powedInertia = inertia ^ ticks
	return ((gravityInertia * (1.0 - powedInertia + ticks * inertiaLn)) / (inertia - 1.0) + (powedInertia - 1.0) * initialVelY) / inertiaLn
end

function simulateRound(launchAngleRads, distance)
  local launchCos = math.cos(launchAngleRads)
	local launchSin = math.sin(launchAngleRads)
	local initialVelX = initialVelocity * launchCos
	local initialVelY = initialVelocity * launchSin
	local offsetX = cannonOffsetLength * launchCos - cannonOffsetHeight * launchSin
	local offsetY = cannonOffsetLength * launchSin + cannonOffsetHeight * launchCos
	local currentTime = wolframGetTimeGivenX(distance, offsetX, initialVelX)
	return offsetY + wolframGetYDelta(currentTime, initialVelY)
end

function calculateArcAngle(v, d, h)
  local returnAngle = math.atan2(
    (v * v) - math.sqrt(
      (v * v * v * v)
      -
      gravity * (gravity * (d * d) + h * (v * v) * 2.0)
    ),
    gravity * d
  )
  return returnAngle
end

function calculateYaw(startX, startZ, endX, endZ)
  return math.deg(math.atan2(startX - endX, endZ - startZ))
end

--https://www.desmos.com/calculator/1ttos7ukya
function calculatePitch()
  local cannonDeltaX = cannonExitX - cannonPivotX
  local cannonDeltaZ = cannonExitZ - cannonPivotZ

  cannonOffsetLength = math.sqrt(cannonDeltaX * cannonDeltaX + cannonDeltaZ * cannonDeltaZ)
  cannonOffsetHeight = cannonExitY - cannonPivotY

  --Simulation
  local deltaX = targetX - cannonPivotX
  local deltaZ = targetZ - cannonPivotZ
  local distance = math.sqrt(deltaX * deltaX + deltaZ * deltaZ)
  local height = targetY - cannonPivotY
  print("Distance:", distance, "Height:", height)

  --Setup Initial Guess
  local launchAngleRads = calculateArcAngle(initialVelocity, distance, height)
  local currentYPos = simulateRound(launchAngleRads, distance)
  local currentYDelta = height - currentYPos
	local prevYDelta = currentYDelta + 1.0
  local newHeight = height + currentYDelta

  local iterations = 0
  while math.abs(currentYDelta - prevYDelta) > 6e-14 do
    launchAngleRads = calculateArcAngle(initialVelocity, distance, newHeight)
    if launchAngleRads ~= launchAngleRads then
      return nil
    end

    prevYDelta = currentYDelta
		currentYPos = simulateRound(launchAngleRads, distance)
		currentYDelta = height - currentYPos
		newHeight = newHeight + currentYDelta

		iterations = iterations + 1
    print(iterations, math.abs(currentYDelta - prevYDelta))
  end

  return math.deg(launchAngleRads)
end

--Actual Main Function
redstone.setAnalogOutput("top", 0)
redstone.setAnalogOutput("bottom", 0)
redstone.setAnalogOutput("left", 0)
redstone.setAnalogOutput("right", 0)

desiredPitch = calculatePitch()
desiredYaw = normalizeAngle(calculateYaw(cannonPivotX, cannonPivotZ, targetX, targetZ) + cannonYawOffset)
print("Pitch:", desiredPitch, "Yaw:", desiredYaw)
sleep(1)

--Cannon Aiming
if desiredPitch ~= nil and desiredYaw ~= nil and desiredPitch > -30.0 and desiredPitch < 60.0 then
  while true do
    local blockData = reader.getBlockData()
    local cannonPitch = blockData["CannonPitch"]
    local cannonYaw = blockData["CannonYaw"]

    local pitchDelta = normalizeAngle(normalizeAngle(desiredPitch) - normalizeAngle(cannonPitch))
    local absPitchDelta = math.abs(pitchDelta)
    if absPitchDelta > pitchAngleTolerance then
      local signalStrength = calculateSignal(absPitchDelta / 8.0)
      redstone.setAnalogOutput("top", signalStrength)

      if pitchDelta < 0.0 then
        redstone.setAnalogOutput("bottom", 1)
      else
        redstone.setAnalogOutput("bottom", 0)
      end

      if signalStrength == 15 and absPitchDelta < pitchAngleTolerance * 10 then
        sleep(0.2)
        redstone.setAnalogOutput("top", 0)
        sleep(0.2)
      end
    else
      redstone.setAnalogOutput("top", 0)
      redstone.setAnalogOutput("bottom", 0)
    end

    local yawDelta = normalizeAngle(normalizeAngle(desiredYaw) - normalizeAngle(cannonYaw))
    local absYawDelta = math.abs(yawDelta)
    if absYawDelta > yawAngleTolerance then
      local signalStrength = calculateSignal(absYawDelta / 8.0)
      redstone.setAnalogOutput("left", signalStrength)

      if yawDelta < 0.0 then
        redstone.setAnalogOutput("right", 1)
      else
        redstone.setAnalogOutput("right", 0)
      end

      if signalStrength == 15 and absYawDelta < yawAngleTolerance * 10 then
        sleep(0.2)
        redstone.setAnalogOutput("left", 0)
        sleep(0.2)
      end
    else
      redstone.setAnalogOutput("left", 0)
      redstone.setAnalogOutput("right", 0)
    end

    print(pitchDelta, yawDelta, cannonPitch - lastPitch, cannonYaw - lastYaw)
    --[[
    if absPitchDelta <= pitchAngleTolerance and absYawDelta <= yawAngleTolerance then
      break
    end
    ]]--

    --Store last variables
    lastPitch = cannonPitch
    lastYaw = cannonYaw
  end
else
  print("Out of range!")
end