local libtoolbar = require "libtoolbar"
local images = require "images"

Interface = {
	items = {}
}

function Interface:runCMake()
	print("run CMake");
end

function Interface:init()
	self.name = "CMake C/C++";
	libtoolbar.push_special_action_button
	(
		self,
		"save",
		"save",
		images.save
	)
	libtoolbar.push_special_action_button
	(
		self,
		"saveAll",
		"saveAll",
		images.saveAll
	)
	libtoolbar.push_splitter
	(
		self
	)
	libtoolbar.push_button
	(
		self,
		"runCMake",
		Interface.runCMake,
		images.cmake
	)
	libtoolbar.push_button
	(
		self,
		"build",
		Interface.build,
		images.cmake
	)
	libtoolbar.push_button
	(
		self,
		"run",
		Interface.run,
		images.run
	)
	libtoolbar.push_button
	(
		self,
		"buildAndRun",
		Interface.buildAndRun,
		images.build
	)
	libtoolbar.push_button
	(
		self,
		"buildAndRun",
		Interface.buildAndRun,
		images.build_run
	)
	libtoolbar.push_button
	(
		self,
		"cancel",
		Interface.cancel,
		images.cancel
	)
	libtoolbar.push_splitter
	(
		self
	)
	libtoolbar.push_special_action_button
	(
		self,
		"debug",
		"cpp_debug",
		images.debug
	)
	libtoolbar.push_special_action_button
	(
		self,
		"nextLine",
		"cpp_debug_next_line",
		images.next_line
	)
	libtoolbar.push_special_action_button
	(
		self,
		"stepInto",
		"cpp_debug_step_into",
		images.step_into
	)
	libtoolbar.push_special_action_button
	(
		self,
		"stepOut",
		"cpp_debug_step_out",
		images.step_out
	)
end

function Interface:callAction(id)
	local anyFound = false
	for	_, item in pairs(self.items) do
		if (item.id == id) then
			anyFound = true
			item.action()
			break
		end
	end
	if (not anyFound) then
		print("not found")
	end
end

function Interface:new(o)
	o = o or {}
	setmetatable(o, self)
	self.__index = self
	o:init()
	return o
end

return Interface