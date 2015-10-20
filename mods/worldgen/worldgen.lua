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


function WorldGen:new(name, noise_manager)
	local instance = {
		initialized = false,
		map_size = {
			x = constants.block_size,
			y = constants.block_size,
			z = constants.block_size
		},
		modules = List:new(),
		name = name or "WorldGen",
		noise_manager = noise_manager or NoiseManager:new(),
		persistent = {},
		prototypes = List:new()
	}
	
	setmetatable(instance, self)
	self.__index = self
	
	return instance
end


function WorldGen:create_noise(module, noise_param)
	local parameters = {
		offset = noise_param.offset or 0,
		scale = noise_param.scale,
		spread = {
			x = noise_param.spreadx,
			y = noise_param.spready or noise_param.spreadx,
			z = noise_param.spreadz or noise_param.spreadx
		},
		seed = noise_param.seed or stringutil.hash(self.name .. module.name .. noise_param.name),
		octaves = noise_param.octaves,
		persist = noise_param.persistence,
		flags = noise_param.flags
	}
	
	return minetest.get_perlin_map(parameters, self.map_size)
end

function WorldGen:init()
	log.info(self.name .. ": Initializing...")
	
	self.prototypes:foreach(function(prototype, index)
		log.info(self.name .. ": Initializing module \"" .. prototype.name .. "\"")
		
		local module = self:prototype_to_module(prototype)
		self.modules:add(module)
	end)
	
	self.initialized = true
	
	-- Destroy the prototypes so that they can be collected by the GC.
	self.prototypes = nil
end

function WorldGen:log_time(name, watch_name)
	local time = stopwatch.stop_only(watch_name)
	local formatted_time = numberutil.format(time, 3)
	
	log.info("    ", name .. " ", string.rep(".", 50 - #name - #formatted_time), " ", formatted_time, " ms")
end

function WorldGen:prepare_module_noises(module, minp, maxp)
	for key, value in pairs(module.noise_objects) do
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

function WorldGen:prepare_module_randoms(module, seed)
	local random_source = PcgRandom(seed)
	
	module.pcgrandom_names:foreach(function(pcgrandom_name, index)
		module.pcgrandoms[pcgrandom_name] = PcgRandom(random_source:next())
	end)
	
	module.pseudorandom_names:foreach(function(pseudorandom_name, index)
		module.pseudorandoms[pseudorandom_name] = PseudoRandom(random_source:next())
	end)
end

function WorldGen:prototype_to_module(prototype)
	local module = {
		condition = prototype.condition,
		name = prototype.name,
		nodes = {},
		noise_objects = {},
		noises = {},
		objects = {},
		params = {},
		pcgrandom_names = List:new(),
		pcgrandoms = {},
		pseudorandom_names = List:new(),
		pseudorandoms = {},
		run_2d = prototype.run_2d,
		run_3d = prototype.run_3d,
		run_after = prototype.run_after,
		run_before = prototype.run_before
	}
	
	prototype.nodes:foreach(function(node, index)
		module.nodes[node.name] = nodeutil.get_id(node.node)
		
		log.info(self.name .. ": Added node \"",
			node.node,
			"\" as \"",
			node.name,
			"\" with ID \"",
			module.nodes[node.name],
			"\".")
		
		if module.nodes[node.name] < 0 or module.nodes[node.name] == 127 then
			log.error(self.name .. ": Node \"" .. tostring(node.node) .. "\" was not found.")
		end
	end)
	
	prototype.noises2d:foreach(function(noise_param, index)
		module.noise_objects[noise_param.name] = {
			map = self:create_noise(module, noise_param),
			type = "2D"
		}
	end)
	
	prototype.noises3d:foreach(function(noise_param, index)
		module.noise_objects[noise_param.name] = {
			map = self:create_noise(module, noise_param),
			type = "3D"
		}
	end)
	
	prototype.objects:foreach(function(object, index)
		module.objects[object.name] = object.object
	end)
	
	prototype.params:foreach(function(param, index)
		module.params[param.name] = param.value
	end)
	
	prototype.pcgrandoms:foreach(function(pcgrandom, index)
		module.pcgrandom_names:add(pcgrandom)
	end)
	
	prototype.pseudorandoms:foreach(function(pseudorandom, index)
		module.pseudorandom_names:add(pseudorandom)
	end)
	
	return module
end

function WorldGen:register(name, module)
	local prototype = nil
	
	if type(module) == "table" then
		prototype = tableutil.clone(module)
		prototype.name = name
	else
		prototype = ModuleConstructor:new(name)
		module(prototype)
	end
	
	self.prototypes:add(prototype)
end

function WorldGen:run(map_manipulator, minp, maxp, seed)
	if not self.initialized then
		self:init()
	end
	
	local separator = string.rep("-", 34 - #self.name)
	log.info(separator, " ", self.name, " ", separator)
	
	local formatted_minp = minp.x .. ", " .. minp.y .. ", " .. minp.z
	local formatted_maxp = maxp.x .. ", " .. maxp.y .. ", " .. maxp.z
	local space = string.rep(" ", 38 - #formatted_minp - #formatted_maxp)
	log.info("    ", formatted_minp, space, " / ", space, formatted_maxp)
	
	local metadata = {
		minp = minp,
		maxp = maxp,
		persistent = self.persistent
	}
	
	stopwatch.start("worldgen (" .. self.name .. ")")
	
	self.modules:foreach(function(module, index)
		self:run_module(module, map_manipulator, metadata, minp, maxp, seed)
	end)
	
	self:log_time("Total", "worldgen (" .. self.name .. ")")
end

function WorldGen:run_module(module, map_manipulator, metadata, minp, maxp, seed)
	stopwatch.start("worldgen.module (" .. module.name .. ")")
	
	if module.condition == nil or module.condition(module, metadata, minp, maxp) then
		self:prepare_module_noises(module, minp, maxp)
		self:prepare_module_randoms(module, seed)
		
		if module.run_before ~= nil then
			module.run_before(module, metadata, map_manipulator, minp, maxp)
		end
		
		if module.run_2d ~= nil or module.run_3d ~= nil then
			for x = minp.x, maxp.x, 1 do
				for z = minp.z, maxp.z, 1 do
					if module.run_2d ~= nil then
						module.run_2d(module, metadata, map_manipulator, x, z)
					end
					
					if module.run_3d ~= nil then
						for y = minp.y, maxp.y, 1 do
							module.run_3d(module, metadata, map_manipulator, x, z, y)
						end
					end
				end
			end
		end
		
		if module.run_after ~= nil then
			module.run_after(module, metadata, map_manipulator, minp, maxp)
		end
	end
	
	self:log_time(module.name, "worldgen.module (" .. module.name .. ")")
end

