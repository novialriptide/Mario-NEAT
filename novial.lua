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
        genome_id = 0,
        calculated_fitness = nil
    }

    function genome:get_node(innov)
        for k, v in pairs(genome.nodes) do 
            if v.innov == innov then
                return v
            end
        end
    end

    function genome:does_node_exist(innov)
        if genome:get_node(innov) == nil then
            return false
        else
            return true
        end
    end

    function genome:add_i_node(x, y) -- create a new method to get hte va
        -- x and y should not be used in NEAT itself
        local world_coords = cell_to_screen(x, y)
        local in_node = {innov = table.getn(genome.nodes)+1, type = "INPUT", x = world_coords.x + box_size/2, y = world_coords.y + box_size/2, cell_x = x, cell_y = y}
        table.insert(genome.nodes, in_node)
    end

    function genome:get_i_value(level_data, innov)
        local g = genome:get_node(innov)
        return level_data[g.cell_y][g.cell_x]
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
        local available_nodes = {}
        for k, v in pairs(genome.nodes) do
            if v.type ~= "INPUT" then
                local in_nodes = genome:get_in_nodes(v.innov)
                local sum = 0
                for k, v in pairs(in_nodes) do
                    if genome:does_node_exist(v.innov) then
                        local val = nil
                        local g = genome:get_node(v.innov)
                        if g.type == "INPUT" then
                            val = genome:get_i_value(level_data, v.innov)
                        else
                            val = g.value
                        end

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
            if v.type == "OUTPUT" and v.value > 0.9 and v.button ~= "start" and v.button ~= "select" then
                inputs[v.button] = true
            end
        end
        joypad.set(1, inputs)

        return inputs
    end

    function genome:get_fitness()
        local timer = get_game_timer() / 100
        local score = timer + mario_x / 10
        return score
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

    function genome:is_dead()
        if memory.readbyte(0x000E) == 11 then -- 6 is dead, 11 is dying
            return true
        end
        return false
    end

    return genome
end

function basic_setup(genome)
    for r=1, table.getn(level) do
        for c=1, table.getn(level[1]) do
            genome:add_i_node(c, r)
        end
    end
    
    for i=1, table.getn(inputs_keys) do
        local coords = get_button_coords(i)
        genome:add_o_node(coords.x, coords.y, inputs_keys[i])
    end
end

function is_same_species(genome1, genome2)
    local diff_genes = {}
    function check(t1, t2)
        local function has_value(table, value)
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
    
    local eqtn = ((#diff_genes) / N) + (get_average_weight(genome1) - get_average_weight(genome2))
    return eqtn
end

function new_generation(number_of_genomes, innov)
    local generation = {
        genomes = {},
        highest_species_id = 1,
        total_genomes = 0,
        innov = innov,
        species_rep = {1}
    }

    function generation:get_genome(genome_id)
        for k, v in pairs(generation.genomes) do
            if v.genome_id == genome_id then
                return v
            end
        end
    end

    function generation:check_species(genome_id)
        print("testing genome_id: ".. genome_id)
        local g = generation.genomes[genome_id]
        local species_found = false
        if #generation.genomes > 0 and has_value(generation.species_rep, genome_id) == false then
            for k, v in pairs(generation.species_rep) do
                local other_g = generation:get_genome(v)
                local species_compatibility = is_same_species(other_g, g)
                print("species rep: "..v..", genome_id: "..g.genome_id..", spec_com: "..species_compatibility)

                if species_compatibility < config.compatibility_threshold then
                    g.species_id = other_g.species_id
                    species_found = true
                end
            end
            
            if not species_found then
                g.species_id = generation.highest_species_id + 1
                generation.highest_species_id = generation.highest_species_id + 1
                generation.species_rep[g.species_id] = g.genome_id
            end
        end
    end

    function generation:check_all_genomes_species()
        for k, v in pairs(generation.genomes) do
            generation:check_species(v.genome_id)
        end
        print(generation.species_rep, #generation.genomes)
    end

    function generation:new_genome()
        local g = new_genome()
        basic_setup(g)
        table.insert(generation.genomes, g)
        g.generation_id = generation.innov
        g.genome_id = #generation.genomes

        return g
    end

    function generation:get_genome(genome_id)
        for k, v in pairs(generation.genomes) do
            if v.genome_id == genome_id then
                return v
            end
        end
    end

    function generation:get_adjusted_fitness(genome_id)
        local g = generation:get_genome(genome_id)
        local sum = 0
        for k, v in pairs(generation.genomes) do
            if v.genome_id ~= genome_id and g.species_id == v.species_id then
                local thres = 0
                if math.abs(v.calculated_fitness - g.calculated_fitness) > config.fitness_threshold then
                    thres = 0
                end
                if math.abs(v.calculated_fitness - g.calculated_fitness) < config.fitness_threshold then
                    thres = 1
                end
                sum = sum + thres
            end
        end
        return g.calculated_fitness / sum
    end

    function generation:get_adjusted_fitness_sum(species_id)
        local sum = 0
        local elements = 0
        for k, v in pairs(generation.genomes) do
            if v.species_id == species_id then
                sum = sum + generation:get_adjusted_fitness(v.genome_id)
                print(generation:get_adjusted_fitness(v.genome_id))
                elements = elements + 1
            end
        end
        return sum
    end

    function generation:get_fitness_sum(species_id)
        local sum = 0
        local elements = 0
        for k, v in pairs(generation.genomes) do
            if v.species_id == species_id then
                sum = sum + v:get_fitness()
                elements = elements + 1
            end
        end
        return sum / elements
    end

    function get_strong_genomes()
        local function compare(a,b)
            return a.calculated_fitness > b.calculated_fitness
        end

        table.sort(gen.genomes, compare)
        local found_species = {}
        local new_genome_list = {}
        for k, v in pairs(gen.genomes) do
            if not has_value(found_species, v.species_id) then
                table.insert(new_genome_list, v)
                table.insert(found_species, v.species_id)
            end
        end
        return new_genome_list
    end
    
    for i = 1, number_of_genomes do
        generation:new_genome()
    end

    return generation
end

function breed(genome1, genome2)

end

function mutate(genome)
    local has_mutate_happen = false
    if config.node_add_prob > math.random() then
        genome:add_h_node()
        has_mutate_happen = true
    end

    if config.node_delete_prob > math.random() then
        genome:delete_node(math.random(1, #genome.nodes))
        has_mutate_happen = true
    end

    if config.conn_add_prob > math.random() then
        -- to make it even for the input and hidden nodes to become connected, there will be a 1/2 chance for the type of nodes to be added
        if #genome.nodes > 229 and 0.5 > math.random(0, 1) then
            genome:add_connection(math.random(222, #genome.nodes), math.random(230, #genome.nodes))
            has_mutate_happen = true
        else
            genome:add_connection(math.random(1, #genome.nodes), math.random(222, #genome.nodes))
            has_mutate_happen = true
        end
    end

    if config.conn_delete_prob > math.random() and #genome.connects > 0 then
        genome:remove_connection(math.random(1, #genome.connects))
        has_mutate_happen = true
    end

    for k, v in pairs(genome.connects) do
        if config.weight_mutate_rate > math.random() then
            v.weight = math.random(config.weight_min_value, config.weight_max_value) + math.random()
            has_mutate_happen = true
        end
        
        if config.enabled_default and config.enabled_mutate_rate > math.random() then
            if 0.5 > math.random() then
                v.enabled = true
                has_mutate_happen = true
            else
                v.enabled = false
                has_mutate_happen = true
            end
        end
    end
    if not has_mutate_happen then
        mutate(genome)
    end
end

function draw_info(generation, species, genome, fitness)
    gui.drawtext(x_offset, y_offset + box_size*16, "gen: "..generation, color1, color2)
    gui.drawtext(x_offset, y_offset + box_size*16+10, "species: "..species, color1, color2)
    gui.drawtext(x_offset, y_offset + box_size*16+10*2, "genome: "..genome, color1, color2)
    gui.drawtext(x_offset, y_offset + box_size*16+10*3, "fitness: "..fitness, color1, color2)
end

generations = {}

gen = new_generation(config.pop_size, 1)
table.insert(generations, gen)
focus_genome = gen.genomes[1]
for i=1, 1 do
    for k, v in pairs(gen.genomes) do
        v.species_id = k
        mutate(v)
        -- mutate(v)
    end
end
-- gen:check_all_genomes_species()

function move_genomes(genomes, gen)
    -- move genomes to new gen
    for k, v in pairs(genomes) do
        v.generation_id = gen.innov
        v.species_id = 1
        v.genome_id = k
    end
    gen.genomes = genomes
end

function do_this_when_dead()
    focus_genome.calculated_fitness = focus_genome:get_fitness()
    emu.poweron()
    if focus_genome.genome_id ~= #gen.genomes then
        focus_genome = gen.genomes[focus_genome.genome_id + 1]
    else
        local new_genomes = get_strong_genomes()
        gen = new_generation(#new_genomes, #generations + 1)
        move_genomes(new_genomes, gen)
        table.insert(generations, gen)
        focus_genome = gen.genomes[1]
        gen:check_all_genomes_species()
        for k, v in pairs(gen.species_rep) do 
            for g=1, gen:get_adjusted_fitness_sum(v) do
                local wow_genome = gen:new_genome()
                wow_genome.nodes = gen:get_genome(v).nodes
                wow_genome.connects = gen:get_genome(v).connects
                for i=1, 15 do
                    mutate(wow_genome)
                    mutate(wow_genome)
                end
            end
        end
    end
end

function test_next_gen()
    -- force starts game
    if memory.readbyte(0x0770) == 0 then -- weird solution, i know
        joypad.set(1, {start = true})
        emu.frameadvance()
        joypad.set(1, {start = false})
    end
    
    -- new gen
    if focus_genome:is_dead() then
        do_this_when_dead()
    end
end

is_timer_set = false
start_timeout = 0

function is_not_moving()
    return 0 == memory.readbyte(0x0057)
end

while (true) do
    if is_not_moving() and not is_timer_set and get_game_timer() ~= 0 then
        is_timer_set = true
        start_timeout = get_game_timer()
    end
    if not is_not_moving() then
        is_timer_set = false
    end

    get_positions()
    local level = get_map()
    read_enemies(level)
    display_map(level)
    display_buttons()
    draw_info(focus_genome.generation_id, focus_genome.species_id, focus_genome.genome_id, focus_genome:get_fitness())
    focus_genome:draw_connections()
    focus_genome:draw_hidden()
    focus_genome:eval(level)
    focus_genome:set_joypad_val()
    test_next_gen()

    if get_game_timer() <= start_timeout - 5 and is_timer_set then
        is_timer_set = false
        do_this_when_dead()
    end
    print(#gen.genomes)
    emu.frameadvance()
end