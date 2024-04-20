local component = require("component")
local keyboard = require("keyboard")
local colors = require("screenColors")
local thread = require("thread")

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
local reactorCount = 0

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
        reactorCount = reactorCount + 1
    end
end


local vpWidth = 0
local vpHeight = 0

function initScreen()

    -- check if needed resolution is supported
    local maxWidth, maxHeight = gpu.maxResolution()
    if maxWidth < 160 and maxHeight < 50 then
        print("PLEASE INSTALL TIER 3 GRAPHICS CARD!")
        return
    end

    gpu.setResolution(maxWidth, maxHeight)

    local cellSize = math.floor((2 * reactorCount + 1) / 5 + 0.5)
    vpHeight = cellSize * 5
    vpWidth = cellSize * 16

    gpu.setViewport(vpWidth, vpHeight)

    gpu.setBackground(colors.black)
    gpu.setForeground(colors.white)
end


local function drawSeparator(row)
    gpu.fill(0, row, vpWidth, 1, "─")
end

-- draw a row of reactor stats
local function drawReactorStats(reactorStats, rowIndex)
    local activityColor = colors.red
    if reactorStats.isActive then
        activityColor = colors.green
    end

    -- Draw activity
    gpu.setForeground(activityColor)
    gpu.set(0, rowIndex, "██")

    -- Draw fuel name
    gpu.setForeground(colors.white)
    gpu.set(3, rowIndex, "Fuel: " .. reactorStats.fuelName)

    -- Draw progressbar
    --[[
    local progress = math.floor(reactorStats.currentProcessTime / reactorStats.totalProcessTime * 10)
    gpu.setForeground(colors.green)
    for i = 0, progress do
        gpu.set(17 + i, rowIndex, "█")
    end
    gpu.setForeground(colors.red)
    for j = progress, 10 do
        gpu.set(17 + j, rowIndex, "█")
    end
    ]]
    gpu.set(17, reactorStats.currentProcessTime .. "/" .. reactorStats.totalProcessTime)

    -- Draw generated power
    gpu.setForeground(colors.white)
    gpu.set(23, rowIndex, "Power: " .. reactorStats.power)
end

local function updateThread()
    while true do
        drawSeparator(0)
        local rowIndex = 0
        for _, proxy in pairs(reactors) do
            local reactorStats = getReactorStats(proxy)
            drawReactorStats(reactorStats, rowIndex)
            coroutine.yield()
            drawSeparator(rowIndex + 1)
            rowIndex = rowIndex + 2
            coroutine.yield()
        end
        coroutine.yield()
    end
end

-- main entrypoint function
function main()
    initReactors()
    initScreen()

    local t = thread.create(updateThread)

    while true do
        if keyboard.isControlDown() and keyboard.isKeyDown("w") then
            t:kill()
            break
        end
    end

    local maxWidth, maxHeight = gpu.maxResolution()
    gpu.setViewport(maxWidth, maxHeight)

    os.exit()
end


main()