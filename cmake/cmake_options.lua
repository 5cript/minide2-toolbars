local json = require "json.lua/json"

local CmakeOptions = {
	loaded = false,
	content = {}
}

local function isempty(s)
  return s == nil or s == ''
end

function CmakeOptions:load(j)
	if (isempty(j)) then
		return
	end	
	self.content = json.decode()
end

function CmakeOptions:new(o)
	o = o or {}
	setmetatable(o, self)
	self.__index = self
	return o
end

return CmakeOptions