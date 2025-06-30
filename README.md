# Nakama Lua Matchmaking System

This project implements a basic matchmaking system for PVP arena games using Nakama's Lua runtime.

## Features

### Player Ranking System
- **Rank Tiers**: Bronze, Silver, Gold, Diamond
- **Compatible Matching**: Players can be matched with same or adjacent ranks
- **Persistent Storage**: Ranks are stored in Nakama's storage system

### Matchmaking System
- **Match Types**: 1v1 and 3v3 matches
- **Queue Management**: FIFO queue system with rank-based matching
- **Automatic Matching**: When enough compatible players are found

### Match Rules
- **1v1 Matches**: 
  - Duration: 5 minutes
  - Win condition: First elimination wins
  - 2 players required

- **3v3 Matches**:
  - Duration: 10 minutes  
  - Win condition: Team with most eliminations wins
  - 6 players required (3 per team)

### Reward System
- **Base Reward**: 100 coins
- **Winner Bonus**: +50% for winning
- **Team Match Bonus**: +20% for 3v3 matches
- **Persistent History**: All rewards are stored

## Available RPCs

### Core System
- `healthcheck` - Server health status
- `get_player_rank` - Get current player rank
- `set_player_rank` - Set player rank (admin/testing)

### Matchmaking
- `join_matchmaking` - Join matchmaking queue
  ```json
  {"match_type": "1v1"}  // or "3v3"
  ```
- `leave_matchmaking` - Leave matchmaking queue
- `get_match_types` - Get available match types

### Match & Rewards
- `complete_match` - Complete a match and receive rewards
  ```json
  {
    "match_id": "match_1v1_123456",
    "eliminations": 3,
    "match_type": "1v1", 
    "is_winner": true
  }
  ```
- `get_rewards_history` - Get player's reward history

## Usage Example

1. **Set Player Rank** (optional, defaults to Bronze):
   ```json
   POST /v2/rpc/set_player_rank
   {"rank": 2}  // 1=Bronze, 2=Silver, 3=Gold, 4=Diamond
   ```

2. **Join Matchmaking**:
   ```json
   POST /v2/rpc/join_matchmaking  
   {"match_type": "1v1"}
   ```

3. **When Match Found**: 
   - Server responds with match details
   - Players connect to external game server
   - Game plays out with elimination tracking

4. **Complete Match**:
   ```json
   POST /v2/rpc/complete_match
   {
     "match_id": "returned_match_id",
     "eliminations": 2,
     "match_type": "1v1",
     "is_winner": true
   }
   ```

## Architecture

- **Player Ranking** (`player_ranking.lua`): Manages player ranks
- **Matchmaking** (`matchmaking.lua`): Queue management and match creation  
- **Main** (`main.lua`): RPC registration and match completion/rewards
- **Storage**: Uses Nakama's built-in storage for persistence

## Running the System

1. Start with Docker Compose:
   ```bash
   docker compose up
   ```

2. Server will be available at:
   - HTTP API: `http://localhost:7350`
   - Console: `http://localhost:7351` (admin/password)

## Notes

- This implementation focuses on matchmaking logic rather than real-time gameplay
- Actual game state is managed by external dedicated servers
- Match handlers are simplified due to Nakama version compatibility
- All player data persists in PostgreSQL database