-- This information tells other players more about the mod
name = "更好的女武神"
description =
"按照永不妥协的思路重做了薇格弗德的技能树。"
author = "embrace"
version = "1.12" -- This is the version of the template. Change it to your own number.

-- This is the URL name of the mod's thread on the forum; the part after the ? and before the first & in the url
forumthread = ""

-- This lets other players know if your mod is out of date, update it to match the current version in the game
api_version = 10

-- Compatible with Don't Starve Together
dst_compatible = true

-- Not compatible with Don't Starve
dont_starve_compatible = false
reign_of_giants_compatible = false
shipwrecked_compatible = false

-- Character mods are required by all clients
all_clients_require_mod = true

icon_atlas = "modicon.xml"
icon = "modicon.tex"

-- The mod's tags displayed on the server list
server_filter_tags = {
    "wathgrithr",
}

configuration_options = {

    { name = "Title", label = "其他改动", options = { { description = "", data = "0" }, }, default = "0", },
    {
        name = "song_lunarseed",
        label = "非阵营战歌改动",
        hover = "非阵营战歌可以放在启迪之冠中，并在用天体珠宝升级后，视为放置天体珠宝。",
        options = {
            { description = "关闭", data = false, hover = "" },
            { description = "开启", data = true, hover = "" },
        },
        default = true,
    },
}
