module(..., package.seeall)

Connection = require("neat/connection")
Node = require("neat/node")

function new()
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
            local _node = Node.new(v.value, "INPUT", _innov)
            _node.x = v.x
            _node.y = v.y
            table.insert(nodes, _node)
        end
        for k, v in pairs(inputs_keys) do
            _innov = _innov + 1
            table.insert(nodes, Node.new(0, "OUTPUT", _innov))
        end

        _innov = _innov + 1
        table.insert(nodes, Node.new(1, "BIAS", _innov))

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
        if genome:get_node(node2).type == "BIAS" or genome:get_node(node2).type == "INPUT" then return false end

        local connect_node = Connection.new(node1, node2, math.random(config.weight_min_value, config.weight_max_value) + math.random())
        if weight ~= nil then connect_node.weight = weight end

        if genome:does_node_exist(node1) and genome:does_node_exist(node2) then
            for k, v in pairs(genome.connections) do
                -- test if the connection is already implemented
                if v.node_in == connect_node.node_in and v.node_out == connect_node.node_out then
                    return false
                end
            end

            for k, v in pairs(global_connections) do
                if connect_node.node_in == v.node_in and connect_node.node_out == v.node_out then     
                    connect_node.innov = v.innov
                    table.insert(genome.connections, connect_node)
                    return true
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
        table.insert(genome.hidden_nodes, Node.new(0, "HIDDEN"))
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
                local color = const.color3
                if v.weight >= 0 then 
                    color = const.color5 
                end 
                if not v.enabled then 
                    color = {r = 0, g = 0, b = 255} 
                end
                
                if node_in.type == "INPUT" then
                    converted_coords = cell_to_screen(node_in.x, node_in.y)
                    gui.drawline(
                        converted_coords.x,
                        converted_coords.y,
                        node_out.x+const.box_size/2,
                        node_out.y+const.box_size/2,
                        color
                    )
                end
                if node_in.type == "HIDDEN" or node_in.type == "BIAS" then
                    gui.drawline(
                        node_in.x,
                        node_in.y,
                        node_out.x + const.box_size/2,
                        node_out.y + const.box_size/2,
                        color
                    )
                end
            end
        end
    end

    function genome:draw_nodes(enable_innovs)
        for k, v in pairs(genome.hidden_nodes) do
            if v.type == "BIAS" or v.type == "HIDDEN" then
                draw_world_tile(
                    v.x, v.y,
                    const.color1,
                    const.color2
                )
                if enable_innovs then 
                    gui.text(v.x, v.y, v.innov, const.color1)
                end
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