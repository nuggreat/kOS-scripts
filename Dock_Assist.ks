PARAMETER degreesOfRotation IS 0, facingForward IS FALSE.
LOCAL dockingPoint IS SHIP:PARTSTAGGED("dockingPoint")[0].
FOR lib IN LIST("lib_dock","lib_rocket_utilities") { IF EXISTS("1:/lib/" + lib + ".ksm") { RUNONCEPATH("1:/lib/" + lib + ".ksm"). } ELSE { RUNONCEPATH("1:/lib/" + lib + ".ks"). }}
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
	WAIT 0.01.
	CLEARSCREEN.
	PRINT "      Dist: " + ROUND(relDist[0],2).
	PRINT "     Speed: " + ROUND(relSpeed[0]:MAG,2).
	PRINT " ".
	PRINT " For  Dist: " + ROUND(relDist[1],3).
	PRINT " For Speed: " + ROUND(relSpeed[1],3).
	PRINT " ".
	PRINT " Top  Dist: " + ROUND(relDist[2],3).
	PRINT " Top Speed: " + ROUND(relSpeed[2],3).
	PRINT " ".
	PRINT "Star  Dist: " + ROUND(relDist[3],3).
	PRINT "Star Speed: " + ROUND(relSpeed[3],3).
}
 UNLOCK STEERING.