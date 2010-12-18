require "list"
local phy = love.physics
local gfx = love.graphics

-- global ping table
ping = {
    static_physobs = {},
    physob_list = list.new(),
    splat_list = list.new() }

-- global tune table
tune = {
    ping_lifetime = 5.0,
    splat_lifetime = 10.0
}

local SOLID = ("x"):byte(1)

local level = [[

         xxxxxxxxxxxxxxx
         x             x
         x             x
xxxxxxxxxxxxxxxxxxxx   x
x                  x   x
x                      x   
x                      x
x                  xxxxx
x                  x
x   xx             x
x   xx             x
x                  x
xxxxxxx     xxxxxxxx
      x     x
      x     x
      xxxxxxx
]]

-- px, py is position
-- rx, ry is radius
local function new_box(mass, px, py, rx, ry)
    local body = phy.newBody(ping.world, px, py, mass, mass)
    local shape = phy.newRectangleShape(body, 0, 0, rx * 2, ry * 2, 0)
    return { body = body,
             shape = shape,
             rx = rx,
             ry = ry,
             type = "box" }
end

-- px, py is position
-- r is radius
local function new_circle(mass, px, py, r, restitution)
    local body = phy.newBody(ping.world, px, py, mass, mass)
    local shape = phy.newCircleShape(body, 0, 0, r)
    shape:setRestitution(restitution)
    return { body = body,
             shape = shape,
             r = r, 
             type = "circle" }
end

local function do_ping(px, py)

    local SUBDIVS = 200
    local SPEED = 100
    local RADIUS = 1.0
    local SPREAD_RADIUS = 10
    local RESTITUTION = 1
    local MASS = 1

    local d_theta = (2 * math.pi) / SUBDIVS
    for i = 1, SUBDIVS do
        local vx, vy = SPEED * math.cos(d_theta * i), SPEED * math.sin(d_theta * i)
        local ox, oy = SPREAD_RADIUS * math.cos(d_theta * i), SPREAD_RADIUS * math.sin(d_theta * i)
        local physob = new_circle(MASS, px + ox, py + oy, RADIUS, RESTITUTION)
        physob.shape:setCategory(1)
        physob.shape:setMask(1)
        physob.body:setLinearVelocity(vx, vy)
        physob.ttl = tune.ping_lifetime

        ping.physob_list:add(physob)
    end

end

local function new_splat(px, py, nx, ny)
    return {px = px, py = py, nx = nx, ny = ny, ttl = tune.splat_lifetime}
end

local function contact_add(a, b, contact)
    local px, py = contact:getPosition()
    local nx, ny = contact:getNormal()
    local splat = new_splat(px, py, nx, ny)
    ping.splat_list:add(splat)
end

local function create_world()
    ping.world = phy.newWorld(-1000, -1000, 1000, 1000, 0, 0, true)

    ping.world:setCallbacks(contact_add, nil, nil, nil)

    local HEIGHT = 30
    local WIDTH = 30
    local y = 0
    for line in string.gmatch(level, ".-\n") do
        for x = 1, #line do
            if line:byte(x) == SOLID then
                local box = new_box(0, x * WIDTH, y * HEIGHT, WIDTH/2, HEIGHT/2)
                box.shape:setCategory(2)
                table.insert(ping.static_physobs, box)
            end
        end
        y = y + 1
    end

    do_ping(350, 200)
end

function love.load()
    ping.t = 0
    ping.fps = 0

    gfx.setBlendMode("additive")

    print("Welcome to Ping!")

    create_world()
end

local function rot(x, y, theta)
    local sin_theta = math.sin(theta)
    local cos_theta = math.cos(theta)
    return x * cos_theta - y * sin_theta, x * sin_theta + y * cos_theta
end

function love.draw()

   gfx.setBackgroundColor(0, 0, 0)

   -- draw fps
   gfx.setColor(255, 255, 255, 255)
   gfx.print("fps = "..ping.fps, 50, 50)
   gfx.print("num_bodies = "..ping.world:getBodyCount(), 50, 20 )


   -- draw static physobs in black
   for _, physob in ipairs(ping.static_physobs) do

       local px, py = physob.body:getPosition()
       local theta = physob.body:getAngle()

       if physob.type == "box" then
           gfx.setColor(30,0,0,255)
           local rx, ry = rot(physob.rx, physob.ry, theta)
           local ax, ay = px + rx, py + ry
           local cx, cy = px - rx, py - ry
           local rx, ry = rot(physob.rx, -physob.ry, theta)
           local bx, by = px + rx, py + ry
           local dx, dy = px - rx, py - ry

           gfx.line(ax, ay, bx, by, cx, cy, dx, dy, ax, ay)
       else
           gfx.setColor(0,0,0,255)
           gfx.circle(px, py, physob.r)
       end
   end

   -- draw pings
   for p in ping.physob_list:values() do
       local px, py = p.body:getPosition()

       local alpha = (p.ttl > 0) and (p.ttl / tune.ping_lifetime) or 0
       gfx.setColor(0, 255, 0, 255 * alpha)

       gfx.point(px, py)
   end

   -- draw splats
   for splat in ping.splat_list:values() do

       local alpha = (splat.ttl > 0) and (splat.ttl / tune.splat_lifetime) or 0
       gfx.setColor(0, 65, 0, 255 * alpha)

       --local ox, oy = 0.1 * splat.ny, 0.1 * -splat.nx

       gfx.point(splat.px, splat.py)
       --gfx.line(splat.px + ox, splat.py + oy, splat.px - ox, splat.py - oy)
   end

end

function love.mousepressed(x, y, button)
end

function love.mousereleased(x, y, button)
end

function love.update(dt)
   local x, y = love.mouse.getPosition()
   ping.fps = 1/dt
   ping.t = ping.t + dt

   -- process pings
   ping.physob_list:for_each_remove(function (physob)
                                        physob.ttl = physob.ttl - dt

                                        if physob.ttl < 0 then
                                            physob.shape:setMask(1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16)
                                            return true
                                        end

                                        return false
                                    end)

   -- process splats
   ping.splat_list:for_each_remove(function (splat)
                                       splat.ttl = splat.ttl - dt
                                       local remove = splat.ttl < 0
                                       return remove
                                   end)
   ping.world:update(dt)

   if ping.t > 2 then
       do_ping(350 + (math.random() * 50), 200 + math.random() * 50)
       ping.t = 0
   end
end