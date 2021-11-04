local Cmake = require "cmake"

local cmake = {}

function make_toolbar()
	cmake = Cmake:new()
	return cmake
end

function get_toolbar()
	return cmake
end