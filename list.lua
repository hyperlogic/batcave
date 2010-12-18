-- single linked list
-- NOTE: only works on tables
-- This is because the a next key is added to the element table,
-- instead of creating a new "node" table for each element.

local assert = assert
module(...)

-- for each element in list, apply the function f
-- if f returns true then remove that elem from the list.
local function for_each_remove(self, f)
    local curr = self.head
    local prev = nil
    while curr do
        local remove = f(curr)
        
        if remove then
            -- remove curr from list
            if prev then
                prev.next = curr.next
            else
                self.head = curr.next
            end
        end
        prev, curr = curr, curr.next
    end    
end

-- returns iterator function which can be used in a generic for.
-- Example:
--   for elem in list:values() do
--       print elem
--   end
local function values(self)
    assert(self)
    local l = { next = self.head }
    return function () if l then l = l.next end return l end
end

-- add elem to the front of the list
-- Example:
--  list:add(new)
local function add(self, elem)
    elem.next = self.head
    self.head = elem
end

-- returns a new list table
function new()
    local list = { head = nil,
                   for_each_remove = for_each_remove,
                   add = add,
                   values = values }
    return list
end
