require "joy"
local gfx = love.graphics
local kbd = love.keyboard

module(..., package.seeall)

local function pickup(player, item)
    if item.type == "vial" then
        player.health = player.health + tune.player_pickup_vial_amount
        love.audio.play(sounds.health)
        if player.health > tune.player_max_health then
            player.health = tune.player_max_health
        end
    elseif item.type == "sonar" then
        player.sonar = player.sonar + tune.player_pickup_sonar_amount
        love.audio.play(sounds.sonar)
        if player.sonar > tune.player_max_sonar then
            player.sonar = tune.player_max_sonar
        end
    elseif item.type == "star" then
        love.audio.play(sounds.star)
        player.stars = player.stars + 1
    elseif item.type == "exit" then
        player.exit = true
    end
end

local function timestep(player, stick_accel, flap_accel, dt)
    local k = player.on_ground and tune.player_ground_drag_const or tune.player_air_drag_const
    ax = stick_accel - k * player.vx
    local ay = tune.player_gravity + flap_accel
    local vx = ax * dt + player.vx
    local vy = ay * dt + player.vy
    local px = 0.5 * ax * dt * dt + player.vx * dt + player.px
    local py = 0.5 * ay * dt * dt + player.vy * dt + player.py

    -- clamp vel
    local v_len = math.sqrt(vx^2 + vy^2)
    if v_len > tune.player_max_vel then
        vx = (vx / v_len) * tune.player_max_vel
        vy = (vy / v_len) * tune.player_max_vel
    end

    player.vx, player.vy = vx, vy
    player.px, player.py = px, py
end

local function process(player, dt)

    -- blink
    if player.dead then
        player.eyes_open = false
    else
        player.blink_timer = player.blink_timer - dt
        if player.blink_timer < 0 then
            if player.eyes_open then
                player.eyes_open = false
                player.blink_timer = math.random() * 0.3
            else
                player.eyes_open = true
                player.blink_timer = 3.0 + math.random()
            end
        end
    end

    -- get left stick, account for dead_spot
    local stick_x, stick_y = joy.getAxes(1)
    if stick_x then
        if player.dead or math.sqrt(stick_x^2 + stick_y^2) < tune.player_stick_dead_spot then
            stick_x, stick_y = 0, 0
        end
    else
        stick_x, stick_y = 0, 0
    end

    if kbd.isDown("left") then
        stick_x = stick_x - 0.7
    end
    if kbd.isDown("right") then
        stick_x = stick_x + 0.7
    end

    stick_accel = tune.player_stick_accel * stick_x

    if not player.dead then
        -- flaps
        local BUTTON_A = 11
        local flap_action = joy.isDown(1, BUTTON_A) or kbd.isDown("up")
        if flap_action and not player.flap_down then
            player.flap_down = true
            player.flap_list:add({ttl = tune.player_flap_duration})

            love.audio.play(sounds.flap)

        elseif not flap_action and player.flap_down then
            player.flap_down = false
        end

        -- pings
        local BUTTON_B = 12
        local ping_action = joy.isDown(1, BUTTON_B) or kbd.isDown(" ")
        if ping_action and not player.ping_down then
            player.ping_down = true

            if player.sonar > tune.player_sonar_cost then
                spawn_ring(player.px, player.py, player.vx, player.vy)

                love.audio.play(sounds.ping)

                player.sonar_timer = tune.player_sonar_regen_timer
                player.sonar = player.sonar - tune.player_sonar_cost
            end

            -- blink for a short moment
            player.eyes_open = false
            player.blink_timer = 0.5

        elseif not ping_action and player.ping_down then
            player.ping_down = false
        end
    end

    -- add up all the flap forces
    local flap_accel = 0
    if not player.dead then
        player.flap_list:for_each_remove(
            function(flap)
                flap.ttl = flap.ttl - dt
                flap_accel = flap_accel - tune.player_flap_accel
                return flap.ttl < 0
            end)
    end

    -- modulate flaps with the stick
    local flap_factor = 1 - ((stick_y + 1) / 2)
    flap_accel = flap_accel * flap_factor

    local old_px, old_py = player.px, player.py

    -- euler integrator
    local time_step = 0.001
    local time_left = dt
    while time_left > time_step do
        timestep(player, stick_accel, flap_accel, time_step)
        time_left = time_left - time_step
    end
    timestep(player, stick_accel, flap_accel, time_left)

    local was_damaged = false

    -- tunnel check
    local line = {old_px, old_py, player.px, player.py}
    local ix, iy, nx, ny, type = ping.bsp:line_probe(line)
    if ix then
        -- snap the player away from the normal
        player.px, player.py = ix + nx, iy + ny

        if type == "spikes" then
            was_damaged = true
        end
    end

    -- vertical line_probe
    if math.abs(player.vy) > 0 then
        local sign = player.vy > 0 and 1 or -1
        local direction = sign * tune.player_probe_length
        local line = {player.px, player.py, player.px, player.py + direction}
        local ix, iy, nx, ny, type = ping.bsp:line_probe(line)
        if ix and math.abs(iy - player.py) < math.abs(tune.player_height) then
            -- snap the player to the ground
            player.py = iy - sign * tune.player_height
            player.vy = 0
            player.on_ground = true

            if type == "spikes" then
                was_damaged = true
            end
        else
            player.on_ground = false
        end
    end

    -- horizontal line_probe
    if math.abs(player.vx) > 0 then
        local sign = player.vx > 0 and 1 or -1
        local forward = sign * tune.player_probe_length
        local line = {player.px, player.py, player.px + forward, player.py}
        local ix, iy, nx, ny, type = ping.bsp:line_probe(line)
        if ix and math.abs(ix - player.px) < math.abs(tune.player_height) then
            -- snap the player to the wall
            player.px = ix - sign * tune.player_height
            player.vx = 0

            if type == "spikes" then
                was_damaged = true
            end
        end
    end

    if not player.dead then
        -- do spike damage
        player.damage_timer = player.damage_timer - dt
        if was_damaged and player.damage_timer < 0 then
            player.health = player.health - tune.player_spike_damage
            player.damage_timer = tune.player_damage_timer

            love.audio.play(sounds.hurt)
        end

        -- regen sonar
        player.sonar_timer = player.sonar_timer - dt
        if player.sonar_timer < 0 and player.sonar < tune.player_max_sonar then
            player.sonar = player.sonar + tune.player_sonar_regen_rate * dt
            if player.sonar > tune.player_max_sonar then
                player.sonar = tune.player_max_sonar
            end
        end

        -- death
        if player.health <= 0 then
            love.audio.play(sounds.death)
            player.dead = true
        end
    end
end

-- draw player
local function draw(player)

   -- debug draw
   --gfx.setColor(0, 128, 0, 255)
   --gfx.circle("line", ping.player.px, ping.player.py, tune.player_height)

   -- draw black body
   gfx.setBlendMode("alpha")
   gfx.setColor(0, 0, 0, 255)
   gfx.circle("fill", player.px, player.py, tune.player_height - 1)

   -- draw green eyes
   if player.eyes_open then
       local eye_x = 4
       local eye_y = -2
       local eye_radius = 1

       gfx.setColor(0, 128, 0, 255)
       gfx.circle("fill", player.px + eye_x, player.py + eye_y, eye_radius)
       gfx.circle("fill", player.px - eye_x, player.py + eye_y, eye_radius)
   end
end

function new(px, py)
    local player = {
        px = px, py = py, 
        vx = 0, vy = 0, 
        eyes_open = true, 
        blink_timer = 3.0 + math.random(),
        flap_list = list.new(),
        health = tune.player_max_health,
        damage_timer = 0,
        sonar = tune.player_max_sonar,
        sonar_timer = 0,
        stars = 0,
        exit = false,

        -- methods
        process = process,
        draw = draw,
        pickup = pickup,
    }

    return player
end
