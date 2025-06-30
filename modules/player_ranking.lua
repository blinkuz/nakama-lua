local nk = require("nakama")

-- Player ranking system for matchmaking
local player_ranking = {}

-- Rank tiers with numeric values for easy comparison
local RANKS = {
    BRONZE = 1,
    SILVER = 2,
    GOLD = 3,
    DIAMOND = 4
}

local RANK_NAMES = {
    [1] = "BRONZE",
    [2] = "SILVER", 
    [3] = "GOLD",
    [4] = "DIAMOND"
}

-- Get player's current rank (defaults to BRONZE for new players)
function player_ranking.get_player_rank(user_id)
    local objects = nk.storage_read({
        {collection = "player_stats", key = "rank", user_id = user_id}
    })
    
    if #objects == 0 then
        -- New player, set default rank to BRONZE
        player_ranking.set_player_rank(user_id, RANKS.BRONZE)
        return RANKS.BRONZE
    end
    
    local rank_data = nk.json_decode(objects[1].value)
    return rank_data.rank or RANKS.BRONZE
end

-- Set player's rank
function player_ranking.set_player_rank(user_id, rank)
    local rank_data = {
        rank = rank,
        updated_at = os.time()
    }
    
    nk.storage_write({
        {collection = "player_stats", key = "rank", user_id = user_id, value = nk.json_encode(rank_data)}
    })
end

-- Get rank name from numeric value
function player_ranking.get_rank_name(rank)
    return RANK_NAMES[rank] or "BRONZE"
end

-- Check if two players can be matched based on rank (same rank or adjacent ranks)
function player_ranking.can_match_ranks(rank1, rank2)
    return math.abs(rank1 - rank2) <= 1
end

-- Get all rank constants
function player_ranking.get_ranks()
    return RANKS
end

return player_ranking