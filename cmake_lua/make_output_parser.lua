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
	
	local tokenOffset = 1
	local isWindowsDrivePath = false;
	local windowsDriveLetter = '';
	for i=1,#tokens do
		if tokens[i].value == "/" or tokens[i].value == "\\" then
			break;
		end
		tokenOffset = tokenOffset + 1;
	end
	if (tokenOffset > 2) then
		if (tokens[tokenOffset - 1].value == ":" and is_upper(tokens[tokenOffset - 2].value)) then
			isWindowsDrivePath = true
			windowsDriveLetter = tokens[tokenOffset - 2].value
		end		
	end
	if (tokenOffset >= #tokens) then
		return nil;
	end
	
	local searchStart = tokenOffset;
	local path = ""
	if (isWindowsDrivePath) then
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
	
	local lineNumber = nil;
	if firstColon + 1 < #tokens then
		lineNumber = tonumber(tokens[firstColon + 1].value)
	end
	
	local column = nil;
	if (lineNumber ~= nil) then
		if firstColon + 3 <= #tokens and tokens[firstColon + 3].value then
			column = tonumber(tokens[firstColon + 3].value)
		end
	end
	local message = ""
	local messageStart = firstColon + 1
	if (lineNumber ~= nil) then
		messageStart = messageStart + 2
	end
	if (column ~= nil) then
		messageStart = messageStart + 2
	end
	
	for i = messageStart,#tokens do
		message = message .. tokens[i].value .. " "
	end
	
	if (column == nil) then
		column = 0
	end
	if (lineNumber == nil) then
		lineNumber = 0
	end
	
	--[[
	print("------------")
	print(line)
	print(path)
	print(lineNumber)
	print(column)
	print(message)
	print("------------")
	]]--
	
	return {
		file = path,
		line = lineNumber,
		column = column,
		message = message
	}
end

return MakeParser