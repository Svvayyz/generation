```lua
local localplayer = custom_player_t.create(entity.get_local_player()) 
local threat = custom_player_t.create(client.current_threat())

local simulation = simulation_ctx_t.create(localplayer)

local sim_result = simulation:simulate_angle(0, 0) -- angle, hitbox (index)
local damage = sim_result:get_damage(threat, 1.00) -- from_player, multipoint_scale

-- what can we use this for?

-- made the function so you can make jitter gen 
local sort = function(data, initial_damage, comparsion_function)
    local result = { best_dmg = initial_damage, best_angle = 0 }

    for angle, damage in pairs(data) do 
        if comparsion_function(result.best_dmg, damage, angle) then 
            result = { best_dmg = damage, best_angle = angle }
        end 
    end 

    return result
end 

-- a cool damage based freestanding
local freestanding = {} do 
    function freestanding:process(hitbox, multipoint_scale) 
        local data = {
            [-90] = simulation:sim_angle(-90, hitbox):get_dmg(threat, multipoint_scale),
            [0] = simulation:sim_angle(0, hitbox):get_dmg(threat, multipoint_scale),
            [90] = simulation:sim_angle(90, hitbox):get_dmg(threat, multipoint_scale)
        }

        return sort(data, 9999, function(best_damage, damage) return damage < best_damage end)
    end
end 

-- generation / pre anti bruteforce ("avoidness")
-- you'll have to optimize it yourself, i've done more than enough spoonfeeding for now
-- good luck i guess
local generation = {} do 
    function generation:obtain_data(hitbox, multipoint_scale)
        local data = {} 
        
        for angle = -180, 180 do 
            data[angle] = simulation:sim_angle(angle, hitbox):get_dmg(threat, multipoint_scale) 
        end 

        return data 
    end 

    function generation:generate_jitter(type, hitbox, multipoint_scale)
        local data = generation:obtain_data(hitbox, multipoint_scale)

        return sort(data, 9999, function(best_damage, damage, angle)
            if type == "center" then 
                return (damage + data[-angle] / 2) < best_damage -- add the left side 
            elseif type == "offset" then 
                return (damage + data[0] / 2) < best_damage -- add center 
            elseif type == "skitter" then 
                return (damage + data[0] + data[-angle]) < best_damage -- add center + left 
            end 

            return damage < best_damage -- ????
        end)
    end 

    function generation:generate_yaw(hitbox, multipoint_scale)
        local data = generation:obtain_data(hitbox, multipoint_scale)

        return sort(data, 9999, function(best_damage, damage) return damage < best_damage end)
    end 

    function generation:generate_flick(hitbox, multipoint_scale)
        local data = generation:obtain_data(hitbox, multipoint_scale)

        return sort(data, 0, function(best_damage, damage) return damage > best_damage end)
    end 
end 
```

# Have fun ig 
