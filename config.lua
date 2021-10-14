-- Config taken from:
-- https://github.com/CodeReclaimers/neat-python/blob/master/examples/memory-fixed/config

-- NEAT configuration for the fixed-length bit-sequence memory experiment.

-- The `NEAT` section specifies parameters particular to the NEAT algorithm
-- or the experiment itself.  This is the only required section.
--  [NEAT]

config = {
    fitness_threshold               = 3500, -- found solution
    population                      = 300,
    reset_on_extinction             = 0,

    -- [DefaultGenome]
    num_inputs                      = 13*17,
    conn_add_prob                   = 0.6,
    conn_delete_prob                = 0.5,
    weight_max_value                = 30,
    weight_min_value                = -30,
    weight_add_value                = 5,
    weight_add_rate                 = 0.3,
    weight_mutate_rate              = 0.8,
    enabled_default                 = true,
    enabled_mutate_rate             = 0.2,
    node_add_prob                   = 0.5,
    node_delete_prob                = 0.25,
    bias_add_prob                   = 0.3,
    adaptive_mutate_rate            = 0.05,

    -- [DefaultSpeciesSet]
    compatibility_threshold         = 3.0,

    -- [DefaultReproduction]
    survival_threshold              = 0.15,
    use_adjusted_fitness            = true,
    crossover_rate                  = 0.70,
    strong_species_selector_mode    = 1,
    margin_error_value              = 10,
    adaptive_mutate_mode            = 3,
    emergency_reproduce             = 20, -- how many generations will it take to reproduce 2 species
    on_reset_generations            = 25, -- how many generations will it take to reset all generation mutations
}

return config