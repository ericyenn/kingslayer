-- EnemyChatData.luau
-- Contains all enemy chat phrases organized by type and state

local EnemyChatData = {}

-- Chat phrases organized by enemy type and AI state
EnemyChatData.ChatPhrases = {
    -- Default phrases for any enemy type
    default = {
        idle = {
            "Nothing happening here.",
            "Quiet around these parts.",
            "How's your watch going?",
            "Pretty peaceful tonight.",
            "Seen anything interesting?",
            "Just another boring shift.",
            "All quiet on my end.",
            "Nothing to report."
        },
        patrol = {
            "All clear on my route.",
            "Making my rounds.",
            "Patrol route looks good.",
            "Nothing suspicious spotted.",
            "Area seems secure.",
            "Just checking the perimeter.",
            "Keeping an eye out.",
            "Making sure everything's in order."
        }
    },
    
    -- Specific phrases for melee enemies (guards, warriors, etc.)
    melee = {
        idle = {
            "My weapon feels heavy today.",
            "Ready for anything that comes.",
            "Keeping my blade sharp.",
            "Standing guard as always.",
            "Nothing beats a good sword.",
            "These boots are killing me.",
            "At least the weather's nice.",
            "Hope nothing exciting happens."
        },
        patrol = {
            "Checking for intruders.",
            "Securing the area.",
            "No threats detected.",
            "Perimeter sweep complete.",
            "All entrances secured.",
            "Area is locked down tight.",
            "No signs of trouble.",
            "Everything's under control."
        }
    },
    
    -- Specific phrases for ranged enemies (archers, mages, etc.)
    ranged = {
        idle = {
            "Good visibility from here.",
            "Perfect vantage point.",
            "Can see for miles.",
            "Arrows are ready.",
            "Watching the horizon.",
            "Eyes open, ready to shoot.",
            "Scanning for targets.",
            "Range is clear."
        },
        patrol = {
            "Sweeping with my eyes.",
            "No movement detected.",
            "Covering the long range.",
            "All sight lines clear.",
            "No targets in range.",
            "Watching from afar.",
            "Keeping overwatch.",
            "Long range all clear."
        }
    },
    
    -- Specific phrases for special enemies (bosses, unique units, etc.)
    special = {
        idle = {
            "The power flows through me.",
            "Ancient magic stirs.",
            "Something feels different today.",
            "The air crackles with energy.",
            "I sense disturbances.",
            "Magic is strong here.",
            "The elements whisper secrets.",
            "Mystical forces are at work."
        },
        patrol = {
            "Channeling protective wards.",
            "Magical barriers holding strong.",
            "Sensing no hostile magic.",
            "The arcane is balanced.",
            "No magical threats detected.",
            "Weaving protective spells.",
            "Mystical defenses active.",
            "Ancient powers stand guard."
        }
    }
}

-- Get random chat phrase for an enemy type and state
function EnemyChatData:GetRandomPhrase(enemyType, aiState)
    -- Validate inputs
    if not enemyType or not aiState then
        return nil
    end
    
    -- Only allow chat during idle and patrol states
    if aiState ~= "idle" and aiState ~= "patrol" then
        return nil
    end
    
    -- Get phrases for this enemy type, fallback to default
    local typeData = self.ChatPhrases[enemyType] or self.ChatPhrases.default
    local statePhrases = typeData[aiState]
    
    if not statePhrases or #statePhrases == 0 then
        return nil
    end
    
    -- Return random phrase
    return statePhrases[math.random(1, #statePhrases)]
end

-- Get all available enemy types that have chat data
function EnemyChatData:GetAvailableEnemyTypes()
    local types = {}
    for enemyType, _ in pairs(self.ChatPhrases) do
        table.insert(types, enemyType)
    end
    return types
end

return EnemyChatData 