-- Type definitions for Boss System
export type BossState = "Falling" | "Moving" | "Attacking" | "Invincible" | "Cooldown" | "Dead"

export type BossData = {
    model: Model,
    humanoid: Humanoid,
    rootPart: BasePart,
    health: number,
    maxHealth: number,
    state: BossState,
    currentTarget: Player?,
    moveCounter: number,
    lastMeleeHit: {[Player]: number}, -- Track melee cooldowns per player
    isInvincible: boolean,
    invincibilityStartTime: number?,
    currentSequence: {string},
    currentSequenceIndex: number,
    lastActionTime: number,
    lastDebugTime: number?,
    wasCloseToTarget: boolean?,
    landingConnection: RBXScriptConnection?,
    landingTime: number?, -- Track when boss landed for grace period
    inGracePeriod: boolean?, -- Track if boss is in grace period
}

export type AbilityConfig = {
    damage: number,
    cooldownAfter: number,
    [string]: any, -- Allow additional properties per ability
}

export type MovementConfig = {
    speed: number,
    pathfindingUpdateRate: number,
    stoppingDistance: number,
    selectNewPlayerAfterAttack: boolean,
    meleeRange: number,
    meleeDamage: number,
    meleeKnockback: number,
    meleeCooldown: number,
}

export type InvincibilityConfig = {
    triggerAfterMoves: number,
    triggerVariation: number,
    duration: number,
    visualEffect: string,
    healAmount: number,
    damageReduction: number,
}

export type PlayerTarget = {
    player: Player,
    character: Model,
    humanoid: Humanoid,
    rootPart: BasePart,
    lastPosition: Vector3,
}

export type AttackResult = {
    success: boolean,
    damage: number?,
    playersHit: {Player}?,
    duration: number?,
}

return {} 