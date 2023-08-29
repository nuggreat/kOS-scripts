//----instructions for use of script----
//--------------------------------------
//----first you must target the docking port you want to dock to----
//----second you must tag the docking port on your ship that you want to use to dock with with the tag "dockingPort"----
//----third you must click control from for the docking port you are using----
//----forth your ship must be ahead of the target docking port as this script has no avoidance logic
//------that would cause it to move around the target to get to a good position to start trying to dock----
//----fifth you should be at a fairly low relative speed when this script start
//------while it can deal with a high relative speed that will cost a lot more DV----
//----sixth there are 2 parameters for the script that are defaulted first is the acceleration target, second is the max speed----
//--------------------------------------------------------------------------------------------------------------------------------
 
PARAMETER accelLimit IS 0.05, maxSpeed IS 2.
 
//PID setup         PIDLOOP(kP,kI,kD,min,max)
LOCAL forRCS_PID IS  PIDLOOP(4,0.02,0,-1,1).
LOCAL topRCS_PID IS  PIDLOOP(4,0.02,0,-1,1).
LOCAL starRCS_PID IS PIDLOOP(4,0.02,0,-1,1).
 
SAS OFF.
LOCK STEERING TO LOOKDIRUP(-TARGET:PORTFACING:FOREVECTOR, TARGET:PORTFACING:TOPVECTOR).
 
PRINT "Alineing to Target.".
LOCAL timePre IS TIME:SECONDS.
LOCAL done TO FALSE.
UNTIL done {
    LOCAL angleTo IS ABS(STEERINGMANAGER:ANGLEERROR) + ABS(STEERINGMANAGER:ROLLERROR).
    IF angleTo < 0.5 {
        IF (TIME:SECONDS - timePre) >= 5 { SET done TO TRUE. }
    } ELSE {
        SET timePre TO TIME:SECONDS.
        SET done TO ABORT.
    }
    WAIT 0.01.
}
 
RCS ON.
LOCAL done IS FALSE.
PRINT "translating".
UNTIL done {
    LOCAL axisDist IS axis_distance(SHIP:PARTSTAGGED("dockingPort")[0],TARGET).
    LOCAL axisSpeed IS axis_speed(SHIP,TARGET).
   
    IF ABS(axisDist[2]) + ABS(axisDist[3]) < 0.5 {
        SET forRCS_PID:SETPOINT TO RCS_decel_setpoint(accelLimit,axisDist[1],maxSpeed).
    } ELSE {
        SET forRCS_PID:SETPOINT TO 0.
    }
    SET topRCS_PID:SETPOINT TO RCS_decel_setpoint(accelLimit,axisDist[2],maxSpeed).
    SET starRCS_PID:SETPOINT TO RCS_decel_setpoint(accelLimit,axisDist[3],maxSpeed).
   
    SET SHIP:CONTROL:FORE TO forRCS_PID:UPDATE(TIME:SECONDS,axisSpeed[1]).
    SET SHIP:CONTROL:TOP TO topRCS_PID:UPDATE(TIME:SECONDS,axisSpeed[2]).
    SET SHIP:CONTROL:STARBOARD TO starRCS_PID:UPDATE(TIME:SECONDS,axisSpeed[3]).
   
    WAIT 0.01.
    SET done TO 1 > axisDist[0].
}
 
SET SHIP:CONTROL:FORE TO 0.
SET SHIP:CONTROL:TOP TO 0.
SET SHIP:CONTROL:STARBOARD TO 0.
SET SHIP:CONTROL:NEUTRALIZE TO TRUE.
RCS OFF.
       
FUNCTION RCS_decel_setpoint {
    PARAMETER accel,dist,speedLimit.
    LOCAL posNeg IS 1.
    IF dist < 0 { SET posNeg TO -1. }
    RETURN MIN(MAX((SQRT(2 * ABS(dist) / accel) * accel) * posNeg,-speedLimit),speedLimit).
}
 
FUNCTION axis_speed {
    PARAMETER craft,        //the craft to calculate the speed of (craft using RCS)
    station.                //the target the speed is relative  to
    LOCAL localStation IS target_craft(station).
    LOCAL localCraft IS target_craft(craft).
    LOCAL craftFacing IS localCraft:FACING.
    IF craft:ISTYPE("DOCKINGPORT") { SET craftFacing TO craft:PORTFACING. }
    LOCAL relitaveSpeedVec IS localCraft:VELOCITY:ORBIT - localStation:VELOCITY:ORBIT.  //relitaveSpeedVec is the speed as reported by the navball in target mode as a vector along the target prograde direction
    LOCAL speedFor IS VDOT(relitaveSpeedVec, craftFacing:FOREVECTOR).   //positive is moving forwards, negative is moving backwards
    LOCAL speedTop IS VDOT(relitaveSpeedVec, craftFacing:TOPVECTOR).    //positive is moving up, negative is moving down
    LOCAL speedStar IS VDOT(relitaveSpeedVec, craftFacing:STARVECTOR).  //positive is moving right, negative is moving left
    RETURN LIST(relitaveSpeedVec,speedFor,speedTop,speedStar).
}
 
FUNCTION axis_distance {
    PARAMETER craft,    //port that all distances are relative to (craft using RCS)
    station.            //port you want to dock to
    LOCAL craftFacing IS target_craft(craft):FACING.
    IF craft:ISTYPE("DOCKINGPORT") { SET craftFacing TO craft:PORTFACING. }
    LOCAL distVec IS station:POSITION - craft:POSITION.//vector pointing at the station port from the craft port
    LOCAL dist IS distVec:MAG.
    LOCAL distFor IS VDOT(distVec, craftFacing:FOREVECTOR). //if positive then stationPort is ahead of craftPort, if negative than stationPort is behind of craftPort
    LOCAL distTop IS VDOT(distVec, craftFacing:TOPVECTOR).      //if positive then stationPort is above of craftPort, if negative than stationPort is below of craftPort
    LOCAL distStar IS VDOT(distVec, craftFacing:STARVECTOR).    //if positive then stationPort is to the right of craftPort, if negative than stationPort is to the left of craftPort
    RETURN LIST(dist,distFor,distTop,distStar).
}
 
FUNCTION target_craft {
    PARAMETER tar.
    IF NOT tar:ISTYPE("Vessel") { RETURN tar:SHIP. }
    RETURN tar.
}