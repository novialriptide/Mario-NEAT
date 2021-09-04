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

function sigmoid(x)
    return 1 / (1 + math.pow(2.71828, -x))
end

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
    
    for _y=32, 224, 16 do -- 12
        level_map[c_row] = {}
        for _x=0, 256, 16 do -- 16
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
ai_inputs = get_map()

function draw_world_tile(x, y, color1, color2)
    local x = x - 2
    gui.drawbox(x, y, x+box_size, y+box_size, color2, color1)
end

function draw_map(level)
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

function draw_buttons()
    for k, v in pairs(inputs_keys) do
        local _inputs = joypad.read(1)
        if _inputs[v] then
            gui.drawtext(210, y_offset + (k-1)*10, v, color1, color2)
        else
            gui.drawtext(210, y_offset + (k-1)*10, v, color2, color2)
        end
    end
end

connect_gene_innov = 1
global_connections = {}

function map_to_list(level_data)
    local map_list = {}
    for r=1, #level_data do
        for c=1, #level_data[r] do
            table.insert(map_list, {value = level_data[r][c], x = c, y = r})
        end
    end

    return map_list
end

function element_to_screen(element)
    return {x = (element-1) % 17 + 1, y = math.floor((element-1) / 17) + 1}
end

function cell_to_screen(x, y)
    return {x = x_offset - box_size/2 + box_size*(x-1), y = y_offset - box_size/2 + box_size*(y-1)}
end

function random_screen_coords()
    return {x = math.random(14*4 + 30, 210 - 50), y = math.random(20 + 10, 50 + 16*4 - 10)}
end

function get_button_coords(button_number)
    return {x = 210, y = y_offset + (button_number-1)*10}
end

function new_node(value, type, innov)
    local node = {
        innov = innov,
        value = value, 
        type = type,
        x = 0,
        y = 0
    }

    local coords = {}
    if type == "HIDDEN" then
        coords = random_screen_coords()
    end
    if type == "OUTPUT" then
        coords = get_button_coords(innov - config.num_inputs)
    end
    
    node.x = coords.x
    node.y = coords.y
    
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

function new_genome()
    local genome = {
        hidden_nodes = {},
        connections = {},
        is_alive = true
    }
    
    function genome:get_nodes()
        local nodes = {}
        local _innov = 0
        for k, v in pairs(map_to_list(ai_inputs)) do 
            _innov = _innov + 1
            local _node = new_node(v.value, "INPUT", _innov)
            _node.x = v.x
            _node.y = v.y
            table.insert(nodes, _node)
        end
        for k, v in pairs(inputs_keys) do
            _innov = _innov + 1
            table.insert(nodes, new_node(0, "OUTPUT", _innov))
        end
        for k, v in pairs(genome.hidden_nodes) do
            _innov = _innov + 1
            v.innov = _innov
            table.insert(nodes, v)
        end

        return nodes
    end

    function genome:get_node(innov)
        for k, v in pairs(genome:get_nodes()) do 
            if v.innov == innov then
                return v
            end
        end
    end

    function genome:does_node_exist(innov)
        return genome:get_node(innov) ~= nil
    end

    function genome:add_node()
        table.insert(genome.hidden_nodes, new_node(0, "HIDDEN"))
    end

    function genome:delete_node(innov)
        for k, v in pairs(genome.hidden_nodes) do
            if innov == v.innov then
                table.remove(genome.hidden_nodes, k)
            end
        end
    end

    function genome:add_connection(node1, node2)
        local connect_node = new_connection(node1, node2, math.random(config.weight_min_value, config.weight_max_value))
        -- must add a try except thing to cover nodes that dont exist
        if genome:does_node_exist(node1) and genome:does_node_exist(node2) then
            for k, v in pairs(global_connections) do
                if connect_node.node_in == v.node_in and connect_node.node_out == v.node_out then
                    for k, v in pairs(genome.connections) do
                        if v == connect_node then
                            return
                        end
                    end        
                    connect_node.innov = v.innov
                    table.insert(genome.connections, connect_node)
                    return
                end
            end
            connect_node.innov = connect_gene_innov
            connect_gene_innov = connect_gene_innov + 1

            table.insert(global_connections, connect_node)
            table.insert(genome.connections, connect_node)
        end
        -- print(genome.connections)
    end

    function genome:remove_connection(innov)
        for k, v in pairs(genome.connections) do
            if innov == v.innov then
                table.remove(genome.connections, k)
            end
        end
    end

    function genome:get_in_nodes(innov)
        -- gets all of the nodes that connect to the specific node's input
        local results = {}
        for k, v in pairs(genome.connections) do
            if v.node_out == innov and v.enabled then
                table.insert(results, {innov = v.node_in, weight = v.weight})
            end
        end
        return results
    end

    function genome:eval()
        local nodes = genome:get_nodes()

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

        local output_nodes = {}
        for k, v in pairs(nodes) do
            if v.type == "OUTPUT" then
                table.insert(output_nodes, v)
            end
        end
        
        local inputs = {}
        local inputs_keys = {"A", "B", "right", "left", "up", "down", "start", "select"}
        for k, v in pairs(output_nodes) do
            if v.value > 0.9 then
                inputs[inputs_keys[k]] = true
            end
        end
        joypad.set(1, inputs)

        return inputs
    end

    function genome:draw_connections()
        for k, v in pairs(genome.connections) do
            if genome:does_node_exist(v.node_in) and genome:does_node_exist(v.node_out) and v.enabled then
                local node_in = genome:get_node(v.node_in)
                local node_out = genome:get_node(v.node_out)
                if node_in.type == "INPUT" then
                    print(node_in)
                    local converted_coords = cell_to_screen(node_in.x, node_in.y)
                    gui.drawline(converted_coords.x, converted_coords.y, node_out.x+box_size/2, node_out.y+box_size/2, color3)
                end
            end
        end
    end

    function genome:draw_nodes()
        for k, v in pairs(genome.hidden_nodes) do
            draw_world_tile(v.x, v.y, color1, color2)
        end
    end

    return genome
end

focus_genome = new_genome()
focus_generation = nil
focus_species = nil

focus_genome:add_connection(13*17, 13*17+1)
focus_genome:add_connection(1, 13*17+1)
focus_genome:add_node()
focus_genome:add_node()

print(focus_genome:get_nodes())

while (true) do
    get_positions()
    ai_inputs = get_map()
    read_enemies(ai_inputs)
    draw_map(ai_inputs)

    focus_genome:draw_connections()
    focus_genome:draw_nodes()
    focus_genome:eval()
    draw_buttons()
    
    emu.frameadvance()
end