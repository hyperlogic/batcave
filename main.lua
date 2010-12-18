local phy = love.physics
local gfx = love.graphics

-- global ping table
ping = {
    physobs = {},
    splats = {} }

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

    local SUBDIVS = 300
    local SPEED = 100
    local RADIUS = 0.001
    local SPREAD_RADIUS = 10
    local RESTITUTION = 1
    local MASS = 1
    local d_theta = (2 * math.pi) / SUBDIVS
    for i = 1, SUBDIVS do
        local vx, vy = SPEED * math.cos(d_theta * i), SPEED * math.sin(d_theta * i)
        local ox, oy = SPREAD_RADIUS * math.cos(d_theta * i), SPREAD_RADIUS * math.sin(d_theta * i)
        local physob = new_circle(MASS, px + ox, py + oy, RADIUS, RESTITUTION)
        physob.body:setLinearVelocity(vx, vy)
        table.insert(ping.physobs, physob)
    end

end

local function new_splat(px, py, nx, ny)
    return {px = px, py = py}
end

local function coll_add(a, b, contact)
end

local function coll_persist(a, b, contact)
end

local function coll_remove(a, b, contact)
    local px, py = contact:getPosition()
    local nx, ny = contact:getNormal()
    table.insert(ping.splats, new_splat(px, py, nx, ny))
end

local function coll_result(a, b, contact)
end

local function create_world()
    ping.world = phy.newWorld(-1000, -1000, 1000, 1000, 0, 0, true)

    ping.world:setCallbacks(coll_add, coll_persist, coll_remove, coll_result)

    local HEIGHT = 30
    local WIDTH = 30
    local y = 0
    for line in string.gmatch(level, ".-\n") do
        for x = 1, #line do
            if line:byte(x) == SOLID then
                local box = new_box(0, x * WIDTH, y * HEIGHT, WIDTH/2, HEIGHT/2)
                table.insert(ping.physobs, box)
            end
        end
        y = y + 1
    end

    do_ping(350, 200)
end

function love.load()
    ping.t = 0
    ping.fps = 0

    print("Welcome to Ping!")

    create_world()
end

local function rot(x, y, theta)
    local sin_theta = math.sin(theta)
    local cos_theta = math.cos(theta)
    return x * cos_theta - y * sin_theta, x * sin_theta + y * cos_theta
end

function love.draw()

   love.graphics.setBackgroundColor(25, 25, 25)

   -- draw fps
   love.graphics.setColor(256, 256, 256)
   love.graphics.print("fps = "..ping.fps, 50, 50)

   -- draw black ground quads

   for i, physob in ipairs(ping.physobs) do

       local px, py = physob.body:getPosition()
       local theta = physob.body:getAngle()

       if physob.type == "box" then
           gfx.setColor(0,0,0,255)
           local rx, ry = rot(physob.rx, physob.ry, theta)
           local ax, ay = px + rx, py + ry
           local cx, cy = px - rx, py - ry
           local rx, ry = rot(physob.rx, -physob.ry, theta)
           local bx, by = px + rx, py + ry
           local dx, dy = px - rx, py - ry

           gfx.line(ax, ay, bx, by, cx, cy, dx, dy, ax, ay)
       else
           gfx.setColor(0,255,0,255)
           gfx.point(px, py)
       end
   end

   for i, splat in ipairs(ping.splats) do
       gfx.setColor(0,64,0,255)
       gfx.point(splat.px, splat.py)
   end

end

function love.mousepressed(x, y, button)
   if button == 'l' then
	  text.color = red
   end
end

function love.mousereleased(x, y, button)
   if button == 'l' then
	  text.color = white
   end
end

function love.update(dt)
   local x, y = love.mouse.getPosition()
   ping.fps = 1/dt
   ping.t = ping.t + dt

   ping.world:update(dt)
end