-- This was programmed by Novial // Andrew
-- Paper used: http://nn.cs.utexas.edu/downloads/papers/stanley.ec02.pdf

config = require("config")

math.randomseed(os.time())
math.random(); math.random(); math.random() -- agony agony agony agony agony agony agony

LOG_MUTATIONS = false
box_size = 4
x_offset = 20
y_offset = 40

color1 = 0xFF0000FF
color2 = 0x400000FF
color3 = 0xDD0000FF
color4 = 0xAA0000FF

mario_x = 0
mario_y = 0

mario_map_x = 0
mario_map_y = 0

mario_x_screen_scroll = 0
moving_objects = {}
inputs_keys = {"A", "B", "right", "left", "up", "down"}

function sigmoid(x)
    return 1 / (1 + math.pow(2.71828, -x))
end

function get_game_timer()
    return tonumber(memory.readbyte(0x07F8)..memory.readbyte(0x07F9)..memory.readbyte(0x07FA))
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
    if byte ~= 0 and byte ~= 194 then return 1 end
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
    mario_map_x = 8
    mario_map_y = math.floor(memory.readbyte(0x00CE) / 16)
    return level_map
end
ai_inputs = get_map()

function draw_world_tile(x, y, color1, color2)
    gui.drawbox(x, y, x+box_size, y+box_size, color2, color1)
end

function draw_map(level)
    local function draw_tile(x, y, color1, color2)
        local x = x - 2
        gui.drawbox(x_offset+x*box_size, y_offset+y*box_size, x_offset+x*box_size+box_size, y_offset+y*box_size+box_size, color2, color1)
    end
    local columns = 16
    local rows = 14
    gui.drawbox(x_offset-box_size, y_offset+box_size, x_offset+columns*box_size, y_offset+rows*box_size, color2, color2)
    if mario_map_x > 0 and mario_map_x < table.getn(level[1]) and mario_map_y > 0 and mario_map_y < table.getn(level) then
        draw_tile(mario_map_x, mario_map_y, color3, color3)
    end
    for y=1, table.getn(level), 1 do
        for x=1, table.getn(level[y]), 1 do
            if level[y][x] == 1 then draw_tile(x, y, color1, color2) end
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
                level[s_ey][s_ex] = 3 + 1 / memory.readbyte(0x0016 + _e)
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

function cell_to_screen(x, y)
    return {x = x_offset+(x-2)*box_size + box_size/2, y = y_offset+(y-0)*box_size + box_size/2}
end

function random_screen_coords()
    return {x = math.random(14*4 + 30, 210 - 50), y = math.random(20 + 10, 50 + 16*4 - 10)}
end

function get_button_coords(button_number)
    return {x = 210, y = y_offset + (button_number-1)*10}
end

function get_diff_genes(genome1, genome2)
    local diff_genes = {}
    local function check(t1, t2)
        local function has_value(table, value)
            for k, v in pairs(table) do
                if v.innov == value then
                    return true
                end
            end
            return false
        end
        
        for k, v in pairs(t1.connections) do
            if has_value(t2.connections, v.innov) == false then
                table.insert(diff_genes, v)
            end
        end
    end

    check(genome1, genome2)
    check(genome2, genome1)

    return diff_genes
end

function is_same_species(genome1, genome2)
    local function get_average_weight(genome)
        local average = 0
        for k, v in pairs(genome.connections) do 
            average = average + v.weight
        end
        if #genome.connections == 0 then
            return 0
        else
            return average / #genome.connections
        end
    end
    
    local diff_genes = get_diff_genes(genome1, genome2)
    local N = #genome1.connections
    if #genome1.connections < #genome2.connections then
        N = #genome2.connections
    end
    if #genome1.connections < 20 and #genome2.connections < 20 then
        N = 1
    end
    
    local eqtn = ((#diff_genes) / N) + (get_average_weight(genome1) - get_average_weight(genome2))
    return eqtn
end

function new_node(value, type, innov)
    local node = {innov = innov, value = value, type = type, x = 0, y = 0}
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
    return {weight = weight, node_in = node1, node_out = node2, innov = 0, enabled = true}
end

function new_genome()
    local genome = {hidden_nodes = {}, connections = {}, is_alive = true, calculated_fitness = 0}
    
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
        local connect_node = new_connection(node1, node2, math.random(config.weight_min_value, config.weight_max_value) + math.random())
        -- must add a try except thing to cover nodes that dont exist
        if genome:does_node_exist(node1) and genome:does_node_exist(node2) then
            for k, v in pairs(global_connections) do
                if connect_node.node_in == v.node_in and connect_node.node_out == v.node_out then
                    for k, v in pairs(genome.connections) do
                        -- test if the connection is already implemented
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

    function genome:get_fitness()
        local timer = get_game_timer()
        local score = timer + mario_x
        return score
    end

    return genome
end

function copy_node(node)
    local n = new_node(node.value, node.type, node.innov)
    n.x = node.x
    n.y = node.y

    return n
end

function copy_connection(connection)
    local c = new_connection(connection.node_in, connection.node_out, connection.weight)
    c.innov = connection.innov

    return c
end

function copy_genome(genome)
    local g = new_genome()
    for k, v in pairs(genome.hidden_nodes) do
        local n = copy_node(v)
        table.insert(g.hidden_nodes, n)
    end
    for k, v in pairs(genome.connections) do
        local c = copy_connection(v)
        table.insert(g.connections, c)
    end
    
    return g
end

function new_species()
    local species = {
        genomes = {}
    }

    function species:mutate_genomes()
        for k, v in pairs(species.genomes) do
            mutate(v)
        end
    end

    function species:species_eval(genome)
        return is_same_species(genome, species.genomes[1])
    end

    function species:get_average_fitness()
        local sum = 0
        for k, v in pairs(species.genomes) do
            sum = sum + v.calculated_fitness
        end

        return sum / #genomes
    end

    function species:get_fitness_sum()
        local sum = 0
        for k, v in pairs(species.genomes) do
            sum = sum + species.genomes[k]:get_fitness()
        end

        return sum
    end

    function species:sort_genomes()
        local function compare(a,b)
            return a.calculated_fitness > b.calculated_fitness
        end

        table.sort(species.genomes, compare)
    end

    return species
end

generations = {}

function new_generation()
    local generation = {
        species = {},
        unspecified_genomes = {}
    }

    function generation:mutate_genomes()
        print("Mutating...")
        for k, v in pairs(generation.species) do
            v:mutate_genomes()
        end
        print("Mutation Complete!")
    end

    function generation:_find_species(genome)
        local function new_species_data(species_innov, species_dis)
            return {species_innov = species_innov, species_dis = species_dis}
        end
        local search_results = {}
        for k, v in pairs(generation.species) do
            local thres = v:species_eval(genome)
            if thres < config.compatibility_threshold then
                table.insert(search_results, new_species_data(k, thres))
            end
        end
        
        local function compare(a,b)
            return a.species_dis > b.species_dis
        end

        table.sort(search_results, compare)
        if next(search_results) then
            table.insert(generation.species[search_results[1].species_innov].genomes, genome)
        end
        if not next(search_results) then
            local species = new_species()
            table.insert(species.genomes, genome)
            table.insert(generation.species, species)
            print("new species found")
        end
    end

    function generation:find_all_species()
        for k, v in pairs(generation.unspecified_genomes) do
            generation:_find_species(v)
        end

        generation.unspecified_genomes = {}
    end

    function generation:get_population_size()
        local pop = 0
        for k, v in pairs(generation.species) do
            pop = pop + #v.genomes
        end

        return pop
    end

    function generation:get_genomes()
        local pop = {}
        for k1, v1 in pairs(generation.species) do
            for k2, v2 in pairs(v1.genomes) do
                table.insert(pop, v2)
            end
        end

        return pop
    end

    function generation:get_fitness_sum()
        local sum = 0
        for k, v in pairs(generation.species) do
            sum = sum + v:get_fitness_sum()
        end

        return sum
    end

    function generation:sort_species()
        local function compare(a,b)
            return a.genomes[1].calculated_fitness > b.genomes[1].calculated_fitness
        end

        table.sort(generation.species, compare)
    end

    table.insert(generations, generation)
    return generation
end

function copy_generation(generation)
    local g = new_generation()
    g.population_size = generation.population_size
    g.species = generation.species
    g.unspecified_genomes = generation.unspecified_genomes

    return g
end

function new_inital_generation(population_size)
    local generation = new_generation()

    for i=1, population_size do
        table.insert(generation.species, new_species())
        table.insert(generation.species[i].genomes, new_genome())
    end

    table.insert(generations, generation)
    return generation
end

function get_same_genes(genome1, genome2)
    local same_genes = {}
    for k1, v1 in pairs(genome1.connections) do
        for k2, v2 in pairs(genome2.connections) do
            if v2.innov == v1.innov then
                table.insert(same_genes, copy_connection(v1))
            end
        end
    end

    return same_genes
end

function get_excess_disjoint_genes(genome1, genome2)
    -- returns genome1 excess and disjoint genes
    local same_genes = get_same_genes(genome1, genome2)
    local diff_genes = {}
    for k1, v1 in pairs(genome1.connections) do
        for k2, v2 in pairs(same_genes) do
            if v1.innov ~= v2.innov then
                table.insert(diff_genes, copy_connection(v1))
            end
        end
    end

    return diff_genes
end

function mutate(genome)
    local has_mutate_happen = false
    if config.node_delete_prob > math.random() then
        if #genome.hidden_nodes > 1 and #genome.connections > 0 then
            if LOG_MUTATIONS then print("node deleted") end
            genome:delete_node(math.random(1, #genome:get_nodes()))
            has_mutate_happen = true
        end
    end

    if config.node_add_prob > math.random() then
        if #genome.connections ~= 0 then
            if LOG_MUTATIONS then print("node added") end
            genome:add_node()
            has_mutate_happen = true
        end
    end

    if config.conn_delete_prob > math.random() and #genome.connections > 0 then
        if #genome.hidden_nodes > 0 and #genome.connections > 1 then
            if LOG_MUTATIONS then print("connection deleted") end
            genome:remove_connection(math.random(1, #genome.connections))
            has_mutate_happen = true
        end
    end

    if config.conn_add_prob > math.random() then
        if LOG_MUTATIONS then print("connection added") end
        -- to make it even for the input and hidden nodes to become connected, there will be a 1/2 chance for the type of nodes to be added
        if #genome:get_nodes() > 13*17+6 and 0.5 > math.random(0, 1) then
            genome:add_connection(math.random(13*17+1, #genome:get_nodes()), math.random(13*17+6+1, #genome:get_nodes()))
        else
            genome:add_connection(math.random(1, #genome:get_nodes()), math.random(13*17+1, #genome:get_nodes()))
        end
        has_mutate_happen = true
    end

    for k, v in pairs(genome.connections) do
        if config.weight_mutate_rate > math.random() then
            v.weight = math.random(config.weight_min_value, config.weight_max_value) + math.random()
            if LOG_MUTATIONS then print("weight mutated ("..v.weight..")") end
            -- has_mutate_happen = true
        end
        
        if config.enabled_default and config.enabled_mutate_rate > math.random() then
            if 0.5 > math.random() then
                if LOG_MUTATIONS then print("connection enabled") end
                v.enabled = true
            else
                if LOG_MUTATIONS then print("connection disabled") end
                v.enabled = false
            end
            -- has_mutate_happen = true
        end
    end
    if not has_mutate_happen then
        mutate(genome)
    end
end

function crossover(genome1, genome2)
    local dis_ex_genes = {}
    local genome = 0
    if genome1.calculated_fitness >= genome2.calculated_fitness then
        dis_ex_genes = get_excess_disjoint_genes(genome1, genome2)
        genome = copy_genome(genome1)
    end
    
    if genome1.calculated_fitness < genome2.calculated_fitness then
        dis_ex_genes = get_excess_disjoint_genes(genome2, genome1)
        genome = copy_genome(genome2)
    end

    local genes = {}
    for k1, v1 in pairs(genome1.connections) do
        for k2, v2 in pairs(genome2.connections) do
            if v1.innov == v2.innov then
                table.insert(genes, {copy_connection(v1), copy_connection(v2)})
            end
        end
    end

    local new_connections = {}
    for k, v in pairs(genes) do
        if math.random() >= 0.5 then table.insert(new_connections, v[1]) end
        if math.random() < 0.5 then table.insert(new_connections, v[2]) end
    end

    local genome_connections = {}
    local n = 0
    for k,v in ipairs(new_connections) do n=n+1; genome_connections[n] = v end
    for k,v in ipairs(dis_ex_genes) do n=n+1; genome_connections[n] = v end
    genome.connections = genome_connections

    return genome
end

function get_adjusted_fitness(genomes, genome)
    sum = 0
    for k, v in pairs(genomes) do
        local spec_com = is_same_species(genome, v)
        local val = 0
        if spec_com < config.compatibility_threshold then val = 1 end
        sum = sum + val
    end
    return genome.calculated_fitness / sum
end

function get_adjusted_fitness_sum(gen_genomes, species_genomes)
    sum = 0
    for k, v in pairs(species_genomes) do
        sum = sum + get_adjusted_fitness(gen_genomes, v)
    end

    return sum
end

num_no_changes = 0
focus_generation_key = 1
focus_species_key = 1
focus_genome_key = 1
highest_fitness_score = 0
highest_fitness_genome = 0
highest_fitness_score_generation = 0

new_inital_generation(config.pop_size)
focus_generation = generations[focus_generation_key]
focus_generation:mutate_genomes()

-- focus_generation.species[1].genomes[1].connections = {}
-- focus_generation.species[1].genomes[1]:add_connection(13*17, 13*17+3)

focus_species = focus_generation.species[focus_species_key]
focus_genome = focus_species.genomes[focus_genome_key]

function write_data(file_name, data)
    local function compile_data(data)
        local compiled_data = ""
        for k1, v1 in pairs(data.species) do
            for k2, v2 in pairs(v1.genomes) do
                compiled_data = compiled_data.."\n species: "..k1..", genome: "..k2.. ", fitness score: "..v2.calculated_fitness
                for k3, v3 in pairs(v2.hidden_nodes) do
                    compiled_data = compiled_data.."\n - [node] value: "..v3.value..", type: "..v3.type..", coords: ("..v3.x..","..v3.y..")"
                end

                for k3, v3 in pairs(v2.connections) do
                    local enabled_str = "true"
                    if v3.enabled then enabled_str = "true" end
                    if not v3.enabled then enabled_str = "false" end
                    compiled_data = compiled_data.."\n - [conn] innov: "..v3.innov..", weight: "..v3.weight..", node_in: "..v3.node_in..", node_out: "..v3.node_out..", enabled: "..enabled_str
                end
            end
        end

        return compiled_data
    end
    file = io.open("saves/"..file_name..".txt", "w")
    file:write(compile_data(data))
    file:close()
end

function do_this_when_dead()
    local survival_num = #focus_generation.species * config.survival_threshold + 1
    focus_genome.calculated_fitness = focus_genome:get_fitness()
    if focus_genome.calculated_fitness > highest_fitness_score then
        highest_fitness_score = focus_genome.calculated_fitness
        highest_fitness_genome = copy_genome(focus_genome)
    end
    if focus_genome.calculated_fitness > highest_fitness_score_generation then
        highest_fitness_score_generation = focus_genome.calculated_fitness
    end
    if focus_genome.calculated_fitness >= config.fitness_threshold then
        write_data("gen"..focus_generation_key, focus_generation)
        print("Threshold reached!!")
        return
    end
    emu.poweron()
    if focus_species_key == #focus_generation.species then
        if highest_fitness_score > highest_fitness_score_generation then
            num_no_changes = num_no_changes + 1
        end
        
        if num_no_changes > 10 then
            survival_num = 2
        end

        write_data("gen"..focus_generation_key, focus_generation)
        focus_species_key = 1
        focus_genome_key = 1
        for k, v in pairs(focus_generation.species) do
            v:sort_genomes()
        end

        focus_generation:sort_species()
        local strong_species = {}
        for g=1, tonumber(survival_num) do
            table.insert(strong_species, focus_generation.species[g])
        end

        local function compare1(a,b)
            return a.genomes[1].calculated_fitness > b.genomes[1].calculated_fitness
        end
        
        local function compare2(a,b)
            return a.calculated_fitness > b.calculated_fitness
        end

        table.sort(strong_species, compare1)
        local new_gen = new_generation()
        for k, v in pairs(strong_species) do
            local new_spec = new_species()
            local new_genomes_num = get_adjusted_fitness_sum(focus_generation:get_genomes(), v.genomes) / #focus_generation:get_genomes()
            print("creating "..new_genomes_num.." genomes for generation "..(focus_generation_key + 1).."..")
            table.insert(new_spec.genomes, copy_genome(v.genomes[1]))
            for i=1, new_genomes_num do
                local g = 0
                if math.random() > 0.5 then
                    g = copy_genome(v.genomes[1])
                else
                    g = crossover(v.genomes[math.random(1, #v.genomes)], v.genomes[math.random(1, #v.genomes)])
                end

                mutate(g)
                table.insert(new_gen.unspecified_genomes, g)
            end
            print("done!")
            table.insert(new_gen.species, new_spec)
        end

        new_gen:find_all_species()
        focus_generation = new_gen
        focus_generation_key = focus_generation_key + 1
        focus_species_key = 1
        focus_genome_key = 1
        highest_fitness_score_generation = 0
    elseif focus_genome_key == #focus_species.genomes then
        focus_species_key = focus_species_key + 1
        focus_genome_key = 1
    else
        focus_genome_key = focus_genome_key + 1
    end
    focus_generation = generations[focus_generation_key]
    focus_species = focus_generation.species[focus_species_key]
    focus_genome = focus_species.genomes[focus_genome_key]
    print("")
    print("Total Pop           : "..focus_generation:get_population_size())
    print("Total Species       : "..#focus_generation.species)
    print("Total Species Pop   : "..#focus_species.genomes)
    print("Highest Fitness Net : "..highest_fitness_score)
    print("Highest Fitness Gen : "..highest_fitness_score_generation)
end

function test_next_gen()
    if memory.readbyte(0x0770) == 0 then
        joypad.set(1, {start = true})
        emu.frameadvance()
        joypad.set(1, {start = false})
    end
    
    -- new gen
    if is_dead() then
        do_this_when_dead()
    end
end

function draw_info(generation, species, genome, fitness)
    local text = {"gen: "..generation, "species: "..species, "genome: "..genome, "fitness: "..fitness}
    for i=0, 3 do
        gui.drawtext(x_offset - 3, y_offset + - 3 + box_size*16+8*i, text[i+1], color1, color2)
    end
end

is_timer_set = false
start_timeout = 0

function is_not_moving()
    return 0 == memory.readbyte(0x0057)
end

function is_dead()
    return memory.readbyte(0x000E) == 0x0B or memory.readbyte(0x000E) == 0x06 -- 6 is dead, 11 is dying
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
    ai_inputs = get_map()
    read_enemies(ai_inputs)
    draw_map(ai_inputs)

    focus_genome:draw_connections()
    focus_genome:draw_nodes()
    focus_genome:eval()
    draw_buttons()
    
    draw_info(focus_generation_key, focus_species_key, focus_genome_key, focus_genome:get_fitness())

    if get_game_timer() <= start_timeout - 8 and is_timer_set then
        is_timer_set = false
        do_this_when_dead()
    end
    test_next_gen()

    emu.frameadvance()
end