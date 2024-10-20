local vector, ffi = require "vector" or vec3_t, require "ffi" -- base libraries 
local trace = require "gamesense/trace" -- external library

local fgv_to_iv = function(v) return vector(v.x, v.y, v.z) end -- foreign vector to internal vector 

local custom_player_t = {} do 
    local import_get_client_networkable = vtable_bind("client.dll", "VClientEntityList003", 0, "void*(__thiscall*)(void*, int)")
    local import_get_client_unknown = vtable_thunk(0, "void*(__thiscall*)(void*)")
    local import_get_client_renderable = vtable_thunk(5, "void*(__thiscall*)(void*)")
    local import_get_model = vtable_thunk(8, "const void*(__thiscall*)(void*)")
    local import_get_studio_model = vtable_bind("engine.dll", "VModelInfoClient004", 32, "void*(__thiscall*)(void*, const void*)")

    ffi.cdef[[ 
        typedef struct {
            float x;
            float y;
            float z;
        } vector3_t;
    ]]
    
    ffi.cdef[[ 
        typedef struct {
            int id;
            int version;
            long checksum;
            char name_char_array[64];
            int length;
            vector3_t eye_pos;
            vector3_t illium_pos;
            vector3_t hull_mins;
            vector3_t hull_maxs;
            vector3_t mins;
            vector3_t maxs;
            int flags;
            int bones_count;
            int bone_index;
            int bone_controllers_count;
            int bone_controller_index;
            int hitbox_sets_count;
            int hitbox_set_index;
            int local_anim_count;
            int local_anim_index;
            int local_seq_count;
            int local_seq_index;
            int activity_list_version;
            int events_indexed;
            int textures_count;
            int texture_index;
        } studio_hdr_t;

        typedef struct {
            int name_index;
            int hitbox_count;
            int hitbox_index;
        } studio_hitbox_set_t;

        typedef struct {
            int bone;
            int group;
            vector3_t mins;
            vector3_t maxs;
            int name_index;
            int paddink0[3];
            float radius;
            int paddink1[4];
        } studio_box_t;
    ]]

    local get_origin_internal = function(ctx) return vector(entity.get_origin(ctx.index)) end 
    local hitbox_position_internal = function(ctx, hitbox_index) return vector(entity.hitbox_position(ctx.index, hitbox_index)) end 
    local get_eye_position_internal = function(ctx) return ctx.index end 

    local get_studio_model_internal = function(ctx) 
        local networkable = import_get_client_networkable(ctx.index)
        local client_unknown = import_get_client_unknown(ffi.cast("void***", networkable))
        local renderable = import_get_client_renderable(ffi.cast("void***", client_unknown))
        local model = import_get_model(ffi.cast("void***", renderable))

        return import_get_studio_model(ffi.cast("void***", model))
    end 

    local get_hitbox_set_internal = function(ctx, hitbox_set_index)
        local studio_hdr = ffi.cast("studio_hdr_t*", ctx:get_studio_model())

        if hitbox_set_index > studio_hdr.hitbox_sets_count then return end 
    
        return ffi.cast("studio_hitbox_set_t*", (ffi.cast("uint8_t*", studio_hdr) + studio_hdr.hitbox_set_index) + hitbox_set_index)[0]
    end 

    local get_studio_hitbox_internal = function(ctx, hitbox_index)
        local hitbox_set = ctx:get_hitbox_set(0)

        if not hitbox_set then return end 
        if hitbox_index > hitbox_set.hitbox_count then return end 

        return ffi.cast("studio_box_t*", (ffi.cast("unsigned char*", hitbox_set) + hitbox_set.hitbox_index) + hitbox_index)[0]
    end 

    function custom_player_t.create(index) 
        local new_player_t = { index = index }

        new_player_t.get_origin = get_origin_internal
        new_player_t.hitbox_position = hitbox_position_internal
        new_player_t.get_eye_position = get_eye_position_internal

        -- FFI
        new_player_t.get_studio_model = get_studio_model_internal
        new_player_t.get_hitbox_set = get_hitbox_set_internal
        new_player_t.get_studio_hitbox = get_studio_hitbox_internal

        return new_player_t
    end 
end 

local simulation_ctx_t = {} do 
    local simulation_result_t = {} do
        local get_damage_internal = function(ctx, from_player, multipoint_scale)
            if not from_player then error "'get_damage_internal' invalid player" end 
            if not multipoint_scale then error "'get_damage_internal' invalid multipoint scale" end -- no multipoints, fuck em 

            local from_player_eye = from_player:get_eye_position()
            local studio_hitbox = ctx.player:get_studio_hitbox(ctx.hitbox)

            if not studio_hitbox then error("'get_damage_internal' failed to get studio hitbox " .. ctx.hitbox) end 

            local mins = fgv_to_iv(studio_hitbox.mins) * multipoint_scale
            local maxs = fgv_to_iv(studio_hitbox.maxs) * multipoint_scale

            local trace_result = trace.hull(from_player_eye, ctx.position, mins, maxs, {
                    skip = function(entindex) return entindex ~= ctx.player end, 
                    mask = "MASK_SHOT", contents = "CONTENTS_HITBOX", type = "TRACE_ENTITIES_ONLY"
                }
            )

            if trace_result.entindex ~= ctx.player or trace_result.fraction == 1 then return 0 end -- faggots lifestyle

            -- from: from_player/his eye, to: bullet's end potsition, skip: from_player 
            local _, damage = client.trace_bullet(from_player, from_player_eye, trace_result.end_pos:unpack(), from_player) 

            return damage 
        end     
        
        function simulation_result_t.create(player, hitbox, position)
            local new_simulation_result = {}

            new_simulation_result.player = player 
            new_simulation_result.hitbox = hitbox
            new_simulation_result.position = position

            new_simulation_result.get_dmg = get_damage_internal
            new_simulation_result.get_damage = get_damage_internal

            return new_simulation_result
        end 
    end 

    local simulate_angle_internal = function(ctx, angle, hitbox)
        if not angle then error "'simulate_angle_internal' invalid angle" end 
        if not hitbox then error "'simulate_angle_internal' invalid hitbox" end 

        local hitbox_pos = ctx.player:hitbox_position(hitbox)
        local origin = ctx.player:get_origin()

        local radius = origin:dist2d(hitbox_pos)

        origin.z = hitbox_pos.z 

        local angles = vector():init_from_angles(0, angle, 0) * radius
        local position = origin + angles

        return simulation_result_t:create(ctx.player, hitbox, position) 
    end 

    function simulation_ctx_t:create(player)
        local new_simulation_ctx = { player = player }
        
        new_simulation_ctx.simulate_angle, new_simulation_ctx.sim_angle = simulate_angle_internal, simulate_angle_internal

        return new_simulation_ctx
    end 
end 

-- an example on how to use it

local localplayer = custom_player_t.create(entity.get_local_player()) 
local threat = custom_player_t.create(client.current_threat())

local simulation = simulation_ctx_t.create(localplayer)

local sim_result = simulation:simulate_angle(0, 0) -- angle, hitbox (index)
local damage = sim_result:get_damage(threat, 1.00) -- from_player, multipoint_scale
