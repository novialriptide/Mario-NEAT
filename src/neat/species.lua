module(..., package.seeall)

function new()
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