require("ui.t7.utility.lobbyutilityog") -- Ripped original file from Wraith

function Engine.GetLobbyMaxClients()
    Engine.SetDvar("sv_maxclients", 8)
    Engine.SetDvar("com_maxclients", 8)
    Engine.SetLobbyMaxClients(Enum.LobbyType.LOBBY_TYPE_GAME, 8)
    Engine.SetLobbyMaxClients(Enum.LobbyType.LOBBY_TYPE_PRIVATE, 8)
    return 8
end