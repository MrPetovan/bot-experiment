local U = {};

local RB = Vector(-7174.000000, -6671.00000,  0.000000)
local DB = Vector(7023.000000, 6450.000000, 0.000000)
local maxGetRange = 1600;
local maxAddedRange = 200;

local fSpamThreshold = 0.55;

local listBoots = {
	['item_boots'] = 45, 
	['item_tranquil_boots'] = 90, 
	['item_power_treads'] = 45, 
	['item_phase_boots'] = 45, 
	['item_arcane_boots'] = 50, 
	['item_guardian_greaves'] = 55,
	['item_travel_boots'] = 100,
	['item_travel_boots_2'] = 100
}

local modifier = {
	"modifier_winter_wyvern_winters_curse",
	"modifier_modifier_dazzle_shallow_grave",
	"modifier_modifier_oracle_false_promise",
	"modifier_oracle_fates_edict"
}

function U.InitiateAbilities(hUnit, tSlots)
	local abilities = {};
	for _,i in pairs(tSlots) do
		table.insert(abilities, hUnit:GetAbilityInSlot(i));
	end
	return abilities;
end

function U.CantUseAbility(bot)
	return bot:NumQueuedActions() > 0 
		   or not bot:IsAlive() or bot:IsInvulnerable() or bot:IsCastingAbility() or bot:IsUsingAbility() or bot:IsChanneling()  
	       or bot:IsSilenced() or bot:IsStunned() or bot:IsHexed() or bot:IsHexed()   
		   or bot:HasModifier("modifier_doom_bringer_doom")
		   or bot:HasModifier('modifier_item_forcestaff_active')
end

function U.CanBeCast(ability)
	return ability:IsTrained() and ability:IsFullyCastable() and not ability:IsHidden();
end

function U.GetProperCastRange(bIgnore, hUnit, abilityCR)
	local attackRng = hUnit:GetAttackRange();
	if bIgnore then
		return abilityCR;
	elseif abilityCR <= attackRng then
		return attackRng + maxAddedRange;
	elseif abilityCR + maxAddedRange <= maxGetRange then
		return abilityCR + maxAddedRange;
	elseif abilityCR > maxGetRange then
		return maxAddedRange;
	end
end

function U.GetVulnerableWeakestUnit(bHero, bEnemy, nRadius, bot)
	local units = {};
	local weakest = nil;
	local weakestHP = 10000;
	if bHero then
		units = bot:GetNearbyHeroes(nRadius, bEnemy, BOT_MODE_NONE);
	else
		units = bot:GetNearbyLaneCreeps(nRadius, bEnemy);
	end
	for _,u in pairs(units) do
		if u:GetHealth() < weakestHP and U.CanCastOnNonMagicImmune(u) then
			weakest = u;
			weakestHP = u:GetHealth();
		end
	end
	return weakest;
end

function U.GetVulnerableUnitNearLoc(bHero, bEnemy, nCastRange, nRadius, vLoc, bot)
	local units = {};
	local weakest = nil;
	if bHero then
		units = bot:GetNearbyHeroes(nCastRange, bEnemy, BOT_MODE_NONE);
	else
		units = bot:GetNearbyLaneCreeps(nCastRange, bEnemy);
	end
	for _,u in pairs(units) do
		if GetUnitToLocationDistance(u, vLoc) < nRadius and U.CanCastOnNonMagicImmune(u) then
			weakest = u;
			break;
		end
	end
	return weakest;
end

function U.CanSpamSpell(bot, manaCost)
	local initialRatio = 1.0;
	if manaCost < 100 then
		initialRatio = 0.6;
	end
	return ( bot:GetMana() - manaCost ) / bot:GetMaxMana() >= ( initialRatio - bot:GetLevel()/(2*25) );
end


function U.GetAllyWithNoBuff(nCastRange, sModifier, bot)
	local target = nil;
	local allies = bot:GetNearbyHeroes(nCastRange, false, BOT_MODE_NONE);
	for _,u in pairs(allies) do
		if not u:HasModifier(sModifier) and U.CanCastOnNonMagicImmune(u) then
			target = u;
			break;
		end
	end
	return target;
end

function U.GetBuildingWithNoBuff(nCastRange, sModifier, bot)
	local ancient = GetAncient(GetTeam());
	if not ancient:IsInvulnerable() and GetUnitToUnitDistance(ancient, bot) < nCastRange then
		return ancient;
	end
	local barracks = bot:GetNearbyBarracks(nCastRange, false);
	for _,u in pairs(barracks) do
		if not u:HasModifier(sModifier) and not u:IsInvulnerable() then
			return u;
		end
	end
	local towers = bot:GetNearbyTowers(nCastRange, false);
	for _,u in pairs(towers) do
		if not u:HasModifier(sModifier) and not u:IsInvulnerable() then
			return u;
		end
	end
	return nil;
end

function U.GetSpellKillTarget(bot, bHero, nRadius, nDamage, nDamageType)
	local units = {};
	if bHero then
		units = bot:GetNearbyHeroes(nRadius, true, BOT_MODE_NONE);
	else
		units = bot:GetNearbyLaneCreeps(nRadius, true);
	end
	for _,unit in pairs(units) do
		if unit ~= nil and unit:GetHealth() <= unit:GetActualIncomingDamage(nDamage, nDamageType) then
			return unit;
		end
	end
	return nil;
end

function U.IsEnemyTargetMyTarget(bot, hTarget)
	local enemies = bot:GetNearbyHeroes(1600, true, BOT_MODE_NONE);
	for _,enemy in pairs(enemies) do
		local eaTarget = enemy:GetAttackTarget(); 
		if eaTarget ~= nil and eaTarget == hTarget then
			return true;
		end	
	end
	return false;
end
--============== ^^^^^^^^^^ NEW FUNCTION ABOVE ^^^^^^^^^ ================--

function U.IsRetreating(npcBot)
	return npcBot:GetActiveMode() == BOT_MODE_RETREAT and npcBot:GetActiveModeDesire() > BOT_MODE_DESIRE_MODERATE and npcBot:DistanceFromFountain() > 0
end

function U.IsValidTarget(npcTarget)
	return npcTarget ~= nil and npcTarget:IsAlive() and npcTarget:IsHero(); 
end

function U.IsSuspiciousIllusion(npcTarget)
	--TO DO Need to detect enemy hero's illusions better
	local bot = GetBot();
	--Detect allies's illusions
	if npcTarget:IsIllusion() or npcTarget:HasModifier('modifier_illusion') 
	   or npcTarget:HasModifier('modifier_phantom_lancer_doppelwalk_illusion') or npcTarget:HasModifier('modifier_phantom_lancer_juxtapose_illusion')
       or npcTarget:HasModifier('modifier_darkseer_wallofreplica_illusion') or npcTarget:HasModifier('modifier_terrorblade_conjureimage')	   
	then
		return true;
	else
	--Detect replicate and wall of replica illusions
		if npcTarget:GetTeam() ~= bot:GetTeam() then
			local TeamMember = GetTeamPlayers(GetTeam());
			for i = 1, #TeamMember
			do
				local ally = GetTeamMember(i);
				if ally ~= nil and ally:GetUnitName() == npcTarget:GetUnitName() then
					return true;
				end
			end
		end
		return false;
	end
end

function U.CanCastOnMagicImmune(npcTarget)
	return npcTarget:CanBeSeen() and not npcTarget:IsInvulnerable() and not U.IsSuspiciousIllusion(npcTarget);
end

function U.CanCastOnNonMagicImmune(npcTarget)
	return npcTarget:CanBeSeen() and not npcTarget:IsMagicImmune() and not npcTarget:IsInvulnerable() and not U.IsSuspiciousIllusion(npcTarget);
end

function U.CanCastOnTargetAdvanced( npcTarget )
	return npcTarget:CanBeSeen() and not npcTarget:IsMagicImmune() and not npcTarget:IsInvulnerable() and not U.HasForbiddenModifier(npcTarget)
end

function U.CanKillTarget(npcTarget, dmg, dmgType)
	return npcTarget:GetActualIncomingDamage( dmg, dmgType ) >= npcTarget:GetHealth(); 
end

function U.HasForbiddenModifier(npcTarget)
	for _,mod in pairs(modifier)
	do
		if npcTarget:HasModifier(mod) then
			return true
		end	
	end
	return false;
end

function U.ShouldEscape(npcBot)
	local tableNearbyEnemyHeroes = npcBot:GetNearbyHeroes( 1000, true, BOT_MODE_NONE );
	if ( npcBot:WasRecentlyDamagedByAnyHero(2.0) or npcBot:WasRecentlyDamagedByTower(2.0) or ( tableNearbyEnemyHeroes ~= nil and #tableNearbyEnemyHeroes > 1  ) )
	then
		return true;
	end
end

function U.IsRoshan(npcTarget)
	return npcTarget ~= nil and npcTarget:IsAlive() and string.find(npcTarget:GetUnitName(), "roshan");
end

function U.IsDisabled(enemy, npcTarget)
	if enemy 
	then
		return npcTarget:IsRooted( ) or npcTarget:IsStunned( ) or npcTarget:IsHexed( ) or npcTarget:IsNightmared() or U.IsTaunted(npcTarget); 
	else
		return npcTarget:IsRooted( ) or npcTarget:IsStunned( ) or npcTarget:IsHexed( ) or npcTarget:IsNightmared() or npcTarget:IsSilenced( ) or U.IsTaunted(npcTarget);
	end
end

function U.IsSlowed(bot)
	local speedPlusBoots =  U.GetUpgradedSpeed(bot);
	return bot:GetCurrentMovementSpeed() < speedPlusBoots;
end

function U.GetUpgradedSpeed(bot)
	for i=0,5 do
		local item = bot:GetItemInSlot(i);
		if item ~= nil and listBoots[item:GetName()] ~= nil then
			return bot:GetBaseMovementSpeed()+listBoots[item:GetName()];
		end
	end
	return bot:GetBaseMovementSpeed();
end

function U.IsTaunted(npcTarget)
	return npcTarget:HasModifier("modifier_axe_berserkers_call") or npcTarget:HasModifier("modifier_legion_commander_duel") 
	    or npcTarget:HasModifier("modifier_winter_wyvern_winters_curse");
end

function U.IsInRange(npcTarget, npcBot, nCastRange)
	return GetUnitToUnitDistance( npcTarget, npcBot ) <= nCastRange;
end

function U.IsInTeamFight(npcBot, range)
	local tableNearbyAttackingAlliedHeroes = npcBot:GetNearbyHeroes( range, false, BOT_MODE_ATTACK );
	return tableNearbyAttackingAlliedHeroes ~= nil and #tableNearbyAttackingAlliedHeroes >= 2;
end

function U.CanNotUseAbility(npcBot)
	return npcBot:IsCastingAbility() or npcBot:IsUsingAbility() or npcBot:IsInvulnerable() or npcBot:IsChanneling() or npcBot:IsSilenced() or npcBot:HasModifier("modifier_doom_bringer_doom");
end

function U.IsGoingOnSomeone(npcBot)
	local mode = npcBot:GetActiveMode();
	return mode == BOT_MODE_ROAM or
		   mode == BOT_MODE_TEAM_ROAM or
		   mode == BOT_MODE_GANK or
		   mode == BOT_MODE_ATTACK or
		   mode == BOT_MODE_DEFEND_ALLY
end

function U.IsDefending(npcBot)
	local mode = npcBot:GetActiveMode();
	return mode == BOT_MODE_DEFEND_TOWER_TOP or
		   mode == BOT_MODE_DEFEND_TOWER_MID or
		   mode == BOT_MODE_DEFEND_TOWER_BOT 
end

function U.IsPushing(npcBot)
	local mode = npcBot:GetActiveMode();
	return mode == BOT_MODE_PUSH_TOWER_TOP or
		   mode == BOT_MODE_PUSH_TOWER_MID or
		   mode == BOT_MODE_PUSH_TOWER_BOT 
end

function U.GetTeamFountain()
	local Team = GetTeam();
	if Team == TEAM_DIRE then
		return DB;
	else
		return RB;
	end
end

function U.GetComboItem(npcBot, item_name)
	local Slot = npcBot:FindItemSlot(item_name);
	if Slot >= 0 and Slot <= 5 then
		return npcBot:GetItemInSlot(Slot);
	else
		return nil;
	end
end

function U.GetMostHpUnit(ListUnit)
	local mostHpUnit = nil;
	local maxHP = 0;
	for _,unit in pairs(ListUnit)
	do
		local uHp = unit:GetHealth();
		if  uHp > maxHP then
			mostHpUnit = unit;
			maxHP = uHp;
		end
	end
	return mostHpUnit
end

function U.StillHasModifier(npcTarget, modifier)
	return npcTarget:HasModifier(modifier);
end

function U.AllowedToSpam(npcBot, nManaCost)
	return ( npcBot:GetMana() - nManaCost ) / npcBot:GetMaxMana() >= fSpamThreshold;
end

function U.IsProjectileIncoming(npcBot, range)
	local incProj = npcBot:GetIncomingTrackingProjectiles()
	for _,p in pairs(incProj)
	do
		if GetUnitToLocationDistance(npcBot, p.location) < range and not p.is_attack and p.is_dodgeable then
			return true;
		end
	end
	return false;
end

function U.GetMostHPPercent(listUnits, magicImmune)
	local mostPHP = 0;
	local mostPHPUnit = nil;
	for _,unit in pairs(listUnits)
	do
		local uPHP = unit:GetHealth() / unit:GetMaxHealth()
		if ( ( magicImmune and U.CanCastOnMagicImmune(unit) ) or ( not magicImmune and U.CanCastOnNonMagicImmune(unit) ) ) 
			and uPHP > mostPHP  
		then
			mostPHPUnit = unit;
			mostPHP = uPHP;
		end
	end
	return mostPHPUnit;
end

function U.GetCanBeKilledUnit(units, nDamage, nDmgType, magicImmune)
	local target = nil;
	for _,unit in pairs(units)
	do
		if ( ( magicImmune and U.CanCastOnMagicImmune(unit) ) or ( not magicImmune and U.CanCastOnNonMagicImmune(unit) ) ) 
			   and U.CanKillTarget(unit, nDamage, nDmgType) 
		then
			unitKO = target;	
		end
	end
	return target;
end

function U.GetCorrectLoc(target, delay)
	if target:GetMovementDirectionStability() < 1.0 then
		return target:GetLocation();
	else
		return target:GetExtrapolatedLocation(delay);	
	end
end

function U.GetClosestUnit(units)
	local target = nil;
	if units ~= nil and #units >= 1 then
		return units[1];
	end
	return target;
end

function U.GetEnemyFountain()
	local Team = GetTeam();
	if Team == TEAM_DIRE then
		return RB;
	else
		return DB;
	end
end

function U.GetEscapeLoc()
	local bot = GetBot();
	local team = GetTeam();
	if bot:DistanceFromFountain() > 2500 then
		return GetAncient(team):GetLocation();
	else
		if team == TEAM_DIRE then
			return DB;
		else
			return RB;
		end
	end
end

function U.IsStuck2(npcBot)
	if npcBot.stuckLoc ~= nil and npcBot.stuckTime ~= nil then 
		local EAd = GetUnitToUnitDistance(npcBot, GetAncient(GetOpposingTeam()));
		if DotaTime() > npcBot.stuckTime + 5.0 and GetUnitToLocationDistance(npcBot, npcBot.stuckLoc) < 25  
           and npcBot:GetCurrentActionType() == BOT_ACTION_TYPE_MOVE_TO and EAd > 2200		
		then
			print(npcBot:GetUnitName().." is stuck")
			--DebugPause();
			return true;
		end
	end
	return false
end

function U.IsStuck(npcBot)
	if npcBot.stuckLoc ~= nil and npcBot.stuckTime ~= nil then 
		local attackTarget = npcBot:GetAttackTarget();
		local EAd = GetUnitToUnitDistance(npcBot, GetAncient(GetOpposingTeam()));
		local TAd = GetUnitToUnitDistance(npcBot, GetAncient(GetTeam()));
		local Et = npcBot:GetNearbyTowers(450, true);
		local At = npcBot:GetNearbyTowers(450, false);
		if npcBot:GetCurrentActionType() == BOT_ACTION_TYPE_MOVE_TO and attackTarget == nil and EAd > 2200 and TAd > 2200 and #Et == 0 and #At == 0  
		   and DotaTime() > npcBot.stuckTime + 5.0 and GetUnitToLocationDistance(npcBot, npcBot.stuckLoc) < 25    
		then
			print(npcBot:GetUnitName().." is stuck")
			return true;
		end
	end
	return false
end

function U.IsExistInTable(u, tUnit)
	for _,t in pairs(tUnit) do
		if u:GetUnitName() == t:GetUnitName() then
			return true;
		end
	end
	return false;
end 

function U.FindNumInvUnitInLoc(pierceImmune, bot, nRange, nRadius, loc)
	local nUnits = 0;
	if nRange > 1600 then nRange = 1600 end
	local units = bot:GetNearbyHeroes(nRange, true, BOT_MODE_NONE);
	for _,u in pairs(units) do
		if ( ( pierceImmune and U.CanCastOnMagicImmune(u) ) or ( not pierceImmune and U.CanCastOnNonMagicImmune(u) ) ) and GetUnitToLocationDistance(u, loc) <= nRadius then
			nUnits = nUnits + 1;
		end
	end
	return nUnits;
end

function U.CountInvUnits(pierceImmune, units)
	local nUnits = 0;
	if units ~= nil then
		for _,u in pairs(units) do
			if ( pierceImmune and U.CanCastOnMagicImmune(u) ) or ( not pierceImmune and U.CanCastOnNonMagicImmune(u) )  then
				nUnits = nUnits + 1;
			end
		end
	end
	return nUnits;
end

function U.CanBeDominatedCreeps(name)
	return name == "npc_dota_neutral_centaur_khan"
		 or name == "npc_dota_neutral_polar_furbolg_ursa_warrior"	
		 or name == "npc_dota_neutral_satyr_hellcaller"	
		 or name == "npc_dota_neutral_dark_troll_warlord"	
		 or name == "npc_dota_neutral_mud_golem"	
		 or name == "npc_dota_neutral_harpy_storm"	
		 or name == "npc_dota_neutral_ogre_magi"	
		 or name == "npc_dota_neutral_alpha_wolf"	
		 or name == "npc_dota_neutral_enraged_wildkin"	
		 or name == "npc_dota_neutral_satyr_trickster"	
end

return U;