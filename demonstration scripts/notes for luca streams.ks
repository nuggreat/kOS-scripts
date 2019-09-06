/me LOG "IF NOT SHIP:UNPACKED AND SHIP:LOADED { WAIT UNTIL SHIP:UNPACKED AND SHIP:LOADED. WAIT 1. } GLOBAL c IS addons:camera:flightcamera. core:doevent("+CHAR(34)+"open terminal"+CHAR(34)+")." TO PATH("1:/startup.ks"). SET CORE:BOOTFILENAME TO "startup".
/me LOG "IF NOT SHIP:UNPACKED AND SHIP:LOADED { WAIT UNTIL SHIP:UNPACKED AND SHIP:LOADED. WAIT 1. } core:doevent("+CHAR(34)+"open terminal"+CHAR(34)+")." TO PATH("1:/startup.ks"). SET CORE:BOOTFILENAME TO "startup".

GLOBAL stage_check IS { LOCAL ns IS FALSE. IF STAGE:READY { IF MAXTHRUST = 0 { SET ns TO TRUE. } ELSE { LOCAL el IS LIST(). LIST ENGINES IN el. FOR e IN el { IF e:IGNITION AND e:FLAMEOUT { SET ns TO TRUE. BREAK. } } } IF ns	{ STAGE. } } ELSE { SET ns TO TRUE. } }.

/me list engines in englist. set tcon to true. on time:second { local dif is (tpid:setpoint - ship:velocity:surface:mag). for eng in englist {if eng:primarymode {if dif > 50 {eng:togglemode.}} else {if diff < 25 {eng:togglemode.}} return tcon.}}
list engines in englist. for eng in engList {eng:togglemode.}
/me set tpid to pidloop(0.1,0.001,1,0,1). set tpid:setpoint to 175. lock throttle to tpid:update(time:seconds,ship:velocity:surface:mag).
/me set pitch_roll to { parameter mypitch, myroll. local upvec is ship:up:vector. local returndir is lookdirup(vxcl(upvec,ship:srfprograde:forevector),upvec). set returndir to angleaxis(-mypitch,returndir:starvector) * returndir. set returndir to angleaxis(myroll,returndir:forevector) * returndir. return returndir. }. set p to 10. set r to 0. lock steering to pitch_roll:CALL(p,r).

set twpid to pidloop(0.5,0.2,0.02,-1,1). set twpid:setpoint to -1. lock wheelthrottle to twpid:update(time:seconds, (choose ship:velocity:surface:mag if (vdot(ship:velocity:surface,ship:facing:forevector) > 0) else -ship:velocity:surface:mag)).

if hasnode{until not hasnode{remove nextnode. wait 0.}}
ADD NODE(TIME:SECONDS + 60,0,0,0).
UNTIL NEXTNODE:ORBIT:TRANSITION = "ENCOUNTER" { SET NEXTNODE:PROGRADE TO NEXTNODE:PROGRADE - 1. WAIT 0. }
steeringmanager rollcontrolrange
LOCK THROTTLE TO NEXTNODE:DELTAV:MAG / (SHIP:MASS / SHIP:AVAILABLETHRUST).
LOCK STEERING TO SHIP:PROGRADE:TOPVECTOR.

/me ADD NODE(TIME:SECONDS + ETA:PERIAPSIS,0,0,SQRT(BODY:MU / (SHIP:ORBIT:PERIAPSIS + BODY:RADIUS)) - VELOCITYAT(SHIP,TIME:SECONDS + ETA:PERIAPSIS):ORBIT:MAG).
/me ADD NODE(TIME:SECONDS + ETA:APOAPSIS,0,0,SQRT(BODY:MU / (SHIP:ORBIT:APOAPSIS + BODY:RADIUS)) - VELOCITYAT(SHIP,TIME:SECONDS + ETA:APOAPSIS):ORBIT:MAG).

/me SET keepStage TO TRUE. ON TIME:SECOND { LIST ENGINES IN el. FOR eng IN el { if eng:FLAMEOUT OR (MAXTHRUST = 0) { STAGE. BREAK.} } IF keepStage { PRESERVE. } }

/me when vang(nextnode:deltaV,ship:facing:forevector) > 5 then {lock throttle to 0.}
/me warpto(nextnode:ETA - 60).
/me when nextnode:eta < (nodetime / 2) then {lock throttle to nextnode:deltaV / acc. }

/me lock radial to vxcl(ship:velocity:orbit,-up:vector). lock normal to vcrs(ship:velocity:orbit,-up:vector).

/me lock steering to vxcl(ship:velocity:orbit,up:vector).//radial in
/me lock steering to vxcl(ship:velocity:orbit,-up:vector).//radial out

/me lock steering to vcrs(ship:velocity:orbit,-up:vector).//normal?
/me lock steering to vcrs(ship:velocity:orbit,up:vector).//anti normal?

/me ADD NODE(TIME:SECONDS + ETA:APOAPSIS,0,0,0).
/me UNTIL NEXTNODE:ORBIT:APOAPSIS > MUN:APOAPSIS { SET NEXTNODE:PROGRADE TO NEXTNODE:PROGRADE + 1. }
/me UNTIL NEXTNODE:ORBIT:HASNEXTPATCH { SET NEXTNODE:ETA TO NEXTNODE:ETA + 1. }.

/me set lo to -100. set hi to 100. set st to 10. for p in range(lo,hi,st) { for r in range(lo,hi,st) { for no in range(lo,hi,st) { set n:prograde to n:prograde + p. set n:radialout to n:radialout + r. set n:normal to n:normal + no. wait 0. if nextnode:orbit:hasnextpatch { break. break. break. } else {set n:prograde to n:prograde - p. set n:radialout to n:radialout - r. set n:normal to n:normal - no. } } } print round(((r-lo)*100) / (hi-lo),1) + "% done" }. print "one eternity later".

/me lock relveld to target:velocity:orbit - ship:velocity:orbit. lock relPosd to target:position - ship:position. lock sff TO ship:facing:forevector. lock sft to ship:facing:topvector. lock sfs to ship:facing:starvector. set tw to terminal:width. set rcsDisp to true.

/me on time:second { print ("for speed: " + round(vdot(relveld,sff),2)):padright(tw) at(0,0). print ("for  dist: " + round(vdot(relposd,sff),2)):padright(tw) at(0,1). print ("top speed: " + round(vdot(relveld,sft),2)):padright(tw) at(0,2). print ("top  dist: " + round(vdot(relposd,sft),2)):padright(tw) at(0,3). print ("star speed: " + round(vdot(relveld,sfs),2)):padright(tw)at(0,4). print ("star  dist: " + round(vdot(relposd,sfs),2)):padright(tw)at(0,5). return rcsDisp. }
set keepD to true. set dTime to time:seconds. set dDelta to 0. set dOld to target:distance. when true then {set dTime to dTime + 1. local dNew is (positionat(ship,dTime) - positionat(target,dTime)):MAG. set dDelta to dOld - dNew. set dOld to dNew. if dDelta >= 0 and keepD {PRESERVE.} else { print "dist: " + round(dOld) + "km in: " + round(dTime - time:seconds - 1,2) + "s". }}

ADD NODE(TIME:SECONDS + ETA:APOAPSIS,0,0,-10).

PRINT "relative Velocity: " + ROUND((VELOCITYAT(SHIP,14400 + TIME:SECONDS) - VELOCITYAT(TARGET,14400 + TIME:SECONDS)):MAG,2).

LOCK rt_vel TO SHIP:VELOCITY:ORBIT - TARGET:VELOCITY:ORBIT. LOCK STEERING TO -rt_vel.

LOCK THROTTLE TO (rt_vel):MAG / (SHIP:AVAILABLETHRUST / SHIP:MASS).
WHEN rt_vel:MAG < 0.01 THEN {LOCK THROTTLE TO 0.}

/me KUNIVERSE:TIMEWARP:WARPTO(TIME:SECONDS + NEXTNODE:ETA - burn_duration(345,(NEXTNODE:DELTAV / 1.5):MAG)).

/me WHEN NEXTNODE:ETA < burn_duration(345,(NEXTNODE:DELTAV / 2):MAG) THEN {LOCK THROTTLE TO NEXTNODE:DELTAV:MAG / (SHIP:AVAILABLETHRUST / SHIP:MASS).}
/me WHEN NEXTNODE:DELTAV:MAG < 0.1 THEN { LOCK THROTTLE TO 0. }


LOCK STEERING TO SHIP:SRFRETROGRADE.
WHEN SHIP:VERTICALSPEED > -10 THEN {LOCK STEERING TO -SHIP:VELOCITY:SURFACE  + SHIP:UP:FOREVECTOR * 10.}
lock srfgrav to body:mu / body:radius^2. lock shipacc to (ship:availablethrust / ship:mass) * .95 - localgrav. set bound is ship:bounds.

lock vspeedtar to shipacc * sqrt(2 * abs(bound:bottomaltradar - offset) / shipacc) + 0.5.
lock throttle to -verticalspeed - vspeedtar + minthrot.
WHEN VANG(SHIP:VELOCITY:SURFACE,SHIP:UP:VECTOR) > 179 THEN { LOCK THROTTLE TO -SHIP:VERTICALSPEED - vSpeedTar + minThrot. }
WAIT UNTIL FALSE.

LIST ENGINES IN engList. PRINT "DV aprox: " + ROUND(engList[0]:ISP * 9.80665 * LN(SHIP:MASS / SHIP:DRYMASS)).

/me SET burn_duration TO { PARAMETER ISPs, DV IS NEXTNODE:DELTAV:MAG, wMass IS SHIP:MASS, sThrust IS SHIP:AVAILABLETHRUST. LOCAL dMass IS wMass / (CONSTANT:E^ (DV / (ISPs * 9.80665))). LOCAL flowRate IS sThrust / (ISPs * 9.80665). RETURN (wMass - dMass) / flowRate. }.

LIST ENGINES IN engList. PRINT "aprox burn time: " ROUND((SHIP:MASS - (SHIP:MASS / (CONSTANT:E^ (NEXTNODE:DELTAV:MAG / (engList[0]:ISP * 9.80665))))) / (SHIP:AVAILABLETHRUST. / (engList[0]:ISP * 9.80665)),2).}
/me list engines in engList. for eng in engList { SET eng:gimbal:lock to true. }
/me WHEN SHIP:ORBIT:HASNEXTPATCH AND (SHIP:ORBIT:NEXTPATCH:BODY = MUN) THEN {LOCK THROTTLE TO 0.}

IF HASNODE{UNTIL NOT HASNODE{REMOVE NEXTNODE. WAIT 0.}}
/me ADD NODE(TIME:SECONDS + 870,0,0,0).
/me UNTIL NEXTNODE:ORBIT:HASNEXTPATCH AND (NEXTNODE:ORBIT:NEXTPATCH:BODY = MUN) { SET NEXTNODE:ETA TO NEXTNODE:ETA + 1. }
/me when vang(SHIP:FACING:VECTOR, NEXTNODE:DELTAV > 90) THEN { LOCK THROTTLE TO 0. }
UNTIL NEXTNODE:ORBIT:NEXTPATCH:PERIAPSIS < 30000 AND NEXTNODE:ORBIT:NEXTPATCH:PERIAPSIS > 25000{ SET NEXTNODE:ETA TO NEXTNODE:ETA + 1. WAIT 0. }
UNTIL NEXTNODE:ORBIT:PERIAPSIS < 40000 { SET NEXTNODE:PROGRADE TO NEXTNODE:PROGRADE - 1. WAIT 0. }
PRINT NEXTNODE:ORBIT:PERIAPSIS.

LOCK THROTTLE TO 1. WHEN SHIP:ORBIT:NEXTPATCH:PERIAPSIS < 30000 THEN { LOCK THROTTLE TO 0. PRINT "PE below 30km".}

SET warp TO 5. WHEN SHIP:ALTITUDE < 500000000 THEN {SET warp TO 0. }

/me SET fairing TO SHIP:PARTSDUBBEDPATTERN("shell")[0]:GETMODULE("moduleproceduralfairing"):DOEVENT("deploy"). PRINT fairing[0]:GETMODULE("moduleproceduralfairing"):ALLEVENTS.
fairing[0].

/me print "opcodes per tick: " + ROUND(core:getfield("kOS average power") / 0.0002)

/me set hl to highlight(ship,rgba(random(),random(),random(),1)). set keep to true. on time:second { set hl:color to rgba(random(),random(),random(),1). return keep. }

/me set keep to false. for h in hl {set h:enabled to false.}

/me set pr to true. set pri to 5. set prj to 3. set prm to sqrt(pri). on time:second { IF MOD(pri,prj) = 0 { set pri to pri + 2. set prj to 3. set prm to sqrt(pri). } else { set prj to prj + 2. } if prm < prj { hudtext(pri:tostring, min(prm,10), 2, 40, rgb(random(),random(),random()), false). set pri to pri + 2. set prj to 3. set prm to sqrt(pri). } return pr. }

/me global hl is list(). for par in ship:parts { hl:add(highlight(par,rgba(random(),random(),random(),1))). } for h in hl {set h:enabled to true. }. set keep to true. on time:second { set hl[floor(random() * hl:length)]:color to rgba(random(),random(),random(),1). return keep. }
/me set keep to false. for h in hl {set h:enabled to false.}
/me set rgb_gen to {parameter maxval,val. local result is mod(val,maxval) / maxval * 3. local re is max(min(1 - result,1),0). local gr is 0. local bl is max(min(result,1),0). if result > 1 { set bl to max(min(2 - result,1),0). set gr to max(min(result - 1,1),0). if result > 2 { set gr to max(min(3 - result,1),0). set re to max(min(result - 2,1),0). } } return rgba(re,gr,bl,2). }.
/me set cc to 0. set hli to 0. set hl to list(). for par in ship:parts { hl:add(highlight(par,rgb_gen:call(300,0))).} for h in hl {set h:enabled to true.}
/me set keep to true. when round(time:seconds) then { print cc + " " + hli. set cc to mod(cc + 1,300). set hli to mod(hli + 1,hl:length). set hl[hli]:color to rgb_gen:call(300,cc). if keep { return true. } else { for h in hl {set h:enabled to false. }}}

/me set keep to true. on time:second { print cc + " " + hli. set cc to mod(cc + 1,300). set hli to mod(hli + 1,hl:length).  if keep { return true. } else { for h in hl {set h:enabled to false. }}}
/me set keep to false. set af to 1. until af < 0 { for h in hl { set h:color:a to max(af,0). } set af to af - 0.01. wait 0.}