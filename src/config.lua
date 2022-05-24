-- Config taken from:
-- https://github.com/CodeReclaimers/neat-python/blob/master/examples/memory-fixed/config

config = {
    enable_nudge                    = false, -- refreshes the joypad incase Mario gets stuck

    fitness_threshold               = 3500, -- found solution
    population                      = 300,
    reaction_time                   = 5, -- update eval after how many frames

    -- [Draw]
    draw_nodes                      = false,
    draw_connections                = false,

    -- [DefaultGenome]
    num_inputs                      = 13*17,
    conn_add_prob                   = 2.5,
    conn_delete_prob                = 0,
    weight_max_value                = 30,
    weight_min_value                = -30,
    weight_add_value                = 5,
    weight_add_prob                 = 0.01,
    weight_mutate_prob              = 0.01,
    enabled_default                 = true,
    enabled_mutate_prob             = 0.2,
    node_add_prob                   = 0.5,
    node_delete_prob                = 0.25,
    bias_add_prob                   = 0.3,
    adaptive_mutate_rate            = 0.05,

    -- [DefaultSpeciesSet]
    compatibility_threshold         = 3.0,
    backup_per_gen                  = 10,

    -- [DefaultReproduction]
    survival_threshold              = 0.3,
    use_adjusted_fitness            = false,
    crossover_rate                  = 0.70,
    crossover_rate_change           = 0.05,
    strong_species_selector_mode    = 2,
    margin_error_value              = 10,
    adaptive_mutate_mode            = 3,
    enable_emergency_reproduce      = false,
    emergency_reproduce             = 10, -- how many generations will it take to reproduce 2 species
    on_reset_generations            = 15, -- how many generations will it take to reset all generation mutations
}

return config