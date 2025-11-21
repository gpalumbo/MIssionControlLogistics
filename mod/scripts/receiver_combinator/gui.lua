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

-- ============================================================================
-- GUI CREATION FUNCTIONS
-- ============================================================================

--- Create settings panel (placeholder for future configuration)
--- @param parent LuaGuiElement Parent element
--- @param entity LuaEntity The receiver entity
local function create_settings_panel(parent, entity)
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

    -- Placeholder text (will be replaced with actual configuration UI)
    local placeholder = frame.add{
        type = "label",
        caption = "Surface configuration will be added here"
    }
    placeholder.style.font_color = {r = 0.6, g = 0.6, b = 0.6}

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

--- Handler for close button click
local gui_handlers = {
    close_button = function(event)
        local player = game.players[event.player_index]
        receiver_gui.close_gui(player)
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

    -- Add custom click handlers here if needed
end

return receiver_gui
