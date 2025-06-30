local nk = require("nakama")
local player_ranking = require("player_ranking")

local matchmaking = {}

-- Match types
local MATCH_TYPES = {
    ONE_V_ONE = "1v1",
    THREE_V_THREE = "3v3"
}

-- Matchmaking queue storage
local MATCHMAKING_QUEUE_COLLECTION = "matchmaking_queue"

-- Join matchmaking queue
function matchmaking.join_queue(context, payload)
    local user_id = context.user_id
    local request = nk.json_decode(payload)
    local match_type = request.match_type or MATCH_TYPES.ONE_V_ONE
    
    if match_type ~= MATCH_TYPES.ONE_V_ONE and match_type ~= MATCH_TYPES.THREE_V_THREE then
        error("Invalid match type. Use '1v1' or '3v3'")
    end
    
    -- Get player's rank
    local player_rank = player_ranking.get_player_rank(user_id)
    
    -- Check if player is already in queue
    local existing_queue = nk.storage_read({
        {collection = MATCHMAKING_QUEUE_COLLECTION, key = user_id}
    })
    
    if #existing_queue > 0 then
        return nk.json_encode({
            success = false,
            message = "Player already in matchmaking queue"
        })
    end
    
    -- Add player to queue
    local queue_data = {
        user_id = user_id,
        rank = player_rank,
        match_type = match_type,
        joined_at = os.time()
    }
    
    nk.storage_write({
        {collection = MATCHMAKING_QUEUE_COLLECTION, key = user_id, value = nk.json_encode(queue_data)}
    })
    
    -- Try to find a match
    local match_id = matchmaking.try_create_match(match_type, player_rank)
    
    local response = {
        success = true,
        message = "Joined matchmaking queue",
        match_type = match_type,
        rank = player_ranking.get_rank_name(player_rank)
    }
    
    if match_id then
        response.match_found = true
        response.match_id = match_id
    end
    
    return nk.json_encode(response)
end

-- Leave matchmaking queue
function matchmaking.leave_queue(context, payload)
    local user_id = context.user_id
    
    nk.storage_delete({
        {collection = MATCHMAKING_QUEUE_COLLECTION, key = user_id}
    })
    
    return nk.json_encode({
        success = true,
        message = "Left matchmaking queue"
    })
end

-- Try to create a match with available players 
function matchmaking.try_create_match(match_type, initiator_rank)
    local required_players = (match_type == MATCH_TYPES.ONE_V_ONE) and 2 or 6
    
    -- Get all players in queue for this match type
    local queue_players = matchmaking.get_queue_players(match_type, initiator_rank)
    
    if #queue_players < required_players then
        return nil -- Not enough players
    end
    
    -- Select players for the match
    local selected_players = {}
    for i = 1, required_players do
        table.insert(selected_players, queue_players[i])
    end
    
    -- Create a match ID (in a real implementation, this would be handled by the game client)
    local match_id = "match_" .. match_type .. "_" .. os.time() .. "_" .. math.random(1000)
    
    -- Store match information
    local match_data = {
        match_id = match_id,
        match_type = match_type,
        players = selected_players,
        created_at = os.time(),
        status = "active"
    }
    
    nk.storage_write({
        {collection = "active_matches", key = match_id, value = nk.json_encode(match_data)}
    })
    
    -- Remove selected players from queue
    local delete_requests = {}
    for _, player in ipairs(selected_players) do
        table.insert(delete_requests, {
            collection = MATCHMAKING_QUEUE_COLLECTION,
            key = player.user_id
        })
    end
    nk.storage_delete(delete_requests)
    
    nk.logger_info("Match created: " .. match_id .. " for " .. match_type .. " with " .. required_players .. " players")
    
    return match_id
end

-- Get players in queue for specific match type and compatible rank
function matchmaking.get_queue_players(match_type, target_rank)
    local cursor = nil
    local players = {}
    
    repeat
        local objects, new_cursor = nk.storage_list(nil, MATCHMAKING_QUEUE_COLLECTION, 100, cursor)
        cursor = new_cursor
        
        for _, obj in ipairs(objects) do
            local queue_data = nk.json_decode(obj.value)
            
            -- Check match type and rank compatibility
            if queue_data.match_type == match_type and 
               player_ranking.can_match_ranks(queue_data.rank, target_rank) then
                table.insert(players, queue_data)
            end
        end
    until cursor == nil or cursor == ""
    
    -- Sort by join time (first in, first served)
    table.sort(players, function(a, b)
        return a.joined_at < b.joined_at
    end)
    
    return players
end

-- Get matchmaking constants
function matchmaking.get_match_types()
    return MATCH_TYPES
end

return matchmaking