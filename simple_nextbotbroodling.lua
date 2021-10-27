
AddCSLuaFile()

ENT.Base = "base_nextbot"
ENT.Spawnable = true
ENT.LookingSound = Sound("npc/scanner/scanner_siren1.wav")
ENT.AlertSound = Sound("npc/turret_floor/alarm.wav")
ENT.ScaredSound = Sound("npc/scanner/cbot_servoscared.wav")
--ENT.AlertSound = Sound("vo/Breencast/br_welcome04.wav") --For Mikey & Cwombles
local vcount = 0

function ENT:Initialize()
    self:SetModel("models/Lamarr.mdl")

    self.LoseTargetDist = 2000
    self.SearchRadius = 1000
end

function ENT:SetEnemy(ent)
    self.Enemy = ent
end

function ENT:GetEnemy()
    return self.Enemy
end

function ENT:HaveEnemy()
    if(self:GetEnemy() and IsValid(self:GetEnemy()))then
        if(self:GetRangeTo(self:GetEnemy():GetPos()) > self.LoseTargetDist)then
            return self:FindEnemy()
        
        elseif(self:GetEnemy():IsPlayer() and not self:GetEnemy():Alive())then
            return self:FindEnemy()
        end

        return true
    else
        return self:FindEnemy()
    end
end

function ENT:FindEnemy()
    local _ents = ents.FindInSphere(self:GetPos(),self.SearchRadius)

    for k,v in ipairs(_ents)
    do
        if(v:IsPlayer())then
            self:SetEnemy(v)
            return true
        end
    end

    self:SetEnemy(nil)
    return false
end



function ENT:RunBehaviour()
    while(true)
    do
        if(self:HaveEnemy())then
            --self:EmitSound(self.AlertSound, 500, 170) --For Mikey & Cwombles
            self:EmitSound(self.AlertSound)
            
            self.loco:FaceTowards(self:GetEnemy():GetPos())

            self:PlaySequenceAndWait("plant")
            self:PlaySequenceAndWait("pet_angry")
            self:PlaySequenceAndWait("unplant")

            self:StartActivity(ACT_RUN)
            self.loco:SetDesiredSpeed(400)
            self.loco:SetAcceleration(500)

            if(self:GetEnemy():GetActiveWeapon():GetClass() == "weapon_bugbait")then
                self:StopSound(self.AlertSound)
                self:EmitSound(self.ScaredSound, 100, 150)
                self:RunAway()
            else
                self:ChaseEnemy()
            end

            self.loco:SetAcceleration(250)
            self:PlaySequenceAndWait("charge_miss_slide")

            self:StartActivity(ACT_IDLE)
            self:StopSound(self.AlertSound)
        else
            self:StartActivity(ACT_WALK)
            self.loco:SetDesiredSpeed(100)
            self:MoveToPos(self:GetPos()+Vector(math.Rand(-1,1),math.Rand(-1,1),0)*400)
            self:StartActivity(ACT_IDLE)
            self:EmitSound(self.LookingSound)
        end
    end
end

function ENT:ChaseEnemy(options)
    local options = options or {}
    local path = Path("Follow")

    path:SetMinLookAheadDistance(options.lookahead or 300)
    path:SetGoalTolerance(options.tolerance or 0)
    path:Compute(self,self:GetEnemy():GetPos())

    if(not path:IsValid())then
        return "failed"
    end

    while(path:IsValid() and self:HaveEnemy())
    do
        if(path:GetAge()>0.1)then
            path:Compute(self,self:GetEnemy():GetPos())
        end

        path:Update(self)

        if(options.draw)then
            path:Draw()
        end

        if(self:GetEnemy():GetActiveWeapon():GetClass() == "weapon_bugbait")then
            break
        end

        if(self.loco:IsStuck())then
            self:HandleStuck()
            return "stuck"
        end

        coroutine.yield()
    end
    return "ok"
end

local function AddNPC( t, class )
    list.Set( "NPC", class or t.Class, t )
end

AddNPC({
    Name = "Broodling",
    Class = "simple_nextbotbroodling",
    Category = "Broodlurkers",
    Health = "10"
})

function ENT:RunAway()
    self:StartActivity(ACT_RUN)
    self:MoveToPos(self:GetPos()+Vector(math.Rand(-10,10),math.Rand(-10,10),0)*300)
    --self:PlaySequenceAndWait("fear_reaction")
end

function ENT:OnContact(theTouched)
    local ENTAttackSound = CreateSound(self,"npc/zombie/zo_attack1.wav")
    if(theTouched:IsPlayer() and not ENTAttackSound:IsPlaying() and not theTouched:IsOnFire())then
        ENTAttackSound:Play()
        theTouched:Ignite(0.5,10)
    else
        return
    end
end

function ENT:OnInjured(dmginfo)
    if(dmginfo:GetInflictor():GetPos():Distance(self:GetPos()) < 125 and not dmginfo:GetInflictor():IsOnFire())then
        dmginfo:GetInflictor():Ignite(1,10)
    else
        return
    end
end

function ENT:OnKilled(dmginfo)
    hook.Call("OnNPCKilled",GAMEMODE,self,dmginfo:GetAttacker(),dmginfo:GetInflictor())
    self:StopSound(self.AlertSound)
    self:StopSound(self.LookingSound)

    local vpoint = self:GetPos()
    local effectdata_bloodsplat = EffectData()

    effectdata_bloodsplat:SetOrigin(vpoint)
    effectdata_bloodsplat:SetMagnitude(100)
    util.Effect("AntlionGib",effectdata_bloodsplat)

    if(dmginfo:GetInflictor():GetPos():Distance(self:GetPos()) < 90)then
        dmginfo:GetInflictor():Ignite(5,10)
    end

    local body = ents.Create("prop_ragdoll")
    body:SetPos(self:GetPos())
    body:SetModel(self:GetModel())
    body:Spawn()

    self:Remove()

    timer.Simple(10,
    function()
    body:Remove()
    end
    )
end

    function ENT:OnRemove()
        self:StopSound(self.AlertSound)
        self:StopSound(self.LookingSound)
        self:StopSound(self.ScaredSound)
    end

