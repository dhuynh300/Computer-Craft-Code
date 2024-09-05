-- Enforce labels
if not os.getComputerLabel() then
	print("Please set a label!")
	return
end

-- Create a startup program
local originFileName = "rom/chunkQuarry.lua"
local destFileName = "chunkQuarry-\"..os.getComputerLabel()..\".lua"
local file = fs.open("startup.lua", "w")
file.writeLine("-- Update our program with the one in ROM")
file.writeLine("local originFileName = \""..originFileName.."\"")
file.writeLine("local destFileName = \""..destFileName.."\"")
file.writeLine("fs.delete(destFileName)")
file.writeLine("fs.copy(originFileName, destFileName)")
file.writeLine("print(\"Startup: Updated lua.\")\n")
file.writeLine("-- Then run our program")
file.writeLine("print(\"Startup: Running program.\")")
file.write("shell.run(destFileName)")
file.close()
print("Done installing script and creating startup file!\nRunning Program...")
shell.run("startup.lua")