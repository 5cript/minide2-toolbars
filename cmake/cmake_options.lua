local json = require "json"

local CmakeOptions = {
	loaded = false,
	content = {},
	template = {
		file_version = 2,
		build_targets = {},
		active_target = -1
	},
	build_target_template = {
		environment = "#default",
		name = "Debug",
		cmake_arguments = "-G\"MSYS_Makefiles\"",
		lower_level_command = "make",
		lower_level_arguments = "-j12",
		build_directory = "./build/debug"
	}
}

local function isempty(s)
  return s == nil or s == ''
end

function CmakeOptions:load(j)
	if (isempty(j)) then
		return
	end	
	self.content = json.decode(j)
end

function CmakeOptions:get_json()
	return json.encode(self.content)
end

-- Patches missing values into the content
function CmakeOptions:patch()
	local anyPatch = false

	if (self.content.active_target == nil) then
		self.content.active_target = self.template.active_target
		anyPatch = true
	end
	if (self.content.build_targets == nil) then
		self.content.build_targets = self.template.build_targets
		anyPatch = true
	end
	if (self.content.file_version == nil) then
		self.t.file_version = self.template.file_version
		anyPatch = true
	end
	
	return anyPatch
end

function CmakeOptions:get_template()
	return json.encode(self.template)
end

function CmakeOptions:new(o)
	o = o or {}
	setmetatable(o, self)
	self.__index = self
	return o
end

return CmakeOptions