# How we usin

```lua
local localplayer = custom_player_t.create(entity.get_local_player()) 
local threat = custom_player_t.create(client.current_threat())

local simulation = simulation_ctx_t.create(localplayer)

local sim_result = simulation:simulate_angle(0, 0) -- angle, hitbox (index)
local damage = sim_result:get_damage(threat, 1.00) -- from_player, multipoint_scale

-- what can we use this for?

-- a cool damage based freestanding
local freestanding = {} do 
   function freestanding:process() 
      local values = {
         [-90] = simulation:sim_angle(-90, 0):get_dmg(),
         [0] = simulation:sim_angle(0, 0):get_dmg(),
         [90] = simulation:sim_angle(90, 0):get_dmg()
      }

      local result = { best_dmg = 9999, best_angle = 0 }

      for angle, damage in pairs(values) do 
          if result.best_dmg < damage then 
              result = { best_dmg = damage, best_angle = angle }
          end
      end

      return result
   end
end 
```

# Have fun ig 
