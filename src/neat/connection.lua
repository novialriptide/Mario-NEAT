module(..., package.seeall)

function new(node1, node2, weight)
    return {weight = weight, node_in = node1, node_out = node2, innov = 0, enabled = config.enabled_default, mutation_modifier = 1}
end