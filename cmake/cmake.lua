local libtoolbar = require "libtoolbar"
local images = require "images"
local CmakeOptions = require "cmake_options"
local json = require "json"
local MakeParser = require "make_output_parser"

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
					self.streamer:send_info("saving patched settings file", "")
					local result = self.project_control:save_project_file
					(
						options_file_name, 
						self.options:get_template()
					)
					if (result ~= 0) then
						self.streamer:send_error("could not save project file template", ErrorTypes.io, "")
					end
					-- TODO! Send error on stream if patched file could not be saved
				end
			else
				self.streamer:send_warning("Saving template to file", json.encode({
					content = content
				}))
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

function Cmake:load_profiles(comboboxId)
	local result = self:load_options()
	local data = {
		targets = self.options.content.build_targets,
		toolbarId = self.id,
		itemId = comboboxId
	}
	if (isempty(result) or data == nil) then
		data.empty = true
	end
	self.streamer:remote_call("setComboboxData", json.encode(data))
end

function Cmake:pre_execution_work()
	self:load_options()
	
	if (isempty(self.build_target)) then
		self.streamer:send_error("No build target selected", ErrorTypes.precondition, "")
		return false
	end
	
	local project_directory = self.project_control:get_project_directory()
	if (isempty(project_directory)) then
		self.streamer:send_error("Could not get active project directory", ErrorTypes.precondition, "")
		return false
	end
	
	local target = nil;
	for	_, targetIt in pairs(self.options.content.build_targets) do
		if (targetIt.name == self.build_target) then
			target = targetIt
			break
		end
	end
	if (target == nil) then
		self.streamer:send_error("target not found", ErrorTypes.precondition, "")
		return false
	end
	if (target.build_directory == nil) then
		self.streamer:send_error("target misses build directory ", ErrorTypes.precondition, "")
		return false
	end
	
	local env = self.settings_provider:environment(target.environment)
	
	local extraArgs = target.cmake_arguments
	if (extraArgs == nil) then
		extraArgs = ""
	end
	if (target.c_compiler ~= nil) then
		extraArgs = extraArgs .. " -DCMAKE_C_COMPILER=\"" .. target.c_compiler .. "\""
	end
	if (target.cpp_compiler ~= nil) then
		extraArgs = extraArgs .. " -DCMAKE_CXX_COMPILER=\"" .. target.cpp_compiler .. "\""
	end
	if (target.archiver ~= nil) then
		extraArgs = extraArgs .. " -DCMAKE_AR=\"" .. target.archiver .. "\""
	end
	if (target.lower_level_command ~= nil) then
		extraArgs = extraArgs .. " -DCMAKE_MAKE_PROGRAM=\"" .. target.lower_level_command .. "\""
	end
	
	return {
		project_directory = project_directory,
		target = target,
		env = env,
		extraArgs = extraArgs
	}
end

function Cmake:is_process_running(process)
	-- check if already running
	if (self[process] ~= nil) then
		local exitStatus = self[process]:try_get_exit_status()
		if (exitStatus == nil) then
			return "running"
		end
		return "ended"
	end
	return "no process"
end

function Cmake:run_cmake()		
	-- check if already running
	if (self.cmakeProcess ~= nil) then
		local exitStatus = self.cmakeProcess:try_get_exit_status()
		if (exitStatus == nil) then
			self.streamer:send_error("cmake is already/still running", ErrorTypes.precondition, "")	
			return false
		end
	end
	
	local prework = self:pre_execution_work()
	if (prework == false) then
		print("error prework")
		return
	end	
	
	self.streamer:remote_call("disableItem", json.encode({
		items = {"runCMake", "build", "run", "buildAndRun", "debug"}
	}))

	self:clearLog("cmake", OutputType.cmake)
	self.streamer:send_info("running CMake", "")
	self.cmakeProcess = Process:new()
	local err = self.cmakeProcess:execute
	(
		"cmake.exe " .. "-B" .. "\"./" .. prework.target.build_directory .. "\" " .. prework.extraArgs,
		prework.project_directory,
		prework.env,
		function (cout) 
			self.streamer:send_subprocess_stdout("cmake", cout, OutputType.cmake)
		end,
		function (cerr) 
			self.streamer:send_subprocess_stderr("cmake", cerr, OutputType.cmake)
		end,
		function (exitStatus)
			self.streamer:send_subprocess_info("cmake", json.encode({
				what = "processEnded",
				status = exitStatus
			}))
			self:actionCompleted("runCMake");
		end
	)
	print(err)
end

function Cmake:build()	
	local prework = self:pre_execution_work()
	if (prework == false) then
		print("error prework")
		return
	end	
	
	-- check if already running
	if (self.llProcess ~= nil) then
		local exitStatus = self.llProcess:try_get_exit_status()
		if (exitStatus == nil) then
			self.streamer:send_error
			(
				prework.target.lower_level_command .. " is already/still running", 
				ErrorTypes.precondition, 
				""
			)	
			return false
		end
	end
	
	self.streamer:remote_call("disableItem", json.encode({
		items = {"runCMake", "build", "run", "buildAndRun", "debug"}
	}))

	self:clearLog(prework.target.lower_level_command, OutputType.build)
	self.streamer:send_info("running " .. prework.target.lower_level_command, "")
	self.llProcess = Process:new()
	local err = self.llProcess:execute
	(
		prework.target.lower_level_command .. " " .. prework.target.lower_level_arguments,
		prework.project_directory .. "/" .. prework.target.build_directory,
		prework.env,
		function (cout) 
			self.streamer:send_subprocess_stdout(prework.target.lower_level_command, cout, OutputType.build)
		end,
		function (cerr) 
			self.streamer:send_subprocess_stderr(prework.target.lower_level_command, cerr, OutputType.build)
		end,
		function (exitStatus)
			self.streamer:send_subprocess_info(prework.target.lower_level_command, json.encode({
				what = "processEnded",
				status = exitStatus
			}))
			self:actionCompleted("build");
		end
	)
end

function Cmake:build_run()
	--self:build();
	--self:run();
end

function Cmake:clearLog(logName, type)
	local clearCommand = string.char(0x1b) .. "[2J"
	self.streamer:send_subprocess_stdout(logName, clearCommand, type)	
end

function Cmake:actionCompleted(itemId)
	self.streamer:remote_call("actionCompleted", json.encode({
		toolbarId = self.id,
		itemId = itemId
	}))
end
	

function Cmake:run()
	print("run")
	
	local prework = self:pre_execution_work()
	if (prework == false) then
		print("error prework")
		return
	end	
	
	if (prework.target.output_executable == nil) then
		self.streamer:send_error
		(
			"build target is missing output_executable parameter", 
			ErrorTypes.precondition, 
			""
		)	
		return
	end
	
	local runParams = ""
	if (prework.target.run_parameters ~= nil) then
		runParams = prework.target.run_parameters
	end
	
	
	local runDir = prework.project_directory 
	if (prework.target.execution_directory ~= nil) then
		runDir = runDir .. "/" .. prework.target.execution_directory
	end
	
	-- check if already running
	if (self.productProcess ~= nil) then
		local exitStatus = self.productProcess:try_get_exit_status()
		if (exitStatus == nil) then
			self.streamer:send_error
			(
				prework.target.output_executable .. " is already/still running", 
				ErrorTypes.precondition, 
				""
			)	
			return false
		end
	end
	
	self.streamer:remote_call("disableItem", json.encode({
		items = {"runCMake", "build", "run", "buildAndRun", "debug"}
	}))

	local runCommand = 
		prework.project_directory .. "/" ..
		prework.target.build_directory .. "/" ..
		prework.target.output_executable .. " " .. runParams
	;
	self:clearLog(prework.target.output_executable, OutputType.other)
	self.streamer:send_info("running " .. prework.target.output_executable, "")
	self.productProcess = Process:new()
	local err = self.productProcess:execute
	(
		runCommand,
		runDir,
		prework.env,
		function (cout) 
			self.streamer:send_subprocess_stdout(prework.target.output_executable, cout, OutputType.other)
		end,
		function (cerr) 
			self.streamer:send_subprocess_stderr(prework.target.output_executable, cerr, OutputType.other)
		end,
		function (exitStatus)
			self.streamer:send_subprocess_info(prework.target.output_executable, json.encode({
				what = "processEnded",
				status = exitStatus
			}))
			self:actionCompleted("run");
		end
	)
	if (err ~= 0) then
		self.streamer:send_subprocess_info(prework.target.output_executable, json.encode({
			what = "processStartFailure",
			error = err,
			command = runCommand
		}))
	end
end

function Cmake:cancel()
	print("cancel");
end

function Cmake:show_settings()
	self.streamer:remote_call("showProjectSettings", json.encode({
		settingsFile = options_file_name
	}))
end

function Cmake:on_log_double_click(name, line, lineContent)
	local parser = MakeParser()
	local result = parser:parse_line(lineContent);
	if (result == false or result == nil) then
		print("failed to parse log line")
	else
		self.project_control:open_file_at(result.file, result.line, result.column, result.message)
	end
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
					label = "$Save",
					pngbase64 = images.save,
					special_actions = {"save"}
				},
				{
					is_splitter = true
				},
				{
					label = "$ProjectSettings",
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
			pngbase64 = images.cmake,
			cancelable = true,
			disables = {"build", "buildAndRun", "run", "debug", "runCMake"}
		}
	)
	libtoolbar.push_item
	(
		self,
		{
			id = "build",
			action = function() Cmake.build(self) end,
			type = "IconButton",
			pngbase64 = images.build,
			cancelable = true,
			disables = {"build", "buildAndRun", "run", "debug", "runCMake"}
		}
	)
	libtoolbar.push_item
	(
		self,
		{
			id = "buildAndRun",
			action = function() Cmake.build_run(self) end,
			type = "IconButton",
			pngbase64 = images.build_run,
			cancelable = true,
			disables = {"build", "buildAndRun", "run", "debug", "runCMake"}
		}
	)
	libtoolbar.push_item
	(
		self,
		{
			id = "run",
			action = function() Cmake.run(self) end,
			type = "IconButton",
			pngbase64 = images.run,
			cancelable = true,
			disables = {"build", "buildAndRun", "run", "debug", "runCMake"}
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
			pngbase64 = images.debug,
			disables = {"build", "buildAndRun", "run", "debug", "runCMake"}
		}
	)
	libtoolbar.push_item
	(
		self,
		{
			id = "nextLine",
			special_actions = {"cpp_debug_next_line"},
			type = "IconButton",
			pngbase64 = images.next_line,
			disabled_by_default = true
		}
	)
	libtoolbar.push_item
	(
		self,
		{
			id = "stepInto",
			special_actions = {"cpp_debug_step_into"},
			type = "IconButton",
			pngbase64 = images.step_into,
			disabled_by_default = true
		}
	)
	libtoolbar.push_item
	(
		self,
		{
			id = "stepOut",
			special_actions = {"cpp_debug_step_out"},
			type = "IconButton",
			pngbase64 = images.step_out,
			disabled_by_default = true
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
			load = function() self:load_profiles("buildProfile") end
		}
	)
	self.project_control = ProjectControl:new()
	self.options = CmakeOptions:new()
	self.streamer = Streamer:new()
	self.settings_provider = SettingsProvider:new()
end

function Cmake:call_action(id)
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

function combox_select(id, value)
	if (id == "buildProfile") then
		Cmake.build_target = value
	end
	print(Cmake.build_target)
end

function Cmake:new(o)
	o = o or {}
	setmetatable(o, self)
	self.__index = self
	o:init()
	return o
end

return Cmake