function lol(file_name)
    local file, err = io.open("saves/"..file_name..".txt", "w")
    if file == nil then
        print("Could not open file [".. err.."]")
    else
        local shit = ""
        for i=1, 30000 do
            shit = shit.."ddddddd"
        end
        file:write(shit)
        file:close()
    end
end

lol("gen".."36")