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


Biomes = {}


function Biomes:new(noise_manager, name)
	local instance = {
		constructors = List:new(),
		default_biome = nil,
		initialized = false,
		biomes = List:new(),
		name = name or "Biomes",
		noise_manager = noise_manager or NoiseManager:new(),
		persistent = {}
	}
	
	setmetatable(instance, self)
	self.__index = self
	
	return instance
end


function Biomes:constructor_to_module(constructor)
	local module = {
		condition = constructor.condition,
		fits = constructor.fits,
		name = constructor.name,
		nodes = {},
		noisemaps = {},
		noises = {},
		params = {}
	}
	
	constructor.nodes:foreach(function(node, index)
		module.nodes[node.name] = minetest.get_content_id(node.node_name)
		
		log.info(self.name .. ": Added node \"",
			node.node_name,
			"\" as \"",
			node.name,
			"\" with ID \"",
			module.nodes[node.name],
			"\".")
		
		if module.nodes[node.name] < 0 or module.nodes[node.name] == 127 then
			log.error(self.name .. ": Node \"" .. node.node_name .. "\" was not found.")
		end
	end)
	
	constructor.noises:foreach(function(noise_param, index)
		local noisemap = nil
		
		if noise_param.type == "2D" then
			noisemap = self.noise_manager:get_map2d(
				noise_param.octaves,
				noise_param.persistence,
				noise_param.scale,
				noise_param.spreadx,
				noise_param.spready,
				noise_param.flags
			)
		elseif noise_param.type == "3D" then
			noisemap = self.noise_manager:get_map3d(
				noise_param.octaves,
				noise_param.persistence,
				noise_param.scale,
				noise_param.spreadx,
				noise_param.spready,
				noise_param.spreadz,
				noise_param.flags
			)
		end
		
		module.noisemaps[noise_param.name] = {
			map = noisemap,
			type = noise_param.type
		}
	end)
	
	constructor.params:foreach(function(param, index)
		module.params[param.name] = param.value
	end)
	
	return module
end

function Biomes:get_biome(x, y, z, temperature, humidity, metadata)
	if not self.initialized then
		self:init()
	end
	
	local fitting_biome = self.default_biome
	
	local metadata = metadata or {}
	
	self.biomes:foreach(function(biome, index)
		if biome.fits(biome, metadata, x, y, z, temperature, humidity) then
			fitting_biome = biome
		end
	end)
	
	return fitting_biome
end

function Biomes:init()
	self.constructors:foreach(function(constructor, index)
		log.info(self.name .. ": Initializing module \"" .. constructor.name .. "\"")
		local module = self:constructor_to_module(constructor)
		self.biomes:add(module)
	end)
	
	self.initialized = true
	
	-- Destroy the constructors so that they can be collected by the GC.
	self.constructors = nil
end

function Biomes:register(name, module)
	if type(module) == "table" then
		self:register_from_table(name, module)
	else
		self:register_from_constructor(name, module)
	end
end

function Biomes:register_from_constructor(name, constructor_function)
	local constructor = BiomeConstructor:new(name)
	
	constructor_function(constructor)
	
	self.constructors:add(constructor)
end

function Biomes:register_from_table(name, table)
	local constructor = BiomeConstructor:new()
	
	if tables.nodes ~= nil then
		for index, value in ipairs(table.nodes) do
			constructor:require_node(value.name, value.node_name)
		end
	end
	
	if table.noises ~= nil then
		for index, value in ipairs(table.params) do
			constructor:require_noise(
				value.name,
				value.value,
				value.octaves,
				value.persistence,
				value.scale,
				value.spreadx,
				value.spready,
				value.spreadz,
				value.flags)
		end
	end
	
	if table.params ~= nil then
		for index, value in ipairs(table.params) do
			constructor:add_param(value.name, value.value)
		end
	end
	
	constructor:set_fits(table.fits)
	
	self.constructors:add(constructor)
end

function Biomes:set_default_biome(biome)
	self.default_biome = biome
end

