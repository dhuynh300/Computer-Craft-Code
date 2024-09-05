-- Peripherals
local reader = peripheral.wrap("blockReader_1")
local pitchMotor = peripheral.wrap("right")
local yawMotor = peripheral.wrap("left")

-- Reloading
local timeSinceLastReload = 0

-- Angles
local desiredPitch = 0.0 -- Range = -30, 60
local desiredYaw = 0.0 -- Range = -360, 360
local reductions = 4-- 1 reduction is half the speed, 2 is 1/4, etc.
local inputRPM = 256
local degMul = 8 * 2 ^ reductions -- Input degrees to cannon degrees multiplier
local precision = 1.0 / degMul -- The smallest angle adjustment that can be made
local degPerSec = inputRPM / 60.0 * 360.0 / degMul
local secPerDeg = 1.0 / degPerSec

-- Cannon Positions
local cannonPivotX = 0.0
local cannonPivotY = 0.0
local cannonPivotZ = 0.0

local cannonExitX = 0.0
local cannonExitY = 0.0
local cannonExitZ = 0.0

-- Cannon Offsets
local cannonOffsetLength = 0.0
local cannonOffsetHeight = 0.0
local cannonYawOffset = 0.0

-- Functions
function normalizeAngle(angle)
  local returnAngle = math.fmod(angle, 360.0)

  if returnAngle > 180.0 then
    returnAngle = returnAngle - 360.0
  elseif returnAngle < -180.0 then
    returnAngle = returnAngle + 360.0
  end

  return returnAngle
end

function toAngles(vecStart, vecEnd)
  local deltaVector = vecEnd - vecStart
  local len = math.sqrt(deltaVector.x * deltaVector.x + deltaVector.z * deltaVector.z)
  local pitch = math.deg(math.atan2(deltaVector.y, len))
  local yaw = math.deg(math.atan2(-deltaVector.x, deltaVector.z))
  return pitch, yaw
end

-- ========================================  Actual Main Function ======================================== --

-- Locate cannon pivot position relative to computer position using GPS (remember +0.5 for center of block)
local computerX, computerY, computerZ = gps.locate()
cannonPivotX = computerX + 0.5
cannonPivotY = computerY + 3.5
cannonPivotZ = computerZ + 8.5

-- Testing
desiredPitch, desiredYaw = toAngles(vector.new(cannonPivotX, cannonPivotY, cannonPivotZ), vector.new(45.5, 80.5, 153.5))
desiredPitch = 6.455799999
desiredYaw = 6.185254916

-- Notify user of cannon specs
print("Cannon XYZ:", cannonPivotX, cannonPivotY, cannonPivotZ)
print("Cannon Precision:", precision, "degrees\n")
print("desiredPitch, desiredYaw:", desiredPitch, desiredYaw)
sleep(1)

-- Main loop
while true do
  local blockData = reader.getBlockData()
  timeSinceLastReload = timeSinceLastReload + 1
  rs.setOutput("bottom", false)

  -- Output
  if not pitchMotor.isRunning() and not yawMotor.isRunning() then
    if timeSinceLastReload >= 70 then
      timeSinceLastReload = 0
      rs.setOutput("bottom", true)
    end
  end


  -- Kinematics
  local cannonPitch = blockData["CannonPitch"]
  local cannonYaw = blockData["CannonYaw"]

  local pitchDelta = normalizeAngle(normalizeAngle(desiredPitch) - normalizeAngle(cannonPitch))
  local absPitchDelta = math.abs(pitchDelta)

  local yawDelta = normalizeAngle(normalizeAngle(desiredYaw) - normalizeAngle(cannonYaw))
  local absYawDelta = math.abs(yawDelta)

  if not pitchMotor.isRunning() and not yawMotor.isRunning() then
    print(pitchDelta, yawDelta)
  end

  if not pitchMotor.isRunning() then
    if absPitchDelta >= precision * 2 then
      local cannonPitchRotate = absPitchDelta * degMul
      if pitchDelta > 0 then
        pitchMotor.rotate(cannonPitchRotate, 2)
      else
        pitchMotor.rotate(cannonPitchRotate, -2)
      end
    elseif absPitchDelta > precision then
      if pitchDelta > 0 then
        pitchMotor.rotate(1, 1)
      else
        pitchMotor.rotate(1, -1)
      end
      sleep(0.5) -- Create mod has an anti-spam system for changing directions
    end
  end

  if not yawMotor.isRunning() then
    if absYawDelta >= precision * 2 then
      local cannonYawRotate = absYawDelta * degMul
      if yawDelta > 0 then
        yawMotor.rotate(cannonYawRotate, 2)
      else
        yawMotor.rotate(cannonYawRotate, -2)
      end
      print(cannonYawRotate)
    elseif absYawDelta > precision then
      if yawDelta > 0 then
        yawMotor.rotate(1, 1)
      else
        yawMotor.rotate(1, -1)
      end
      sleep(0.5) -- Create mod has an anti-spam system for changing directions
    end
  end
end