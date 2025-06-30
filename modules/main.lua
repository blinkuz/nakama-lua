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

-- Simulate match completion and rewards
local function complete_match(context, payload)
    local user_id = context.user_id
    local request = nk.json_decode(payload)
    local match_id = request.match_id
    local eliminations = request.eliminations or 0
    local match_type = request.match_type or "1v1"
    local is_winner = request.is_winner or false
    
    -- Calculate rewards
    local base_reward = 100
    local reward_multiplier = 1.0
    
    if is_winner then
        reward_multiplier = reward_multiplier + 0.5  -- 50% bonus for winning
    end
    
    if match_type == "3v3" then
        reward_multiplier = reward_multiplier + 0.2  -- 20% bonus for team matches
    end
    
    local final_reward = math.floor(base_reward * reward_multiplier)
    
    -- Store reward
    local reward_data = {
        coins = final_reward,
        eliminations = eliminations,
        match_type = match_type,
        match_id = match_id,
        is_winner = is_winner,
        awarded_at = os.time()
    }
    
    local reward_key = "reward_" .. os.time() .. "_" .. math.random(1000)
    nk.storage_write({
        {collection = "player_rewards", key = reward_key, user_id = user_id, value = nk.json_encode(reward_data)}
    })
    
    nk.logger_info("Reward given to " .. user_id .. ": " .. final_reward .. " coins for match " .. match_id)
    
    return nk.json_encode({
        success = true,
        reward = final_reward,
        match_type = match_type,
        eliminations = eliminations,
        is_winner = is_winner
    })
end

-- Get player rewards history
local function get_rewards_history(context, payload)
    local user_id = context.user_id
    
    local cursor = nil
    local rewards = {}
    
    repeat
        local objects, new_cursor = nk.storage_list(user_id, "player_rewards", 20, cursor)
        cursor = new_cursor
        
        for _, obj in ipairs(objects) do
            local reward_data = nk.json_decode(obj.value)
            table.insert(rewards, reward_data)
        end
    until cursor == nil or cursor == ""
    
    -- Sort by awarded time (newest first)
    table.sort(rewards, function(a, b)
        return a.awarded_at > b.awarded_at
    end)
    
    return nk.json_encode({
        rewards = rewards,
        total_rewards = #rewards
    })
end

-- Register RPCs
nk.register_rpc(healthcheck, "healthcheck")
nk.register_rpc(matchmaking.join_queue, "join_matchmaking")
nk.register_rpc(matchmaking.leave_queue, "leave_matchmaking")
nk.register_rpc(get_player_rank, "get_player_rank")
nk.register_rpc(set_player_rank, "set_player_rank")
nk.register_rpc(get_match_types, "get_match_types")
nk.register_rpc(complete_match, "complete_match")
nk.register_rpc(get_rewards_history, "get_rewards_history")

nk.logger_info("Complete matchmaking system initialized")