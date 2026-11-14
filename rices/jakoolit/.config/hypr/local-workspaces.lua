-- Pin five workspaces to each screen in the requested physical order.
local last_targets

local function configure_workspaces()
    local hdmi, displayport, laptop, fallback
    for _, monitor in ipairs(hl.get_monitors()) do
        if monitor.enabled and not monitor.is_mirror then
            fallback = fallback or monitor
            if monitor.name:match("^HDMI") then hdmi = hdmi or monitor end
            if monitor.name:match("^DP") then displayport = displayport or monitor end
            if monitor.name:match("^eDP") or monitor.name:match("^LVDS") then laptop = monitor end
        end
    end
    fallback = laptop or fallback
    if not fallback then return end
    local targets = {
        (hdmi or fallback).name,
        (displayport or fallback).name,
        (laptop or fallback).name,
    }
    local signature = table.concat(targets, ";")
    if signature == last_targets then return end
    last_targets = signature

    for id = 1, 15 do
        local group = math.floor((id - 1) / 5) + 1
        hl.workspace_rule({
            workspace = tostring(id),
            monitor = targets[group],
            persistent = true,
            default = id == 1 or id == 6 or id == 11,
        })
    end

    -- Rules place new workspaces; move existing workspaces with their windows.
    for _, workspace in ipairs(hl.get_workspaces()) do
        local id = workspace.id
        if id >= 1 and id <= 15 then
            local target = targets[math.floor((id - 1) / 5) + 1]
            if workspace.monitor and workspace.monitor.name ~= target then
                hl.dispatch(hl.dsp.workspace.move({ workspace = tostring(id), monitor = target }))
            end
        end
    end
end

local modifier = mainMod or "SUPER"
for key = 1, 5 do
    hl.unbind(modifier .. " + SHIFT + " .. key)
    hl.bind(modifier .. " + SHIFT + " .. key, hl.dsp.focus({ workspace = key + 10 }))
    hl.bind(modifier .. " + CTRL + SHIFT + " .. key, hl.dsp.window.move({ workspace = key + 10 }))
end
for id = 1, 10 do
    hl.bind(modifier .. " + CTRL + " .. (id % 10), hl.dsp.window.move({ workspace = id }))
end

hl.on("monitor.added", configure_workspaces)
hl.on("monitor.removed", configure_workspaces)
hl.on("config.props_refreshed", configure_workspaces)
configure_workspaces()
