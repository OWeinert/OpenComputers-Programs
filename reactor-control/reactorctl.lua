local component = require("component")
local keyboard = require("keyboard")
local colors = require("screenColors")

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
    local processTimeMult = reactorProxy.getReactorProcessTime() / reactorProxy.getReactorProcessTime()

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

local function updateCoroutine()
    while true do
        drawSeparator(0)
        local rowIndex = 0
        for _, proxy in pairs(reactors) do
            local reactorStats = getReactorStats(proxy)

            -- Draw activity
            local activityColor = colors.red
            if reactorStats.isActive then
                activityColor = colors.green
            end
            gpu.setForeground(activityColor)
            gpu.set(1, rowIndex, "██")

            -- Draw fuel name
            gpu.setForeground(colors.white)
            gpu.set(4, rowIndex, "Fuel: " .. reactorStats.fuelName .. "  ")

            -- Draw progressbar
            local roundedTotalProcessTime = math.ceil(reactorStats.totalProcessTime)

            local rawProgress = math.floor(reactorStats.currentProcessTime / roundedTotalProcessTime * 10)
            local clampedProgress = math.min(math.max(rawProgress, 0), 10)
            gpu.setForeground(colors.green)
            for i = 0, clampedProgress do
                gpu.set(22 + i, rowIndex, "█")
            end
            gpu.setForeground(colors.red)
            for j = clampedProgress, 10 do
                gpu.set(22 + j, rowIndex, "█")
            end

            local timeLeft = math.max(math.ceil((roundedTotalProcessTime - reactorStats.currentProcessTime) / 20), 0)
            gpu.setForeground(colors.white)
            gpu.set(34, rowIndex, "Time Left: " .. reactorStats.roundedTotalProcessTime .. " s  ")

            -- Draw generated power
            gpu.set(60, rowIndex, "Power: " .. reactorStats.power)

            -- draw seperator
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

    local update = coroutine.create(updateCoroutine)
    coroutine.resume(update)
    while true do
        coroutine.resume(update)
        os.sleep(0)
    end

    local maxWidth, maxHeight = gpu.maxResolution()
    gpu.setViewport(maxWidth, maxHeight)

    os.exit()
end


main()