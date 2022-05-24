module(..., package.seeall)

Species = require("neat/species")

function new()
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
            local species = Species.new()
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

    function generation:get_fitness_average()
        local genomes = generation:get_genomes()
        local sum = 0
        for k, v in pairs(genomes) do
            sum = sum + v.calculated_fitness
        end

        return sum / #genomes
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