local nk = require("nakama")
local player_ranking = require("player_ranking")

-- Match handler for authoritative game state management
local match_handler = {}

-- Match constants
local MATCH_DURATION = {
    ["1v1"] = 300,    -- 5 minutes for 1v1
    ["3v3"] = 600     -- 10 minutes for 3v3
}

local TICK_RATE = 1  -- 1 second per tick

-- Match initialization
function match_handler.match_init(context, initial_state)
    local state = {
        match_type = initial_state.match_type,
        players = initial_state.players or {},
        start_time = os.time(),
        duration = MATCH_DURATION[initial_state.match_type],
        eliminations = {},  -- Track eliminations per player/team
        teams = {},         -- For 3v3 matches
        winner = nil,
        match_ended = false,
        rewards_distributed = false
    }
    
    -- Initialize teams for 3v3
    if state.match_type == "3v3" then
        state.teams = {
            team_a = {},
            team_b = {}
        }
        
        -- Assign players to teams
        for i, player in ipairs(state.players) do
            if i <= 3 then
                table.insert(state.teams.team_a, player.user_id)
                state.eliminations[player.user_id] = 0
            else
                table.insert(state.teams.team_b, player.user_id)
                state.eliminations[player.user_id] = 0
            end
        end
    else
        -- Initialize eliminations for 1v1
        for _, player in ipairs(state.players) do
            state.eliminations[player.user_id] = 0
        end
    end
    
    nk.logger_info("Match initialized: " .. state.match_type .. " with " .. #state.players .. " players")
    
    return state, TICK_RATE, "match_handler"
end

-- Match loop (called every tick)
function match_handler.match_loop(context, dispatcher, tick, state, messages)
    local current_time = os.time()
    local elapsed_time = current_time - state.start_time
    
    -- Check if match time has expired
    if elapsed_time >= state.duration and not state.match_ended then
        state = match_handler.end_match_by_time(state)
    end
    
    -- Process messages from clients
    for _, message in ipairs(messages) do
        local msg_data = nk.json_decode(message.data)
        
        if msg_data.type == "elimination" then
            state = match_handler.handle_elimination(state, msg_data.eliminated_by, msg_data.eliminated_player)
        elseif msg_data.type == "get_status" then
            match_handler.send_match_status(dispatcher, message.sender, state, elapsed_time)
        end
    end
    
    -- Send periodic updates
    if tick % 10 == 0 then -- Every 10 seconds
        match_handler.broadcast_match_update(dispatcher, state, elapsed_time)
    end
    
    return state
end

-- Handle player elimination
function match_handler.handle_elimination(state, eliminator_id, eliminated_id)
    if state.match_ended then
        return state
    end
    
    -- Record elimination
    if state.eliminations[eliminator_id] then
        state.eliminations[eliminator_id] = state.eliminations[eliminator_id] + 1
    end
    
    nk.logger_info("Elimination: " .. eliminator_id .. " eliminated " .. eliminated_id)
    
    -- Check win conditions
    if state.match_type == "1v1" then
        -- In 1v1, first elimination wins
        state.winner = eliminator_id
        state.match_ended = true
        match_handler.distribute_rewards(state)
    elseif state.match_type == "3v3" then
        -- In 3v3, continue until time runs out
        -- Winner will be determined by most eliminations at the end
    end
    
    return state
end

-- End match when time expires
function match_handler.end_match_by_time(state)
    state.match_ended = true
    
    if state.match_type == "3v3" then
        -- Calculate team scores
        local team_a_score = 0
        local team_b_score = 0
        
        for _, player_id in ipairs(state.teams.team_a) do
            team_a_score = team_a_score + (state.eliminations[player_id] or 0)
        end
        
        for _, player_id in ipairs(state.teams.team_b) do
            team_b_score = team_b_score + (state.eliminations[player_id] or 0)
        end
        
        if team_a_score > team_b_score then
            state.winner = "team_a"
        elseif team_b_score > team_a_score then
            state.winner = "team_b"
        else
            state.winner = "tie"
        end
        
        nk.logger_info("3v3 Match ended - Team A: " .. team_a_score .. ", Team B: " .. team_b_score)
    elseif state.match_type == "1v1" and not state.winner then
        -- If no eliminations in 1v1, it's a tie
        state.winner = "tie"
    end
    
    match_handler.distribute_rewards(state)
    return state
end

-- Distribute rewards to winners
function match_handler.distribute_rewards(state)
    if state.rewards_distributed then
        return
    end
    
    local winners = {}
    
    if state.match_type == "1v1" then
        if state.winner and state.winner ~= "tie" then
            table.insert(winners, state.winner)
        end
    elseif state.match_type == "3v3" then
        if state.winner == "team_a" then
            winners = state.teams.team_a
        elseif state.winner == "team_b" then
            winners = state.teams.team_b
        else
            -- In case of tie, all players get rewards
            for _, player_id in ipairs(state.teams.team_a) do
                table.insert(winners, player_id)
            end
            for _, player_id in ipairs(state.teams.team_b) do
                table.insert(winners, player_id)
            end
        end
    end
    
    -- Give rewards (coins, experience, etc.)
    for _, player_id in ipairs(winners) do
        match_handler.give_rewards(player_id, state.match_type, state.winner == "tie")
    end
    
    state.rewards_distributed = true
    nk.logger_info("Rewards distributed to " .. #winners .. " players")
end

-- Give rewards to a player
function match_handler.give_rewards(user_id, match_type, is_tie)
    local reward_amount = 100  -- Base reward
    
    if not is_tie then
        reward_amount = reward_amount * 1.5  -- Bonus for winning
    end
    
    if match_type == "3v3" then
        reward_amount = reward_amount * 1.2  -- Bonus for team matches
    end
    
    -- Update player's coins/rewards in storage
    local reward_data = {
        coins = math.floor(reward_amount),
        match_type = match_type,
        awarded_at = os.time(),
        is_winner = not is_tie
    }
    
    local reward_key = "reward_" .. os.time() .. "_" .. math.random(1000)
    nk.storage_write({
        {collection = "player_rewards", key = reward_key, user_id = user_id, value = nk.json_encode(reward_data)}
    })
    
    nk.logger_info("Reward given to " .. user_id .. ": " .. reward_amount .. " coins")
end

-- Send match status to a specific player
function match_handler.send_match_status(dispatcher, sender, state, elapsed_time)
    local status = {
        match_type = state.match_type,
        elapsed_time = elapsed_time,
        remaining_time = math.max(0, state.duration - elapsed_time),
        eliminations = state.eliminations,
        teams = state.teams,
        winner = state.winner,
        match_ended = state.match_ended
    }
    
    dispatcher.broadcast_message(2, nk.json_encode(status), {sender})
end

-- Broadcast match update to all players
function match_handler.broadcast_match_update(dispatcher, state, elapsed_time)
    local update = {
        type = "match_update",
        elapsed_time = elapsed_time,
        remaining_time = math.max(0, state.duration - elapsed_time),
        eliminations = state.eliminations,
        match_ended = state.match_ended
    }
    
    dispatcher.broadcast_message(1, nk.json_encode(update))
end

-- Player joins match
function match_handler.match_join(context, dispatcher, tick, state, presences)
    for _, presence in ipairs(presences) do
        nk.logger_info("Player joined match: " .. presence.user_id)
    end
    return state
end

-- Player leaves match
function match_handler.match_leave(context, dispatcher, tick, state, presences)
    for _, presence in ipairs(presences) do
        nk.logger_info("Player left match: " .. presence.user_id)
        -- In a real game, you might want to handle player disconnections
    end
    return state
end

-- Match termination
function match_handler.match_terminate(context, dispatcher, tick, state, grace_seconds)
    nk.logger_info("Match terminated")
    return nil
end

-- Match signal (for external events)
function match_handler.match_signal(context, dispatcher, tick, state, data)
    return state, data
end

return match_handler