local FTD = FTD

-- Boss tips for the "Next Boss" callout in the Forces & Bloodlust panel.
-- Keyed by boss display name exactly as MDT's own dungeon data names it
-- (RouteIndex reads this off enemyData.name, the same name MDT's map/pull
-- list already show) -- case-sensitive, English client. `/ftd debug` prints
-- the boss name(s) MDT is reporting for each pull in your current route, so
-- you can copy the exact key straight out of that if a boss isn't showing up.
--
-- Each entry is an ordered list of 1-3 short, plain-text tips -- the callout
-- only ever shows the first 2. A tip starting with "TANK:", "HEAL:" or
-- "DPS:" gets that word colored; everything else prints plain.
--
-- Seeded below with all 8 current-season dungeons (own wording, condensed
-- from public strategy write-ups, not copied text). A few dual-boss fights
-- are keyed under both their combined name and each individual boss's name,
-- since it isn't known ahead of time which one MDT flags as "the boss" --
-- double-check every key against `/ftd debug` in your own client before
-- relying on it, since MDT's exact string has to match to the letter, and
-- edit freely; this is a starting point, not a guarantee of accuracy.
--
-- FTD.TacticsData = {
--   ["Example Boss Name"] = {
--     "Move out of the frontal cone.",
--     "HEAL: keep a HoT rolling on the tank during Bleeding Wound.",
--   },
-- }

FTD.TacticsData = {

  -- =========================================================================
  -- ALTAR OF FANGS
  -- =========================================================================

  ["Rav'i"] = {
    "Stack on Messy Eaters (Ssscavenging) to break their shields fast.",
    "Spread out for Triple Shot's frontal cleave.",
    "HEAL: dispel Regurgitate if you're hit by it.",
  },

  ["The Writhing Coil"] = {
    "Interrupt every Toxic Atrophy cast.",
    "Snap Death Rattle tethers with a movement ability to cut the AoE damage.",
    "Stack and CC the Uncoiled Writhe adds during Death Rattle -- they mirror damage to the boss.",
  },

  ["Zul'jan"] = {
    "Soak all 4 Ritual of the Fang beams -- have healing cooldowns ready.",
    "Stand in Boneslicer on purpose to clear Ritual Venom stacks before they expire.",
    "TANK: defensive for Chop Down, and watch for puddles if stacks remain.",
  },

  -- =========================================================================
  -- MURDER ROW
  -- =========================================================================

  ["Kystia Manaheart"] = {
    "DPS: focus the Nibbles adds while Felshield is up, not the boss.",
    "Interrupt or CC the Mirror Images to kill them fast.",
    "HEAL: save cooldowns for Destabilized at 20% -- heavy raid damage.",
  },

  ["Zaen Bladesorrow"] = {
    "Avoid the barrels dropped by Same-Day Delivery.",
    "Cleave down the Fel-Infused Freight from Fire Bomb quickly to cut group damage.",
    "HEAL: prepare cooldowns for Killing Spree, worse if the freight is still up.",
  },

  ["Xathuux the Annihilator"] = {
    "TANK: face Legion Strike's frontal toward the arena edge.",
    "DPS: swap onto the Legion Axe from Axe Toss immediately.",
    "Spread out for Infernal Crush and use a defensive -- it overlaps with Demonic Rage.",
  },

  ["Lithiel Cinderfury"] = {
    "Keep interrupts rotating on Chaos Bolt.",
    "Kill the Wild Imps from Fingers of Gul'dan before Malefic Wave hits, or they get empowered.",
    "Wait for Malefic Wave to finish before stepping through Demonic Gateway.",
  },

  -- =========================================================================
  -- DEN OF NALORAKK
  -- =========================================================================

  ["The Hoardmonger"] = {
    "Watch which resource pile gets empowered at 90/70/40% -- it changes the abilities that follow.",
    "Grab a Spoiled Supplies mushroom within 12 seconds or it bursts.",
    "Step out of the Earthshatter/Bonespike Slam frontal.",
  },

  ["Sentinel of Winter"] = {
    "HEAL: dispel Glacial Torment quickly.",
    "Stack to bait Raging Squall's tornadoes into one spot, then rotate as a group.",
    "Kill the Shattering Frostspike adds and soak the snow piles they leave.",
  },

  ["Nalorakk"] = {
    "Drop Echoing Maul debuffs near existing echoes -- don't walk into echoes yourself.",
    "Group behind the tank's shield for Overwhelming Onslaught; tank soaks the follow-up slam.",
    "Wall up in the center to block the charging echoes during Fury of the War God.",
  },

  -- =========================================================================
  -- THE BLINDING VALE
  -- =========================================================================

  ["Lightblossom Trinity"] = {
    "Interrupt Light Bolt on rotation.",
    "Tank plus 2 DPS soak the Lightblossom Beam circles.",
    "Avoid the Lightsower Dash line and step away from Thornblade's target.",
  },

  ["Ikuzz the Light Hunter"] = {
    "HEAL: cooldowns ready for Thorncaller Roar.",
    "Avoid Bloodthorn Roots, or use freedom/cleanse if caught.",
    "Kite the Bloodthirsty Gaze fixate over the roots to clear them.",
  },

  ["Lightwarden Ruia"] = {
    "P1: interrupt Warden's Wrath and stack the Lightfire-debuffed players before it expires.",
    "P2 (Bear Form): cleanse or self-heal through the bleed stacks.",
    "P3: the boss cycles through every earlier phase's mechanics every 8s -- stay ready.",
  },

  ["Ziekket"] = {
    "HEAL: cooldowns up throughout for the constant Oozing Xylem damage.",
    "Interrupt and cleave down the Awaken the Lightbloom adds fast.",
    "Soak the Lightbloom's Essence orbs before they reach the boss -- spread who takes each one.",
  },

  -- =========================================================================
  -- VOIDSCAR ARENA
  -- =========================================================================

  ["Taz'Rah"] = {
    "Spread out at the room edge for Nether Dash.",
    "TANK: defensive for Void Blast and avoid standing in old puddles.",
    "Keep moving during Dark Bloom to dodge the orbs the puddles shoot out.",
  },

  ["Atroxus"] = {
    "Avoid the Poison Splash puddles.",
    "DPS: swap to the Toxic Creeper add on sight -- it pulses AoE damage.",
    "TANK: kite the Creeper and watch your Sickening Bite stacks before the next Hulking Claw.",
  },

  ["Charonus"] = {
    "Spread loosely for Cosmic Crash and stay clear of the Unstable Singularity orbs.",
    "Kite the Gravitic Orbs fixate through a Singularity to clear its stacks.",
    "TANK: point Dark Waves away from the group.",
  },

  -- =========================================================================
  -- RUBY LIFE POOLS
  -- =========================================================================

  ["Melidrussa Chillworn"] = {
    "Interrupt Frigid Shard to cut down the tank damage.",
    "Group up to bait Hailburst's ice circles into one spot.",
    "TANK: pick up the adds from Awaken Whelps at 66%/33% -- a shielded AoE follows.",
  },

  ["Kokia Blazehoof"] = {
    "Move away and let the group focus the add spawned by Ritual of Blazebinding.",
    "HEAL: have a big heal ready for Inferno.",
    "TANK: defensive on every Searing Blows.",
  },

  ["Kyrakka and Erkhart Stormvein"] = {
    "Spread out for Inferno Spit and use the wind to move the puddles.",
    "HEAL: dispel the Stormslam debuff before the next cast lands.",
    "Stop casting during Interrupting Cloudburst, then burst once Erkhart mounts up at 50%.",
  },
  -- Same fight, in case MDT flags the two riders as separate boss NPCs.
  ["Kyrakka"] = {
    "Spread out for Inferno Spit and use the wind to move the puddles.",
    "HEAL: dispel the Stormslam debuff before the next cast lands.",
    "Stop casting during Interrupting Cloudburst, then burst once Erkhart mounts up at 50%.",
  },
  ["Erkhart Stormvein"] = {
    "Spread out for Inferno Spit and use the wind to move the puddles.",
    "HEAL: dispel the Stormslam debuff before the next cast lands.",
    "Stop casting during Interrupting Cloudburst, then burst once Erkhart mounts up at 50%.",
  },

  -- =========================================================================
  -- TEMPLE OF SETHRALISS
  -- =========================================================================

  ["Adderis and Aspix"] = {
    "Watch which boss has Storm Blessed immunity and switch damage to the other.",
    "Spread for Gale Force, then collapse together to soak Thunder and Lightning.",
    "Players with Tempest Winds move away from the group before dropping their puddle.",
  },
  -- Same fight, in case MDT flags the two as separate boss NPCs.
  ["Adderis"] = {
    "Watch which boss has Storm Blessed immunity and switch damage to the other.",
    "Spread for Gale Force, then collapse together to soak Thunder and Lightning.",
    "Players with Tempest Winds move away from the group before dropping their puddle.",
  },
  ["Aspix"] = {
    "Watch which boss has Storm Blessed immunity and switch damage to the other.",
    "Spread for Gale Force, then collapse together to soak Thunder and Lightning.",
    "Frenzy enrages Aspix once Adderis dies -- tighten up positioning.",
  },

  ["Merektha"] = {
    "Stack to CC and cleave the Knot of Snakes adds together.",
    "Drop Thunder Spit circles outside the group and use a defensive for the DoT.",
    "During Burrow: interrupt Poison Spit and dispel the poison DoT while killing the adds.",
  },

  ["Galvazzt"] = {
    "Soak between the Lightning Spires and the boss to stop Consume Charge -- can wipe at full energy.",
    "TANK: move the boss away from the puddle Induction leaves.",
  },

  ["Avatar of Sethraliss"] = {
    "Grab a Corruption Burst soak before it explodes at 6 seconds.",
    "Interrupt the Twisted Hexxer's Flame Shock and move out for Latent Hex.",
    "CC and kite the Tormentors away for Shadowlash.",
  },

  -- =========================================================================
  -- KING'S REST
  -- =========================================================================

  ["The Golden Serpent"] = {
    "Stack the Spit Gold puddles together and cleave/slow the Animated Gold adds they spawn.",
    "HEAL: cooldowns ready for Serpentine Gust.",
  },

  ["Mchimba the Embalmer"] = {
    "Top off health before Awakening Slam, then cleave and interrupt the mummy adds it spawns.",
    "Spread out to find and free whoever gets Entombed quickly.",
    "Move Burn Corruption away from the boss and the sarcophagi.",
  },

  ["The Council of Tribes"] = {
    "Stack up for Barrel Through -- it still goes off after one council member dies.",
    "Interrupt Poison Nova; kill Call the Elements totems in order: Explosive, then Thundering, then Torrent.",
    "TANK: keep the boss centered for Whirling Axes.",
  },

  ["Dazar, the First King"] = {
    "Interrupt Deathly Roar and stay out of Hunting Leap's frontal.",
    "Spread for Aerial Smash -- it becomes a 4-target Quaking Leap once Reban mounts up.",
    "TANK: defensive for Blade Combo; HEAL: prepare for Gilded Destruction.",
  },

}
