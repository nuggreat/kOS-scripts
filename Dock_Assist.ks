PARAMETER degreesOfRotation IS 0, facingForward IS FALSE.
LOCAL dockingPoint IS SHIP:PARTSTAGGED("dockingPoint")[0].
FOR lib IN LIST("lib_dock","lib_rocket_utilities") { IF EXISTS("1:/lib/" + lib + ".ksm") { RUNPATH("1:/lib/" + lib + ".ksm"). } ELSE { RUNPATH("1:/lib/" + lib + ".ks"). }}
ABORT OFF.
SAS OFF.
LOCAL targetCraft IS TARGET.
IF targetCraft:ISTYPE("dockingPort"){
	control_point("dockingPoint").
	LOCK STEERING TO ANGLEAXIS(degreesOfRotation,SHIP:FACING:FOREVECTOR) * LOOKDIRUP(-targetCraft:PORTFACING:FOREVECTOR, targetCraft:PORTFACING:TOPVECTOR).
} ELSE {
	IF facingForward {
		LOCK STEERING TO ANGLEAXIS(degreesOfRotation,SHIP:FACING:FOREVECTOR) * (LOOKDIRUP(targetCraft:FACING:FOREVECTOR,targetCraft:FACING:TOPVECTOR)).
	} ELSE {
		LOCK STEERING TO ANGLEAXIS(degreesOfRotation,SHIP:FACING:FOREVECTOR) * (LOOKDIRUP(-targetCraft:FACING:FOREVECTOR,targetCraft:FACING:TOPVECTOR)).
	}
}
UNTIL ABORT {
	LOCAL relSpeed IS axis_speed(SHIP,targetCraft).
	LOCAL relDist IS axis_distance(dockingPoint,targetCraft).
	LOCAL relSpeed1 IS axis_speed(targetCraft,SHIP).
	LOCAL relDist1 IS axis_distance(targetCraft,dockingPoint).
	WAIT 0.01.
	CLEARSCREEN.
	PRINT "      Dist0: " + ROUND(relDist[0],2).
	PRINT "      Dist1: " + ROUND(relDist1[0],2).
	PRINT "     Speed0: " + ROUND(relSpeed[0]:MAG,2).
	PRINT "     Speed1: " + ROUND(relSpeed1[0]:MAG,2).
	PRINT " ".
	PRINT " For  Dist0: " + ROUND(relDist[1],3).
	PRINT " For  Dist1: " + ROUND(relDist1[1],3).
	PRINT " For Speed0: " + ROUND(relSpeed[1],3).
	PRINT " For Speed1: " + ROUND(relSpeed1[1],3).
	PRINT " ".
	PRINT " Top  Dist0: " + ROUND(relDist[2],3).
	PRINT " Top  Dist1: " + ROUND(relDist1[2],3).
	PRINT " Top Speed0: " + ROUND(relSpeed[2],3).
	PRINT " Top Speed1: " + ROUND(relSpeed1[2],3).
	PRINT " ".
	PRINT "Star  Dist1: " + ROUND(relDist1[3],3).
	PRINT "Star  Dist0: " + ROUND(relDist[3],3).
	PRINT "Star Speed1: " + ROUND(relSpeed1[3],3).
	PRINT "Star Speed0: " + ROUND(relSpeed[3],3).
}
UNLOCK STEERING.