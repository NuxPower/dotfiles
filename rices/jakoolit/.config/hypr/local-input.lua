-- Personal touchpad settings, applied after the upstream desktop configuration.
hl.config({
    input = {
        touchpad = {
            natural_scroll = true,
            scroll_factor = 1.35,
            disable_while_typing = true,
        },
    },
    gestures = {
        workspace_swipe_distance = 220,
        workspace_swipe_cancel_ratio = 0.35,
        workspace_swipe_min_speed_to_force = 20,
    },
})

-- Follow a three-finger vertical swipe with a live workspace transition.
hl.gesture({ fingers = 3, direction = "vertical", action = "workspace" })
