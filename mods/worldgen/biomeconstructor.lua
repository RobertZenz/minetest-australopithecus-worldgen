--[[
Copyright (c) 2015, Robert 'Bobby' Zenz
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

* Redistributions of source code must retain the above copyright notice, this
  list of conditions and the following disclaimer.

* Redistributions in binary form must reproduce the above copyright notice,
  this list of conditions and the following disclaimer in the documentation
  and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
--]]


BiomeConstructor = {}


function BiomeConstructor:new(name)
	local instance = {
		fits = nil,
		name = name,
		noises = List:new(),
		nodes = List:new(),
		params = List:new(),
	}
	
	setmetatable(instance, self)
	self.__index = self
	
	return instance
end


function BiomeConstructor:add_param(name, value)
	self.params:add({
		name = name,
		value = value
	})
end

function BiomeConstructor:require_node(name, node_name)
	self.nodes:add({
		name = name,
		node_name = node_name
	})
end

function BiomeConstructor:require_noise2d(name, octaves, persistence, scale, spreadx, spready, flags)
	self.noises:add({
		name = name,
		type = "2D",
		octaves = octaves,
		persistence = persistence,
		scale = scale,
		spreadx = spreadx,
		spready = spready,
		flags = flags
	})
end
		
function BiomeConstructor:require_noise3d(name, octaves, persistence, scale, spreadx, spready, spreadz, flags)
	self.noises:add({
		name = name,
		type = "3D",
		octaves = octaves,
		persistence = persistence,
		scale = scale,
		spreadx = spreadx,
		spready = spready,
		spreadz = spreadz,
		flags = flags
	})
end

function BiomeConstructor:set_fits(fits_function)
	self.fits = fits_function
end

