local component = require("component")
local colors = require("screenColors")
local text = require("text")
local thread = require("thread")
local keyboard = require("keyboard")

if not component.isAvailable("nc_fission_reactor") then
    error("No NuclearCraft FissionReactor detected!")
end

if not component.isAvailable("gpu") then
    error("No GPU detected!")
end

local gpu = component.gpu

-- reactors consisting of address and proxy to the nc_fission_reactor
local reactors = {}
local lastReactorStats = {}
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
    for addr, _ in component.list("nc_fission_reactor") do
        reactors[addr] = component.proxy(addr)
        reactorCount = reactorCount + 1
    end
end


local vpWidth = 0
local vpHeight = 0

function initScreen()

    -- check if needed resolution is supported
    local maxWidth, maxHeight = gpu.maxResolution()
    if maxWidth < 160 and maxHeight < 50 then
        error("PLEASE INSTALL TIER 3 GRAPHICS CARD!")
    end

    gpu.setResolution(maxWidth, maxHeight)

    vpHeight = math.floor((2 * reactorCount + 1) / 5 + 0.5) * 5
    vpWidth = 80

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
    for addr, proxy in pairs(reactors) do
        lastReactorStats[addr] = getReactorStats(proxy)
    end
    while true do
        local row = 2
        for addr, proxy in pairs(reactors) do
            local reactorStats = getReactorStats(proxy)
            local reactorStatsOld = lastReactorStats[addr]
            coroutine.yield()

            -- Draw activity
            if not (reactorStatsOld.isActive == reactorStats.isActive) then
                local activityColor = colors.red
                if reactorStats.isActive then
                    activityColor = colors.green
                end
                gpu.setForeground(activityColor)
                gpu.set(1, row, "██")
            end
            coroutine.yield()

            -- Draw fuel name
            if not (reactorStatsOld.fuelName == reactorStats.fuelName) then
                gpu.setForeground(colors.white)
                gpu.set(4, row, "Fuel: " .. reactorStats.fuelName .. "    ")
            end
            coroutine.yield()

            -- Draw progressbar
            if not (reactorStatsOld.totalProcessTime == reactorStats.totalProcessTime)
                or not (reactorStatsOld.currentProcessTime == reactorStats.currentProcessTime) then

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
                gpu.set(34, row, text.padRight("Time Left: " .. timeLeft .. " s", 18))
            end
            coroutine.yield()

            if not (reactorStatsOld.power == reactorStats.power) then
                gpu.set(52, row, "Power: " .. reactorStats.power)
            end
            coroutine.yield()

            row = row + 2
            lastReactorStats[addr] = reactorStats
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
    for i = 0, reactorCount do
        drawSeparator((2 * i) + 1)
    end

    local c = coroutine.create(reactorCoroutine)
    while true do
        if keyboard.isControlDown() and keyboard.isKeyDown("w") then
            break;
        end
        coroutine.resume(c)
        os.sleep(0)
    end

    os.sleep(0)
    t:kill()

    local maxWidth, maxHeight = gpu.maxResolution()
    gpu.setViewport(maxWidth, maxHeight)

    os.exit()
end


main()