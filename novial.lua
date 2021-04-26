while (true) do
    x = memory.readbyte(0x0086)
    y = memory.readbyte(0x03B8)
    gui.text(50,50, "x:"..x.." y:"..y);
    print(x, y)

    emu.frameadvance();

end;