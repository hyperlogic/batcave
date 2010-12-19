require "list"
require "bsp"
require "player"

local gfx = love.graphics

-- global ping table
ping = {}

-- global tune table
tune = {
    ring_lifetime = 3.0,
    splat_lifetime = 5.0,

    -- player tuning
    player_gravity = 100,
    player_probe_length = 20,
    player_height = 10,
    player_stick_dead_spot = 0.3,
    player_ground_drag_const = 4,
    player_air_drag_const = 6,
    player_stick_accel = 1000,
    player_flap_accel = 500,
    player_flap_duration = 0.3,
    player_max_health = 100,
    player_spike_damage = 30,
    player_damage_timer = 0.6,
    player_max_sonar = 100,
    player_sonar_cost = 4,
    player_sonar_regen_timer = 3,
    player_sonar_regen_rate = 4,
}

-- type to color map
type_color = {
    ground = {0, 255, 0, 255},
    spikes = {255, 0, 0, 255},
}

local function new_particle(px, py, vx, vy)
    return { px = px, py = py, 
             vx = vx, vy = vy }
end

function spawn_ring(px, py, vx, vy)

    local ring = list.new()
    ring.ttl = tune.ring_lifetime

    local SUBDIVS = 100
    local SPEED = 100

    local d_theta = (2 * math.pi) / SUBDIVS
    for i = 1, SUBDIVS do
        local pvx, pvy = SPEED * math.cos(d_theta * i), SPEED * math.sin(d_theta * i)
        ring:add(new_particle(px, py, vx + pvx, vy + pvy))
    end

    ping.ring_list:add(ring)
end

local function new_splat(px, py, nx, ny, alpha, type)
    return {px = px, py = py, 
            nx = nx, ny = ny, 
            ttl = tune.splat_lifetime * alpha, 
            type = type}
end

-- run code under environment
local function run_file_with_env(env, untrusted_file)
    -- use package.path to find untrusted_file
    for path in string.gmatch(package.path, "[^;]+") do
        local filename = string.gsub(path, "?", untrusted_file)
        local file, message = io.open(filename, "r")
        if file then
            file:close()
            local untrusted_function, message = loadfile(filename)
            if not untrusted_function then 
                return nil, message 
            else
                setfenv(untrusted_function, env)
                return pcall(untrusted_function)
            end
        end
    end
end

function create_bsp_from_table(filename)
    local bsp_lines = nil
    local env = {Level = function(t) bsp_lines = t end}
    local result, message = run_file_with_env(env, filename)
    if not result then
        print("ERROR: loading "..filename, message)
        return nil
    end

    -- filter out special types of lines
    local new_lines = {}
    for i, line in ipairs(bsp_lines) do

        local ltype = line[5]

        if ltype == "player" then
            -- spawn a player if there isn't one yet
            if not ping.player then
                ping.player = player.new(line[1], line[2])
                ping.player_spawn_x = line[1]
                ping.player_spawn_y = line[2]
            end
        else
            -- copy line
            table.insert(new_lines, line)
        end
    end
    
    return bsp.new(new_lines)
end

function love.load()
    ping.t = 0
    ping.fps = 0
    ping.ring_list = list.new()
    ping.splat_list = list.new()
    ping.restart_timer = 0
    ping.waiting_for_restart = false

    print("Welcome to Ping!")

    -- load first level
    ping.bsp = create_bsp_from_table("ping/batcave")

    -- make sure we added a player
    assert(ping.player)

    --bsp.dump(ping.bsp)

    -- hide mouse
    love.mouse.setVisible(false)
end

function draw_segment(x1, y1, x2, y2, alpha)

    local MIN_SEG_DIST = 5
    local MAX_SEG_DIST = 10

    local line_dist = math.sqrt((x1 - x2)^2 + (y1 - y2)^2)
    if line_dist < MAX_SEG_DIST then
        local line_alpha 
        if line_dist < MIN_SEG_DIST then
            line_alpha = 1
        else
            line_alpha = (MAX_SEG_DIST - line_dist) / (MAX_SEG_DIST - MIN_SEG_DIST)
        end
        gfx.setColor(0, 255, 0, 255 * alpha * line_alpha)
        gfx.line(x1, y1, x2, y2)
    end
    gfx.setColor(0, 255, 0, 255 * alpha)
    gfx.point(x1, y1)

end

function love.draw()

   gfx.setBackgroundColor(0, 0, 0)
   gfx.setBlendMode("additive")

   -- draw fps
   gfx.setColor(255, 255, 255, 255)
   --gfx.print("fps = "..ping.fps, 50, 50)
   --gfx.print("num_nodes = "..ping.bsp.num_nodes, 50, 20 )

   -- camera follows player
   gfx.push()
   gfx.translate(-ping.player.px + (gfx.getWidth()/2), -ping.player.py + (2*gfx.getHeight()/3))

   --bsp.draw(ping.bsp)

   -- draw rings
   for ring in ping.ring_list:values() do
       local alpha = (ring.ttl > 0) and (ring.ttl / tune.ring_lifetime) or 0
       gfx.setColor(0, 255, 0, 255 * alpha)
       local prev_p, first_p
       for p in ring:values() do
           if prev_p then
               draw_segment(prev_p.px, prev_p.py, p.px, p.py, alpha)
           else
               first_p = p
           end
           prev_p = p
       end
       draw_segment(prev_p.px, prev_p.py, first_p.px, first_p.py, alpha)
   end

   -- draw splats
   for splat in ping.splat_list:values() do
       local alpha = (splat.ttl > 0) and (splat.ttl / tune.splat_lifetime) or 0

       local color = type_color[splat.type]
       if not color then
           color = {0, 255, 0, 255}
       end
       local brightness = 0.4
       gfx.setColor(color[1] * brightness, color[2] * brightness, color[3] * brightness, color[4] * alpha)

       local ox, oy = 2 * splat.ny, 2 * -splat.nx
       gfx.line(splat.px + ox, splat.py + oy, splat.px - ox, splat.py - oy)

       --gfx.point(splat.px, splat.py)
   end

   ping.player:draw()

   gfx.pop()

   -- draw health
   gfx.setColor(32, 32, 32, 255)
   local left, top = 50, 10
   local width, height = 400, 20
   local x_border, y_border = 6, 3
   gfx.rectangle("fill", left, top, width, height)

   local scale = ping.player.health / tune.player_max_health

   gfx.setColor(0, 0, 0, 255)
   gfx.rectangle("fill", left + x_border, top + y_border, width - (2*x_border), height - (2*y_border))
   gfx.setColor(128, 32, 32, 255)
   gfx.rectangle("fill", left + x_border, top + y_border, scale * (width - (2*x_border)), height - (2*y_border))

   -- draw sonar
   gfx.setColor(32, 32, 32, 255)
   local left, top = 10, 40
   local width, height = 20, 400
   local x_border, y_border = 3, 6
   gfx.rectangle("fill", left, top, width, height)

   local scale = ping.player.sonar / tune.player_max_sonar

   gfx.setColor(0, 0, 0, 255)
   gfx.rectangle("fill", left + x_border, top + y_border, width - (2*x_border), height - (2*y_border))
   gfx.setColor(32, 32, 128, 255)

   local y_offset = (1 - scale) * (height - (2*y_border))
   gfx.rectangle("fill", left + x_border, top + y_border + y_offset, width - (2*x_border), (scale * (height - (2*y_border))))

end

function love.mousepressed(x, y, button)
end

function love.mousereleased(x, y, button)
end

function love.update(dt)

    -- clamp dt at 1/10 of a sec
    if dt > 1/10 then
        dt = 1/10
    end

    -- record fps
    ping.fps = 1/dt
    ping.t = ping.t + dt

    -- process rings
    ping.ring_list:for_each_remove(
        function (ring)

            local alpha = (ring.ttl > 0) and (ring.ttl / tune.ring_lifetime) or 0

            ring.ttl = ring.ttl - dt
            for p in ring:values() do
                local old_px, old_py = p.px, p.py
                local old_vx, old_vy = p.vx, p.vy

                -- move particle forward
                local new_px, new_py = old_px + old_vx * dt, old_py + old_vy * dt

                -- check for collisions
                local ix, iy, nx, ny, type = ping.bsp:line_probe({old_px, old_py, new_px, new_py})
                if ix then

                    -- reflect velocity about normal
                    local dot = old_vx * nx + old_vy * ny
                    p.vx = old_vx - (2 * dot * nx)
                    p.vy = old_vy - (2 * dot * ny)

                    -- offset a bit from the wall so we dont get another collision next frame
                    new_px, new_py = ix + nx/2, iy + ny/2

                    ping.splat_list:add(new_splat(ix, iy, nx, ny, alpha, type))
                end
                p.px, p.py = new_px, new_py
            end

            return ring.ttl < 0
       end)

   -- process splats
   ping.splat_list:for_each_remove(
       function (splat)
           splat.ttl = splat.ttl - dt
           local remove = splat.ttl < 0
           return remove
       end)

   -- process player
   ping.player:process(dt)

   ping.restart_timer = ping.restart_timer - dt
   if ping.player.dead and not ping.waiting_for_restart then
       ping.restart_timer = 3
       ping.waiting_for_restart = true
   end

   if ping.waiting_for_restart and ping.restart_timer < 0 then
       ping.player = player.new(ping.player_spawn_x, ping.player_spawn_y)
       ping.waiting_for_restart = false
   end
   
end