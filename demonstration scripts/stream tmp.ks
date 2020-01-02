//info printing.
set obti to true.
set tw to terminal:width.
set bl to " ":padright(tw).
lock s0 to ("ap:  " + apoapsis):padright(tw).
lock s1 to ("eta: " + eta:apoapsis):padright(tw).
lock s2 to ("pe:  " + periapsis):padright(tw).
lock s3 to ("eta: " + eta:periapsis):padright(tw).
lock s4 to ("alt: " + altitude):padright(tw).

lock s5 to ("acc: " + (ship:availablethrust / ship:mass)):padright(tw).
lock s6 to ("vel: " + (choose ship:velocity:surface:mag if navemode = "surface" else ship:velocity:orbit:mag)):padright(tw).
on time:second {
print s0.
print s1.
print bl.
print s2.
print s3.
print bl.
print s4.
print s5.
print s6.
return obti.
}

lock nodeLine to vcrs(vcrs(ship:position - body:position,ship:velocity:orbit),vcrs(target:position - body:position,target:velocity:orbit))

local saveL is kuniverse:quicksavelist.
from { local i is saveL:length - 1. } until i < 0 step { set i to i - 1. } do { print "[" + i + "] = " + saveL[i].}

//adjust node based on distance.
lock ntime to nextnode:orbit:period + time:seconds + nextnode:eta.
lock ntime to (180-nextnode:orbit:meananomalyatepoch) * (nextnode:orbit:period/360) + time:seconds + nextnode:eta.//time of at AP after node
lock ntime to (180-nextnode:orbit:nextpatch:meananomalyatepoch) * (nextnode:orbit:nextpatch:period/360) + time:seconds + nextnode:eta + nextnode:orbit:nextpatcheta.//time of at AP after node after leaving a SOI

lock distat to (positionat(ship,ntime) - positionat(target,ntime)):mag.
set preDist to distat.
until preDist < distat {
set preDist to distat.
set nextnode:prograde to nextnode:prograde - 0.01.
}
set nextnode:prograde to nextnode:prograde + 0.01.
lock velat to (velocityat(ship,ntime) - velocityat(target,ntime)):mag.


//fined close aproach
set dTime to time:seconds + orbit:period / 2.
set dOld to target:distance.
set ts to orbit:period / 360.
until ts < 0.1 {
set dTime to dTime + ts.
local dNew is (positionat(ship,dTime) - positionat(target,dTime)):MAG.
set dDelta to dOld - dNew.
if dDelta < 0 {
set dTime to dTime - ts.
set ts to ts / 10.
} else {
set dOld to dNew.
}
}
print "dist: " + round(dOld/1000,4) + "km in: " + round(dTime - time:seconds - 1,2) + "s".

//expermental docking code
set tarCraft to choose target if target:istype("vessel") else target:ship.
set tarThing to target.
set shipThing to ship:controlpart.
set tw to terminal:width.
set rcsAuto to true.
set forePid to PIDLOOP(4,0.1,0,-1,1).
set starPid to PIDLOOP(4,0.1,0,-1,1).
set topPid to PIDLOOP(4,0.1,0,-1,1).
set foreD to 20.
set starD to 0.
set topD to 0.
set rcsT to 0.05.
set sl to 5.
set cnt to ship:control.
set tumble to false.

when true then {
set ttf to choose tarThing:portfacing if tarThing:ISTYPE("dockingport") else tarThing:facing.
set sf to ship:facing.
set tarD to tarThing:position + ttf:forevector * foreD + ttf:starvector * starD + ttf:topvector * topD.
set relPosd to tarD - shipThing:position.
set tarv to min(sqrt(tarD:MAG * 2 * (ship:mass/rcsT)),sl) * tarD:normalized.
if tumble { set tarV to tarv + vcrs(tarcraft:angularvel,ship:position - tarCraft:position). }
return rcsAuto.
}

when true then {
set relvel to tarCraft:velocity:orbit - ship:velocity:orbit.
set forePid:setpoint to vdot(sf:forevector,tarv).
set starPid:setpoint to vdot(sf:starvector,tarv).
set topPid:setpoint to vdot(sf:topvector,tarv).
set cnt:fore to forePid:UPDATE(TIME:SECONDS,VDOT(sf:forevector,relvel)).
set cnt:starboard to starPid:UPDATE(TIME:SECONDS,VDOT(sf:starvector,relvel)).
set cnt:top to topPid:UPDATE(TIME:SECONDS,VDOT(sf:topvector,relvel)).
return rcsAuto.
}

//possable launch code for bodies with out an atmosphere
set ascentSteer to true.
set tarP to 90.
lock steering to heading(body:geopositionof(ship:velocity:orbit):heading,tarP).
when apoapsis > 15_000 { lock throttle to 0. set ascentSteer to false.}

lock throttle to 1.
wait until ship:verticalspeed > 50.
when true then {
set rad to (body:position - ship:position):sqrmagnitude.
set acc to max(ship:availablethrust/ship:mass,0.00001).
set gra to (body:mu/rad) - vxcl(up:vector,ship:velocity:orbit):sqrmagnitude / SQRT(rad) + max((tvert - ship:verticalspeed)/10,0).
set tarP to max(arcsin(min(gra/acc,1)),(90 - vang(up:vector,ship:velocity:orbit))).
return ascentSteer.
}

set localport to ship:controlpart.
set sep to 100.
set sl to 0.
if target:istype("Vessel") set tVes to target.
else set tVes to target:ship.
set fpid to pidloop(3,0.001,0.2,-1,1).
set tpid to pidloop(fpid:kp,fpid:ki,fpid:kd,-1,1).
set spid to pidloop(fpid:kp,fpid:ki,fpid:kd,-1,1).

function rv {
    set rel_v to velocityat(ship,time:seconds):orbit - velocityat(tVes,time:seconds):orbit.
    set wv_pos to (target:position + target:facing:vector * sep) - localport:position.
    set wanted_v to wv_pos:normalized * min(sl , (wv_pos:mag * 0.25)^0.5).
    set ve to wanted_v - rel_v.
}

when true then {
    rv().
    
    set ship:control:fore to -fpid:update(time:seconds,vdot(facing:vector,ve)).
    set ship:control:top to -tpid:update(time:seconds,vdot(facing:topvector,ve)).
    set ship:control:starboard to -spid:update(time:seconds, vdot(facing:starvector,ve)).
    return true.
}