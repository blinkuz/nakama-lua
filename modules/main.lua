local nk = require("nakama")
local player_ranking = require("player_ranking")
local matchmaking = require("matchmaking")

nk.logger_info("Lua module loaded")

-- Health check endpoint
local function healthcheck(context, payload)
    return nk.json_encode({status = "OK"})
end

-- Get player rank RPC
local function get_player_rank(context, payload)
    local user_id = context.user_id
    local rank = player_ranking.get_player_rank(user_id)
    local rank_name = player_ranking.get_rank_name(rank)
    
    return nk.json_encode({
        rank = rank,
        rank_name = rank_name
    })
end

-- Set player rank RPC (for testing/admin purposes)
local function set_player_rank(context, payload)
    local user_id = context.user_id
    local request = nk.json_decode(payload)
    local new_rank = request.rank
    
    local ranks = player_ranking.get_ranks()
    if new_rank < ranks.BRONZE or new_rank > ranks.DIAMOND then
        error("Invalid rank. Must be between " .. ranks.BRONZE .. " and " .. ranks.DIAMOND)
    end
    
    player_ranking.set_player_rank(user_id, new_rank)
    
    return nk.json_encode({
        success = true,
        new_rank = new_rank,
        rank_name = player_ranking.get_rank_name(new_rank)
    })
end

-- Get match types RPC
local function get_match_types(context, payload)
    return nk.json_encode({
        match_types = matchmaking.get_match_types()
    })
end

-- Register RPCs
nk.register_rpc(healthcheck, "healthcheck")
nk.register_rpc(matchmaking.join_queue, "join_matchmaking")
nk.register_rpc(matchmaking.leave_queue, "leave_matchmaking")
nk.register_rpc(get_player_rank, "get_player_rank")
nk.register_rpc(set_player_rank, "set_player_rank")
nk.register_rpc(get_match_types, "get_match_types")

nk.logger_info("Matchmaking system initialized")