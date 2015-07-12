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


worldgenfunctions = {}


function worldgenfunctions.fade(value, mask_value, module, transform_function, transform_centered_function)
	transform_function = transform_function or transform.linear
	transform_centered_function = transform_centered_function or transform.centered_linear
	
	local fade = 1
	
	if module.params.fade ~= nil then
		if mask_value <= module.params.threshold_mask_min + module.params.fade then
			fade = transform.linear(
				mask_value,
				module.params.threshold_mask_min,
				module.params.threshold_mask_min + module.params.fade)
		elseif mask_value >= module.params.threshold_mask_max - module.params.fade then
			fade = transform.linear(
				mask_value,
				module.params.threshold_mask_max,
				module.params.threshold_mask_max - module.params.fade)
		end
	else
		fade = transform.centered_linear(
			mask_value,
			module.params.threshold_mask_min,
			module.params.threshold_mask_max)
	end
	
	fade = mathutil.clamp(fade, 0, 1)
	
	return value * fade
end

function worldgenfunctions.masked_boost(name, info_name, flag_name, flag_value)
	return function(module, metadata, manipulator, x, z)
		local mask_value = module.noises.mask[x][z]
		mask_value = mathutil.clamp(mask_value, -1, 1)
		
		if mask_value >= module.params.threshold_mask_min and mask_value <= module.params.threshold_mask_max then
			local current_value = metadata[name][x][z]
			
			if (module.params.threshold_above ~= nil and current_value >= module.params.threshold_above)
				or (module.params.threshold_below ~= nil and current_value <= module.params.threshold_below) then
				
				local diff = 0
				if module.params.threshold_above ~= nil then
					diff = math.abs(current_value) - math.abs(module.params.threshold_above)
				elseif module.params.threshold_below ~= nil then
					diff = math.abs(current_value) - math.abs(module.params.threshold_below)
				end
				
				local value = transform.centered_cosine(
					mask_value,
					module.params.threshold_mask_min,
					module.params.threshold_mask_max,
					0,
					module.params.multiplier)
				
				value = value * diff
				
				metadata[name][x][z] = current_value + value
				
				if info_name ~= nil and flag_name ~= nil then
					if flag_value == nil then
						metadata[info_name][x][z][flag_name] = true
					else
						metadata[info_name][x][z][flag_name] = flag_value
					end
				end
			end
		end
	end
end

function worldgenfunctions.masked_noise_2d(name, info_name, flag_name, flag_value)
	return function(module, metadata, manipulator, x, z)
		local mask_value = module.noises.mask[x][z]
		mask_value = mathutil.clamp(mask_value, -1, 1)
		
		if mask_value >= module.params.threshold_mask_min and mask_value <= module.params.threshold_mask_max then
			local value = module.noises.main[x][z]
			value = transform.linear(value, -1, 1, 0, 1)
			value = mathutil.clamp(value, 0, 1)
			
			if module.params.smoothed then
				value = worldgenfunctions.fade(value, mask_value, module)
			end
			
			value = transform.linear(
				value,
				0,
				1,
				module.params.value_min,
				module.params.value_max)
			
			metadata[name][x][z] = metadata[name][x][z] + value
			
			if info_name ~= nil and flag_name ~= nil then
				if flag_value ~= nil then
					metadata[info_name][x][z][flag_name] = true
				else
					metadata[info_name][x][z][flag_name] = flag_value
				end
			end
		end
	end
end

--- Creates a function for usage in set_run_2d.
--
-- Required Parameters:
--  * multiplier - The multipliert that is used, the maximum value for
--                 the ridge.
--  * threshold_mask_min/max - The thresholds for the mask.
--  * threshold_min/max - The threshold for the noise.
--  * fade - The amount that is used for fading out the ridge.
--
-- Required Noises:
--  * ridged - The ridged noise.
--  * mask - The mask noise.
--
-- @param name The name of the metadata object.
-- @return The value calculated.
function worldgenfunctions.masked_ridged_noise_2d(name, info_name, flag_name, flag_value)
	return function(module, metadata, manipulator, x, z)
		local mask_value = module.noises.mask[x][z]
		mask_value = mathutil.clamp(mask_value, -1, 1)
		
		if mask_value >= module.params.threshold_mask_min and mask_value <= module.params.threshold_mask_max then
			local value = module.noises.ridged[x][z]
			value = mathutil.clamp(value, -1, 1)
			
			if value >= module.params.threshold_min and value <= module.params.threshold_max then
				value = transform.centered_linear(
					value,
					module.params.threshold_min,
					module.params.threshold_max)
				value = interpolate.cosine(value)
				value = interpolate.cosine(value)
				value = worldgenfunctions.fade(value, mask_value, module)
				value = value * module.params.multiplier
				
				metadata[name][x][z] = metadata[name][x][z] + value
				
				if info_name ~= nil and flag_name ~= nil then
					if flag_value ~= nil then
						metadata[info_name][x][z][flag_name] = true
					else
						metadata[info_name][x][z][flag_name] = flag_value
					end
				end
			end
		end
	end
end

function worldgenfunctions.multiplied_noise_2d(name)
	return function(module, metadata, manipulator, x, z)
		local value = module.noises.main[x][z]
		value = mathutil.clamp(value, -1, 1)
		value = value * module.params.multiplier
		
		metadata[name][x][z] = metadata[name][x][z] + value
	end
end

function worldgenfunctions.ranged_noise_2d(name)
	return function(module, metadata, manipulator, x, z)
		local value = module.noises.main[x][z]
		value = mathutil.clamp(value, -1, 1)
		value = transform.linear(
			value,
			-1,
			1,
			module.params.low,
			module.params.high)
		
		metadata[name][x][z] = metadata[name][x][z] + value
	end
end

function worldgenfunctions.if_true(name)
	return function(module, metadata, minp, maxp)
		return metadata[name]
	end
end

