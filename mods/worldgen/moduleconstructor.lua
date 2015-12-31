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


ModuleConstructor = {}


function ModuleConstructor:new(name)
	local instance = {
		condition = nil,
		name = name,
		noises2d = List:new(),
		noises3d = List:new(),
		nodes = List:new(),
		objects = List:new(),
		on_init = nil,
		params = List:new(),
		pcgrandoms = List:new(),
		pseudorandoms = List:new(),
		run_2d = nil,
		run_3d = nil,
		run_after = nil,
		run_before = nil
	}
	
	setmetatable(instance, self)
	self.__index = self
	
	return instance
end


function ModuleConstructor:add_object(name, object)
	self.objects:add({
		name = name,
		object = object
	})
end

function ModuleConstructor:add_param(name, value)
	self.params:add({
		name = name,
		value = value
	})
end

function ModuleConstructor:require_node(name, node)
	self.nodes:add({
		name = name,
		node = node
	})
end

function ModuleConstructor:require_noise2d(name, octaves, persistence, scale, spreadx, spready, flags, seed)
	self.noises2d:add({
		name = name,
		octaves = octaves,
		persistence = persistence,
		scale = scale,
		spreadx = spreadx,
		spready = spready,
		flags = flags,
		seed = seed
	})
end
		
function ModuleConstructor:require_noise3d(name, octaves, persistence, scale, spreadx, spready, spreadz, flags, seed)
	self.noises3d:add({
		name = name,
		octaves = octaves,
		persistence = persistence,
		scale = scale,
		spreadx = spreadx,
		spready = spready,
		spreadz = spreadz,
		flags = flags, 
		seed = seed
	})
end

function ModuleConstructor:require_pcgrandom(name)
	self.pcgrandoms:add({
		name = name
	})
end

function ModuleConstructor:require_pseudorandom(name)
	self.pseudorandoms:add({
		name = name
	})
end

function ModuleConstructor:set_condition(condition_function)
	self.condition = condition_function
end

function ModuleConstructor:set_on_init(on_init_function)
	self.on_init = on_init_function
end

function ModuleConstructor:set_run_2d(run_function)
	self.run_2d = run_function
end

function ModuleConstructor:set_run_3d(run_function)
	self.run_3d = run_function
end

function ModuleConstructor:set_run_after(run_function)
	self.run_after = run_function
end

function ModuleConstructor:set_run_before(run_function)
	self.run_before = run_function
end

