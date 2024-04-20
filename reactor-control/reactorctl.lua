local component = require("component")
local keyboard = require("keyboard")
local colors = require("screenColors")
local config = require("reactorctl-cfg")

if not component.isAvailable("nc_fission_reactor") then
    print("No NuclearCraft FissionReactor detected!")
    return
end

if not component.isAvailable("gpu") then
    print("No GPU detected!")
    return
end

local gpu = component.gpu

-- reactors consisting of address and proxy to the nc_fission_reactor
local reactors = {}

--[[
    FUNCTIONS
]]

local function getReactorStats(reactorProxy)
    return {
        isActive = reactorProxy.isProcessing(),
        isComplete = reactorProxy.isComplete(),
        error = reactorProxy.getProblem(),
        fuelName = reactorProxy.getFissionFuelName(),
        power = reactorProxy.getReactorProcessPower(),
        energyStored = reactorProxy.getEnergyStored(),
        currentProcessTime = reactorProxy.getCurrentProcessTime(),
        totalProcessTime = reactorProxy.getReactorProcessTime()
    }
end


function initReactors()
    -- Find all connected reactors
    for address, _ in component.list("nc_fission_reactor") do
        reactors[address] = component.proxy(address)
    end
end


local screenWidth = 0
local screenHeight = 0

function initScreen()

    -- check if needed resolution is supported
    local maxWidth, maxHeight = gpu.maxResolution()
    if maxWidth < 160 and maxHeight < 50 then
        print("PLEASE INSTALL TIER 3 GRAPHICS CARD!")
        return
    end

    screenWidth = (maxHeight / 3) * 5
    screenHeight = maxHeight
    gpu.setResolution(screenWidth, screenHeight)


    gpu.setBackground(colors.black)
    gpu.setForeground(colors.white)
end


local function drawSeparator(row)
    gpu.fill(0, row, screenWidth, 1, "─")
end

-- draw a row of reactor stats
local function drawReactorStats(reactorStats, rowIndex)
    local activityColor = colors.red
    if reactorStats.isActive then
        activityColor = colors.green
    end

end


local function updateCoroutine()
    while true do
        drawSeparator(0)
        local rowIndex = 0
        for address, proxy in pairs(reactors) do
            local reactorStats = getReactorStats(proxy)
            drawSeparator(rowIndex + 1)
            rowIndex = rowIndex + 1
            coroutine.yield()
        end
        coroutine.yield()
    end
end

-- main entrypoint function
function main()
    initReactors()
    initScreen()

    local update = coroutine.create(updateCoroutine)
    coroutine.resume(update)

    local running = true
    while running do
        if keyboard.isControlDown() then
            running = false
            print("program exited")
            break
        end
    end
end


main()