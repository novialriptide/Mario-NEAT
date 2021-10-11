-- Config taken from:
-- https://github.com/CodeReclaimers/neat-python/blob/master/examples/memory-fixed/config

-- NEAT configuration for the fixed-length bit-sequence memory experiment.

-- The `NEAT` section specifies parameters particular to the NEAT algorithm
-- or the experiment itself.  This is the only required section.
--  [NEAT]

config = {
    fitness_threshold               = 3500, -- found solution
    population                      = 300, -- 300,
    reset_on_extinction             = 0,

    -- [DefaultGenome]
    num_inputs                      = 13*17,
    conn_add_prob                   = 0.75,
    conn_delete_prob                = 0.75,
    weight_max_value                = 30,
    weight_min_value                = -30,
    weight_mutate_rate              = 0.8,
    enabled_default                 = true,
    enabled_mutate_rate             = 0.2,
    node_add_prob                   = 0.25,
    node_delete_prob                = 0.25,
    bias_add_prob                   = 0.10,
    adaptive_mutate_rate            = 0.05,

    -- [DefaultSpeciesSet]
    compatibility_threshold         = 3.0,

    -- [DefaultReproduction]
    survival_threshold              = 0.1,
    use_adjusted_fitness            = true,
    crossover_rate                  = 0.70,
    strong_species_selector_mode    = 0,
    margin_error_value              = 10,
    adaptive_mutate_mode            = 3
}

return config