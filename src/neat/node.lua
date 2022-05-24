module(..., package.seeall)

function new(value, type, innov)
    local node = {innov = innov, value = value, type = type, x = 0, y = 0}
    local coords = {}
    if type == "HIDDEN" then
        coords = random_screen_coords()
    end
    if type == "BIAS" then
        coords = {x = 80, y = 100}
    end
    if type == "OUTPUT" then
        coords = get_button_coords(innov - config.num_inputs)
    end
    
    node.x = coords.x
    node.y = coords.y
    
    return node
end