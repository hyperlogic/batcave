require "list"
require "bsp"
local phy = love.physics
local gfx = love.graphics

-- global ping table
ping = {
    ring_list = list.new(),
    splat_list = list.new() }

-- global tune table
tune = {
    ring_lifetime = 3.0,
    splat_lifetime = 5.0,
    player_gravity = 100,
    player_probe_length = 20,
    player_height = 10,
    player_stick_dead_spot = 0.3,
    player_ground_drag_const = 4,
    player_air_drag_const = 10,
    player_stick_accel = 1000,
    player_jump_vel = 200,
}

local SOLID = ("X"):byte(1)
local PLAYER = ("P"):byte(1)

local level = [[

         XXXXXXXXXXXXXXX
         X             X
         X             X
XXXXXXXXXXXXXXXXXXXX   X
X                  X   X
X                      X   
X         P            X
X                  XXXXX
X                  X     
X   XX             X
X   XX             X
X                  X
XXXXXXX     XXXXXXXX
      X     X           
      X     X
      XXXXXXX

]]

local level2 = [[

...........
..........           
...........
.....................
............................
...................X..
...........X...............
................
.........            

]]

local function new_particle(px, py, vx, vy)
    return {px = px, py = py, vx = vx, vy = vy}
end

local function spawn_ring(px, py, vx, vy)

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

local function new_splat(px, py, nx, ny)
    return {px = px, py = py, nx = nx, ny = ny, ttl = tune.splat_lifetime}
end

local function new_player(px, py)
    return {px = px, py = py, vx = 0, vy = 0}
end

local function player_timestep(player, stick_x, stick_y, dt)
    local k = player.on_ground and tune.player_ground_drag_const or tune.player_air_drag_const
    ax = stick_x - k * player.vx
    local ay = tune.player_gravity -- stick_y - k * player.vy
    local vx = ax * dt + player.vx
    local vy = ay * dt + player.vy
    local px = 0.5 * ax * dt * dt + player.vx * dt + player.px
    local py = 0.5 * ay * dt * dt + player.vy * dt + player.py
    player.vx, player.vy = vx, vy
    player.px, player.py = px, py
end

local function process_player(player, dt)

    local stick_x, stick_y = love.joystick.getAxes(0)
    if math.sqrt(stick_x^2 + stick_y^2) > tune.player_stick_dead_spot then
        stick_x, stick_y = tune.player_stick_accel * stick_x, 0
    else
        stick_x, stick_y = 0, 0
    end

    -- check joystick buttons
    local BUTTON_A = 11
    if love.joystick.isDown(0, BUTTON_A) and not player.jump_down then
        player.jump_down = true
        if player.on_ground then
            -- jump!
            player.vy = -tune.player_jump_vel
        end
    elseif not love.joystick.isDown(0, BUTTON_A) and player.jump_down then
        player.jump_down = false
    end

    local BUTTON_B = 12
    if love.joystick.isDown(0, BUTTON_B) and not player.ping_down then
        player.ping_down = true
        spawn_ring(player.px, player.py, player.vx, player.vy)
    elseif not love.joystick.isDown(0, BUTTON_B) and player.ping_down then
        player.ping_down = false
    end


    -- euler integrator
    local time_step = 0.001
    local time_left = dt
    while time_left > time_step do
        player_timestep(player, stick_x, stick_y, time_step)
        time_left = time_left - time_step
    end
    player_timestep(player, stick_x, stick_y, time_left)

    -- vertical line_probe
    if math.abs(player.vy) > 0 then
        local sign = player.vy > 0 and 1 or -1
        local direction = sign * tune.player_probe_length
        local line = {player.px, player.py, player.px, player.py + direction}
        local ix, iy, nx, ny = ping.bsp:line_probe(line)
        if ix and math.abs(iy - player.py) < math.abs(tune.player_height) then
            -- snap the player to the ground
            player.py = iy - sign * tune.player_height
            player.vy = 0
            player.on_ground = true
        else
            player.on_ground = false
        end
    end

    -- horizontal line_probe
    if math.abs(player.vx) > 0 then
        local sign = player.vx > 0 and 1 or -1
        local forward = sign * tune.player_probe_length
        local line = {player.px, player.py, player.px + forward, player.py}
        local ix, iy, nx, ny = ping.bsp:line_probe(line)
        if ix and math.abs(ix - player.px) < math.abs(tune.player_height) then
            -- snap the player to the wall
            player.px = ix - sign * tune.player_height
            player.vx = 0
        end
    end

end

function create_bsp(level)

    bsp_lines = {}
    local HEIGHT = 30
    local WIDTH = 30
    local y = 0
    local prev_line = nil
    for line in string.gmatch(level, ".-\n") do
        for x = 1, #line do

            px, py = WIDTH * x, HEIGHT * y

            if prev_line then
                local x1, y1 = px + WIDTH/2, py - HEIGHT/2
                local x2, y2 = px - WIDTH/2, py - HEIGHT/2
                if prev_line:byte(x) == SOLID and line:byte(x) ~= SOLID then
                    -- downward face
                    table.insert(bsp_lines, {x1, y1, x2, y2})
                elseif prev_line:byte(x) ~= SOLID and line:byte(x) == SOLID then
                    -- upward face
                    table.insert(bsp_lines, {x2, y2, x1, y1})
                end
            end

            if x ~= 1 then
                local x1, y1 = px - WIDTH/2, py - HEIGHT/2
                local x2, y2 = px - WIDTH/2, py + HEIGHT/2
                if line:byte(x-1) == SOLID and line:byte(x) ~= SOLID then
                    -- rightward face
                    table.insert(bsp_lines, {x1, y1, x2, y2})
                elseif line:byte(x-1) ~= SOLID and line:byte(x) == SOLID then
                    -- leftward face
                    table.insert(bsp_lines, {x2, y2, x1, y1})
                end
            end

            if line:byte(x) == PLAYER then
                ping.player = new_player(px, py)
            end
        end
        prev_line = line
        y = y + 1
    end

    return bsp.new(bsp_lines)
end

function love.load()
    ping.t = 0
    ping.fps = 0

    gfx.setBlendMode("additive")

    print("Welcome to Ping!")

    ping.bsp = create_bsp(level)

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

   -- draw fps
   gfx.setColor(255, 255, 255, 255)
   --gfx.print("fps = "..ping.fps, 50, 50)

   --bsp.draw(ping.bsp)
   --gfx.print("num_nodes = "..ping.bsp.num_nodes, 50, 20 )

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
       gfx.setColor(0, 65, 0, 255 * alpha)
       local ox, oy = 2 * splat.ny, 2 * -splat.nx
       gfx.line(splat.px + ox, splat.py + oy, splat.px - ox, splat.py - oy)

       --gfx.point(splat.px, splat.py)
   end

   -- draw player
   gfx.setColor(0, 255, 0, 255)
   gfx.circle("line", ping.player.px, ping.player.py, tune.player_height)

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

    ping.fps = 1/dt
    ping.t = ping.t + dt

    -- process rings
    ping.ring_list:for_each_remove(
        function (ring)
            ring.ttl = ring.ttl - dt
            for p in ring:values() do
                local old_px, old_py = p.px, p.py
                local old_vx, old_vy = p.vx, p.vy

                -- move particle forward
                local new_px, new_py = old_px + old_vx * dt, old_py + old_vy * dt

                -- check for collisions
                local ix, iy, nx, ny = ping.bsp:line_probe({old_px, old_py, new_px, new_py})
                if ix then

                    -- reflect velocity about normal
                    local dot = old_vx * nx + old_vy * ny
                    p.vx = old_vx - (2 * dot * nx)
                    p.vy = old_vy - (2 * dot * ny)

                    -- offset a bit from the wall so we dont get another collision next frame
                    new_px, new_py = ix + nx/2, iy + ny/2

                    ping.splat_list:add(new_splat(ix, iy, nx, ny))
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
   process_player(ping.player, dt)
end