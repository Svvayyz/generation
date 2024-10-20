# How we usin

```lua
local localplayer = custom_player_t.create(entity.get_local_player()) 
local threat = custom_player_t.create(client.current_threat())

local simulation = simulation_ctx_t.create(localplayer)

local sim_result = simulation:simulate_angle(0, 0) -- angle, hitbox (index)
local damage = sim_result:get_damage(threat, 1.00) -- from_player, multipoint_scale
```

# Have fun ig 
