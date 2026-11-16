-- Physical order: 24-inch G2411P, laptop panel, 27-inch G2721E.
-- Use each connected display's current mode and scale; handle unplug/replug.
local last_topology

local function desired_scale(monitor)
    -- Enlarge the laptop UI to 1600x1000 effective size at native sharpness.
    if monitor.name:match("^eDP") and monitor.width == 2560 and monitor.height == 1600 then
        return 1.6
    end
    return monitor.scale
end

local function rank(monitor)
    local description = monitor.description or ""
    if description:find("G2411P", 1, true) then return 1 end
    if monitor.name:match("^eDP") or monitor.name:match("^LVDS") then return 2 end
    if description:find("G2721E", 1, true) then return 3 end
    if monitor.name:match("^DP") then return 1 end
    return 3
end

local function arrange_displays()
    local monitors = {}
    for _, monitor in ipairs(hl.get_monitors()) do
        if monitor.enabled and not monitor.is_mirror and monitor.width > 0 then
            table.insert(monitors, monitor)
        end
    end
    table.sort(monitors, function(a, b)
        if rank(a) == rank(b) then return a.name < b.name end
        return rank(a) < rank(b)
    end)

    local topology = {}
    for _, monitor in ipairs(monitors) do
        table.insert(topology, table.concat({ monitor.name, monitor.width,
            monitor.height, monitor.scale, monitor.transform, monitor.refresh_rate }, ":"))
    end
    local signature = table.concat(topology, ";")
    if signature == last_topology then return end
    last_topology = signature

    local x = 0
    for _, monitor in ipairs(monitors) do
        local scale = desired_scale(monitor)
        -- Register every screen, including ones already in the correct place.
        -- Otherwise the upstream automatic rule can reorder those screens
        -- when another screen's scale or mode changes during a reload.
        hl.monitor({
            output = monitor.name,
            mode = string.format("%dx%d@%.6f", monitor.width, monitor.height, monitor.refresh_rate),
            position = string.format("%dx0", x),
            scale = scale,
            transform = monitor.transform,
        })
        local width = monitor.width
        if monitor.transform % 2 == 1 then width = monitor.height end
        x = x + math.floor(width / scale + 0.5)
    end
end

hl.on("monitor.added", arrange_displays)
hl.on("monitor.removed", arrange_displays)
hl.on("config.props_refreshed", arrange_displays)
arrange_displays()
