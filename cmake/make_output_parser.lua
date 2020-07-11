local lexer = require "pl.lexer";
local class = require "pl.class";

local MakeParser = class()

function is_upper(str)
	return string.byte(str) >= string.byte("A") and string.byte(str) <= string.byte("Z")
end

function MakeParser:parse_line(line)
	tokens = {}
	for t,v in lexer.scan(line) do 
		table.insert(tokens, {
			type = t,
			value = v
		})
	end
	local tokenCount = #tokens;
	local isWindowsDrivePath = false;
	local windowsDriveLetter = '';
	if (tokenCount > 2) then
		if (is_upper(tokens[1].value) and tokens[2].value == ":") then
			isWindowsDrivePath = true
			windowsDriveLetter = tokens[1].value
		end
	end
	
	local searchStart = 1;
	local path = ""
	if (isWindowsDrivePath) then
		searchStart = 3;
		path = windowsDriveLetter .. ":"
	end
	
	local firstColon = 0
	for i = searchStart,#tokens do
		if (tokens[i].value ~= ":") then
			path = path .. tokens[i].value
		else
			firstColon = i
			break
		end
	end
	
	local lineNumber = tokens[firstColon + 1].value;
	local column = tokens[firstColon + 3].value;
	local message = line:sub((path .. ":" .. tostring(lineNumber) .. ":" .. tostring(column) .. ":"):len() + 2, line:len())
	return {
		file = path,
		line = lineNumber,
		column = column,
		message = message
	}
end

return MakeParser