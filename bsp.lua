-- builds 2d bsp tree of lines

local gfx = love.graphics

module(..., package.seeall)

local num_nodes = 0

local function build(lines)

    num_nodes = num_nodes + 1

    if #lines == 0 then
        return {}
    else
        local split_index = math.random(1, #lines)
        local split_line = lines[split_index]

        local sx1, sy1 = split_line[1], split_line[2]
        local sx2, sy2 = split_line[3], split_line[4]

        -- calc normal of split_line
        local snx, sny = sy2 - sy1, sx1 - sx2
        local len = math.sqrt(snx * snx + sny * sny)
        snx, sny = snx / len, sny / len

        local colinear_lines = {split_line}
        local front_lines = {}
        local back_lines = {}

        for i, line in ipairs(lines) do
            if i ~= split_index then

                local lx1, ly1 = line[1], line[2]
                local lx2, ly2 = line[3], line[4]

                local dot1 = (lx1 - sx1) * snx + (ly1 - sy1) * sny
                local dot2 = (lx2 - sx1) * snx + (ly2 - sy1) * sny

                if math.abs(dot1) < 0.001 and math.abs(dot2) < 0.001 then
                    table.insert(colinear_lines, line)
                elseif dot1 > 0 and dot2 > 0 then
                    table.insert(front_lines, line)
                elseif dot1 < 0 and dot2 < 0 then
                    table.insert(back_lines, line)
                else
                    local t = math.abs(dot1) / math.abs(dot2 - dot1)
                    local ix, iy = lx1 + (lx2 - lx1) * t, ly1 + (ly2 - ly1) * t

                    local front_line, back_line
                    if dot1 > 0 or dot2 < 0 then
                        front_line = {lx1, ly1, ix, iy}
                        back_line = {ix, iy, lx2, ly2}
                    else
                        front_line = {ix, iy, lx2, ly2}
                        back_line = {lx1, ly1, ix, iy}
                    end

                    if ((front_line[1] - front_line[3])^2 + (front_line[2] - front_line[4])^2) > 0.01 then
                        table.insert(front_lines, front_line)
                    end

                    if ((back_line[1] - back_line[3])^2 + (back_line[2] - back_line[4])^2) > 0.01 then
                        table.insert(back_lines, back_line)
                    end
                end
            end
        end

        return { front = build(front_lines), 
                 back = build(back_lines),
                 lines = colinear_lines,
                 nx = snx, ny = sny }
    end
end

local function point_on_lines(px, py, lines)
    for _, line in ipairs(lines) do
        local lx1, ly1 = line[1], line[2]
        local lx2, ly2 = line[3], line[4]

        local dot1 = (lx2 - lx1) * (px - lx1) + (ly2 - ly1) * (py - ly1)
        local dot2 = (lx1 - lx2) * (px - lx2) + (ly1 - ly2) * (py - ly2)

        if dot1 >= 0 and dot2 >= 0 then

            local lnx, lny = ly2 - ly1, lx1 - lx2
            local len = math.sqrt(lnx * lnx + lny * lny)
            lnx, lny = lnx / len, lny / len
            return px, py, lnx, lny
        end
    end
    return nil
end

-- line is { x1, y1, x2, y2 }
local function line_probe(bsp, line)

    if bsp and bsp.lines then
        local lx1, ly1 = line[1], line[2]
        local lx2, ly2 = line[3], line[4]
        local x1, y1 = bsp.lines[1][1], bsp.lines[1][2]
        local nx, ny = bsp.nx, bsp.ny

        local dot1 = (lx1 - x1) * nx + (ly1 - y1) * ny
        local dot2 = (lx2 - x1) * nx + (ly2 - y1) * ny

        if dot1 > 0 and dot2 > 0 then
            return line_probe(bsp.front, line)
        elseif dot1 < 0 and dot2 < 0 then
            return line_probe(bsp.back, line)
        else
            local local_t = math.abs(dot1) / math.abs(dot2 - dot1)
            local ix, iy = lx1 + (lx2 - lx1) * local_t, ly1 + (ly2 - ly1) * local_t

            if dot1 > 0 or dot2 < 0 then
                local rpx, rpy, rnx, rny = line_probe(bsp.front, {lx1, ly1, ix, iy})
                if rpx then
                    return rpx, rpy, rnx, rny
                else 
                    rpx, pry, rnx, rny = point_on_lines(ix, iy, bsp.lines)
                    if rpx then
                        return rpx, pry, rnx, rny
                    else
                        return line_probe(bsp.back, {ix, iy, lx2, ly2})
                    end
                end
            else
                local rpx, rpy, rnx, rny = line_probe(bsp.back, {lx1, ly1, ix, iy})
                if rpx then
                    return rpx, rpy, rnx, rny
                else 
                    rpx, rpy, rnx, rny = point_on_lines(ix, iy, bsp.lines)
                    if rpx then
                        return rpx, rpy, rnx, rny
                    else
                        return line_probe(bsp.front, {ix, iy, lx2, ly2})
                    end
                end
            end
        end
    else
        return nil
    end
end

-- takes a table (array) of lines.
-- where each line is a table of 4 elements: { x1, y1, x2, y2 }
-- returns a bsp table, which can be queried with line probes.
function new(lines)
    num_nodes = 0
    local bsp = build(lines)
    bsp.num_nodes = num_nodes
    bsp.line_probe = line_probe
    return bsp
end

function draw(bsp)
    if bsp then
        if bsp.lines then
            for _, line in ipairs(bsp.lines) do
                gfx.setColor(255, line[1] % 255, line[2] % 255, 255)
                gfx.line(line[1], line[2], line[3], line[4])
                gfx.setColor(0, 255, 0)
                local cx, cy = (line[1] + line[3])/2, (line[2] + line[4])/2
                local normal_scale = 10
                gfx.line(cx, cy, cx + bsp.nx * normal_scale, cy + bsp.ny * normal_scale)
            end
        end
    
        draw(bsp.front)
        draw(bsp.back)
    end
end

-- for debuging only REMOVE
local names = {"a", "b", "c", "d", "e", "f", "g", "h", "i", "k", "l", "m", "n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z"}
local g_index = 1
function debug_name(bsp)
    if bsp and bsp.lines then
        bsp.name = names[g_index]
        g_index = g_index + 1
        debug_name(bsp.front)
        debug_name(bsp.back)
    end
end

function dump(bsp, indent)
    if bsp and bsp.lines then
        if not indent then
            indent = 1
        end
        local prefix = string.rep("    ", indent)

        print(prefix.."name = ", bsp.name)
        print(prefix.."nx, ny = ", bsp.nx, bsp.ny)
        for _, line in ipairs(bsp.lines) do
            print(prefix.."line = ", unpack(line))
        end

        print(prefix.."front =")
        dump(bsp.front, indent + 1)

        print(prefix.."back =")
        dump(bsp.back, indent + 1)
    end
end

