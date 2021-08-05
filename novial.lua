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
            if level[y][x] == 3 then draw_tile(x, y, color4, color4) end
        end
    end
end

function cell_to_screen(x, y)
    local x = x - 2
    return {x = x_offset+x*box_size, y = y_offset+y*box_size}
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

connect_gene_innov = 1
global_connects = {}

function new_genome()
    local genome = {
        nodes = {}, -- node genes
        connects = {}, -- connection genes
        generation_id = 1,
        species_id = 1,
        genome_id = 1
    }

    function genome:add_i_node(x, y, val)
        -- x and y should not be used in NEAT itself
        local world_coords = cell_to_screen(x, y)
        local in_node = {innov = table.getn(genome.nodes)+1, type = "INPUT", x = world_coords.x + box_size/2, y = world_coords.y + box_size/2, value = val}
        table.insert(genome.nodes, in_node)
    end

    function genome:add_h_node()
        local random_coords = {x = math.random(14*4 + 30, 210 - 50), y = math.random(20 + 10, 20 + 16*4 - 10)}
        local out_node = {innov = table.getn(genome.nodes)+1, type = "HIDDEN", x = random_coords.x, y = random_coords.y, value = 0}
        table.insert(genome.nodes, out_node)
    end

    function genome:add_o_node(x, y, b)
        local out_node = {innov = table.getn(genome.nodes)+1, button = b, type = "OUTPUT", x = x, y = y, value = 0}
        table.insert(genome.nodes, out_node)
    end

    function genome:delete_node(innov)
        for k, v in pairs(genome.nodes) do
            if innov == v.innov and genome:get_node(innov).type ~= "INPUT" and genome:get_node(innov).type ~= "OUTPUT" then
                table.remove(genome.nodes, k)
            end
        end
    end

    function genome:does_node_exist(innov)
        for k, v in pairs(genome.nodes) do 
            if v.innov == innov then
                return true
            end
        end
        return false
    end

    function genome:get_node(innov)
        for k, v in pairs(genome.nodes) do 
            if v.innov == innov then
                return v
            end
        end
        print("Error: node doesn't exist \"", innov, "\". There are currently \"", #genome.nodes, "\" nodes in total")
    end

    function genome:add_connection(node1, node2)
        local connect_node = {weight = math.random(config.weight_min_value, config.weight_max_value), node_in = node1, node_out = node2, innov = nil, enabled = true}
        -- must add a try except thing to cover nodes that dont exist
        if genome:does_node_exist(node1) and genome:does_node_exist(node2) and genome:get_node(node2).type ~= "INPUT" and genome:get_node(node1).type ~= "OUTPUT" then
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

    function genome:update_i_nodes(start_innov)
        local _innov = start_innov
        for r=1, table.getn(level) do
            for c=1, table.getn(level[1]) do
                genome.nodes[_innov].value = level[r][c]
                _innov = _innov + 1
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

    function genome:eval()
        local available_nodes = {}
        for k, v in pairs(genome.nodes) do
            if v.type ~= "INPUT" then
                local in_nodes = genome:get_in_nodes(v.innov)
                local sum = 0
                for k, v in pairs(in_nodes) do
                    if genome:does_node_exist(v.innov) then
                        sum = sum + genome:get_node(v.innov).value * v.weight
                    end
                end
                v.value = sum
            end
        end
    end

    function genome:set_joypad_val()
        local inputs = {A = nil, B = nil, right = nil, left = nil, up = nil, down = nil, start = nil, select = nil}
        for k, v in pairs(genome.nodes) do
            if v.type == "OUTPUT" and v.value > 0 then
                inputs[v.button] = true
            end
        end
        joypad.set(1, inputs)

        return inputs
    end

    function genome:get_fitness()

    end

    function genome:draw_connections()
        for k, v in pairs(genome.connects) do
            if genome:does_node_exist(v.node_in) and genome:does_node_exist(v.node_out) and v.enabled then
                local node_in = genome:get_node(v.node_in)
                local node_out = genome:get_node(v.node_out)
                gui.drawline(node_in.x, node_in.y, node_out.x+box_size/2, node_out.y+box_size/2, color3)
            end
        end
    end

    function genome:draw_hidden()
        for k, v in pairs(genome.nodes) do
            if v.type == "HIDDEN" then
                draw_world_tile(v.x, v.y, color1, color2)
            end
        end
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
        local coords = get_button_coords(i)
        genome:add_o_node(coords.x, coords.y, inputs_keys[i])
    end
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

    function get_average_weight(genome)
        local average = 0
        for k, v in pairs(genome.connects) do 
            average = average + v.weight
        end
        if #genome.connects == 0 then
            return 0
        else
            return average / #genome.connects
        end
    end

    check(genome1, genome2)
    check(genome2, genome1)
    
    local N = #genome1.connects
    if #genome1.connects < #genome2.connects then
        N = #genome2.connects
    end
    if #genome1.connects < 20 and #genome2.connects < 20 then
        N = 1
    end
    return ((#diff_genes) / N) + (get_average_weight(genome1) - get_average_weight(genome2))
end

function new_generation(number_of_genomes, innov)
    local generation = {
        genomes = {},
        highest_species_id = 1,
        innov = innov
    }

    function generation:new_genome()
        local g = new_genome()
        basic_setup(g)
        table.insert(generation.genomes, g)
        g.generation_id = generation.innov
        g.genome_id = #generation.genomes + 1
    end

    function generation:get_genome(genome_id)
        for k, v in pairs(generation.genomes) do
            if v.genome_id == genome_id then
                return v
            end
        end
    end

    function generation:check_species(genome_id)
        local g = generation.genomes[genome_id]
        if #generation.genomes > 0 then
            for k, v in pairs(generation.genomes) do
                local species_compatibility = is_same_species(v, g)
                print(species_compatibility)
                if species_compatibility < config.compatibility_threshold then
                    g.species_id = v.species_id
                    table.insert(generation.genomes, g)
                    return
                end
            end
            
            g.species_id = generation.highest_species_id + 1
            generation.highest_species_id = generation.highest_species_id + 1 
        end
    end

    function generation:get_average_fitness()
        
    end

    function generation:update_all_genomes()
        for k, v in pairs(generation.genomes) do
            v:update_i_nodes(1)
        end
    end
    
    for i = 1, number_of_genomes do
        generation:new_genome()
    end

    return generation
end

function mutate(genome)
    if config.node_add_prob > math.random() then
        -- print("added node")
        genome:add_h_node()
    end

    if config.node_delete_prob > math.random() then
        -- print("deleted node")
        genome:delete_node(math.random(1, #genome.nodes))
    end

    if config.conn_add_prob > math.random() then
        -- print("added conn")
        -- to make it even for the input and hidden nodes to become connected, there will be a 1/2 chance for the type of nodes to be added
        if #genome.nodes > 229 and 0.5 > math.random(0, 1) then
            genome:add_connection(math.random(222, #genome.nodes), math.random(230, #genome.nodes))
        else
            genome:add_connection(math.random(1, #genome.nodes), math.random(222, #genome.nodes))
        end
    end

    if config.conn_delete_prob > math.random() and #genome.connects > 0 then
        -- print("deleted conn")
        genome:remove_connection(math.random(1, #genome.connects))
    end

    for k, v in pairs(genome.connects) do
        if config.weight_mutate_rate > math.random() then
            v.weight = math.random(config.weight_min_value, config.weight_max_value) + math.random()
        end
        
        if config.enabled_default and config.enabled_mutate_rate > math.random() then
            if 0.5 > math.random() then
                v.enabled = true
            else
                v.enabled = false
            end
        end
    end
end

function draw_info(generation, species, genome)
    gui.drawtext(x_offset, y_offset + box_size*16, "gen: "..generation, color1, color2)
    gui.drawtext(x_offset, y_offset + box_size*16+10, "species: "..species, color1, color2)
    gui.drawtext(x_offset, y_offset + box_size*16+10*2, "genome: "..genome, color1, color2)
end

gen = new_generation(5, 1)
-- print(gen)
g1 = gen.genomes[3]
for i=1, 300 do
    mutate(g1)
end
gen:check_species(3)

while (true) do
    -- gui.drawbox(0, 0, 256, 100, 0xFFFFFFFF)
    get_positions()
    local level = get_map()
    read_enemies(level)
    display_map(level)
    display_buttons()
    draw_info(g1.generation_id, g1.species_id, g1.genome_id)
    gen:update_all_genomes()
    g1:draw_connections()
    g1:draw_hidden()
    g1:eval()
    g1:set_joypad_val()

    emu.frameadvance()
end