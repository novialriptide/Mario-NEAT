box_size = 4

x_offset = 20
y_offset = 20

color1 = 0xFF0000FF
color2 = 0x400000FF

mario_x = 0
mario_y = 0
mario_x_screen_scroll = 0

function get_positions()
    mario_x = memory.readbyte(0x0086) + memory.readbyte(0x006D) * 256
    mario_y = memory.readbyte(0x03B8)
    mario_x_screen_scroll = memory.readbyte(0x071D)
end

function get_tile(_x, _y)
    local _x = _x + mario_x - 16*6
    local page = math.floor(_x / 256) % 2
    local sub_x = math.floor((_x % 256) / 16)
    local sub_y = math.floor((_y - 32) / 16)
    local addr = 0x0500 + page*208 + sub_y*16 + sub_x
    local byte = memory.readbyte(addr)
    if byte ~= 0 and byte ~= 194 then
        return 1
    end
    return 0
end

function read_map()
    local columns = 16
    local rows = 13
    gui.drawbox(x_offset-box_size, y_offset-box_size, x_offset+columns*box_size, y_offset+rows*box_size, color2, color2)

    x_start = (memory.readbyte(0x006D) * 256 + memory.readbyte(0x0086)) - memory.readbyte(0x03AD)
    for _y=32, 208, 16 do
        for _x=0, 256, 16 do
            local tile = get_tile(_x, _y)
            if tile == 1 then
                local x_gui = math.floor(_x/16) - 1
                local y_gui = math.floor(_y/16) - 1
                gui.drawbox(x_offset+x_gui*box_size, y_offset+y_gui*box_size, x_offset+x_gui*box_size+box_size, y_offset+y_gui*box_size+box_size, color1, color1)
            end
        end
    end
end

function read_enemies()
    local enemies_drawn = 0
    for _e=0, 4, 1 do
        if memory.readbyte(0x000F+_e) == 1 then
            enemies_drawn = enemies_drawn + 1
        end
    end
    print(enemies_drawn)
end

while (true) do
    read_map()
    get_positions()
    read_enemies()
    emu.frameadvance()
end