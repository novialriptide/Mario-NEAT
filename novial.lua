box_size = 4

x_offset = 20
y_offset = 20

color1 = 0xFF0000FF
color2 = 0x400000FF
color3 = 0xDD0000FF
color4 = 0xAA0000FF

mario_x = 0
mario_y = 0
mario_x_screen_scroll = 0

moving_objects = {}

inputs = {A = nil, B = nil, right = nil, left = nil, up = nil, down = nil, start = nil, select = nil}
inputs_keys = {"A", "B", "right", "left", "up", "down", "start", "select"}

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
            if level[y][x] == 3 then draw_tile(x, y, color4, color4) end
        end
    end
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
                level[s_ey][s_ex] = 3
            end
        end
    end
end

node_template = {
    innov = nil
}

function sigmoid(x)
    return 1 / (1 + math.pow(2.71828, -x))
end

function linear_combination(inputs, weights)
    if #inputs == #weights then
        local lc = 0
        for i=1, #inputs do 
            lc = lc + inputs[i] * weights[i]
        end
        return lc
    else 
        print("Error: length of tables inputs and weights are not the same")
    end
end

local a = sigmoid(linear_combination({3,5,5,2}, {0.5,0.1,0.2,0.7}))
print(a)

connect_gene_innov = 1
global_connects = {}

function new_genome()
    local genome = {
        nodes = {}, -- node genes
        connects = {} -- connection genes
    }

    function genome:add_i_node(x, y, val)
        -- x and y should not be used in NEAT itself
        local in_node = {innov = table.getn(genome.nodes)+1, in_val = val, type = "INPUT"}
        table.insert(genome.nodes, in_node)
    end

    function genome:add_h_node()

    end

    function genome:add_o_node(b)
        local out_node = {innov = table.getn(genome.nodes)+1, button = b, type = "OUTPUT"}
        table.insert(genome.nodes, out_node)
    end

    function genome:delete_node(innov)
        for k, v in pairs(genome.nodes) do
            if innov == v.innov then
                table.remove(genome.nodes, k)
            end
        end
    end

    function genome:get_in_nodes(innov)
        
    end

    function genome:add_connection(node1, node2)
        local connect_node = {weight = 1.0, node_in = node1, node_out = node2, innov = nil, enabled = true}
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

    function genome:remove_connection(innov)
        for k, v in pairs(genome.connects) do
            if innov == v.innov then
                table.remove(genome.connects, k)
            end
        end
    end

    function genome:update_i_nodes(start_innov)
        local _innov = start_innov
        for r=1, table.getn(level) do
            for c=1, table.getn(level[1]) do
                genome.nodes[_innov].in_val = level[r][c]
                _innov = _innov + 1
            end
        end
    end

    function genome:get_output()

    end

    function genome:get_fitness()

    end

    return genome
end

function basic_setup(genome)
    for r=1, table.getn(level) do
        for c=1, table.getn(level[1]) do
            genome:add_i_node(c, r, level[r][c])
        end
    end
    
    for i=1, table.getn(inputs_keys) do
        genome:add_o_node(inputs_keys[i])
    end
end

function new_generation(number_of_genomes)
    local generation = {
        genomes = {}
    }

    for i = 1, number_of_genomes do
        g = new_genome()
        basic_setup(g)
        table.insert(generation.genomes, g)
    end
    
    function generation:new_genome()
        local g = new_genome()
        basic_setup(g)
        table.insert(genomes, g)
    end

    function generation:get_average_fitness()
        
    end

    function generation:update_all_genomes()
        for k, v in pairs(genomes) do
            v:update_i_nodes()
        end
    end

    return generation
end

function mutate(genome)
    
end

function breed(genome1, genome2)

end

function is_same_species(genome1, genome2)
    local diff_genes = {}
    function check(t1, t2)
        function has_value(table, value)
            for k, v in pairs(table) do
                if v.innov == value then 
                    return true
                end
            end
            return false
        end
        
        for k, v in pairs(t1.connects) do
            if has_value(t2.connects, v.innov) == false then
                table.insert(diff_genes, v)
            end
        end
    end
    check(genome1, genome2)
    check(genome2, genome1)
    
    local c1 = 1.0
    local c2 = 1.0
    local c3 = 1.0
    local N = #genome1.connects
    if #genome1.connects < #genome2.connects then
        N = #genome2.connects
    end
    return (c1 * #diff_genes) / N
end

function draw_connections()

end

gen = new_generation(5)
-- print(gen.genomes)

while (true) do
    get_positions()
    local level = get_map()
    read_enemies(level)
    display_map(level)
    display_buttons()

    joypad.set(1, inputs)

    emu.frameadvance()
end