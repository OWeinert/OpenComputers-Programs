local component = require("component")
local thread = require("thread")
local event = require("event")
local keyboard = require("keyboard")

local colors = require("screenColors")
local config = require("reactorctl-cfg")

if not component.isAvailable("nc_fission_reactor") then
    print("No NuclearCraft FissionReactor detected!")
    return
end

if not component.isAvailable("transposer") then
    print("No Transposer detected!")
    return
end

if not component.isAvailable("gpu") then
    print("No GPU detected!")
    return
end

local gpu = component.gpu

local viewportWidth = 0
local viewportHeight = 0

-- reactors consisting of address and proxy to the nc_fission_reactor
local reactors = {}

-- reactor threads
local threads = {}

-- map of buffers with reactor address as key
local buffers = {}

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


local function reactorThreadFunction (reactor)
    while true do
        local stats = getReactorStats(reactor)
        event.push("reactor_" .. reactor.address, stats)
    end
end


function initReactors()
    -- Find all connected reactors
    for address, _ in component.list("nc_fission_reactor") do
        reactors[address] = component.proxy(address)
    end

    -- create Thread for each reactor
    for address, proxy in #reactors do
        local t = thread.create(reactorThreadFunction, { address = address, proxy = proxy })
        table.insert(threads, t)
    end
end


function initScreen()

    -- check if needed resolution is supported
    local maxWidth, maxHeight = gpu.maxResolution()
    if maxWidth < 160 and maxHeight < 50 then
        print("PLEASE INSTALL TIER 3 GRAPHICS CARD!")
        return
    end

    gpu.setResolution(maxWidth, maxHeight)

    viewportHeight = 1 + (config.rowHeight + 1) * #reactors
    viewportWidth = viewportHeight / 3 * 5 -- 3:5 screen expected

    gpu.setViewport(viewportWidth, viewportHeight)

    -- allocate buffers
    for address, _ in #reactors do
        local buffer = gpu.allocateBuffer(viewportWidth, viewportHeight)
        buffers[address] = buffer
    end

    gpu.setBackground(colors.black)
    gpu.setForeground(colors.white)
end


local function drawSeperator(row)
    gpu.fill(0, row, viewportWidth, 1, "─")
end

-- draw a row of reactor stats
local function drawReactorStats(buffer, reactorStats, rowIndex)
    gpu.setActiveBuffer(buffer)

    local activityColor = colors.red
    if reactorStats.isActive then
        activityColor = colors.green
    end

    gpu.set(0, 0, "██")
    gpu.set(3, 0, reactorStats.fuelName)
    gpu.set(13, 0, reactorStats.currentProcessTime .. "/" .. reactorStats.totalProcessTime)

    local width, height = gpu.getResolution()

    local rowOffset = 1 + (config.rowHeight + 1) * rowIndex
    gpu.bitblt(0, rowOffset, 1, width, height, buffer[address], 0, 0)
end


-- main entrypoint function
function main()
    initReactors()
    initScreen()

    local running = true
    while running do
        if keyboard.isKeyDown("x") then
            running = false
            break;
        end
        thread.waitForAll(threads)

        gpu.setActiveBuffer(0)
        drawSeperator(0)
        local rowIndex = 0
        for address, _ in #reactors do
            local reactorStats = event.pull("reactor_" .. address)
            drawReactorStats(buffers[address], reactorStats, rowIndex)
            drawSeperator(rowIndex + 1)
            rowIndex = rowIndex + 1
        end

    end

    gpu.freeAllBuffers()
    gpu.setActiveBuffer(0)
end


main()