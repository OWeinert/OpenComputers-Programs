local component = require("component")
local colors = require("screenColors")
local text = require("text")

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
    gpu.set(0, row, string.rep("─", vpWidth))
end

local function reactorCoroutine()
    drawSeparator(1)
    for i = 0, reactorCount do
        drawSeparator((2 * i) + 1)
    end
    coroutine.yield()
    while true do
        local row = 2
        for _, proxy in pairs(reactors) do
            local reactorStats = getReactorStats(proxy)

            -- Draw activity
            local activityColor = colors.red
            if reactorStats.isActive then
                activityColor = colors.green
            end
            gpu.setForeground(activityColor)
            gpu.set(1, row, "██")

            -- Draw fuel name
            gpu.setForeground(colors.white)
            gpu.set(4, row, "Fuel: " .. reactorStats.fuelName .. "    ")

            -- Draw progressbar
            local roundedTotalProcessTime = math.floor(reactorStats.totalProcessTime)

            if roundedTotalProcessTime > 0 then
                local rawProgress = math.floor(reactorStats.currentProcessTime / roundedTotalProcessTime * 10)
                local clampedProgress = math.min(math.max(rawProgress, 0), 10)
                gpu.setForeground(colors.red)
                gpu.set(22, row, string.rep("█", clampedProgress))
                gpu.setForeground(colors.green)
                gpu.set(22 + clampedProgress, row, string.rep("█", 10 - clampedProgress))
            else
                gpu.setForeground(colors.red)
                gpu.set(22, row, string.rep("█", 10))
            end

            local timeLeft = math.max(math.floor((roundedTotalProcessTime - reactorStats.currentProcessTime) / 20), 0)
            gpu.setForeground(colors.white)
            gpu.set(34, row, text.padRight("Time Left: " .. timeLeft .. " s  ", 18) .. "Power: " .. reactorStats.power)

            row = row + 2
            coroutine.yield()
        end
        coroutine.yield()
    end
end

-- main entrypoint function
function main()
    initReactors()
    initScreen()

    drawSeparator(1)

    local c = coroutine.create(reactorCoroutine)

    while true do
        coroutine.resume(c)
        os.sleep(0)
    end

    local maxWidth, maxHeight = gpu.maxResolution()
    gpu.setViewport(maxWidth, maxHeight)

    os.exit()
end


main()