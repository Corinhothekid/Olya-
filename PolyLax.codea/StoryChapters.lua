-- Road to Glory | Brothers in Arms interactive chapter data.
PolyLax = PolyLax or {}
local Chapter = {}
PolyLax.StoryChapters = Chapter

Chapter.title = "Brothers in Arms"
Chapter.act = "Act I · The Freshmen"
Chapter.characters = {
    ethan="Ethan Cole", coach="Coach Daniel Mercer", jace="Jace Holloway",
    drip="Nina Reyes", tryout="Locker Room", practice="Practice Field",
    training="Trainer Avery"
}

Chapter.missions = {
    arrival={title="First Day",detail="Meet Ethan in the courtyard.",target="ethan",zone="campus",node="arrival"},
    coach={title="Earn a Look",detail="Visit Coach Mercer inside the school.",target="coach",zone="coach",node="coach"},
    rival={title="An Early Rival",detail="Meet Jace beside the practice field.",target="jace",zone="campus",node="rival"},
    equipment={title="Get Fitted",detail="Enter Drip Lab and speak with Nina.",target="drip",zone="drip",node="equipment"},
    locker={title="First Locker Room",detail="Meet the team in the locker room.",target="tryout",zone="lockers",node="locker"},
    practice={title="First Practice",detail="Finish an opening practice on the outdoor field.",target="practice",zone="campus",activity="practice"},
    tryout={title="Freshman Tryout",detail="Use the locker-room bench to launch your tryout.",target="tryout",zone="lockers",activity="tryout"},
    debrief={title="Mercer's Decision",detail="Ask Coach Mercer about your placement.",target="coach",zone="coach",node="debrief"},
    promise={title="Brothers in Arms",detail="Find Ethan in the courtyard and compare placements.",target="ethan",zone="campus",node="promise"},
    debut={title="First Whistle",detail="Go to the practice field to play your first game.",target="practice",zone="campus",activity="debut"},
    complete={title="The Freshmen Complete",detail="Talk to teammates, train on the field, or visit your clubhouse."}
}

local function option(id,label,changes,nextNode)
    return {id=id,label=label,changes=changes,nextNode=nextNode}
end

local function finish(id,label,changes)
    local result = option(id,label,changes)
    result.finish = true
    return result
end

local function sameUnit(save)
    return save.athlete.position==2 or save.athlete.position==7
end

Chapter.nodes = {
    arrival={
        speaker="ethan",
        text=function(save)
            return "Your first morning at " .. PolyLax.Career.teamName(save.athlete)
                .. ". Ethan is holding the folded goals sheet you both made in middle school. He’s already written ‘varsity’ twice."
        end,
        options={
            option("promise","Tell him you’ll earn it together.",{ethan=8,bond="together"},"arrival_plan"),
            option("honest","Tell him you each have to earn your spot.",{ethan=2,bond="earned"},"arrival_plan"),
            option("race","Make it a race to varsity.",{ethan=-5,bond="rivalry"},"arrival_plan")
        }
    },
    arrival_plan={
        speaker="ethan",
        text=function(save)
            if save.flags.bond=="rivalry" then
                return "Ethan pockets the sheet. “Fine. Loser carries the balls.” His grin comes half a second late. “Mercer wanted to see us before practice.”"
            elseif save.flags.bond=="earned" then
                return "“Fair,” Ethan says. “Just don’t disappear when one of us gets there first. Mercer wanted to see us before practice.”"
            end
            return "“Good,” Ethan says. “Remind me you said that when I make you run extra clears. I saw Mercer heading into his office.”"
        end,
        options={finish("find_coach","Go find Coach Mercer.")}
    },
    coach={
        speaker="coach",
        text="Mercer moves a magnet marked ‘FRESHMEN’ onto the depth chart. “I have room for effort. What do I get from you when a shift goes wrong?”",
        options={
            option("outlet","Make the next outlet and help the group reset.",{coach=7,approach="team"},"coach_next"),
            option("learn","Ask what I missed and fix it on the next shift.",{coach=6,approach="study"},"coach_next"),
            option("prove","Ask for another rep and prove it myself.",{coach=1,approach="prove",reputation=3},"coach_next")
        }
    },
    coach_next={
        speaker="coach",
        text=function(save)
            local ending = "Get fitted at Drip Lab after you meet Jace. He’s at the practice field."
            if save.flags.approach=="study" then
                return "“Good. I’ll be watching how quickly you make an adjustment. " .. ending .. "”"
            elseif save.flags.approach=="prove" then
                return "“Aggression can help. A bad hero play can cost ten people. " .. ending .. "”"
            end
            return "“Good. Your job lasts until the ball is safe with somebody else. " .. ending .. "”"
        end,
        options={finish("outside","Head back outside.")}
    },
    rival={
        speaker="jace",
        text=function(save)
            if sameUnit(save) then
                return "Jace finishes a sprint at midfield. “Mercer’s looking at our rotation, huh? Varsity doesn’t have two free midfield shifts because two friends showed up.”"
            end
            return "Jace finishes a sprint at midfield. “Freshmen usually learn how quick varsity is after one shift. What’s your unit planning to show us?”"
        end,
        options={
            finish("read","Ask him for the read he uses on the first clear.",{jace=8,coach=1,jaceFound="mentor"}),
            finish("challenge","Tell him you’ll make him remember this tryout.",{jace=-8,reputation=4,jaceFound="rival"}),
            finish("quiet","Save the talk for after the reps.",{jace=1,jaceFound="quiet"})
        }
    },
    equipment={
        speaker="drip",
        text="“Nina Reyes. I keep the campus Drip Lab running. Preview a shaft pattern, some glove trim, or a sleeve. What you buy here is for style. The coach still grades the player.”",
        options={finish("browse","Browse the equipment displays.",{fitted=true})},
        after={kind="shop"}
    },
    locker={
        speaker="tryout",
        text="The JV and varsity benches face each other. A clean pinnie waits on the bench with your number. Ethan keeps retying his right cleat even though the knot is already tight.",
        options={
            option("check_in","Sit beside Ethan and walk through the first shift.",{ethan=7,prep="together"},"locker_ethan"),
            option("warmup","Tell him where you’ll meet, then warm up alone.",{prep="alone"},"locker_ethan")
        }
    },
    locker_ethan={
        speaker="ethan",
        text=function(save)
            if save.flags.prep=="together" then
                return "“The first easy pass. Got it.” Ethan finally leaves the laces alone. “I’ll look for you when we clear.”"
            end
            return "“Go ahead. I need a second anyway.” Ethan looks up. “I hope we both get a real shift.”"
        end,
        options={finish("ready","Get ready for the tryout.")}
    },
    debrief={
        speaker="coach",
        text=function(save)
            local result=save.results.tryout
            local observation=result.secondsPlayed and " in "..result.secondsPlayed.." seconds on the field" or ""
            return "“I logged " .. result.focus .. observation .. ". Your evaluation was " .. result.grade
                .. "/100. I’m putting you at " .. result.placement .. ". "
                .. (result.placement=="Varsity rotation" and "Meet me here again if the pace gets away from you.”"
                or "An assignment is where you start. Good reps can change the next board.”")
        end,
        options={
            option("feedback","Ask for a specific thing to work on.",{coach=5,debriefStyle="feedback"},"debrief_coaching"),
            finish("ethan_first","Ask how Ethan handled his shift.",{ethan=4,coach=1,debriefStyle="ethan"}),
            finish("move_on","Take the assignment and head back outside.",{debriefStyle="focus"})
        }
    },
    debrief_coaching={
        speaker="coach",
        text=function(save)
            local role=PolyLax.Career.positions[save.athlete.position].role
            local feedback = {
                A="Work one clean give-and-go before reaching for the difficult shot.",
                M="On your first change of possession, find the open side before making the outlet.",
                D="Take the inside lane away first. You can challenge the stick once the next slide is ready.",
                LSM="Win the easy ground ball, get the outlet moving, and time your exchange.",
                SSDM="Show them the outside lane. Pressure the next catch once your help arrives.",
                FOGO="Decide where the exit goes before you set your feet.",
                G="Make the save first, then call for one reliable outlet."
            }
            return "“" .. feedback[role] .. " And talk to Ethan. He’s been watching the board.”"
        end,
        options={finish("understood","Go check in with Ethan.")}
    },
    promise={
        speaker="ethan",
        text=function(save)
            local own=save.results.tryout.placement
            local other=save.ethan.depth
            if own==other then
                return "“We both got " .. own .. ".” Ethan studies the board. “Same room again. Do we still know how to hold each other to it?”"
            elseif other=="Varsity rotation" then
                return "“I got varsity rotation.” Ethan keeps his voice low. “I really want to take it. I also didn’t want you to find out from a list.”"
            elseif own=="Varsity rotation" then
                return "“You got varsity. I got " .. other .. ".” Ethan folds the goals sheet until it fits in his pocket. “Do you still have time for me after practice?”"
            elseif save.ethan.health=="managed strain" then
                return "“Mercer put me at " .. other .. " while I get my leg right.” Ethan runs a thumb down the board. “Try not to celebrate doing twice the extra reps without me.”"
            end
            return "“Mercer put me at " .. other .. ".” Ethan runs a thumb down the board. “Different reps. We can still make our own plan, right?”"
        end,
        options={
            finish("partners","Pick a time to work together every week.",{ethan=10,friendship="partners"}),
            finish("space","Give each other some space until the next game.",{ethan=-2,friendship="space"}),
            finish("compete","Make your next shift the way to settle it.",{ethan=-10,reputation=3,friendship="compete"})
        }
    }
}

Chapter.sequence={"arrival","coach","rival","equipment","locker","practice","tryout","debrief","promise","debut","complete"}
