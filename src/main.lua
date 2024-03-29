-- This was programmed by Novial // Andrew
-- Papers used: http://nn.cs.utexas.edu/downloads/papers/stanley.ec02.pdf
--              https://neptune.ai/blog/adaptive-mutation-in-genetic-algorithm-with-python-examples
--              https://www.mdpi.com/2078-2489/10/12/390/pdf

config = require("config")
const = require("const")

Genome = require("neat/genome")
Generation = require("neat/generation")
Species = require("neat/species")
Connection = require("neat/connection")
Node = require("neat/node")

math.randomseed(os.time())

mario_x = 0
mario_y = 0
x_progress = 0

mario_map_x = 0
mario_map_y = 0

current_frame = 0
backup_genomes = {}
moving_objects = {}
inputs_keys = {"A", "B", "right", "left"}
inputs = {}
is_nudged = false
is_timer_set = false
start_timeout = 0
crossover_rate = config.crossover_rate
enabled_crossover_rate_modifier = false
prefix = {
    error = "[Error]: ",
    warning = "[Warning]: ",
    network = "[Network]: "
}

function clear_joypad()
    inputs = {}
    is_nudged = false
    for k, v in pairs(inputs_keys) do
        inputs[inputs_keys[k]] = false
    end

    joypad.set(1, inputs)
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
    gui.drawbox(
        x, y, 
        x + const.box_size, 
        y + const.box_size, 
        color2, 
        color1
    )
end

function draw_map(level)
    local function draw_tile(x, y, color1, color2)
        local x = x - 2
        gui.drawbox(
            const.x_offset + x * const.box_size, 
            const.y_offset + y * const.box_size, 
            const.x_offset + x * const.box_size + const.box_size, 
            const.y_offset + y * const.box_size + const.box_size, 
            color2, 
            color1
        )
    end
    local columns = 16
    local rows = 14
    gui.drawbox(
        const.x_offset - const.box_size,
        const.y_offset + const.box_size,
        const.x_offset + columns * const.box_size,
        const.y_offset + rows * const.box_size,
        const.color2,
        const.color2
    )
    if mario_map_x > 0 and mario_map_x < table.getn(level[1]) and mario_map_y > 0 and mario_map_y < table.getn(level) then
        draw_tile(
            mario_map_x,
            mario_map_y,
            const.color3,
            const.color3
        )
    end
    for y=1, table.getn(level), 1 do
        for x=1, table.getn(level[y]), 1 do
            if level[y][x] == 1 then 
                draw_tile(x, y, const.color1, const.color2) 
            end
            if level[y][x] >= 3 then 
                draw_tile(x, y, const.color4, const.color4) 
            end
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
        local _inputs = joypad.read(1)
        if _inputs[v] then
            gui.drawtext(
                210, 
                const.y_offset + (k-1) * 10, v, 
                const.color1, const.color2
            )
        else
            gui.drawtext(
                210,
                const.y_offset + (k - 1) * 10, v,
                const.color3,
                const.color2
            )
        end
    end
end

function map_to_list(level_data)
    local map_list = {}
    for r=1, #level_data do
        for c=1, #level_data[r] do
            table.insert(map_list, {value = level_data[r][c], x = c, y = r})
        end
    end
    return map_list
end

connect_gene_innov = 1
global_connections = {}

function sigmoid(x)
    return 1 / (1 + math.pow(2.71828, -x))
end

function cell_to_screen(x, y)
    return {
        x = const.x_offset+(x-2)*const.box_size + const.box_size/2,
        y = const.y_offset+(y-0)*const.box_size + const.box_size/2
    }
end

function random_screen_coords()
    return {x = math.random(14*4 + 30, 210 - 50), y = math.random(20 + 10, 50 + 16*4 - 10)}
end

function get_button_coords(button_number)
    return {x = 210, y = const.y_offset + (button_number-1) * 10}
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

function copy_node(node)
    local n = Node.new(node.value, node.type, node.innov)
    n.x = node.x
    n.y = node.y

    return n
end

function copy_connection(connection)
    local c = Connection.new(connection.node_in, connection.node_out, connection.weight)
    c.innov = connection.innov
    c.mutation_modifier = connection.mutation_modifier

    return c
end

function copy_genome(genome)
    local g = Genome.new()
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

function copy_generation(generation)
    local g = Generation.new()
    g.population_size = generation.population_size
    g.species = generation.species
    g.unspecified_genomes = generation.unspecified_genomes

    return g
end

function new_inital_generation(population_size)
    print(prefix.network.."Ready, Set, Go! - Algorithm by Andrew Hong")
    local generation = Generation.new()

    for i=1, population_size do
        table.insert(generation.species, Species.new())
        table.insert(generation.species[i].genomes, Genome.new())
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

                if config.adaptive_mutate_mode == 1 then
                    adaptive_mutate1(v2, average_fitness)
                end

                if config.adaptive_mutate_mode == 2 then
                    adaptive_mutate2(v2)
                end

                if config.adaptive_mutate_mode == 3 then
                    adaptive_mutate3(v2)
                end
                
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

    if not success then
        mutate_conn_add(genome)
    end
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
        if spec_com < config.compatibility_threshold then
            val = 1
        end
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
focus_genome = Genome.new()

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

function load_data(file_name)
    local file = io.open(file_name, "rb")
    local data = Genome.new()

    local function split(inputstr, sep)
        if sep == nil then
           sep = "%s"
        end
        local t={}
        for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
           table.insert(t, str)
        end
        return t
    end

    for line in io.lines(file_name) do
        local split_data = split(line, ", ")
        if split_data[2] == "[node]" then
            if split_data[6] ~= "OUTPUT" and split_data[6] ~= "BIAS" then
                local n = Node.new(0, split_data[6], 0)
                n.x = tonumber(split_data[8]:sub(2))
                n.y = tonumber(split_data[9]:sub(1, -2))

                table.insert(data.hidden_nodes, n)
            end
        elseif split_data[2] == "[conn]" then
            local c = Connection.new(
                tonumber(split_data[8]),
                tonumber(split_data[10]),
                tonumber(split_data[6])
            )
            c.enabled = split_data[12] == "true"
            table.insert(data.connections, c)
        end
    end

    print(data)
    return data
end

function do_this_when_dead()
    x_progress = 0
    clear_joypad()
    local survival_num = #focus_generation.species * config.survival_threshold + 1
    local strong_species_selector_mode = config.strong_species_selector_mode
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
    emu.poweron()
    if focus_species_key == #focus_generation.species then
        local average_fitness = focus_generation:get_fitness_average()
        print(prefix.network.."Global Connections Count : "..#global_connections)
        print(prefix.network.."The average fitness score for generation "..focus_generation_key.." is "..average_fitness)
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

        if strong_species_selector_mode == 2 then
            for k, v in pairs(focus_generation.species) do
                if v.genomes[1].calculated_fitness >= average_fitness then
                    table.insert(strong_species, v)
                end
            end
        end

        print(prefix.network..#strong_species.." species have survived to the next generation")

        local function compare1(a,b)
            return a.genomes[1].calculated_fitness > b.genomes[1].calculated_fitness
        end

        local new_genomes_created = 0
        table.sort(strong_species, compare1)
        local new_gen = Generation.new()
        local carried_over_num = 0

        local average_sum = 0
        for k, v in pairs(strong_species) do
            average_sum = average_sum + v:get_average_fitness()
        end

        for k, v in pairs(strong_species) do
            local new_spec = Species.new()
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
        if #new_gen.species >= 4 then
            print(prefix.network.."Found "..#new_gen.species.." species")
        else
            print(prefix.warning.."Found a low number of species ("..#new_gen.species.." species) Adding 5 backup genomes")
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
    
    -- I have no fucking clue, but I think this function has a memory leak?
    collectgarbage()
end

function test_next_gen()
    if memory.readbyte(0x0770) == 0 then
        joypad.set(1, {start = true})
        emu.frameadvance()
        joypad.set(1, {start = false})
        x_progress = 0
        clear_joypad()
    end

    if memory.readbyte(0x0770) == 1 and focus_genome:get_fitness() >= config.fitness_threshold then -- this was implemented after the simulation started
        write_data("gen"..focus_generation_key, focus_generation)
        print(prefix.network.."ya boi reached it..")
        emu.pause()
        return
    end

    -- new gen
    if is_dead() then do_this_when_dead() end
end

function draw_info(generation, species, genome, fitness)
    local text = {"gen: "..generation, "species: "..species, "genome: "..genome, "fitness: "..fitness}
    for i=0, #text-1 do
        gui.drawtext(
            const.x_offset - 3,
            const.y_offset + - 3 + const.box_size * 16 + 8 * i,
            text[i+1],
            const.color1,
            const.color2
        )
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

emu.poweron()
while (true) do
    get_positions()
    ai_inputs = get_map()
    read_enemies(ai_inputs)
    draw_map(ai_inputs)

    if config.draw_connections then
        focus_genome:draw_connections()
    end

    if config.draw_nodes then
        focus_genome:draw_nodes(false)
    end

    if current_frame % config.reaction_time == 0 then
        focus_genome:eval()
    end

    joypad.set(1, inputs)
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
    if get_game_timer() == start_timeout - 4 and is_timer_set and not is_nudged and config.enable_nudge then
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
    current_frame = current_frame + 1
end
