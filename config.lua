-- Config taken from:
-- https://github.com/CodeReclaimers/neat-python/blob/master/examples/memory-fixed/config

-- NEAT configuration for the fixed-length bit-sequence memory experiment.

-- The `NEAT` section specifies parameters particular to the NEAT algorithm
-- or the experiment itself.  This is the only required section.
--  [NEAT]

config = {
    fitness_criterion     = max,
    fitness_threshold     = 3000, -- found solution
    pop_size              = 300, -- 300,
    reset_on_extinction   = 0,

    -- [DefaultGenome]
    num_inputs              = 13*17,
    num_hidden              = 1,
    num_outputs             = 1,
    -- initial_connection      = partial_direct 0.5
    -- feed_forward            = False
    compatibility_disjoint_coefficient = 1.0,
    compatibility_weight_coefficient   = 0.6,
    conn_add_prob           = 0.50,
    conn_delete_prob        = 0.50,
    node_add_prob           = 0.25,
    node_delete_prob        = 0.25,
    bias_add_prob           = 0.10,
    -- activation_default      = my_sinc_function
    -- activation_options      = sigmoid my_sinc_function
    activation_mutate_rate  = 0.1,
    -- aggregation_default     = sum
    -- aggregation_options     = sum
    aggregation_mutate_rate = 0.0,
    bias_init_mean          = 0.0,
    bias_init_stdev         = 1.0,
    bias_replace_rate       = 0.1,
    bias_mutate_rate        = 0.7,
    bias_mutate_power       = 0.5,
    bias_max_value          = 30.0,
    bias_min_value          = -30.0,
    response_init_mean      = 1.0,
    response_init_stdev     = 0.1,
    response_replace_rate   = 0.1,
    response_mutate_rate    = 0.1,
    response_mutate_power   = 0.1,
    response_max_value      = 30.0,
    response_min_value      = -30.0,

    weight_max_value        = 30,
    weight_min_value        = -30,
    weight_init_mean        = 0.0,
    weight_init_stdev       = 1.0,
    weight_mutate_rate      = 0.8,
    weight_replace_rate     = 0.1,
    weight_mutate_power     = 0.5,
    enabled_default         = true,
    enabled_mutate_rate     = 0.01,

    -- [DefaultSpeciesSet]
    compatibility_threshold = 3.0,

    -- [DefaultStagnation]
    -- species_fitness_func = max
    max_stagnation  = 20,

    -- [DefaultReproduction]
    elitism            = 2,
    survival_threshold = 0.2,
}

return config