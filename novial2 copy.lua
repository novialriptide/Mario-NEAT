-- This was programmed by Novial // Andrew
-- Papers used: http://nn.cs.utexas.edu/downloads/papers/stanley.ec02.pdf
--              https://neptune.ai/blog/adaptive-mutation-in-genetic-algorithm-with-python-examples
--              https://www.mdpi.com/2078-2489/10/12/390/pdf

config = require("config")
math.randomseed(os.time())

box_size = 4
x_offset = 20
y_offset = 40
x_bias = 80
y_bias = 100

color1 = {r = 255, g = 0, b = 0, a = 255}
color2 = {r = 93, g = 6, b = 0, a = 255}
color3 = {r = 190, g = 0, b = 0, a = 255}
color4 = {r = 164, g = 0, b = 0, a = 255}
color5 = {r = 22, g = 99, b = 32, a = 255}

color1 = cffff6060
color2 = cff00ccff
color3 = cff00C78C
color4 = cff00FF7F
color5 = cffADFF2F

mario_x = 0
mario_y = 0
x_progress = 0

mario_map_x = 0
mario_map_y = 0

backup_genomes = {}
moving_objects = {}
inputs_keys = {"A", "B", "Right", "Left"}
inputs = {}
is_nudged = false
is_timer_set = false
start_timeout = 0
crossover_rate = config.crossover_rate
enabled_crossover_rate_modifier = false
prefix = {error = "[Error]: ", warning = "[Warning]: ", network = "[Network]: "}

function clear_joypad()
    inputs = {}
    is_nudged = false
    for k, v in pairs(inputs_keys) do
        inputs[inputs_keys[k]] = false
    end

    joypad.set(inputs, 1)
end

function sigmoid(x)
    return 1 / (1 + math.pow(2.71828, -x))
end

function get_game_timer()
    return tonumber(memory.readbyte(0x07F8)..memory.readbyte(0x07F9)..memory.readbyte(0x07FA))
end

function get_positions()
    mario_x = memory.readbyte(0x0086) + memory.readbyte(0x006D) * 256
    mario_y = memory.readbyte(0x03B8)
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
    gui.drawBox(x, y, x+box_size, y+box_size, color2, color1)
end

function draw_map(level)
    local function draw_tile(x, y, color1, color2)
        local x = x - 2
        gui.drawBox(x_offset+x*box_size, y_offset+y*box_size, x_offset+x*box_size+box_size, y_offset+y*box_size+box_size, color2, color1)
    end
    local columns = 16
    local rows = 14
    gui.drawBox(x_offset-box_size, y_offset+box_size, x_offset+columns*box_size, y_offset+rows*box_size, color2, color2)
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
        local _inputs = joypad.get(1)
        if _inputs[v] then
            gui.drawText(210, y_offset + (k-1)*10, v, color1, color2)
        else
            gui.drawText(210, y_offset + (k-1)*10, v, color3, color2)
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
            if not has_value(t2.connections, v.innov) then
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
    if type == "BIAS" then
        coords = {x = 80, y = 100}
    end
    if type == "OUTPUT" then
        coords = get_button_coords(innov - config.num_inputs)
    end
    
    node.x = coords.x
    node.y = coords.y
    
    return node
end

function new_connection(node1, node2, weight)
    return {weight = weight, node_in = node1, node_out = node2, innov = 0, enabled = config.enabled_default, mutation_modifier = 1}
end

function new_genome()
    local genome = {
        hidden_nodes = {}, connections = {}, 
        is_alive = true, calculated_fitness = 0, is_carried_over = false,
        mutation_rates = {
            bias_add_prob = config.bias_add_prob,
            conn_add_prob = config.conn_add_prob,
            conn_delete_prob = config.conn_delete_prob,
            node_add_prob = config.node_add_prob,
            node_delete_prob = config.node_delete_prob,
            enabled_mutate_prob = config.enabled_mutate_prob,
            weight_mutate_prob = config.weight_mutate_prob,
            weight_add_value = config.weight_add_value
        }
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

        _innov = _innov + 1
        table.insert(nodes, new_node(1, "BIAS", _innov))

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

    function genome:split_connection(connection, node_innov)
        local c1 = copy_connection(connection)
        local c2 = copy_connection(connection)
        c1.node_out = node_innov
        c1.innov = 0
        c2.node_in = node_innov
        c2.innov = 0

        return {c1, c2}
    end

    function genome:add_connection(node1, node2, weight)
        if genome:get_node(node2).type == "BIAS" or genome:get_node(node2).type == "INPUT" then
            return false
        end

        local connect_node = new_connection(node1, node2, math.random(config.weight_min_value, config.weight_max_value) + math.random())
        if weight ~= nil then
            connect_node.weight = weight
        end

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

        return true
    end

    function genome:remove_connection(innov)
        for k, v in pairs(genome.connections) do
            if innov == v.innov then
                table.remove(genome.connections, k)
            end
        end
    end

    function genome:add_bias(innov)
        genome:add_connection(config.num_inputs + #inputs_keys + 1, innov)
    end

    function genome:add_node()
        table.insert(genome.hidden_nodes, new_node(0, "HIDDEN"))
        local rand_conn_key = math.random(1, #genome.connections)
        local rand_conn = genome.connections[rand_conn_key]
        local node_innov = #inputs_keys + config.num_inputs + #genome.hidden_nodes + 1
        local new_connections = genome:split_connection(rand_conn, node_innov)
        table.remove(genome.connections, rand_conn_key)
        for k, v in pairs(new_connections) do
            genome:add_connection(v.node_in, v.node_out)
        end
    end

    function genome:delete_node(innov)
        for k, v in pairs(genome.hidden_nodes) do
            if innov == v.innov then
                if v.type == "BIAS" then
                    return false
                end
                table.remove(genome.hidden_nodes, k)
                return true
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
            if v.type ~= "INPUT" and v.type ~= "BIAS" then
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
        
        for k, v in pairs(output_nodes) do
            inputs[inputs_keys[k]] = v.value > 0.9
        end

        if inputs["up"] and inputs["down"] then
            inputs["up"] = false
            inputs["down"] = false
        end
        
        if inputs["left"] and inputs["right"] then
            inputs["left"] = false
            inputs["right"] = false
        end

        for k, v in pairs(nodes) do
            if v.type == "HIDDEN" then v.value = 0 end
        end

        return inputs
    end

    function genome:draw_connections()
        for k, v in pairs(genome.connections) do
            if genome:does_node_exist(v.node_in) and genome:does_node_exist(v.node_out) then
                local node_in = genome:get_node(v.node_in)
                local node_out = genome:get_node(v.node_out)
                local converted_coords = {}
                local color = color3
                if v.weight >= 0 then color = color5 end 
                if not v.enabled then color = {r = 0, g = 0, b = 255} end
                
                if node_in.type == "INPUT" then
                    converted_coords = cell_to_screen(node_in.x, node_in.y)
                    gui.drawLine(converted_coords.x, converted_coords.y, node_out.x+box_size/2, node_out.y+box_size/2, color)
                end
                if node_in.type == "HIDDEN" or node_in.type == "BIAS" then
                    gui.drawLine(node_in.x, node_in.y, node_out.x+box_size/2, node_out.y+box_size/2, color)
                end
            end
        end
    end

    function genome:draw_nodes(enable_innovs)
        for k, v in pairs(genome.hidden_nodes) do
            if v.type == "BIAS" or v.type == "HIDDEN" then
                draw_world_tile(v.x, v.y, color1, color2)
                if enable_innovs then gui.text(v.x, v.y, v.innov, color1) end
            end
        end
    end

    function genome:get_fitness()
        local timer = get_game_timer()
        local score = timer + mario_x
        return score
    end

    function genome:reset_mutation_rates()
        local new_m_rates = {}
        for k, v in pairs(genome.mutation_rates) do
            new_m_rates[k] = config[k]
        end
        genome.mutation_rates = new_m_rates
        
        return g
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
    c.mutation_modifier = connection.mutation_modifier

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

    local new_m_rates = {}
    for k, v in pairs(genome.mutation_rates) do
        new_m_rates[k] = v
    end
    g.mutation_rates = new_m_rates
    
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

        return sum / #species.genomes
    end

    function species:get_fitness_sum()
        local sum = 0
        for k, v in pairs(species.genomes) do
            sum = sum + species.genomes[k]:get_fitness()
        end

        return sum
    end

    function species:sort_genomes()
        for k, v in pairs(species.genomes) do
            if v.is_carried_over then
                table.insert(v, 1, table.remove(v, k))
            end
        end
        
        local function compare(a,b)
            if a.calculated_fitness ~= b.calculated_fitness then
                return a.calculated_fitness > b.calculated_fitness
            end

            return #a.hidden_nodes + #a.connections < #b.hidden_nodes + #b.connections
        end

        table.sort(species.genomes, compare)
    end

    function species:reset_mutation_rates()
        for k, v in pairs(species.genomes) do
            v:reset_mutation_rates()
        end
    end

    return species
end

function new_generation()
    local generation = {
        species = {},
        unspecified_genomes = {}
    }

    function generation:mutate_genomes()
        print(prefix.network.."Mutating...")
        for k, v in pairs(generation.species) do
            v:mutate_genomes()
        end
        print(prefix.network.."Mutation Complete!")
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
            return true
        end

        return false
    end

    function generation:find_all_species()
        local species_found = 0
        for k, v in pairs(generation.unspecified_genomes) do
            if generation:_find_species(v) then
                species_found = species_found + 1
            end
        end

        generation.unspecified_genomes = {}
        return species_found
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

    function generation:reset_mutation_rates()
        for k, v in pairs(generation.species) do
            v:reset_mutation_rates()
        end
    end

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
    print(prefix.network.."Ready, Set, Go! - Algorithm by Novial")
    local generation = new_generation()

    for i=1, population_size do
        table.insert(generation.species, new_species())
        table.insert(generation.species[i].genomes, new_genome())
    end

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

function get_connection_innovs(connections)
    local innovs = {}

    for k, v in pairs(connections) do
        table.insert(innovs, v.innov)
    end

    return innovs
end

function adaptive_mutate1(genome, average_fitness)
    local percentage_increase = 0
    if genome.calculated_fitness >= average_fitness then
        percentage_increase = (1 - config.adaptive_mutate_rate)
    else
        percentage_increase = (1 + config.adaptive_mutate_rate)
    end
    
    local new_m_rates = {}
    for k, v in pairs(genome.mutation_rates) do
        new_m_rates[k] = v * percentage_increase
    end
    genome.mutation_rates = new_m_rates
end

function adaptive_mutate2(genome)
    for k, v in pairs(genome.connections) do
        if math.random() >= 0.5 then
            v.mutation_modifier = v.mutation_modifier * (1 + config.adaptive_mutate_rate)
        else
            v.mutation_modifier = v.mutation_modifier * (1 - config.adaptive_mutate_rate)
        end
    end
end

function adaptive_mutate3(genome)
    local new_m_rates = {}
    for k, v in pairs(genome.mutation_rates) do
        if math.random() >= 0.5 then
            new_m_rates[k] = v * (1 + config.adaptive_mutate_rate)
        else
            new_m_rates[k] = v * (1 - config.adaptive_mutate_rate)
        end
    end
    genome.mutation_rates = new_m_rates
end

function adaptive_mutate()
    if config.adaptive_mutate_mode ~= 0 then
        for k1, v1 in pairs(focus_generation.species) do
            for k2, v2 in pairs(v1.genomes) do
                if config.adaptive_mutate_mode == 1 then adaptive_mutate1(v2, average_fitness) end
                if config.adaptive_mutate_mode == 2 then adaptive_mutate2(v2) end
                if config.adaptive_mutate_mode == 3 then adaptive_mutate3(v2) end
            end
        end
    end
end

function mutate_weight_conn(genome, conn)
    if config.weight_add_prob > math.random() then
        conn.weight = conn.weight + math.random() * genome.mutation_rates.weight_add_value
    else
        conn.weight = math.random(config.weight_min_value, config.weight_max_value) + math.random()
    end
end

function mutate_node_delete(genome)
    if #genome.hidden_nodes > 1 and #genome.connections > 0 then
        genome:delete_node(math.random(1, #genome:get_nodes()))
    end
end

function mutate_conn_delete(genome)
    if #genome.hidden_nodes > 0 and #genome.connections > 1 then
        genome:remove_connection(math.random(1, #genome.connections))
    end
end

function mutate_conn_add(genome)
    -- to make it even for the input and hidden nodes to become connected, there will be a 1/2 chance for the type of nodes to be added
    local success = false
    if #genome:get_nodes() > config.num_inputs+#inputs_keys and 0.5 > math.random() then
        success = genome:add_connection(math.random(config.num_inputs+1, #genome:get_nodes()), math.random(config.num_inputs+#inputs_keys+1, #genome:get_nodes()))
    else
        success = genome:add_connection(math.random(1, #genome:get_nodes()), math.random(config.num_inputs+1, #genome:get_nodes()))
    end

    if success == false then mutate_conn_add(genome) end
end

function mutate_node_add(genome)
    if #genome.connections ~= 0 then
        genome:add_node()
    end
end

function mutate_bias_add(genome)
    genome:add_bias(math.random(config.num_inputs + 1, #genome:get_nodes()))
end

function mutate(genome)
    for k, v in pairs(genome.connections) do
        if genome.mutation_rates.weight_mutate_prob * v.mutation_modifier > math.random() then
            mutate_weight_conn(genome, v)
        end
        
        if genome.mutation_rates.enabled_mutate_prob * v.mutation_modifier > math.random() then
            v.enabled = 0.5 > math.random()
        end
    end

    local function mutate_type(prob, func)
        for i=1, math.floor(prob) do func(genome) end
        if prob - math.floor(prob) > math.random() then func(genome) end
    end

    mutate_type(genome.mutation_rates.node_delete_prob, mutate_node_delete)
    mutate_type(genome.mutation_rates.conn_delete_prob, mutate_conn_delete)
    mutate_type(genome.mutation_rates.conn_add_prob, mutate_conn_add)
    mutate_type(genome.mutation_rates.node_add_prob, mutate_node_add)
    mutate_type(genome.mutation_rates.bias_add_prob, mutate_bias_add)
end

function crossover(genome1, genome2)
    local primary_genome = copy_genome(genome1)
    local secondary_genome = copy_genome(genome2)
    if genome1.calculated_fitness < genome2.calculated_fitness then
        primary_genome = copy_genome(genome2)
        secondary_genome = copy_genome(genome1)
    end

    for k1, v1 in pairs(primary_genome.connections) do
        for k2, v2 in pairs(secondary_genome.connections) do
            if v1.innov == v2.innov then
                if math.random() >= 0.5 then
                    primary_genome.connections[k1] = v2 
                end
            end
        end
    end

    return primary_genome
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

focus_generation = new_inital_generation(config.population)
adaptive_mutate()
focus_generation:mutate_genomes()
focus_species = focus_generation.species[focus_species_key]
focus_genome = focus_species.genomes[focus_genome_key]

--[[
focus_genome.connections = {}
focus_genome:add_connection(196, 222, -10)
focus_genome:add_node()
focus_genome.connections[1].weight = -10
focus_genome.connections[2].weight = 5
focus_genome:add_connection(226, 224, 10)
focus_genome:add_connection(161, 222, 10)
focus_genome:add_connection(179, 222, 10)
]]--
function write_data(file_name, data)
    local function compile_data(data)
        local compiled_data = "crossover rate: "..crossover_rate..""
        for k1, v1 in pairs(data.species) do
            for k2, v2 in pairs(v1.genomes) do
                compiled_data = compiled_data.."\n species: "..k1..", genome: "..k2.. ", fitness score: "..v2.calculated_fitness
                for k3, v3 in pairs(v2:get_nodes()) do
                    if v3.type ~= "INPUT" then
                        compiled_data = compiled_data.."\n - [node] value: "..v3.value..", type: "..v3.type..", coords: ("..v3.x..","..v3.y..")"
                    end
                end

                for k3, v3 in pairs(v2.connections) do
                    local enabled_str = "true"
                    if v3.enabled then enabled_str = "true" end
                    if not v3.enabled then enabled_str = "false" end
                    compiled_data = compiled_data.."\n - [conn] innov: "..v3.innov..", weight: "..v3.weight..", node_in: "..v3.node_in..", node_out: "..v3.node_out..", enabled: "..enabled_str..", mod: "..v3.mutation_modifier
                end

                for k3, v3 in pairs(v2.mutation_rates) do
                    compiled_data = compiled_data.."\n - [mrate] "..k3..": "..v3
                end
            end
        end

        return compiled_data
    end
    local file, err = io.open("saves/"..file_name..".txt", "w")
    if file == nil then
        print(prefix.error.."Could not open file [".. err.."]")
    else
        file:write(compile_data(data))
        file:close()
    end
end

function load_gen(file_name)
    -- broken
    local file = io.open(file_name, "rb")
    local data_gen = new_generation()
    table.insert(data_gen.species, new_species())
    local data = new_genome()

    local function split(inputstr, sep)
        if sep == nil then sep = "%s" end
        local t = {}
        for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
           table.insert(t, str)
        end
        return t
    end

    local current_species = 1
    local current_genome = 1
    local line_num = 1
    for line in io.lines(file_name) do
        local split_data = split(line, ", ")

        if split_data[1] == "species:" and line_nums ~= 2 then
            if tonumber(split_data[2]) > current_species then
                table.insert(data_gen.species[current_species].genomes, data)
                data = new_genome()
                table.insert(data_gen.species, new_species())
                current_species = current_species + 1
            else
                table.insert(data_gen.species[current_species].genomes, data)
                data = new_genome()
            end
        elseif split_data[2] == "[node]" then
            if split_data[6] ~= "OUTPUT" and split_data[6] ~= "BIAS" then
                local n = new_node(0, split_data[6], 0)
                n.x = tonumber(split_data[8]:sub(2))
                n.y = tonumber(split_data[9]:sub(1, -2))

                table.insert(data.hidden_nodes, n)
            end
        elseif split_data[2] == "[conn]" then
            local c = new_connection(
                tonumber(split_data[8]),
                tonumber(split_data[10]),
                tonumber(split_data[6])
            )
            c.enabled = split_data[12] == "true"
            table.insert(data.connections, c)
        end

        line_num = line_num + 1
    end

    return data_gen
end

function do_this_when_dead()
    x_progress = 0
    clear_joypad()
    local survival_num = #focus_generation.species * config.survival_threshold + 1
    local strong_species_selector_mode = config.strong_species_selector_mode
    -- local survival_num = math.min(#focus_generation.species, 2)
    focus_genome.calculated_fitness = focus_genome:get_fitness()

    if focus_species_key == #focus_generation.species then
        if highest_fitness_score >= highest_fitness_score_generation then
            num_no_changes = num_no_changes + 1
        else
            num_no_changes = 0
        end
    end

    if focus_genome.calculated_fitness > highest_fitness_score then
        highest_fitness_score = focus_genome.calculated_fitness
        highest_fitness_genome = copy_genome(focus_genome)
        print(prefix.network.."Highest Fitness Net : "..highest_fitness_score)
    end
    if focus_genome.calculated_fitness > highest_fitness_score_generation then
        highest_fitness_score_generation = focus_genome.calculated_fitness
        print(prefix.network.."Highest Fitness Gen : "..highest_fitness_score_generation)
    end
    client.reboot_core()
    if focus_species_key == #focus_generation.species then
        print(prefix.network.."The average fitness score for generation "..focus_generation_key.." is "..focus_generation:get_fitness_sum() / #focus_generation:get_genomes())
        if num_no_changes > config.emergency_reproduce and strong_species_selector_mode ~= 0 and config.enable_emergency_reproduce then
            print(prefix.warning.."Changing strong_species_selector_mode to 0")
            strong_species_selector_mode = 0
        end

        if num_no_changes > config.on_reset_generations then
            print(prefix.warning.."It looks like we reached a local minima... Resetting every genome's mutation rates and widening search by decreasing crossover rate")
            focus_generation:reset_mutation_rates()
            num_no_changes = 0
            crossover_rate = 0
            enabled_crossover_rate_modifier = true
        end

        write_data("gen"..focus_generation_key, focus_generation)
        focus_species_key = 1
        focus_genome_key = 1
        for k, v in pairs(focus_generation.species) do
            v:sort_genomes()
        end

        focus_generation:sort_species()
        local average_fitness = focus_generation:get_fitness_sum() / #focus_generation.get_genomes()
        adaptive_mutate()

        local strong_species = {}
        if strong_species_selector_mode == 0 then
            for k, v in pairs(focus_generation.species) do
                if v.genomes[1].calculated_fitness >= highest_fitness_score_generation - config.margin_error_value then
                    table.insert(strong_species, v)
                end
            end
        end

        if strong_species_selector_mode == 1 then
            for g=1, survival_num do 
                table.insert(strong_species, focus_generation.species[g])
            end
        end

        print(prefix.network..#strong_species.." species have survived to the next generation")

        local function compare1(a,b)
            return a.genomes[1].calculated_fitness > b.genomes[1].calculated_fitness
        end
        
        local function compare2(a,b)
            return a.calculated_fitness > b.calculated_fitness
        end

        local new_genomes_created = 0
        table.sort(strong_species, compare1)
        local new_gen = new_generation()
        local carried_over_num = 0

        local average_sum = 0
        for k, v in pairs(strong_species) do
            average_sum = average_sum + v:get_average_fitness()
        end

        for k, v in pairs(strong_species) do
            local new_spec = new_species()
            local new_genomes_num = 0
            if config.use_adjusted_fitness then 
                new_genomes_num = get_adjusted_fitness_sum(focus_generation:get_genomes(), v.genomes) / #focus_generation:get_genomes()
            else
                new_genomes_num = (v:get_average_fitness() / average_sum) * config.population
            end
            if v.genomes[1].is_carried_over then
                carried_over_num = carried_over_num + 1
            end
            local prev_g = copy_genome(v.genomes[1])
            prev_g.is_carried_over = true
            table.insert(new_spec.genomes, prev_g)
            for i=1, new_genomes_num do
                local g = {}
                if math.random() > crossover_rate then
                    g = copy_genome(v.genomes[1])
                else
                    g = crossover(v.genomes[math.random(1, #v.genomes)], v.genomes[math.random(1, #v.genomes)])
                end

                mutate(g)
                table.insert(new_gen.unspecified_genomes, g)
                new_genomes_created = new_genomes_created + 1
            end
            table.insert(new_gen.species, new_spec)
        end

        print(prefix.network.."Backing up "..config.backup_per_gen.." genomes")
        for i=1, config.backup_per_gen do
            table.insert(backup_genomes, copy_genome(new_gen:get_genomes()[math.random(1, #new_gen:get_genomes())]))
        end

        print(prefix.network.."Created "..new_genomes_created.." genomes")
        print(prefix.network.."Carried over "..carried_over_num.." genomes")
        local species_found_num = new_gen:find_all_species() + carried_over_num
        if species_found_num >= 4 then
            print(prefix.network.."Found "..species_found_num.." species")
        else
            print(prefix.warning.."Found a low number of species ("..species_found_num.." species) Adding 5 backup genomes")
            for i=1, config.backup_per_gen do
                table.insert(new_gen.unspecified_genomes, copy_genome(backup_genomes[math.random(1, #backup_genomes)]))
            end
            new_gen:find_all_species()
        end

        focus_generation_key = focus_generation_key + 1
        focus_generation = new_gen
        focus_species_key = 1
        focus_genome_key = 1
        highest_fitness_score_generation = 0

        if enabled_crossover_rate_modifier then
            enabled_crossover_rate_modifier = false
            crossover_rate = config.crossover_rate
        end
    elseif focus_genome_key == #focus_species.genomes then
        focus_species_key = focus_species_key + 1
        focus_genome_key = 1
    else
        focus_genome_key = focus_genome_key + 1
    end
    if focus_generation:get_population_size() == 0 then
        print(prefix.error.."Extinction")
    end

    focus_species = focus_generation.species[focus_species_key]
    focus_genome = focus_species.genomes[focus_genome_key]
end

function test_next_gen()
    if memory.readbyte(0x0770) == 0 then
        joypad.set({Start = true}, 1)
        emu.frameadvance()
        joypad.set({Start = false}, 1)
        x_progress = 0
        clear_joypad()
    end

    if memory.readbyte(0x0770) == 1 and focus_genome:get_fitness() >= config.fitness_threshold then -- this was implemented after the simulation started
        write_data("gen"..focus_generation_key, focus_generation)
        print(prefix.network.."ya boi reached it..")
        print(focus_genome)
        return
    end

    -- new gen
    if is_dead() then do_this_when_dead() end
end

function draw_info(generation, species, genome, fitness)
    local text = {"gen: "..generation, "species: "..species, "genome: "..genome, "fitness: "..fitness}
    for i=0, #text-1 do
        gui.drawText(x_offset - 3, y_offset + - 3 + box_size*16+8*i, text[i+1], color1, color2)
    end
end

function is_moving()
    return 0 ~= memory.readbyte(0x0057)
end

function is_moving2()
    return mario_x > x_progress
end

function update_x_progress()
    if mario_x > x_progress then
        x_progress = mario_x
    end
end

function is_dead()
    return memory.readbyte(0x000E) == 0x0B or memory.readbyte(0x000E) == 0x06 -- 6 is dead, 11 is dying
end

-- focus_genome = load_gen("saves/gen1.txt")
client.reboot_core()
while (true) do
    get_positions()
    ai_inputs = get_map()
    read_enemies(ai_inputs)
    draw_map(ai_inputs)
    focus_genome:draw_connections()
    focus_genome:draw_nodes(false)
    focus_genome:eval()
    joypad.set(inputs, 1)
    draw_buttons()
    draw_info(focus_generation_key, focus_species_key, focus_genome_key, focus_genome:get_fitness())

    if not is_moving2() and not is_timer_set and get_game_timer() ~= 0 then
        is_timer_set = true
        start_timeout = get_game_timer()
    end
    if is_moving2() then
        is_timer_set = false
        is_nudged = false
    end
    if get_game_timer() == start_timeout - 4 and is_timer_set and not is_nudged then
        clear_joypad()
        is_nudged = true
    end

    if get_game_timer() <= start_timeout - 8 and is_timer_set then
        is_timer_set = false
        is_nudged = false
        do_this_when_dead()
    end

    test_next_gen()
    update_x_progress()
    emu.frameadvance()
end