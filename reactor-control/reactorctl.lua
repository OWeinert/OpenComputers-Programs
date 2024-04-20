local component = require("component")
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
    local processTimeMult = reactorProxy.getReactorProcessTime() / reactorProxy.getFissionFuelTime()

    return {
        isActive = reactorProxy.isProcessing(),
        isComplete = reactorProxy.isComplete(),
        error = reactorProxy.getProblem(),
        fuelName = reactorProxy.getFissionFuelName(),
        power = reactorProxy.getReactorProcessPower(),
        energyStored = reactorProxy.getEnergyStored(),
        currentProcessTime = reactorProxy.getCurrentProcessTime() * processTimeMult,
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

    -- clear screen
    gpu.fill(0, 0, vpWidth, vpHeight, " ")
end


local function drawSeparator(row)
    gpu.fill(0, row, vpWidth, 1, "─")
end

local function reactorThread(reactorProxy, index)
    while true do
        local reactorStats = getReactorStats(reactorProxy)

        -- Draw activity
        local activityColor = colors.red
        if reactorStats.isActive then
            activityColor = colors.green
        end
        gpu.setForeground(activityColor)
        gpu.set(1, index, "██")

        -- Draw fuel name
        gpu.setForeground(colors.white)
        gpu.set(4, index, "Fuel: " .. reactorStats.fuelName .. "    ")

        -- Draw progressbar
        local roundedTotalProcessTime = math.floor(reactorStats.totalProcessTime)

        if roundedTotalProcessTime > 0 then
            local rawProgress = math.floor(reactorStats.currentProcessTime / roundedTotalProcessTime * 10)
            local clampedProgress = math.min(math.max(rawProgress, 0), 10)
            gpu.setForeground(colors.red)
            for i = 0, clampedProgress do
                gpu.set(22 + i, index, "█")
            end
            gpu.setForeground(colors.green)
            for j = clampedProgress, 10 do
                gpu.set(22 + j, index, "█")
            end
        else
            gpu.setForeground(colors.red)
            for i = 0, 10 do
                gpu.set(22 + i, index, "█")
            end
        end

        local timeLeft = math.max(math.floor((roundedTotalProcessTime - reactorStats.currentProcessTime) / 20), 0)
        gpu.setForeground(colors.white)
        gpu.set(34, index, "Time Left: " .. timeLeft .. " s  ")

        -- Draw generated power
        gpu.set(60, index, "Power: " .. reactorStats.power)

        -- draw seperator
        drawSeparator(index + 1)
        os.sleep(0)
    end
end

-- main entrypoint function
function main()
    initReactors()
    initScreen()

    drawSeparator(0)

    local threads = {}
    local index = 1
    for _, proxy in pairs(reactors) do
        table.insert(threads, thread.create(reactorThread(proxy, index)))
        index = index + 2
    end

    while true do
        os.sleep(0)
    end

    local maxWidth, maxHeight = gpu.maxResolution()
    gpu.setViewport(maxWidth, maxHeight)

    os.exit()
end


main()