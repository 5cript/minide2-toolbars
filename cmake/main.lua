local Interface = require "interface"

local face = {}

function make_interface()
	face = Interface:new()
	face:callAction("runCMake");
	return face.items
end

--[[
function runAction(id)
	print(id)
	
	local proc = Process.new();
	print(proc);
	proc:execute(
		"printenv", 
		".", 
		{
			PATH="D:/msys2/mingw64/bin;D:/msys2/usr/local/bin;D:/msys2/usr/bin;C:/Windows/System32;C:/Windows;C:/Windows/System32/Wbem;C:/Windows/System32/WindowsPowerShell/v1.0",
			SystemRoot="C:\\Windows",
			tmp="C:\\Windows\\Temp"
		},
		function(stdout)
			print(stdout);
		end,
		function(stderr)
			print(stderr)
		end
	)
	local status = proc:get_exit_status()
	print(status);
end
--]]