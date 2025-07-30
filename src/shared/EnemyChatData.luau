-- EnemyChatData.luau
-- Contains all enemy chat phrases organized by type and state

local EnemyChatData = {}

-- Chat phrases organized by enemy type and state
EnemyChatData.ChatPhrases = {
    -- Default phrases for any enemy type
    default = {
        talking = {
            "How's your shift going?",
            "Seen anything interesting lately?",
            "The weather's been nice.",
            "Quiet night, isn't it?",
            "How long have you been here?",
            "Any news from the other posts?",
            "These long shifts are tiring.",
            "At least the company's good.",
            "What do you think about the new orders?",
            "Have you heard any rumors?",
            "The food's been getting better.",
            "I hope nothing exciting happens tonight.",
            "How's your family doing?",
            "These uniforms are getting old.",
            "Remember that incident last week?",
            "The new recruits seem promising."
        }
    },
    
    -- Specific phrases for melee enemies (guards, warriors, etc.)
    melee = {
        talking = {
            "How's your weapon holding up?",
            "Nothing beats a good sword, right?",
            "These long patrols are tiring.",
            "Have you been training lately?",
            "The new recruits need more practice.",
            "Remember that skirmish last month?",
            "These boots are killing my feet.",
            "At least we're not stuck inside.",
            "How's your combat training going?",
            "The new armor feels good.",
            "Have you tried the new training grounds?",
            "These long shifts are getting to me.",
            "How's your family doing?",
            "The new weapons are impressive.",
            "Remember that ambush we survived?",
            "The veterans say it gets easier."
        }
    },
    
    -- Specific phrases for ranged enemies (archers, mages, etc.)
    ranged = {
        talking = {
            "How's the visibility from your post?",
            "These long-range shots are tricky.",
            "Have you been practicing your aim?",
            "The wind's been unpredictable lately.",
            "How's your bow holding up?",
            "These vantage points are perfect.",
            "Have you tried the new arrows?",
            "The long-range training is intense.",
            "How's your eyesight holding up?",
            "These scopes are getting better.",
            "Have you seen any movement in the distance?",
            "The new crossbows are impressive.",
            "How's your accuracy been lately?",
            "These high positions give great views.",
            "Have you been working on your technique?",
            "The archery range has been busy."
        }
    },
    
    -- Specific phrases for special enemies (bosses, unique units, etc.)
    special = {
        talking = {
            "The ancient magic speaks to me.",
            "Can you feel the power in the air?",
            "The mystical forces are strong today.",
            "How's your connection to the arcane?",
            "The elements are restless tonight.",
            "Have you sensed any disturbances?",
            "The ancient spells are holding well.",
            "The mystical barriers are intact.",
            "How's your magical training progressing?",
            "The arcane energies are flowing freely.",
            "Have you noticed the magical resonance?",
            "The ancient powers are awakening.",
            "How's your spellcasting been lately?",
            "The mystical forces are in harmony.",
            "Have you felt the magical currents?",
            "The arcane arts are truly fascinating."
        }
    }
}

-- Get random chat phrase for an enemy type and state
function EnemyChatData:GetRandomPhrase(enemyType, aiState)
    -- Validate inputs
    if not enemyType or not aiState then
        return nil
    end
    
    -- Only allow chat during talking state
    if aiState ~= "talking" then
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