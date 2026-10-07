local root = "mods/active/AnotherScoreboard/scripts/mods/AnotherScoreboard/"
local checks = 0
local function eq(actual, expected, message)
    checks = checks + 1
    if actual ~= expected then
        error(string.format("%s: expected %s, got %s", message or "check", tostring(expected), tostring(actual)), 2)
    end
end

local Sourceless = dofile(root .. "AnotherScoreboard_sourceless.lua")

local recorded = {}
Sourceless.set_recorder(function(stat_id, aid, value)
    local key = stat_id .. ":" .. aid
    recorded[key] = (recorded[key] or 0) + value
end)
local function tally(aid)
    return recorded["debuffs_applied:" .. aid] or 0
end

local function player(talents)
    return { profile = function() return { talents = talents or {} } end }
end

local fury_zealot = player({ zealot_resist_death_fire = { tier = 1 } })
local fury_zealot_2 = player({ zealot_resist_death_fire = 1 })
local plain_zealot = player()
local skitarii = player()
local veteran = player()

local BURN = "flamer_assault"

-- 1. Attack report first, then the ownerless burn: attributed at once.
local enemy = {}
Sourceless.on_attack(enemy, "zealot", "zealot", fury_zealot, 10.0)
eq(Sourceless.on_debuff_added(enemy, BURN, true, true, true, 10.0), "zealot", "attack first returns zealot")
eq(tally("zealot"), 1, "attack first counts the debuff")
eq(Sourceless.dot_owner(enemy, "burning"), "zealot", "attack first owns the burn ticks")
eq(Sourceless.dot_owner(enemy, "bleeding"), nil, "other DoT profiles have no sourceless owner")

-- 2. Burn first, attack report after: resolved by the attack report.
local enemy2 = {}
eq(Sourceless.on_debuff_added(enemy2, BURN, true, true, true, 20.0), nil, "burn first waits")
eq(Sourceless.dot_owner(enemy2, "burning"), nil, "no owner before the attack report")
Sourceless.on_attack(enemy2, "zealot", "zealot", fury_zealot, 20.0)
eq(tally("zealot"), 2, "burn first counts after the attack report")
eq(Sourceless.dot_owner(enemy2, "burning"), "zealot", "burn first owns the ticks after the attack report")

-- 3. A later stack on the same instance neither counts nor changes the owner.
eq(Sourceless.on_debuff_added(enemy2, BURN, false, true, false, 20.2), nil, "stack does nothing")
Sourceless.on_attack(enemy2, "zealot2", "zealot", fury_zealot_2, 20.25)
eq(Sourceless.dot_owner(enemy2, "burning"), "zealot", "stack keeps the instance owner")
eq(tally("zealot2"), 0, "stack is not a debuff for the second zealot")

-- 4. A Zealot without the talent is never credited.
local enemy3 = {}
Sourceless.on_attack(enemy3, "plain", "zealot", plain_zealot, 30.0)
eq(Sourceless.on_debuff_added(enemy3, BURN, true, true, true, 30.0), nil, "zealot without talent not credited")
Sourceless.on_attack(enemy3, "plain", "zealot", plain_zealot, 30.1)
eq(tally("plain"), 0, "pending not resolved by zealot without talent")
Sourceless.on_attack(enemy3, "zealot", "zealot", fury_zealot, 30.2)
eq(tally("zealot"), 3, "pending resolved by the qualifying zealot")

-- 5. Outside the window nothing is attributed.
local enemy4 = {}
eq(Sourceless.on_debuff_added(enemy4, BURN, true, true, true, 40.0), nil, "late burn waits")
Sourceless.on_attack(enemy4, "zealot", "zealot", fury_zealot, 40.6)
eq(Sourceless.dot_owner(enemy4, "burning"), nil, "attack after the window does not resolve")
eq(tally("zealot"), 3, "attack after the window does not count")
eq(Sourceless.on_debuff_added(enemy4, BURN, true, true, true, 41.2), nil, "old attack outside the window")

-- 6. Another class hitting in between does not hide the Zealot's hit.
local enemy5 = {}
Sourceless.on_attack(enemy5, "zealot", "zealot", fury_zealot, 50.0)
Sourceless.on_attack(enemy5, "veteran", "veteran", veteran, 50.1)
eq(Sourceless.on_debuff_added(enemy5, BURN, true, true, true, 50.2), "zealot", "zealot found behind a veteran hit")

-- 7. A new ownerless instance clears the previous owner until it is attributed.
eq(Sourceless.on_debuff_added(enemy5, BURN, true, true, true, 60.0), nil, "new instance waits")
eq(Sourceless.dot_owner(enemy5, "burning"), nil, "new instance clears the old owner")
Sourceless.on_attack(enemy5, "zealot2", "zealot", fury_zealot_2, 60.05)
eq(Sourceless.dot_owner(enemy5, "burning"), "zealot2", "new instance owned by its attacker")

-- 8. Skitarii skull: owner is the skull, so only the debuff count is attributed.
local enemy6 = {}
eq(Sourceless.on_debuff_added(enemy6, BURN, true, false, true, 70.0), nil, "skull burn waits")
Sourceless.on_attack(enemy6, "skitarii", "cryptic", skitarii, 70.1)
eq(tally("skitarii"), 1, "skull burn counts for the skitarii")
eq(Sourceless.dot_owner(enemy6, "burning"), nil, "skull burn ticks are left to the game")
Sourceless.on_attack(enemy6, "skitarii", "cryptic", skitarii, 71.0)
eq(Sourceless.on_debuff_added(enemy6, "cryptic_servo_skull_debuff", true, false, true, 71.1), "skitarii", "skull hack debuff")
eq(tally("skitarii"), 2, "skull hack debuff counts")

-- 9. A Zealot is not credited for the Skitarii-only debuff.
local enemy7 = {}
Sourceless.on_attack(enemy7, "zealot", "zealot", fury_zealot, 80.0)
eq(Sourceless.on_debuff_added(enemy7, "cryptic_servo_skull_debuff", true, false, true, 80.0), nil, "zealot not credited for skull hack")

-- 10. Most recent qualifying attacker wins.
local enemy8 = {}
Sourceless.on_attack(enemy8, "skitarii", "cryptic", skitarii, 90.0)
Sourceless.on_attack(enemy8, "zealot", "zealot", fury_zealot, 90.2)
eq(Sourceless.on_debuff_added(enemy8, BURN, true, true, true, 90.3), "zealot", "most recent qualifying attacker")

-- 11. Templates outside the table and reset.
eq(Sourceless.is_sourceless(BURN), true, "flamer_assault is sourceless")
eq(Sourceless.is_sourceless("bleed"), false, "bleed is not sourceless")
eq(Sourceless.on_debuff_added(enemy8, "bleed", true, true, true, 91.0), nil, "other templates ignored")
Sourceless.reset()
eq(Sourceless.dot_owner(enemy8, "burning"), nil, "reset clears owners")
eq(Sourceless.on_debuff_added(enemy8, BURN, true, true, true, 92.0), nil, "reset clears recent attacks")

print(string.format("sourceless_test: %d checks passed", checks))
