require "list"
require "bsp"
require "player"

-- level data
require "batcave"
require "caverns"

local gfx = love.graphics
local kbd = love.keyboard

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
    player_damage_timer = 0.4,
    player_max_sonar = 100,
    player_sonar_cost = 4,
    player_sonar_regen_timer = 3,
    player_sonar_regen_rate = 4,
    player_pickup_vial_amount = 25,
    player_pickup_sonar_amount = 30,
    player_max_vel = 400,
}

-- type to color map
type_color = {
    ground = {0, 127, 0, 255},
    spikes = {255, 0, 0, 255},
}

textures = {}
fonts = {}
sounds = {}

current_state = nil

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

local function new_item(px, py, type)
    local width = (type == "exit") and 64 or 32
    return {px = px, py = py,
            alpha = 0,
            width = width,
            quad = gfx.newQuad(0, 0, width, width, width, width),
            type = type}
end

function create_bsp_from_table(level_table)
    local bsp_lines = level_table

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
        elseif ltype ~= "ground" and ltype ~= "spikes" then
            ping.item_list:add(new_item(line[1], line[2], ltype))
        else
            -- copy line
            table.insert(new_lines, line)
        end
    end
    
    return bsp.new(new_lines)
end

local function set_current_state(state)
    if current_state then
        current_state:exit()
    end
    current_state = state
    state:enter()
end

--
-- title_screen_state
--
title_screen_state = {}
function title_screen_state.enter(self)
    
    self.slide_num = 1
    self.slides = {{"Batcave", "A game by", "Anthony Thibault", "ajt@hyperlogic.org"},
                   {"Batcave", "Use a xbox360 controller", "or keyboard"},
                   {"Batcave", "To flap wings press A button", "or Up Arrow on keyboard"},
                   {"Batcave", "To use sonar press B button", "or Space on keyboard"},
                   {"Batcave", "Use left stick to move", "or Left and Right Arrow keys"}}
end

function title_screen_state.exit(self)

end

function title_screen_state.process(self, dt)
    if kbd.isDown(" ") and self.space_released then
        self.slide_num = self.slide_num + 1
        self.space_released = false
    end

    if not kbd.isDown(" ") then
        self.space_released = true
    end

    if self.slide_num == #self.slides + 1 then
        ping.level_num = 1
        set_current_state(level_intro_state)
    end
end

function title_screen_state.draw(self)

    local line_y = {150, 300, 400, 500, 600}
    for i, slide in ipairs(self.slides[self.slide_num]) do
        if i == 1 then
            gfx.setFont(fonts.large)
            gfx.setColor(255, 255, 255, 255)
        else
            gfx.setFont(fonts.medium)
        end
        gfx.printf(self.slides[self.slide_num][i], 0, line_y[i], gfx.getWidth(), "center")
    end
end

--
-- level_intro_state
--

level_intro_state = {}
function level_intro_state.enter(self)
    print "enter level_intro_state"
    self.slide_num = 1

    if ping.level_num == 1 then
        self.slides = {"You awake in a dark room",
                       "Your wife is missing...",
                       "You hear a cry for help!"}
    elseif ping.level_num == 2 then
        self.slides = {"As you continue on your way",
                       "You see a pink ribbon",
                       "Your wife's ribbon...",
                       "A sharp scream echos through the cavern!"}
    elseif ping.level_num == 3 then
        self.slides = {"You emerge from the dank cavern",
                       "You catch a glimmer of red light down the long cooridor",
                       "And hear a low growl...",
                       "Stay Tuned...",
                       "And thank you for playing"}
    end
end

function level_intro_state.exit(self)
    print "exit level_intro_state"
end

function level_intro_state.process(self, dt)
    if kbd.isDown(" ") and self.space_released then
        self.slide_num = self.slide_num + 1
        self.space_released = false
    end

    if not kbd.isDown(" ") then
        self.space_released = true
    end

    if self.slide_num == #self.slides + 1 then
        if ping.level_num < 3 then
            set_current_state(level_play_state)
        else
            set_current_state(title_screen_state)
        end
    end
end

function level_intro_state.draw(self)
    gfx.setFont(fonts.large)
    gfx.setColor(255, 255, 255, 255)
    gfx.printf(self.slides[self.slide_num], 0, 200, gfx.getWidth(), "center")
end

--
-- level_play_state
--

level_play_state = {}
function level_play_state.enter(self)
    print "enter level_play_state"

    ping.t = 0
    ping.fps = 0
    ping.ring_list = list.new()
    ping.splat_list = list.new()
    ping.item_list = list.new()
    ping.restart_timer = 0
    ping.waiting_for_restart = false

    if ping.level_num == 1 then
        ping.bsp = create_bsp_from_table(batcave_level)
    elseif ping.level_num == 2 then
        ping.bsp = create_bsp_from_table(caverns_level)
    end

    --bsp.dump(ping.bsp)

    -- make sure we added a player
    assert(ping.player)
    assert(not ping.player.exit)
end

function level_play_state.exit(self)
    print "exit level_play_state"
end

function level_play_state.process(self,dt)
    game_process(dt)
end

function level_play_state.draw(self)
    game_draw()
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

function game_process(dt)
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

   -- process items
   ping.item_list:for_each_remove(
       function (item)

           -- wiggle exit
           if item.type == "exit" then
               if item.orig_x then
                   item.px = item.orig_x + 10 * math.sin(5 * ping.t)
               else
                   item.orig_x = item.px
               end
           end
           
           -- check line of sight and proximity to player.
           local line = {item.px, item.py, ping.player.px, ping.player.py}
           local ix = ping.bsp:line_probe(line)
           local FADE_RATE = 2
           if ix then
               -- fade out
               item.alpha = item.alpha - FADE_RATE * dt
               if item.alpha < 0 then
                   item.alpha = 0
               end
           else
               -- fade in
               item.alpha = item.alpha + FADE_RATE * dt
               if item.alpha > 1 then
                   item.alpha = 1
               end
           end

           local PICKUP_RADIUS = 15
           if math.sqrt((item.px - ping.player.px)^2 + (item.py - ping.player.py)^2) < PICKUP_RADIUS then
               ping.player:pickup(item)
               return true
           end
       end)


   ping.restart_timer = ping.restart_timer - dt
   if ping.player.dead and not ping.waiting_for_restart then
       ping.restart_timer = 3
       ping.waiting_for_restart = true
   end

   if ping.waiting_for_restart and ping.restart_timer < 0 then
       -- restart current level
       set_current_state(level_intro_state)
       ping.player = nil
       ping.waiting_for_restart = false
   end

   if ping.player and ping.player.exit then
       ping.level_num = ping.level_num + 1
       set_current_state(level_intro_state)
       ping.player = nil
   end

end

function game_draw()

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
        local brightness = 1.0
        gfx.setColor(color[1] * brightness, color[2] * brightness, color[3] * brightness, color[4] * alpha)

        local ox, oy = 2 * splat.ny, 2 * -splat.nx
        gfx.line(splat.px + ox, splat.py + oy, splat.px - ox, splat.py - oy)

        --gfx.point(splat.px, splat.py)
    end

    ping.player:draw()

    -- draw items
    for item in ping.item_list:values() do
        gfx.setColor(255, 255, 255, 255*item.alpha)
        gfx.drawq(textures[item.type], item.quad, item.px - item.width/2, item.py - item.width/2, 0)
    end

    gfx.pop()

    -- UI

    -- draw health
    gfx.setColor(32, 32, 32, 255)
    local left, top = 50, 10
    local width, height = 400, 20
    local x_border, y_border = 6, 3
    gfx.rectangle("fill", left, top, width, height)

    local scale = ping.player.health / tune.player_max_health

    gfx.setColor(0, 0, 0, 255)
    gfx.rectangle("fill", left + x_border, top + y_border, width - (2*x_border), height - (2*y_border))
    gfx.setColor(180, 32, 32, 255)
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
    gfx.setColor(32, 128, 32, 255)

    local y_offset = (1 - scale) * (height - (2*y_border))
    gfx.rectangle("fill", left + x_border, top + y_border + y_offset, width - (2*x_border), (scale * (height - (2*y_border))))
end

--
-- love hooks
--

function love.load()
    ping.t = 0
    ping.fps = 0
    ping.ring_list = list.new()
    ping.splat_list = list.new()
    ping.item_list = list.new()
    ping.restart_timer = 0
    ping.waiting_for_restart = false
    ping.level_num = 1

    -- load textures
    textures.star = gfx.newImage("star.png")
    textures.vial = gfx.newImage("vial.png")
    textures.sonar = gfx.newImage("sonar.png")
    textures.exit = gfx.newImage("exit.png")

    fonts.large = gfx.newFont("prstartk.ttf", 50)
    fonts.medium = gfx.newFont("prstartk.ttf", 35)

    sounds.ping = love.audio.newSource("ping.ogg", "static")
    sounds.flap = love.audio.newSource("flap.ogg", "static")
    sounds.hurt = love.audio.newSource("hurt.ogg", "static")
    sounds.death = love.audio.newSource("death.ogg", "static")
    sounds.health = love.audio.newSource("health.ogg", "static")
    sounds.sonar = love.audio.newSource("sonar.ogg", "static")
    sounds.star = love.audio.newSource("star.ogg", "static")

    -- initial state
    set_current_state(title_screen_state)

    -- hide mouse
    love.mouse.setVisible(false)
end

function love.update(dt)

    -- escape out
    if kbd.isDown("escape") then
        love.event.push('q')
    end

    -- clamp dt at 1/10 of a sec
    if dt > 1/10 then
        dt = 1/10
    end

    -- record fps
    ping.fps = 1/dt
    ping.t = ping.t + dt

    current_state:process(dt)
end

function love.draw()
    current_state:draw()
end

function love.mousepressed(x, y, button)
end

function love.mousereleased(x, y, button)
end
