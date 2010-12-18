local phy = love.physics
local gfx = love.graphics

-- global ping table
ping = {
    physobs = {} }

-- px, py is position
-- rx, ry is radius
local function new_box(mass, px, py, rx, ry)
    local body = phy.newBody(ping.world, px, py, mass, mass)
    local shape = phy.newRectangleShape(body, 0, 0, rx * 2, ry * 2, 0)
    return { body = body,
             shape = shape,
             rx = rx, 
             ry = ry }
end

local function create_world()
    ping.world = phy.newWorld(-1000, -1000, 1000, 1000, 0, 100, true)

    table.insert(ping.physobs, new_box(0, 350, 350, 100, 10))
    table.insert(ping.physobs, new_box(1, 350, 100, 20, 10))
    table.insert(ping.physobs, new_box(1, 330, 80, 20, 10))
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

   love.graphics.setBackgroundColor(128, 128, 128)

   -- draw some text
   --love.graphics.setColor(unpack(text.color))
   --love.graphics.print(text.caption, text.pos.x, text.pos.y)

   -- draw fps
   love.graphics.setColor(256, 256, 256)
   love.graphics.print("fps = "..ping.fps, 50, 50)

   -- draw black ground quads
   gfx.setColor(0,0,0,255)
   for i, physob in ipairs(ping.physobs) do
       local px, py = physob.body:getPosition()
       local theta = physob.body:getAngle()

       local rx, ry = rot(physob.rx, physob.ry, theta)
       local ax, ay = px + rx, py + ry
       local cx, cy = px - rx, py - ry
       local rx, ry = rot(physob.rx, -physob.ry, theta)
       local bx, by = px + rx, py + ry
       local dx, dy = px - rx, py - ry

       gfx.line(ax, ay, bx, by, cx, cy, dx, dy, ax, ay)
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