local libtoolbar = require "libtoolbar"
local images = require "images"
local CmakeOptions = require "cmake_options"
local json = require "json"

local options_file_name = "cmake.json"

Cmake = {
	items = {}
}

local function isempty(s)
  return s == nil or s == ''
end

-- Returns error string,  or nil
function Cmake:setup_options() 
	if (not self.project_control:has_active_project()) then
		return "$NoSelectedActiveProject"
	end
	if (not self.project_control:has_meta_directory()) then
		if (not self.project_control:create_meta_directory()) then
			return "$CreatingMetaDirectoryFailed"
		end
	end
	return nil
end

function Cmake:load_options()
	if (not self.options.loaded) then
		self.project_control:update()
		local setup_result = self:setup_options();
		-- No error? Continue then
		if (isempty(setup_result)) then
			local content = self.project_control:read_project_file(options_file_name);
			-- Load options if existing
			if (not isempty(content)) then
				self.options:load(content)
				if (self.options:patch()) then
					local result = self.project_control:save_project_file(options_file_name, self.options:get_template())
					if (result ~= 0) then
						self.streamer:send_error("could not save project file template", ErrorTypes.io, "")
					end
					-- TODO! Send error on stream if patched file could not be saved
				end
			else
				local result = self.project_control:save_project_file(options_file_name, self.options:get_template())
				if (result ~= 0) then
					self.streamer:send_error("could not save project file", ErrorTypes.io, "")
				end
			end
		end
		return setup_result
	end
	return nil
end

function Cmake:save_options()
	local setup_result = self:setup_options();
	if (isempty(setup_result)) then
		self.project_control:save_project_file(options_file_name, self.options:get_json())
	end
	return setup_result
end

function Cmake:run_cmake()
	self:load_options()
	self.streamer:send_info("run CMake", "")
	print("run CMake")
end

function Cmake:build()
	print("build");
end

function Cmake:build_run()
	self:build();
	self:run();
end

function Cmake:run()
	print("run");
end

function Cmake:cancel()
	print("cancel");
end

function Cmake::show_settings()
	self.streamer:remote_call("showSettings", json.encode({
		options_file_name = options_file_name
	}))
end

function Cmake:init()
	self.name = "CMake C/C++";
	self.id = "cmake_toolbar";
	libtoolbar.push_item
	(
		self,
		{
			id = "menu",
			type = "Menu",
			entries = 
			{
				{
					label = "save",
					pngbase64 = images.save,
					special_actions = {"save"}
				},
				{
					is_splitter = true
				},
				{
					label = "settings",
					action = function() Cmake.show_settings(self) end					
				}
			}
		}
	)
	libtoolbar.push_splitter
	(
		self
	)
	libtoolbar.push_item
	(
		self,
		{
			id = "save",
			special_actions = {"save"},
			type = "IconButton",
			pngbase64 = images.save
		}
	)
	libtoolbar.push_item
	(
		self,
		{
			id = "saveAll",
			special_actions = {"saveAll"},
			type = "IconButton",
			pngbase64 = images.save_all
		}
	)
	libtoolbar.push_splitter
	(
		self
	)
	libtoolbar.push_item
	(
		self,
		{
			id = "runCMake",
			action = function() Cmake.run_cmake(self) end,
			type = "IconButton",
			pngbase64 = images.cmake
		}
	)
	libtoolbar.push_item
	(
		self,
		{
			id = "build",
			action = function() Cmake.build(self) end,
			type = "IconButton",
			pngbase64 = images.build
		}
	)
	libtoolbar.push_item
	(
		self,
		{
			id = "buildAndRun",
			action = function() Cmake.build_run(self) end,
			type = "IconButton",
			pngbase64 = images.build_run
		}
	)
	libtoolbar.push_item
	(
		self,
		{
			id = "run",
			action = function() Cmake.run(self) end,
			type = "IconButton",
			pngbase64 = images.run
		}
	)
	libtoolbar.push_item
	(
		self,
		{
			id = "cancel",
			action = function() Cmake.cancel(self) end,
			type = "IconButton",
			pngbase64 = images.cancel
		}
	)
	libtoolbar.push_splitter
	(
		self
	)
	libtoolbar.push_item
	(
		self,
		{
			id = "debug",
			special_actions = {"cpp_debug"},
			type = "IconButton",
			pngbase64 = images.debug
		}
	)
	libtoolbar.push_item
	(
		self,
		{
			id = "nextLine",
			special_actions = {"cpp_debug_next_line"},
			type = "IconButton",
			pngbase64 = images.next_line
		}
	)
	libtoolbar.push_item
	(
		self,
		{
			id = "stepInto",
			special_actions = {"cpp_debug_step_into"},
			type = "IconButton",
			pngbase64 = images.step_into
		}
	)
	libtoolbar.push_item
	(
		self,
		{
			id = "stepOut",
			special_actions = {"cpp_debug_step_out"},
			type = "IconButton",
			pngbase64 = images.step_out
		}
	)
	libtoolbar.push_splitter
	(
		self
	)
	libtoolbar.push_item
	(
		self,
		{
			id = "buildProfile",
			type = "ComboBox",
		}
	)
	self.project_control = ProjectControl:new()
	self.options = CmakeOptions:new()
	self.streamer = Streamer:new()
end

function Cmake:callAction(id)
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

function Cmake:new(o)
	o = o or {}
	setmetatable(o, self)
	self.__index = self
	o:init()
	return o
end

return Cmake