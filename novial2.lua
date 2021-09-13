config = require("config")

math.randomseed(os.time())
math.random(); math.random(); math.random()

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

inputs_keys = {"A", "B", "right", "left", "up", "down", "start", "select"}

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

function element_to_screen(element)
    return {x = (element-1) % 17 + 1, y = math.floor((element-1) / 17) + 1}
end

function cell_to_screen(x, y)
    return {x = x_offset+(x-2)*box_size + box_size/2, y = y_offset+(y-0)*box_size + box_size/2}
    -- return {x = x_offset - box_size/2 + box_size*(x-1), y = y_offset - box_size/2 + box_size*(y-1)}
end

function random_screen_coords()
    return {x = math.random(14*4 + 30, 210 - 50), y = math.random(20 + 10, 50 + 16*4 - 10)}
end

function get_button_coords(button_number)
    return {x = 210, y = y_offset + (button_number-1)*10}
end


function is_same_species(genome1, genome2)
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

    check(genome1, genome2)
    check(genome2, genome1)
    
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

function new_genome()
    local genome = {
        hidden_nodes = {},
        connections = {},
        is_alive = true,
        calculated_fitness = 0
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
        local connect_node = new_connection(node1, node2, math.random(config.weight_min_value, config.weight_max_value) + math.random())
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
    end

    function genome:remove_connection(innov)
        for k, v in pairs(genome.connections) do
            if innov == v.innov then
                table.remove(genome.connections, k)
            end
        end
    end

    function genome:mutate()
        local has_mutate_happen = false
        if config.node_delete_prob > math.random() then
            if #genome.hidden_nodes ~= 0 or #genome.connections ~= 0 then
                genome:delete_node(math.random(1, #genome:get_nodes()))
                has_mutate_happen = true
            end
        end

        if config.node_add_prob > math.random() then
            if #genome.connections ~= 0 then
                genome:add_node()
                has_mutate_happen = true
            end
        end
    
        if config.conn_delete_prob > math.random() and #genome.connections > 0 then
            if #genome.hidden_nodes ~= 0 or #genome.connections ~= 0 then
                genome:remove_connection(math.random(1, #genome.connections))
                has_mutate_happen = true
            end
        end
    
        if config.conn_add_prob > math.random() then
            -- to make it even for the input and hidden nodes to become connected, there will be a 1/2 chance for the type of nodes to be added
            if #genome:get_nodes() > 13*17+8 and 0.5 > math.random(0, 1) then
                genome:add_connection(math.random(13*17+1, #genome:get_nodes()), math.random(13*17+8+1, #genome:get_nodes()))
            else
                genome:add_connection(math.random(1, #genome:get_nodes()), math.random(13*17+1, #genome:get_nodes()))
            end
            has_mutate_happen = true
        end
    
        for k, v in pairs(genome.connections) do
            if config.weight_mutate_rate > math.random() then
                v.weight = math.random(config.weight_min_value, config.weight_max_value) + math.random()
                has_mutate_happen = true
            end
            
            if config.enabled_default and config.enabled_mutate_rate > math.random() then
                if 0.5 > math.random() then
                    v.enabled = true
                else
                    v.enabled = false
                end
                has_mutate_happen = true
            end
        end
        if not has_mutate_happen then
            genome:mutate()
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
        inputs["start"] = nil
        inputs["select"] = nil
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

function copy_genome(genome)
    local g = new_genome()
    for k, v in pairs(genome.hidden_nodes) do
        table.insert(g.hidden_nodes, v)
    end
    for k, v in pairs(genome.connections) do
        table.insert(g.connections, v)
    end
    
    return g
end

function new_species()
    local species = {
        genomes = {}
    }

    function species:mutate_genomes()
        for k, v in pairs(species.genomes) do
            v:mutate()
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

    function species:get_adjusted_fitness(genome_key)
        local g = species.genomes[genome_key]
        local sum = 0
        for k, v in pairs(species.genomes) do
            if k ~= genome_key then
                local spec_com = is_same_species(g, v)
                local thres = 0
                if spec_com < config.compatibility_threshold then
                    thres = 1
                end
                sum = sum + thres
            end
        end
        return g.calculated_fitness / sum
    end

    function species:get_adjusted_fitness_sum()
        local sum = 0
        for k, v in pairs(species.genomes) do
            sum = sum + species:get_adjusted_fitness(k)
        end

        return sum
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
        -- in this function, make it so that it checks the species compatibility 
        -- with others and finds the which is the closest to the threshold value 
        -- in the config.lua file. if it has found two same closest distances,
        -- then it will choose a random species to be assigned
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

    function generation:get_adjusted_fitness_sum()
        local sum = 0
        for k, v in pairs(generation.species) do
            sum = sum + v:get_adjusted_fitness_sum()
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

focus_generation_key = 1
focus_species_key = 1
focus_genome_key = 1
highest_fitness_score = 0
highest_fitness_genome = 0

new_inital_generation(config.pop_size)
focus_generation = generations[focus_generation_key]
focus_generation:mutate_genomes()

-- focus_generation.species[1].genomes[1].connections = {}
-- focus_generation.species[1].genomes[1]:add_connection(13*17, 13*17+3)

focus_species = focus_generation.species[focus_species_key]
focus_genome = focus_species.genomes[focus_genome_key]

function do_this_when_dead()
    focus_genome.calculated_fitness = focus_genome:get_fitness()
    if focus_genome.calculated_fitness > highest_fitness_score then
        highest_fitness_score = focus_genome.calculated_fitness
        highest_fitness_genome = copy_genome(focus_genome)
    end
    if focus_genome.calculated_fitness >= config.fitness_threshold then
        print(focus_genome)
        return
    end
    emu.poweron()
    if focus_species_key == #focus_generation.species then
        -- rewrite this entire mess,
        -- when a new generation is being created, take the top 5 species and take their most successful genome and 
        -- mutate them in relation to the adjusted fitness score sum in a seperate list. after that, delete all of
        -- the old genomes except the top 5 species' genomes, since we already have the good genomes in a seperate 
        -- list. 
        focus_species_key = 1
        focus_genome_key = 1
        local old_pop = focus_generation:get_population_size()
        
        for k, v in pairs(focus_generation.species) do
            v:sort_genomes()
        end

        focus_generation:sort_species()
        local strong_species = {}

        for g=1, tonumber(#focus_generation.species / 2) do
            table.insert(strong_species, focus_generation.species[g])
        end

        local function compare(a,b)
            return a.genomes[1].calculated_fitness > b.genomes[1].calculated_fitness
        end

        table.sort(strong_species, compare)
        local new_gen = new_generation()

        for k, v in pairs(strong_species) do
            local new_spec = new_species()
            local new_genomes_num = get_adjusted_fitness(focus_generation:get_genomes(), v.genomes[1]) / #focus_generation:get_genomes()
            print("creating "..new_genomes_num.." genomes for generation "..(focus_generation_key + 1).."..")
            for i=1, new_genomes_num do
                local g = copy_genome(v.genomes[1])
                g:mutate()
                table.insert(new_gen.unspecified_genomes, g)
            end
            table.insert(new_spec.genomes, copy_genome(v.genomes[1]))
            print("done!")
            table.insert(new_gen.species, new_spec)
        end

        new_gen:find_all_species()
        
        focus_generation = new_gen
        focus_generation_key = focus_generation_key + 1
        focus_species_key = 1
        focus_genome_key = 1
        print(highest_fitness_genome, highest_fitness_score)
    elseif focus_genome_key == #focus_species.genomes then
        focus_species_key = focus_species_key + 1
        focus_genome_key = 1
    else
        focus_genome_key = focus_genome_key + 1
    end
    focus_generation = generations[focus_generation_key]
    focus_species = focus_generation.species[focus_species_key]
    focus_genome = focus_species.genomes[focus_genome_key]
    print("=== Summary =======================")
    print("Generation          : "..focus_generation_key)
    print("Species             : "..focus_species_key)
    print("Genome              : "..focus_genome_key)
    print("Total Pop           : "..focus_generation:get_population_size())
    print("Total Species Pop   : "..#focus_species.genomes)
    print("Highest Fitness     : "..highest_fitness_score)
end

function test_next_gen()
    -- force starts game
    if memory.readbyte(0x0770) == 0 then -- weird solution, i know
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
    gui.drawtext(x_offset - 3, y_offset + - 3 + box_size*16, "gen: "..generation, color1, color2)
    gui.drawtext(x_offset - 3, y_offset + - 3 + box_size*16+8, "species: "..species, color1, color2)
    gui.drawtext(x_offset - 3, y_offset + - 3 + box_size*16+8*2, "genome: "..genome, color1, color2)
    gui.drawtext(x_offset - 3, y_offset + - 3 + box_size*16+8*3, "fitness: "..fitness, color1, color2)
end

is_timer_set = false
start_timeout = 0

function is_not_moving()
    return 0 == memory.readbyte(0x0057)
end

function is_dead()
    if memory.readbyte(0x000E) == 11 then -- 6 is dead, 11 is dying
        return true
    end
    return false
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
    
    test_next_gen()
    draw_info(focus_generation_key, focus_species_key, focus_genome_key, focus_genome:get_fitness())
    -- gui.drawtext(0, 210, "gen: "..focus_generation_key.."  species: "..focus_species_key.."  genome: "..focus_genome_key.."  fitness: "..focus_genome:get_fitness(), color1, color2)
    -- gui.drawtext(0, 220, "developed by novial // andrew hong", color1, color2)

    if get_game_timer() <= start_timeout - 8 and is_timer_set then
        is_timer_set = false
        do_this_when_dead()
    end

    emu.frameadvance()
end