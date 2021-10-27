
--1st)Basic stuff we need for entities

--Defining the base entity to use and making it spawnable, pretty much the same as any other entity
--I.E. set the model and define some variables we will use later

AddCSLuaFile()

ENT.Base = "base_nextbot"
ENT.Spawnable = true
ENT.LookingSound = Sound("npc/scanner/scanner_siren1.wav")
ENT.AlertSound = Sound("npc/turret_floor/alarm.wav")
ENT.RestSound = Sound("items/suitcharge1.wav")
ENT.ScaredSound = Sound("npc/scanner/cbot_servoscared.wav")
ENT.RestFSound = Sound("items/suitchargeok1.wav")
local vcount = 0

function ENT:Initialize()
        self:SetModel("models/vortigaunt.mdl")

        self.LoseTargetDist = 2000--How far the enemy(player) has to be before the npc loses them
        self.SearchRadius = 1000--How far the npc will search for enemies
        --'self.SearchRadius = 1000' is like saying 'self["SearchRadius"] = 1000' ->
        -- -> Or even like saying:
        --                       ENT{
        --                            ["SearchRadius"] = 1000
        --                       --Or even SearchRadius = 1000
        --                          }
end

--2nd)Enemy related stuff
--(I.e. some useful functions for enemy related stuff)

-- ENT:Get/SetEnemy()
-- Simple functions used in keeping our enemy saved

function ENT:SetEnemy(ent)--using (self,ent) ent is the "enemy"(player) sent to the NPC
    self.Enemy = ent --setting the 'Enemy' variable(a key) in the library 'ENT' as the variable 'ent'
end

function ENT:GetEnemy()--After function SetEnemy is run 'self.Enemy' is set so for now on ->
    -- -> if the NPC needs info on who the "enemy"(player) is, then it can use the ->
    -- -> GetEnemy() function that returns 'self.Enemy' to where the function was called
    return self.Enemy
end
--Technically could replace all of above with but is bad because it resets Enemy everytime you just want to get it ->
-- -> instead of reusing the value of 'self.Enemy' which is 'ent' which is the enemy
    -- function ENT:SetEnemy(ent)
    --   self.Enemy = ent
    --   return self.Enemy
    -- end

    -- function ENT:GetEnemy(ent)
    --   return ENT:SetEnemy(ent)
    -- end

-- ENT:HaveEnemy()
-- Returns true if we have an enemy

function ENT:HaveEnemy()
    if (self:GetEnemy() and IsValid(self:GetEnemy()))then
        --if the enemy is too far
    --IMPORTANT: 'self:GetEnemy():GetPos()' This looks weird so I will walk-through how it loops for future reference ->
    -- -> 1st: it gets the Enemy using self as the only parameter in 'self:GetEnemy()' ->
    -- -> 2nd: it then uses that enemy found there and sends it as new self as the ->
    -- ->      only parameter in ':GetPos()'(it kind of looks like Enemyfound:GetPos())
    -- -> The whole thing looks like 'self:GetEnemy():GetPos()'
        if(self:GetRangeTo(self:GetEnemy():GetPos()) > self.LoseTargetDist ) then
            --If the enemy is lost then call FindEnemy() to look for a new one
            --FindEnemy() will return true if an enemy is found, making this function return true
            return self:FindEnemy()

        --If the enemy is dead(we have to check if its a player before we use Alive())
        --(See lines 51-55 to see how the parameters in the 'elseif' work)
        elseif(self:GetEnemy():IsPlayer() and not self:GetEnemy():Alive())then
            return self:FindEnemy()--Return false if the search finds nothing(make the FindEnemy() function later)
        end
        --The enemy is netiher too far nor too dead so we can return true
        return true
    else
        --The enemy isnt valid so lets go for a new one
        return self:FindEnemy()--Will make 'FindEnemy()' function later
    end
end

--This is the all returning 'FindEnemy()' function we were talking about

-- ENT:FindEnemy()
-- Returns true and sets our enemy if we find one

function ENT:FindEnemy()
    --Search around us for entities
    --IMPORTANT: This can be done any way you want(I.e.: ents.FindinCone() to replicate eyesight)

    --1st Parameter: Gets the position of 'self' which is 'ENT'(set when ENT:FindEnemy() was done)
    --2nd Parameter: Is just a normal old Key that we set at the start of the code that has a ->
    -- ->            Value set to it(it is a key value pair) check in the 'ENT:Initialize()' ->
    -- ->            function on line 16
    local _ents = ents.FindInCone(self:EyePos(),self:GetForward(),self.SearchRadius, math.cos(math.rad(60)))
    --Here we loop through every entity in the radius that the above search finds and see if its the one we want
    --This is kind of like a loop through the 'ents' table that is in the '_ents' variable ->
    -- -> and in the 'ents' table is the 'FindInSphere()' search
    for k,v in ipairs(_ents)
    do
        if(v:IsPlayer())then--'IsPlayer()' is a function that returns true if the ->
            -- ->             parameter(varible) matches the player ->
            -- ->             'v' in 'v:IsPlayer()' is the value in the key/value pair that is ->
            -- ->             sent(as self) in the parameter(of 'IsPlayer()') to check if it is a player ->
            -- ->             so if the entity in/at 'ents.FindInSphere(self:GetPos(),self.SearchRadius)' ->
            -- ->             is also the player then the if statment returns true and sets the ENT(self) ->
            -- ->             as the enemy using the 'SetEnemy()' function and sets 'v' as the variable ->
            -- ->             for the parameter and consiquently sets 'v'(ent) as the value for the ->
            -- ->             'self.Enemy' Key(Remember 'self.Enemy = ent') ->
            -- ->             In essence its a massive rabbit whole that leads to setting the Value ->
            -- ->             to a Key in a key/value pair that is in a table 'ENT'(self)
            --We found one so lets set it as our enemy and return true
            self:SetEnemy(v)
            return true
        end
    end
    --We found nothing so we will set our enemy as nil(nothing) and return false
    self:SetEnemy(nil)
    return false
end
--It is important that in the above function we return true or false because the boolean ->
-- -> is needed to return in other functions that call 'ENT:FindEnemy()' elsewhere ->
-- -> and use the boolean found in the 'ENT:FindEnemy()' function as its return boolean ->

-- -> EX: function 'ENT:HaveEnemy()'(on line 54) uses the boolean from 'ENT:FindEnemy()' ->
-- -> for this purpose



--Next is making the bot actually do something other then just setting an entity as an enemy ->
-- ->(do something after it finds an enemy)
--This next part is where most of the AI is set up

--IMPORTANT: This function is a COROUTINE - which is basically ->
-- -> just a giant looping section of code ->
-- -> except you can pause it for a period of time using 'coroutine.wait(time)'
--Coroutines allow you to do things in a timed order, letting you pause the function ->
-- -> so we can make the bot face the player or play an animation
--And since it is in a 'while true' loop, it will run for as long as the bot exists
--So after your AI has finished running everything it can do, it will go back and do it again

--BELOW IS AN EXAMPLE OF A VERY SIMPLE BOT:

--  function ENT:RunBehavior()
--    while(true)               --Here is the loop, it will run forever(infinite loop)
--    do
--          self:StartActivity(ACT_WALK)    --Walk animation(done by using ACT_WALK from ACT library)
--          self.loco:SetDesiredSpeed(200)  --Walk Speed
--          self:MoveToPos(self:GetPos() + Vector(math.Rand(-1,1),math.Rand(-1,1),0)*400)  --Walk to a random place within about 400 units(called yielding)
--          --In the above line of code, the position of the entity 'ENT'(self) ->
--          -- -> is added to a Vector with a random x axis and y axis(the side to side motions) ->
--          -- -> from (-1,1)(so it could be -1,0, or 1) and ->
--          -- -> the z axis(up and down), which is 0 because we dont want our NPC floating up ->
--          -- -> all of the Vector then being multiplied by 400 to make sure the NPC ->
--          -- -> moves far enough away
--
--          self:StartActivity(ACT_IDLE)    --Idle animation
--          coroutine.wait(2)               --Pause for 2 seconds
--
--          coroutine.yield()               --This basically ends the loop and checks if ->
--                                  -- -> the condtion for the loop (while(true)) is still ->
--                                  -- -> true and should keep running, since we made it an ->
--                                  -- -> infinite loop on purpose it will keep running as long as the NPC exists
--          --The function is done here, but will start back at the top of the loop ->
--          --  -> and make the bot walk somewhere else
--    end
--  end



--Now the much better AI that I will use
--"Brain" of our bot
--Must have a few things:
--1: Check if we have an enemy, if not it will look for one using the 'HaveEnemy()' function(line 51)
--2: If there is an enemy then play some animations and run at the player
--3: If there are not any enemies, then walk to a random spot(like we did in the simple AI for a bot)
--4: Stand idle for 2 seconds


-- ENT:RunBehavior()
-- This where the meat of our AI is

function ENT:RunBehaviour()
    --This function is called when the entity is first spawned, it acts as a giant loop ->
    -- -> that will run as long as the NPC exists
        while(true)
        do
            --Lets use the above mentioned functions to see if we have/can find an enemy
            if(self:HaveEnemy())then

                self:EmitSound(self.AlertSound, 100, 50)
                local runspeed = 450

                --Now that we have an enemy, the code in this block will run
                self.loco:FaceTowards(self:GetEnemy():GetPos()) --Face our enemy
                --For the next three lines of code its basically just playing scripted animations we made
                --'PlaySequenceAndWait()' function finds the sequence(anim.) we tell it to play and doesnt ->
                -- -> continue the code until the animation is done(it sends 'ENT' as a self in and ->
                -- -> the name of the sequence(animation) I.e. '"plant"' for the first of the three
                --self:PlaySequenceAndWait("plant") --Lets make a pose to show we found an enemy
                --self:PlaySequenceAndWait("dog_angry") --Play an animation to show the enemy we are angry
                --self:PlaySequenceAndWait("unplant") --Get out of the pose

                self:StartActivity(ACT_RUN) --Set the animation
                self.loco:SetDesiredSpeed(450) --Set the speed we will be moving at ->
                -- -> Dont worry the animation will speed up/slow down to match
                self.loco:SetAcceleration(900) --We are going to run at the enemy quickly so ->
                -- -> we want to accelerate really fast

                if(self:GetEnemy():GetActiveWeapon():GetClass() == "weapon_bugbait")then
                    --Make a 'ENT:StopAllSounds()' function one day
                    self:StopSound(self.AlertSound)
                    self:EmitSound(self.ScaredSound)
                    self:RunAway()
                else
                    self:ChaseEnemy(nil,runspeed) --Runs a "new" function(because we will add it later in the code) ->
                    -- ->But it will be the new function like 'MoveToPos()'
                    --'self:ChaseEnemy()' function will keep running until it loses sight of the Enemy then->
                    -- -> it will move to the next line below in this loop
                end
                self.loco:SetAcceleration(400) --Set this back to its default since we are done chasing the enemy
                --self:PlaySequenceAndWait("charge_miss_slide") --Lets play a fancy animation ->
                -- -> when we stop moving
                self:StartActivity(ACT_IDLE) --We are done so go back to idle
                --Now once the above function is finished doing what it needs to do ->
                -- -> the code will loop back to the start
                --Unless you put stuff after the if statement, then that will be run before it loops
                self:StopSound(self.AlertSound)
            else
                --Since we cant find an enemy, lets wander
                --Its the same code used in Garrys test bot(the simple AI we commented out above)
                self:StartActivity(ACT_WALK) --Walk animation
                self.loco:SetDesiredSpeed(200) --Walk speed
                self:MoveToPos(self:GetPos()+Vector(math.Rand(-1,1),math.Rand(-1,1),0)*400)
                self:StartActivity(ACT_IDLE)
                self:EmitSound(self.LookingSound)
            end
            --At this point in the code the bot has stopped chasing the player or ->
            -- -> finished walking to a random spot
            --Using this next function we are goint to wait 2 seconds until we go ahead and reapeat it
            coroutine.wait(0.2) --IMPORTANT: Now the coroutine function('coroutine.wait(2)') is ->
            -- -> not causing the 'while(true)' loop to restart, instead we are utilizing ->
            -- -> the 'coroutine.wait(2)' function as a way to make our NPC not instantly snap into ->
            -- -> doing different animations and functions, and it instead waits and ->
            -- -> flows more naturally(this is why coroutine functions are used primarily for this reason) ->
            -- -> and since the 'coroutine.wait(2)' function is the last line of code in the loop ->
            -- -> THE 'while(true)' LOOP causes the restart because it checks its condition if its true ->
            -- -> (its set to always be true) and the restarts because its true, the while loop causes ->
            -- -> the restart to the infinite loop just like a while loop normally does, its just ->
            -- -> that this one is infinite
        end
end

    --Now we have to make that 'ChaseEnemy()' function we were talking about earlier
    --Its pretty much identical to the 'MoveToPos' function Garry made in the Nextbot base
    --Except for some useful changes
    --1: It builds a path to follow leading directly to the set enemy
    --2: Keep updating the path as the enemy and the bot moves around
    --3: Stop chasing the enemy if we dont have one anymore. Using the 'HaveEnemy()' function ->
    -- -> we made earlier

    -- ENT:ChaseEnemy()
    -- Works similarly to Garrys 'MoveToPos' function
    -- except it will constantly follow the position of the enemy until there no longer is an enemy

    function ENT:ChaseEnemy(options,runspeed)--Has parameters 'ENT'(self) and a new parameter ->
        -- -> 'options' that we will set as a table later in the function

        local options = options or {} --Make a table for options using options table given or make a deafult table
        local path = Path("Follow")
        local runspeed = runspeed
        local twcount = 0
        --local velocityBOT = self:GetGroundSpeedVelocity()
        --local velocity_int = tonumber(tostring(velocityBOT))--In Lua I discovered that ->
        -- -> the variable type 'userdata' cannot be compared to by integers ->
        -- -> so this is how you turn the 'userdata' "integer" into a true 'integer' variable type
        
        path:SetMinLookAheadDistance(options.lookahead or 300)
        path:SetGoalTolerance(options.tolerance or 0)
        path:Compute(self,self:GetEnemy():GetPos()) --Compute the path towards the enemy's postion
        --'boolean PathFollower:Compute(NextBot from, Vector to, function generator = nil)' ->
        -- -> I.e. the 'Compute()' function, computes the shortest path from bot to "goal" ->
        -- -> via the A* algorithm
        --Look at the 'PathFollower:Compute' default generator code online(really REALLY cool)

        if(not path:IsValid())then
            return "failed"
        end
        
        while(path:IsValid() and self:HaveEnemy())
        do
        self.loco:SetDesiredSpeed(runspeed)
        --local velocityBOT = self:GetGroundSpeedVelocity()
        --local velocity_int = tonumber(tostring(velocityBOT))--In Lua I discovered that ->
        -- -> the variable type 'userdata' cannot be compared to by integers ->
        -- -> so this is how you turn the 'userdata' "integer" into a true 'integer' variable type

            if(path:GetAge()>0.1)then --Since we are following the player we have to constantly ->
                                      -- -> remake the path
                --Remember 'ENT' is STILL 'self'
                path:Compute(self,self:GetEnemy():GetPos())--Compute the path towards the ->
                                                           -- -> enemys postion again
            end

            --Remember for the line of code below: 'ENT' is STILL 'self' and ->
            -- -> the 'path's 'self' is also in there first(kind of like 'selfv2') ->
            -- -> but this "selfv2" is NOT the same as 'self' which is still ENT ->
            -- -> So to make it clearer the function can also be written as ->
            -- -> 'path.Update(path,self)' this shows what I mean more clearly

            path:Update(self)--This function moves the bot along the path ->
            -- -> I.e. gets the NPC to move to the Computed(calculated) postion 
            -- -> You might ask how it is supposed to continously make new more efficient paths ->
            -- -> to the player if it cant continiously update ->
            -- -> Well thats the job of the while loop! It makes the whole block ->
            -- ->(including the 'Update()' function) code run again! Until the player is ->
            -- -> lost, this is why we put the 'and self:HaveEnemy()' in the while loop condition

            if(options.draw)then
                path:Draw()
            end

            print(self:GetEnemy():GetActiveWeapon():GetClass())
            if(self:GetEnemy():GetActiveWeapon():GetClass() == "weapon_bugbait")then
                break
            end
            --If were stuck then call the 'HandleStuck()' function and abandon(that path)
            --IMPORTANT: Come back to this if statment to try and make the Dog NPC explode ->
            -- -> when it gets stuck(I.e. a special yield when it runs/finds the function ->
            -- -> 'HandleStuck()' (At leas thats what I think you do, FOR NOW))
            if(self.loco:IsStuck())then
                self:HandleStuck()
                return "stuck"
            end
            --local x = self:GetVelocity():Unpack()

            --if(self:HaveEnemy())then
                --if(x < 100 )then
                    --self:SetDesiredSpeed(self:GetVelocity():Sub(Vector(10,0,0)))
                --else
                    --return
                --end
            --end

            --if(self:HaveEnemy())then
            --    self.loco:SetDesiredSpeed()
            --end
            
            --How to make the Broodmother get slower as it chases the player until it stops ->
            -- -> and needs a 3 second rest

            runspeed = runspeed - 0.3

            if(runspeed <= 175)then

                if(twcount == 0)then
                self:StartActivity(ACT_WALK)
                twcount = twcount+1
                end

                if(runspeed <= 125)then
                    self:StopSound(self.AlertSound)
                    self:StartActivity(ACT_IDLE)
                    self:EmitSound(self.RestSound)
                    self.loco:SetDesiredSpeed(0)

                    coroutine.wait(2.5)
                    self:StopSound(self.RestSound)
                    self:EmitSound(self.RestFSound)
                    coroutine.wait(0.5)
                    
                    runspeed = 450
                    if(self:HaveEnemy())then
                        self:EmitSound(self.AlertSound, 100, 50)
                        self:StartActivity(ACT_RUN)
                    end
                end
            end

            coroutine.yield() --Basically ends the loop and makes the while loop ->
            -- -> check if its parameter is true again
        end

        return "ok"
    end

    --NEARLY DONE!
    --Now we want to add it to the NPC spawn tab when the player opens the menu ->
    -- -> by hitting the "Q" key on their keyboard

    --Check how lists are done by referncing the "helloliststyledtables.lua" I made earlier OR ->
    -- -> check the explanation I made below(starting on line 341) as a good way to understand ->
    -- -> what lists are

    --The list library allows you to add and retrieve values to and from lists ->
    -- -> The list library is basically a fancy wrapper for a table but ->
    -- -> with much more limited functionality

    --It also makes it easier to flick through it to find a certain key/value pair vs ->
    -- -> the very complicated way it would be if you used just tables

    --IMPORTANT: Using the function 'list.Set(string identifier, any key, any item(value))' ->
    -- -> is bascially just an easy way to make a table(by using the list library) ->
    -- -> the 'Set()' function part of the list library('list's table) is how you ->
    -- -> fill the Keys("simple_nextbot") with the Items/Values(anything after the brackets) ->
    -- -> and the "NPC" is the string identifier for the list(table) basically ->
    -- -> notice how everything after the 'Set' is in a parenthesis, thats because ->
    -- -> are all just parameters fed into a 'Set()'function to fill the "NPC" list(table) ->
    -- -> you made
    --Check code on line 416 onward for an example
    local function AddNPC( t, class )
        list.Set( "NPC", class or t.Class, t )
    end

    AddNPC({
        Name = "Brood Mother",
        Class = "simple_nextbot",
        Category = "Broodlurkers",
        Health = "200"
    })

    AddNPC({
        Name = "Broodling",
        Class = "simple_nextbotbroodling",
        Category = "Broodlurkers",
        Health = "10"
    })

    --list.Set("NPC", "simple_nextbot", {
    --    Name = "Very Angry Dog",
    --    Class = "simple_nextbot",
    --    Category = "Aggressive Dog",
    --    Health = "200"
    --})

    function ENT:RunAway()
            self:StartActivity(ACT_RUN)
            --self:MoveToPos(self:GetPos()+Vector(math.Rand(-10,10),math.Rand(-10,10),0)*300)
            self:MoveToPos(self:GetPos()+Vector(math.Rand(0,1),math.Rand(0,1),0)+((self:GetEnemy():GetPos())*Vector(-1.5,-1.5,0)))
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
        --hook.Call("OnNPCInjured",GAMEMODE,self,dmginfo:GetAttacker(),dmginfo:GetInflictor())
        if(dmginfo:GetInflictor():GetPos():Distance(self:GetPos()) < 125 and not dmginfo:GetInflictor():IsOnFire())then--Ignites player when ENT is injured if player is close enough
            dmginfo:GetInflictor():Ignite(1,10)
        else
            print(dmginfo:GetInflictor():GetPos():Distance(self:GetPos()))
            return
        end
    end

    function ENT:OnKilled(dmginfo)
        hook.Call("OnNPCKilled",GAMEMODE,self,dmginfo:GetAttacker(),dmginfo:GetInflictor())
        self:StopSound(self.AlertSound)
        self:StopSound(self.LookingSound)
        self:StopSound(self.RestSound)
        self:StopSound(self.RestFSound)
        
        local vpoint = self:GetPos()
        local effectdata_explo = EffectData()
        local effectdata_bloodsplat = EffectData()--Makes 'effectdata_bloodsplat' an object from ->
        -- -> the returned data from the function 'EffectData()'
        effectdata_explo:SetOrigin(vpoint)
        effectdata_explo:SetMagnitude(100)
        effectdata_explo:SetScale(10)
        util.Effect("Explosion",effectdata_explo)

        effectdata_bloodsplat:SetOrigin(vpoint)
        util.Effect("AntlionGib",effectdata_bloodsplat)

        if(dmginfo:GetInflictor():GetPos():Distance(self:GetPos()) < 90)then--Ignites player when ENT dies if player is close enough to ENT
            dmginfo:GetInflictor():Ignite(5,10)
        end
        
        --heedcreeb:Spawn() work on him splitting into 4 more headcrab models with some powers but slower
        local babynpc1 = ents.Create("simple_nextbotbroodling")
        local babynpc2 = ents.Create("simple_nextbotbroodling")
        local babynpc3 = ents.Create("simple_nextbotbroodling")
        local babynpc4 = ents.Create("simple_nextbotbroodling")
       
        babynpc1:SetPos(self:GetPos()+Vector(0,0,0)*40)
        babynpc1:SetModel(self:GetModel())
        babynpc1:Spawn()
        babynpc2:SetPos(self:GetPos()+Vector(1,1,0)*40)
        babynpc2:SetModel(self:GetModel())
        babynpc2:Spawn()
        babynpc3:SetPos(self:GetPos()+Vector(1,0,0)*40)
        babynpc3:SetModel(self:GetModel())
        babynpc3:Spawn()
        babynpc4:SetPos(self:GetPos()+Vector(0,1,0)*40)
        babynpc4:SetModel(self:GetModel())
        babynpc4:Spawn()
       
        local body = ents.Create("prop_ragdoll")
        body:SetPos(self:GetPos())
        body:SetModel(self:GetModel())
        body:Spawn()
        
        self:Remove()


        --Code block below removes the ragdoll of dead ENT after 5 seconds(So lots of bodies arnt laying aroudn after a while)
        timer.Simple(0.5,
        function()
        body:Remove()
        end
        )
    end

    function ENT:OnRemove()
        self:StopSound(self.AlertSound)
        self:StopSound(self.LookingSound)
        self:StopSound(self.RestSound)
        self:StopSound(self.ScaredSound)
        self:StopSound(self.RestFSound)
    end
    --For Example using the method above we have two lists(called "NPC1" and "NPC2") we want to make
    --We could use the 'Set()' function that is part of the list library ->
    -- -> (all together it looks like 'list.Set()') or we could do it the long way and make ->
    -- -> two lists(or tables rather) manually
    -- Remember lists are basically just fancy tables

--You can think of the List as a table way up here(line 348) and it contains the two tables below
--    list = {
--    local NPC1 = {
--        simple_nextbot1 = {
--            Name = "Very Angry NPC1",
--            Class = "simple_nextbot1",
--            Category = "Nextbot1"
--        }
--
--    }
--
--    local NPC2 = {
--        simple_nextbot2 = {
--            Name = "Very Angry NPC2",
--            Class = "simple_nextbot2",
--            Category = "Nextbot2"
--        }
--    }
-- }