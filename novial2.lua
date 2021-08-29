config = require("config")

math.randomseed(os.time())

box_size = 4

x_offset = 20
y_offset = 40

color1 = 0xFF0000FF
color2 = 0x400000FF
color3 = 0xDD0000FF
color4 = 0xAA0000FF

mario_x = 0
mario_y = 0
mario_x_screen_scroll = 0

moving_objects = {}

inputs_keys = {"A", "B", "right", "left", "up", "down", "start", "select"}

function get_game_timer()
    return tonumber(memory.readbyte(0x07F8)..memory.readbyte(0x07F9)..memory.readbyte(0x07FA))
end

function has_value(tab, val)
    for index, value in ipairs(tab) do
        if value == val then
            return true
        end
    end
    return false
end

function get_positions()
    mario_x = memory.readbyte(0x0086) + memory.readbyte(0x006D) * 256
    mario_y = memory.readbyte(0x03B8)
    mario_x_screen_scroll = memory.readbyte(0x071D)
end

function get_tile(_x, _y)
    local _x = _x + mario_x - 16*6
    local page = math.floor(_x / 256) % 2
    local sub_x = math.floor((_x % 256) / 16)
    local sub_y = math.floor((_y - 32) / 16)
    local addr = 0x0500 + page*208 + sub_y*16 + sub_x
    local byte = memory.readbyte(addr)
    if byte ~= 0 and byte ~= 194 then
        return 1
    end
    return 0
end

function get_map()
    local level_map = {}
    local c_col = 1
    local c_row = 1
    x_start = (memory.readbyte(0x006D) * 256 + memory.readbyte(0x0086)) - memory.readbyte(0x03AD)
    
    for _y=32, 224, 16 do
        level_map[c_row] = {}
        for _x=-16, 240, 16 do
            local tile = get_tile(_x, _y)
            if tile == 1 then
                local x_gui = math.floor(_x/16) - 1
                local y_gui = math.floor(_y/16) - 1
                level_map[c_row][c_col] = 1
            else
                level_map[c_row][c_col] = 0
            end
            c_col = c_col + 1
        end
        c_col = 1
        c_row = c_row + 1
    end
    local mario_map_x = 8
    local mario_map_y = math.floor(memory.readbyte(0x00CE) / 16)
    if mario_map_x > 0 and mario_map_x < table.getn(level_map[1]) and mario_map_y > 0 and mario_map_y < table.getn(level_map) then
        level_map[mario_map_y][mario_map_x] = 2
    end
    return level_map
end
level = get_map()

function draw_world_tile(x, y, color1, color2)
    local x = x - 2
    gui.drawbox(x, y, x+box_size, y+box_size, color2, color1)
end

function display_map(level)
    local function draw_tile(x, y, color1, color2)
        local x = x - 2
        gui.drawbox(x_offset+x*box_size, y_offset+y*box_size, x_offset+x*box_size+box_size, y_offset+y*box_size+box_size, color2, color1)
    end
    local columns = 16
    local rows = 14
    gui.drawbox(x_offset-box_size, y_offset-box_size, x_offset+columns*box_size, y_offset+rows*box_size, color2, color2)
    for y=1, table.getn(level), 1 do
        for x=1, table.getn(level[y]), 1 do
            if level[y][x] == 1 then draw_tile(x, y, color1, color2) end
            if level[y][x] == 2 then draw_tile(x, y, color3, color3) end
            if level[y][x] >= 3 then draw_tile(x, y, color4, color4) end
        end
    end
end

function cell_to_screen(x, y)
    local x = x - 2
    return {x = x_offset+x*box_size, y = y_offset+(y-0)*box_size}
end

function display_buttons()
    for k, v in pairs(inputs_keys) do
        local _inputs = joypad.read(1)
        if _inputs[v] then
            gui.drawtext(210, y_offset + (k-1)*10, v, color1, color2)
        else
            gui.drawtext(210, y_offset + (k-1)*10, v, color2, color2)
        end
    end
end

function get_button_coords(button_number)
    return {x = 210, y = y_offset + (button_number-1)*10}
end

function read_enemies(level)
    local enemies_drawn = 0
    for _e=0, 4, 1 do
        if memory.readbyte(0x000F + _e) ~= 0 then
            -- local ex = memory.readbyte(0x0087 + _e) - 16*2
            local ex = memory.readbyte(0x6E + _e)*0x100 + memory.readbyte(0x87+_e) - mario_x + 16*9
            local ey = memory.readbyte(0x00CF + _e)
            enemies_drawn = enemies_drawn + 1
            local s_ex = math.floor(ex/16)
            local s_ey = math.floor(ey/16)
            if s_ex > 0 and s_ex < table.getn(level[1]) and s_ey > 0 and s_ey < table.getn(level) then
                level[s_ey][s_ex] = 3 + memory.readbyte(0x0016 + _e)
            end
        end
    end
end

global_connects = {}

function map_to_list(level_data)
    map_list = {}
    for r=1, 12 do
        for c=1, 16 do
            table.insert(map_list, level_data[r][c])
        end
    end

    return map_list
end

function new_node(value, type)
    local node = {
        innov = 0,
        value = value, 
        type = type
    }

    return node
end

function new_connection(node1, node2, weight)
    local connection = {
        weight = weight, 
        node_in = node1, 
        node_out = node2, 
        innov = 0, 
        enabled = true
    }
    
    return connection
end

function new_generation()
    local generation = {
        species = {}
    }

    return generation
end

function new_species()
    local species = {
        genomes = {}
    }

    return species
end

function new_genome(inputs, outputs)
    local genome = {
        nodes = {},
        connections = {},
        is_alive = true,
        num_inputs = inputs,
        num_outputs = outputs
    }

    function genome:get_node(innov)
        for k, v in pairs(genome.nodes) do 
            if v.innov == innov then
                return v
            end
        end
    end

    function genome:does_node_exist(innov)
        return not genome:get_node(innov) == nil
    end

    function genome:add_node()
        table.insert(genome.nodes, new_node(0, "HIDDEN"))
    end

    function genome:delete_node(innov)
        for k, v in pairs(genome.nodes) do
            if innov == v.innov then
                table.remove(genome.nodes, k)
            end
        end
    end

    function genome:add_connection(node1, node2)
        local connect_node = new_connection(node1, node2, math.random(config.weight_min_value, config.weight_max_value))
        -- must add a try except thing to cover nodes that dont exist
        if genome:does_node_exist(node1) and genome:does_node_exist(node2) then
            for k, v in pairs(global_connects) do
                if connect_node.node_in == v.node_in and connect_node.node_out == v.node_out then
                    for k, v in pairs(genome.connects) do
                        if v == connect_node then
                            return
                        end
                    end        
                    connect_node.innov = v.innov
                    table.insert(genome.connects, connect_node)
                    return
                end
            end
            connect_node.innov = connect_gene_innov
            connect_gene_innov = connect_gene_innov + 1

            table.insert(global_connects, connect_node)
            table.insert(genome.connects, connect_node)
        end
    end

    function genome:remove_connection(innov)
        for k, v in pairs(genome.connects) do
            if innov == v.innov then
                table.remove(genome.connects, k)
            end
        end
    end

    function genome:get_in_nodes(innov)
        -- gets all of the nodes that connect to the specific node's input
        local outputs = {}
        for k, v in pairs(genome.connects) do
            if v.node_out == innov and v.enabled then
                table.insert(outputs, {innov = v.node_in, weight = v.weight})
            end
        end
        return outputs
    end

    function genome:eval(level_data)
        local nodes = {}
        for k, v in pairs(map_to_list(level_data)) do table.insert(nodes, new_node(v, "INPUT")) end
        for i=1, genome.num_outputs do table.insert(nodes, new_node(0, "OUTPUT")) end
        for k, v in pairs(genome.nodes) do table.insert(nodes, v) end

        local available_nodes = {}
        for k, v in pairs(nodes) do
            if v.type ~= "INPUT" then
                local in_nodes = genome:get_in_nodes(v.innov)
                local sum = 0
                for k, v in pairs(in_nodes) do
                    if genome:does_node_exist(v.innov) then
                        local val = nil
                        local g = genome:get_node(v.innov)
                        val = g.value

                        sum = sum + val * v.weight
                    end
                end
                v.value = sigmoid(sum)
            end
        end
    end

    function genome:set_joypad_val()
        local inputs = {A = nil, B = nil, right = nil, left = nil, up = nil, down = nil, start = nil, select = nil}
        for k, v in pairs(genome.nodes) do
            if v.type == "OUTPUT" and v.value > 0.9 and v.button ~= "start" then
                inputs[v.button] = true
            end
        end
        joypad.set(1, inputs)

        return inputs
    end

    return genome
end

focus_genome = nil
focus_generation = nil
focus_species = nil

while (true) do
    get_positions()
    local level = get_map()
    read_enemies(level)
    display_map(level)

    focus_genome:eval()
    
    emu.frameadvance()
end