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


WorldGen = {}


function WorldGen:new(noise_manager, name)
	local instance = {
		cache = BlockedCache:new(),
		constructors = List:new(),
		initialized = false,
		modules = List:new(),
		name = name or "WorldGen",
		noise_manager = noise_manager or NoiseManager:new(),
		persistent = {}
	}
	
	setmetatable(instance, self)
	self.__index = self
	
	return instance
end


function WorldGen:constructor_to_module(constructor)
	local module = {
		condition = constructor.condition,
		name = constructor.name,
		nodes = {},
		noise_bases = {},
		noises = {},
		objects = {},
		params = {},
		pcgrandom_bases = {},
		random_bases = {},
		run_2d = constructor.run_2d,
		run_3d = constructor.run_3d,
		run_after = constructor.run_after,
		run_before = constructor.run_before
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
		
		module.noise_bases[noise_param.name] = {
			map = noisemap,
			type = noise_param.type
		}
	end)
	
	constructor.objects:foreach(function(object, index)
		module.objects[object.name] = object.object
	end)
	
	constructor.params:foreach(function(param, index)
		module.params[param.name] = param.value
	end)
	
	constructor.pcgrandoms:foreach(function(pcgrandom, index)
		module.pcgrandom_bases[pcgrandom.name] = self.noise_manager:get_random()
	end)
	
	constructor.randoms:foreach(function(random, index)
		module.pcgrandom_bases[pcgrandom.name] = self.noise_manager:get_pcgrandom()
	end)
	
	return module
end

function WorldGen:init()
	self.constructors:foreach(function(constructor, index)
		log.info(self.name .. ": Initializing module \"" .. constructor.name .. "\"")
		local module = self:constructor_to_module(constructor)
		self.modules:add(module)
	end)
	
	self.initialized = true
	
	-- Destroy the constructors so that they can be collected by the GC.
	self.constructors = nil
end

function WorldGen:prepare_module_noises(module, minp, maxp)
	for key, value in pairs(module.noise_bases) do
		local valuemap = nil
		
		if value.type == "2D" then
			valuemap = value.map:get2dMap({
				x = minp.x,
				y = minp.z
			})
			valuemap = arrayutil.swapped_reindex2d(valuemap, minp.x, minp.z)
		elseif value.type == "3D" then
			valuemap = value.map:get3dMap({
				x = minp.x,
				y = minp.y,
				z = minp.z
			})
			valuemap = arrayutil.swapped_reindex3d(valuemap, minp.x, minp.y, minp.z)
		end
		
		module.noises[key] = valuemap
	end
end

function WorldGen:prepare_module_random(module, minp, maxp, seed)
	
end

function WorldGen:register(name, module)
	if type(module) == "table" then
		self:register_from_table(name, module)
	else
		self:register_from_constructor(name, module)
	end
end

function WorldGen:register_from_constructor(name, constructor_function)
	local constructor = WorldGenConstructor:new(name)
	
	constructor_function(constructor)
	
	self.constructors:add(constructor)
end

function WorldGen:register_from_table(name, table)
	local constructor = WorldGenConstructor:new(name)
	
	if table.nodes ~= nil then
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
	
	if table.objects ~= nil then
		for index, value in ipairs(table.objects) do
			constructor:add_object(value.name, value.object)
		end
	end
	
	if table.params ~= nil then
		for index, value in ipairs(table.params) do
			constructor:add_param(value.name, value.value)
		end
	end
	
	constructor:set_condition(table.condition)
	constructor:set_run_before(table.run_before)
	constructor:set_run_2d(table.run_2d)
	constructor:set_run_3d(table.run_3d)
	constructor:set_run_after(table.run_after)
	constructor:set_run_before(table.run_before)
	
	self.constructors:add(constructor)
end

function WorldGen:run(map_manipulator, minp, maxp, seed)
	if not self.initialized then
		self:init()
	end
	
	log.info("")
	log.info("-------- " .. self.name .. " --------")
	log.info("From: " .. tableutil.to_string(minp, true, false))
	log.info("To: " .. tableutil.to_string(maxp, true, false))
	
	local metadata = {
		minp = minp,
		maxp = maxp,
		persistent = self.persistent
	}
	
	stopwatch.start("worldgen.modules (" .. self.name .. ")")
	
	self.modules:foreach(function(module, index)
		self:run_module(module, map_manipulator, metadata, minp, maxp, seed)
	end)
	
	log.info("--------------------------")
	stopwatch.stop("worldgen.modules (" .. self.name .. ")", "Summary")
	log.info("==========================\n")
end

function WorldGen:run_module(module, map_manipulator, metadata, minp, maxp, seed)
	stopwatch.start("worldgen.module (" .. self.name .. ")")
	
	if module.condition == nil or module.condition(module, metadata, minp, maxp) then
		self:prepare_module_noises(module, minp, maxp)
		
		if module.run_before ~= nil then
			module.run_before(module, metadata, map_manipulator, minp, maxp)
		end
		
		worldgenutil.iterate3d(minp, maxp, function(x, z, y)
			if module.run_3d ~= nil then
				module.run_3d(module, metadata, map_manipulator, x, z, y)
			end
		end, nil, function(x, z)
			if module.run_2d ~= nil then
				module.run_2d(module, metadata, map_manipulator, x, z)
			end
		end)
		
		if module.run_after ~= nil then
			module.run_after(module, metadata, map_manipulator, minp, maxp)
		end
	end
	
	stopwatch.stop("worldgen.module (" .. self.name .. ")", module.name)
end

