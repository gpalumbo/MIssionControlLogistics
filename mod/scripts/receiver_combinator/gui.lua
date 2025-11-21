-- Mission Control Mod - Receiver Combinator GUI
-- This module handles the GUI for receiver combinators on space platforms

local flib_gui = require("__flib__.gui")
local gui_entity = require("lib.gui.gui_entity")
local gui_circuit_inputs = require("lib.gui.gui_circuit_inputs")
local globals = require("scripts.globals")
local circuit_utils = require("lib.circuit_utils")

local receiver_gui = {}

-- GUI element names
local GUI_NAMES = {
    MAIN_FRAME = "receiver_combinator_frame",
    TITLEBAR_FLOW = "receiver_combinator_titlebar_flow",
    DRAG_HANDLE = "receiver_combinator_drag_handle",
    CLOSE_BUTTON = "receiver_combinator_close",
    POWER_LABEL = "receiver_combinator_power",
    POWER_SPRITE = "receiver_combinator_power_sprite",
    SETTINGS_FRAME = "receiver_combinator_settings_frame",
    SURFACES_SCROLL = "receiver_surfaces_scroll",
    SURFACES_TABLE = "receiver_surfaces_table",
    SURFACE_CHECKBOX_PREFIX = "receiver_surface_checkbox_",
    SELECT_ALL_BUTTON = "receiver_select_all",
    CLEAR_ALL_BUTTON = "receiver_clear_all",
    HOLD_SIGNAL_TOGGLE = "receiver_hold_signal_toggle",
    INPUT_SIGNAL_GRID_FRAME = "receiver_combinator_input_grid",
    OUTPUT_SIGNAL_GRID_FRAME = "receiver_combinator_output_grid"
}

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

--- Get receiver data from player's GUI state
--- @param player LuaPlayer
--- @return table|nil receiver_data, LuaEntity|nil entity
local function get_receiver_data_from_player(player)
    if not player then return nil, nil end

    local gui_state = globals.get_player_gui_state(player.index)
    if not gui_state then return nil, nil end

    local receiver_data = storage.receivers[gui_state.open_entity]
    if not receiver_data or not receiver_data.entity or not receiver_data.entity.valid then
        return nil, nil
    end

    return receiver_data, receiver_data.entity
end

--- Get all discovered planets/surfaces
--- Returns table of {surface_index, surface_name, is_planet}
--- @return table Array of surface info
local function get_discovered_surfaces()
    local surfaces = {}

    -- Iterate through all planets
    for _, planet in pairs(game.planets) do
        if planet.surface then
            table.insert(surfaces, {
                surface_index = planet.surface.index,
                surface_name = planet.name,
                is_planet = true
            })
        end
    end

    -- Sort by name for consistent display
    table.sort(surfaces, function(a, b)
        return a.surface_name < b.surface_name
    end)

    return surfaces
end

--- Check if a surface is configured for a receiver
--- @param receiver_data table Receiver data
--- @param surface_index uint Surface index to check
--- @return boolean True if configured
local function is_surface_configured(receiver_data, surface_index)
    if not receiver_data or not receiver_data.configured_surfaces then
        return false
    end

    for _, idx in ipairs(receiver_data.configured_surfaces) do
        if idx == surface_index then
            return true
        end
    end

    return false
end

-- ============================================================================
-- GUI CREATION FUNCTIONS
-- ============================================================================

--- Create settings panel with surface configuration
--- @param parent LuaGuiElement Parent element
--- @param entity LuaEntity The receiver entity
local function create_settings_panel(parent, entity)
    local receiver_data = storage.receivers[entity.unit_number]
    if not receiver_data then
        return nil
    end

    local frame = parent.add{
        type = "frame",
        name = GUI_NAMES.SETTINGS_FRAME,
        direction = "vertical",
        style = "inside_deep_frame"
    }
    frame.style.padding = 8
    frame.style.horizontally_stretchable = true

    -- Header
    local header = frame.add{
        type = "label",
        caption = {"", "[font=default-semibold]Surface Configuration[/font]"}
    }
    header.style.bottom_margin = 4

    -- Description
    local desc = frame.add{
        type = "label",
        caption = "Select which planets this receiver communicates with:"
    }
    desc.style.font_color = {r = 0.7, g = 0.7, b = 0.7}
    desc.style.bottom_margin = 8

    -- Button row for Select All / Clear All
    local button_flow = frame.add{
        type = "flow",
        direction = "horizontal"
    }
    button_flow.style.horizontal_spacing = 8
    button_flow.style.bottom_margin = 8

    button_flow.add{
        type = "button",
        name = GUI_NAMES.SELECT_ALL_BUTTON,
        caption = "Select All",
        style = "button"
    }

    button_flow.add{
        type = "button",
        name = GUI_NAMES.CLEAR_ALL_BUTTON,
        caption = "Clear All",
        style = "button"
    }

    -- Scroll pane for surface checkboxes
    local scroll = frame.add{
        type = "scroll-pane",
        name = GUI_NAMES.SURFACES_SCROLL,
        vertical_scroll_policy = "auto-and-reserve-space",
        horizontal_scroll_policy = "never"
    }
    scroll.style.maximal_height = 200
    scroll.style.bottom_margin = 12

    -- Table for checkboxes
    local surfaces_table = scroll.add{
        type = "table",
        name = GUI_NAMES.SURFACES_TABLE,
        column_count = 1
    }
    surfaces_table.style.horizontally_stretchable = true
    surfaces_table.style.vertical_spacing = 4

    -- Get all discovered surfaces and create checkboxes
    local discovered_surfaces = get_discovered_surfaces()

    if #discovered_surfaces == 0 then
        local no_surfaces_label = surfaces_table.add{
            type = "label",
            caption = "No planets discovered yet"
        }
        no_surfaces_label.style.font_color = {r = 0.6, g = 0.6, b = 0.6}
    else
        for _, surface_info in ipairs(discovered_surfaces) do
            local checkbox_flow = surfaces_table.add{
                type = "flow",
                direction = "horizontal"
            }
            checkbox_flow.style.vertical_align = "center"

            local checkbox = checkbox_flow.add{
                type = "checkbox",
                name = GUI_NAMES.SURFACE_CHECKBOX_PREFIX .. surface_info.surface_index,
                caption = surface_info.surface_name,
                state = is_surface_configured(receiver_data, surface_info.surface_index)
            }
        end
    end

    -- Separator
    local separator = frame.add{
        type = "line",
        direction = "horizontal"
    }
    separator.style.top_margin = 8
    separator.style.bottom_margin = 8

    -- Hold signal toggle
    local toggle_flow = frame.add{
        type = "flow",
        direction = "horizontal"
    }
    toggle_flow.style.vertical_align = "center"
    toggle_flow.style.horizontal_spacing = 8

    local toggle_checkbox = toggle_flow.add{
        type = "checkbox",
        name = GUI_NAMES.HOLD_SIGNAL_TOGGLE,
        caption = "Hold last signal when in transit",
        state = receiver_data.hold_signal_in_transit or false,
        tooltip = "If checked, the receiver will continue outputting the last received signals when the platform is traveling. If unchecked, signals will be cleared during transit."
    }

    return frame
end

--- Create input signal grid (signals being sent to space)
--- @param parent LuaGuiElement Parent element
--- @param entity LuaEntity The receiver entity
local function create_input_signal_grid(parent, entity)
    -- Create frame for input signals
    local frame = parent.add{
        type = "frame",
        name = GUI_NAMES.INPUT_SIGNAL_GRID_FRAME,
        direction = "vertical",
        style = "inside_shallow_frame"
    }
    frame.style.padding = 8
    frame.style.horizontally_stretchable = true
    frame.style.width = 400

    -- Header
    local header = frame.add{
        type = "label",
        caption = {"", "[font=default-semibold]Input Signals[/font]"}
    }
    header.style.bottom_margin = 4

    local desc = frame.add{
        type = "label",
        caption = "Signals from platform circuits (sent to ground)"
    }
    desc.style.font_color = {r = 0.7, g = 0.7, b = 0.7}
    desc.style.bottom_margin = 4

    -- Get input signals from entity
    local signals = circuit_utils.get_input_signals(entity, "combinator_input")

    -- Create sub-grids for red and green wires
    gui_circuit_inputs.create_signal_sub_grid(frame, signals.red)
    gui_circuit_inputs.create_signal_sub_grid(frame, signals.green)

    return frame
end

--- Create output signal grid (signals received from space)
--- @param parent LuaGuiElement Parent element
--- @param entity LuaEntity The receiver entity
local function create_output_signal_grid(parent, entity)
    -- Get receiver data to access hidden output combinators
    local receiver_data = storage.receivers[entity.unit_number]
    if not receiver_data then
        return nil
    end

    -- Create frame for output signals
    local frame = parent.add{
        type = "frame",
        name = GUI_NAMES.OUTPUT_SIGNAL_GRID_FRAME,
        direction = "vertical",
        style = "inside_shallow_frame"
    }
    frame.style.padding = 8
    frame.style.horizontally_stretchable = true
    frame.style.width = 400

    -- Header
    local header = frame.add{
        type = "label",
        caption = {"", "[font=default-semibold]Output Signals[/font]"}
    }
    header.style.bottom_margin = 4

    local desc = frame.add{
        type = "label",
        caption = "Signals from ground (received from space)"
    }
    desc.style.font_color = {r = 0.7, g = 0.7, b = 0.7}
    desc.style.bottom_margin = 4

    -- Read signals from hidden output combinators
    -- These are constant combinators set by network_manager
    local output_signals = {red = {}, green = {}}

    -- Read red output signals
    if receiver_data.output_entity_red and receiver_data.output_entity_red.valid then
        local red_signals = circuit_utils.get_circuit_signals(
            receiver_data.output_entity_red,
            defines.wire_connector_id.circuit_red
        )
        if red_signals then
            for signal_id, count in pairs(red_signals) do
                table.insert(output_signals.red, {
                    signal_id = signal_id,
                    count = count,
                    wire_color = "red"
                })
            end
        end
    end

    -- Read green output signals
    if receiver_data.output_entity_green and receiver_data.output_entity_green.valid then
        local green_signals = circuit_utils.get_circuit_signals(
            receiver_data.output_entity_green,
            defines.wire_connector_id.circuit_green
        )
        if green_signals then
            for signal_id, count in pairs(green_signals) do
                table.insert(output_signals.green, {
                    signal_id = signal_id,
                    count = count,
                    wire_color = "green"
                })
            end
        end
    end

    -- Create sub-grids for red and green wires
    gui_circuit_inputs.create_signal_sub_grid(frame, output_signals.red)
    gui_circuit_inputs.create_signal_sub_grid(frame, output_signals.green)

    return frame
end

-- ============================================================================
-- GUI EVENT HANDLERS
-- ============================================================================

--- Refresh the settings panel to update checkbox states
--- @param player LuaPlayer The player viewing the GUI
local function refresh_settings_panel(player)
    local receiver_data, entity = get_receiver_data_from_player(player)
    if not receiver_data then return end

    local frame = player.gui.screen[GUI_NAMES.MAIN_FRAME]
    if not frame then return end

    local content_frame = frame.children[2]  -- inside_shallow_frame
    if not content_frame then return end

    local settings_frame = content_frame[GUI_NAMES.SETTINGS_FRAME]
    if settings_frame then
        settings_frame.destroy()
    end

    -- Recreate settings panel
    create_settings_panel(content_frame, entity)
end

--- Handler for close button click
local gui_handlers = {
    close_button = function(event)
        local player = game.players[event.player_index]
        receiver_gui.close_gui(player)
    end,

    select_all_button = function(event)
        local player = game.players[event.player_index]
        local receiver_data, entity = get_receiver_data_from_player(player)
        if not receiver_data then return end

        -- Get all discovered surfaces and add them all
        local discovered_surfaces = get_discovered_surfaces()
        local surface_indices = {}

        for _, surface_info in ipairs(discovered_surfaces) do
            table.insert(surface_indices, surface_info.surface_index)
        end

        globals.set_receiver_surfaces(entity.unit_number, surface_indices)

        -- Refresh the panel to show updated checkboxes
        refresh_settings_panel(player)
    end,

    clear_all_button = function(event)
        local player = game.players[event.player_index]
        local receiver_data, entity = get_receiver_data_from_player(player)
        if not receiver_data then return end

        -- Clear all configured surfaces
        globals.set_receiver_surfaces(entity.unit_number, {})

        -- Refresh the panel to show updated checkboxes
        refresh_settings_panel(player)
    end
}

-- ============================================================================
-- MAIN GUI FUNCTIONS
-- ============================================================================

--- Create the main GUI for receiver combinator
--- @param player LuaPlayer The player to show the GUI to
--- @param entity LuaEntity The receiver combinator entity
function receiver_gui.create_gui(player, entity)
    -- Close any existing GUI
    receiver_gui.close_gui(player)

    -- Create main frame using FLib
    local refs = flib_gui.add(player.gui.screen, {
        type = "frame",
        name = GUI_NAMES.MAIN_FRAME,
        direction = "vertical",
        children = {
            -- Titlebar with drag handle
            {
                type = "flow",
                name = GUI_NAMES.TITLEBAR_FLOW,
                style = "flib_titlebar_flow",
                drag_target = GUI_NAMES.MAIN_FRAME,
                children = {
                    {
                        type = "label",
                        style = "frame_title",
                        caption = {"entity-name.receiver-combinator"},
                        ignored_by_interaction = true
                    },
                    {
                        type = "empty-widget",
                        name = GUI_NAMES.DRAG_HANDLE,
                        style = "flib_titlebar_drag_handle",
                        ignored_by_interaction = false,
                        drag_target = GUI_NAMES.MAIN_FRAME,
                    },
                    {
                        type = "sprite-button",
                        name = GUI_NAMES.CLOSE_BUTTON,
                        style = "frame_action_button",
                        sprite = "utility/close",
                        hovered_sprite = "utility/close_black",
                        clicked_sprite = "utility/close_black",
                        tooltip = {"gui.close-instruction"},
                        handler = gui_handlers.close_button
                    }
                }
            },
            -- Content frame
            {
                type = "frame",
                style = "inside_shallow_frame",
                direction = "vertical",
                children = {
                    -- Power status row
                    {
                        type = "flow",
                        direction = "horizontal",
                        style_mods = {
                            vertical_align = "center",
                            horizontal_spacing = 8,
                            bottom_margin = 8
                        },
                        children = {
                            {
                                type = "label",
                                caption = "Status: "
                            },
                            {
                                type = "sprite",
                                name = GUI_NAMES.POWER_SPRITE,
                                sprite = gui_entity.get_power_status(entity).sprite,
                                style_mods = {
                                    stretch_image_to_widget_size = false
                                }
                            },
                            {
                                type = "label",
                                name = GUI_NAMES.POWER_LABEL,
                                caption = gui_entity.get_power_status(entity).text
                            }
                        }
                    }
                }
            }
        }
    })

    -- Add UI sections after main frame creation
    local content_frame = refs[GUI_NAMES.MAIN_FRAME].children[2]  -- The inside_shallow_frame

    -- Add settings panel (placeholder)
    create_settings_panel(content_frame, entity)

    -- Add signal grids in a horizontal flow
    local signal_flow = content_frame.add{
        type = "flow",
        direction = "horizontal",
        style_mods = {
            horizontal_spacing = 8,
            top_margin = 8
        }
    }

    -- Add input and output signal grids side by side
    create_input_signal_grid(signal_flow, entity)
    create_output_signal_grid(signal_flow, entity)

    -- Center the window
    refs[GUI_NAMES.MAIN_FRAME].auto_center = true

    -- Make the GUI respond to ESC key by setting it as the player's opened GUI
    player.opened = refs[GUI_NAMES.MAIN_FRAME]

    -- Store entity reference in player's GUI state
    globals.set_player_gui_entity(player.index, entity, "receiver_combinator")
end

--- Close the GUI for a player
--- @param player LuaPlayer The player to close the GUI for
function receiver_gui.close_gui(player)
    local frame = player.gui.screen[GUI_NAMES.MAIN_FRAME]
    if frame then
        frame.destroy()
    end

    -- Clear player GUI state
    globals.clear_player_gui_entity(player.index)
end

--- Update the GUI with current receiver state
--- @param player LuaPlayer The player viewing the GUI
function receiver_gui.update_gui(player)
    local frame = player.gui.screen[GUI_NAMES.MAIN_FRAME]
    if not frame then return end

    -- Get the entity from player GUI state
    local receiver_data, entity = get_receiver_data_from_player(player)
    if not receiver_data then
        receiver_gui.close_gui(player)
        return
    end

    -- Update power status
    local power_status = gui_entity.get_power_status(entity)
    local content_frame = frame.children[2]  -- inside_shallow_frame
    if content_frame then
        local status_flow = content_frame.children[1]
        if status_flow then
            local power_sprite = status_flow[GUI_NAMES.POWER_SPRITE]
            local power_label = status_flow[GUI_NAMES.POWER_LABEL]

            if power_sprite then
                power_sprite.sprite = power_status.sprite
            end
            if power_label then
                power_label.caption = power_status.text
            end
        end
    end

    -- Update signal grids (destroy and recreate for fresh data)
    local signal_flow = content_frame.children[3]  -- The horizontal flow with signal grids
    if signal_flow then
        -- Destroy existing grids
        local input_grid = signal_flow[GUI_NAMES.INPUT_SIGNAL_GRID_FRAME]
        local output_grid = signal_flow[GUI_NAMES.OUTPUT_SIGNAL_GRID_FRAME]

        if input_grid then input_grid.destroy() end
        if output_grid then output_grid.destroy() end

        -- Recreate grids
        create_input_signal_grid(signal_flow, entity)
        create_output_signal_grid(signal_flow, entity)
    end
end

-- ============================================================================
-- EVENT HANDLERS (called from control.lua)
-- ============================================================================

--- Handle GUI opened event
--- @param event EventData.on_gui_opened
function receiver_gui.on_gui_opened(event)
    local entity = event.entity
    if entity and entity.valid and entity.name == "receiver-combinator" then
        local player = game.players[event.player_index]

        -- Ensure entity is registered (in case this is from a loaded save)
        if not storage.receivers[entity.unit_number] then
            game.print("[Mission Control] Warning: Receiver combinator not registered, cannot open GUI")
            return
        end

        -- Close the default combinator GUI that Factorio opened
        if player.opened == entity then
            player.opened = nil
        end

        -- Open our custom GUI
        receiver_gui.create_gui(player, entity)
    end
end

--- Handle GUI closed event
--- @param event EventData.on_gui_closed
function receiver_gui.on_gui_closed(event)
    -- Check if the closed element is our GUI
    if event.element and event.element.name == GUI_NAMES.MAIN_FRAME then
        receiver_gui.close_gui(game.players[event.player_index])
    end
end

--- Handle GUI click events (delegated to FLib)
--- @param event EventData.on_gui_click
function receiver_gui.on_gui_click(event)
    -- First try FLib handlers
    flib_gui.dispatch(event)

    local element = event.element
    if not element or not element.valid then return end

    -- Handle Select All button
    if element.name == GUI_NAMES.SELECT_ALL_BUTTON then
        gui_handlers.select_all_button(event)
        return
    end

    -- Handle Clear All button
    if element.name == GUI_NAMES.CLEAR_ALL_BUTTON then
        gui_handlers.clear_all_button(event)
        return
    end
end

--- Handle GUI checked state changed events
--- @param event EventData.on_gui_checked_state_changed
function receiver_gui.on_gui_checked_state_changed(event)
    local element = event.element
    if not element or not element.valid then return end

    local player = game.players[event.player_index]
    local receiver_data, entity = get_receiver_data_from_player(player)
    if not receiver_data then return end

    -- Handle surface checkbox toggle
    if element.name:match("^" .. GUI_NAMES.SURFACE_CHECKBOX_PREFIX) then
        -- Extract surface index from element name
        local surface_index_str = element.name:gsub("^" .. GUI_NAMES.SURFACE_CHECKBOX_PREFIX, "")
        local surface_index = tonumber(surface_index_str)

        if surface_index then
            if element.state then
                -- Checkbox checked - add surface
                globals.add_receiver_surface(entity.unit_number, surface_index)
            else
                -- Checkbox unchecked - remove surface
                globals.remove_receiver_surface(entity.unit_number, surface_index)
            end
        end
        return
    end

    -- Handle hold signal toggle
    if element.name == GUI_NAMES.HOLD_SIGNAL_TOGGLE then
        globals.set_receiver_hold_signal(entity.unit_number, element.state)
        return
    end
end

return receiver_gui
