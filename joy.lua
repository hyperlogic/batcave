local joy = love.joystick

module(..., package.seeall)

function getAxes(index)
    if joy.getJoystickCount() >= index then
        return joy.getJoysticks()[index]:getAxes()
    else
        return 0, 0, 0, 0
    end
end

function isDown(index, button)
    if joy.getJoystickCount() >= index then
        return joy.getJoysticks()[index]:isDown(button)
    else
        return false
    end
end
