FUNCTION VecDrawAdd { // Draw the vector or update it.
	PARAMETER vecDrawLex,vecStart,vecTarget,localColour,localLabel,localScale.

	IF vecDrawLex:KEYS:CONTAINS(localLabel) {
		SET vecDrawLex[localLabel]:START to vecStart.
		SET vecDrawLex[localLabel]:VEC to vecTarget.
		SET vecDrawLex[localLabel]:COLOUR to localColour.
		SET vecDrawLex[localLabel]:SCALE to localScale.
	} ELSE {
		vecDrawLex:ADD(localLabel,VECDRAW(vecStart,vecTarget,localColour,localLabel,localScale,TRUE,0.2)).
	}
}

FUNCTION accel_data { //using the Accelerometer part returns the current acceleration of the SHIP in m/s
	LOCAL accelPart IS SHIP:PARTSNAMED("sensorAccelerometer").
	IF accelPart:LENGTH > 0 {
		LOCAL accelModule IS accelPart[0]:GETMODULE("moduleenvirosensor").
		LOCAL accelData IS accelModule:GETFIELD("display").
		IF accelData = "off" {
			accelModule:DOEVENT("toggle display").
			WAIT 0.
			SET accelData TO accelModule:GETFIELD("display").
		}
		SET accelData TO accelData:SUBSTRING(0,accelData:LENGTH - 2):TONUMBER(0) * 9.80665.
		RETURN accelData.
	} ELSE {
		RETURN 0.
	}
}

FUNCTION advanced_heading {//works just like HEADING but lets you set the roll
	PARAMETER myHeading,myPitch,myRoll.//positive myRoll is is right wing up left down(q key)
	LOCAL returnDir IS HEADING(myHeading,myPitch).
	RETURN ANGLEAXIS(myRoll,returnDir:FOREVECTOR) * returnDir.
}

FUNCTION pitch_roll {//intended for use with aircraft, needs navBall2 lib
	PARAMETER myPitch,myRoll.
	LOCAL returnDir IS HEADING(heading_of_vector(SHIP:SRFPROGRADE:FOREVECTOR),myPitch).
	RETURN ANGLEAXIS(myRoll,returnDir:FOREVECTOR) * returnDir.
}

FUNCTION pitch_roll {//intended for use with aircraft, needs navBall2 lib
	PARAMETER myPitch,myRoll.
	LOCAL returnDir IS SHIP:SRFPROGRADE.
	SET returnDir TO ANGLEAXIS(pitch_of_vector(returnDir:FOREVECTOR) - myPitch, returnDir:STARVECTOR) * returnDir.
	RETURN ANGLEAXIS(myRoll,returnDir:FOREVECTOR) * returnDir.
}

FUNCTION pitch_roll {
	PARAMETER myPitch, myRoll.//intended for use with aircraft
	LOCAL upVec IS SHIP:UP:VECTOR.
	LOCAL returnDir IS LOOKDIRUP(VXCL(upVec,SHIP:SRFPROGRADE:FOREVECTOR),upVec).
	
	SET returnDir TO ANGLEAXIS(myPitch,returnDir:STARVECTOR) * returnDir.
	SET returnDir TO ANGLEAXIS(myRoll,returnDir:FOREVECTOR) * returnDir.
	RETURN returnDir.
}

FUNCTION pitch_roll {//intended for use with aircraft
	PARAMETER wantPitch,wantRoll.

	LOCAL returnDir IS SHIP:SRFPROGRADE.
	LOCAL pitchOffset IS 90 - VANG(SHIP:SRFPROGRADE:FOREVECTOR,SHIP:UP:VECTOR).

	SET returnDir TO ANGLEAXIS(pitchOffset - wantPitch,returnDir:STARVECTOR) * returnDir.
	SET returnDir TO ANGLEAXIS(wantRoll,returnDir:FOREVECTOR) * returnDir.
	RETURN returnDir.
}


FUNCTION pseudo_throttle {
	PARAMETER throt, tConfig.  //tConfig LIST(LIST(trigger level for engine set, list of engines to cycle))
	FOR data IN tConfig {
		IF throt > data[0] {
			FOR eng IN data[1] { eng:ACTIVATE(). }
		} ELSE {
			FOR eng IN data[1] { eng:SHUTDOWN(). }
		}
	}
}

FUNCTION pseudo_throttle_config { //creates config file for pseudo_throttle
	PARAMETER tagHeader IS "eng", symetry IS 2.
	LOCAL numberPairs IS SHIP:PARTSTAGGEDPATTERN(tagHeader):LENGTH / symetry + 1.
	LOCAL tConfig IS LIST().
	FROM { LOCAL i IS numberPairs - 2. } UNTIL 0 > i STEP { SET i TO i - 1. } DO {
		tConfig:ADD(LIST((i + 1) / numberPairs,SHIP:PARTSTAGGED(tagHeader + i))).
	}
	RETURN tConfig.
}

FUNCTION burn_along_vector {//needs libs formating, rocker utilities
	PARAMETER DVvector,startTime IS TIME:SECONDS,doStage IS TRUE.
	ABORT OFF.
	LOCAL timePast IS TIME:SECONDS.
	LOCAL potentialAccel IS SHIP:AVAILABLETHRUST / SHIP:MASS.
	LOCAL shipISP IS isp_calc().
	LOCAL count IS 5.

	LOCK STEERING TO DVvector.
	WAIT UNTIL (ABS(STEERINGMANAGER:ANGLEERROR) < 0.1) AND (startTime <= TIME:SECONDS).//wait until within 0.1 degrees of target
	LOCK THROTTLE TO MAX(MIN(DVvector:MAG / (potentialAccel * 1),1),0.01).
	CLEARSCREEN.
	UNTIL DVvector:MAG < 0.01 OR ABORT {	//executing the burn
		WAIT 0.
		SET potentialAccel TO SHIP:AVAILABLETHRUST / SHIP:MASS.
		LOCAL timeNow IS TIME:SECONDS.
		LOCAL throt IS THROTTLE.
		LOCAL shipFacingFore IS SHIP:FACING:FOREVECTOR.

		LOCAL deltaTime IS timeNow - timePast.
		SET timePast TO timeNow.
		LOCAL shipAcceleration IS (potentialAccel * throt * deltaTime).
		SET DVvector TO DVvector - (shipAcceleration * shipFacingFore).

		IF count >= 5 {
			PRINT " DeltaV left on burn:" + padding(DVvector:MAG,1,1) + "m/s      " AT(0,0).
			PRINT "   Time left on burn:" + time_converter(burn_duration(shipISP,DVvector:MAG),1) + "      " AT(0,1).
			SET count TO 0.
		} ELSE {
			SET count TO count + 1.
		}

		IF stage_check(doStage) { SET shipISP TO isp_calc(). }//if i stage recalculate the ISP
	}
}

FUNCTION burn_vec_constructor {
	PARAMETER burnTime,burnRadial,burnNormal,burnPrograde,localBody IS SHIP:BODY.
	
	LOCAL vecUp IS (POSITIONAT(SHIP,nodeTime) - localBody:POSITION):NORMALIZED.
	LOCAL vecNodePrograde IS VELOCITYAT(SHIP,nodeTime):ORBIT:NORMALIZED.
	LOCAL vecNodeNormal IS VCRS(vecNodePrograde,vecUp):NORMALIZED.
	LOCAL vecNodeRadial IS VCRS(vecNodeNormal,vecNodePrograde):NORMALIZED.
	
	RETURN vecNodeRadial * burnRadial + vecNodeNormal * burnNormal + vecNodePrograde * burnPrograde.
}

FUNCTION pid_debug {
	PARAMETER pidToDebug.
	//CLEARSCREEN.
	PRINT "Setpoint: " + ROUND(pidToDebug:SETPOINT,2) + "     " AT(0,0).
	PRINT "   Error: " + ROUND(pidToDebug:ERROR,2) + "     " AT(0,1).
	PRINT "       P: " + ROUND(pidToDebug:PTERM,3) + "      " AT(0,2).
	PRINT "       I: " + ROUND(pidToDebug:ITERM,3) + "      " AT(0,3).
	PRINT "       D: " + ROUND(pidToDebug:DTERM,3) + "      " AT(0,4).
	PRINT "     Max: " + ROUND(pidToDebug:MAXOUTPUT,2) + "     " AT(0,5).
	PRINT "  Output: " + ROUND(pidToDebug:OUTPUT,2) + "     " AT(0,6).
	PRINT "     min: " + ROUND(pidToDebug:MINOUTPUT,2) + "     " AT(0,7).
//	LOG (pidToDebug:SETPOINT + "," + pidToDebug:ERROR + "," + pidToDebug:PTERM + "," + pidToDebug:ITERM + "," + pidToDebug:DTERM + "," + pidToDebug:MAXOUTPUT + "," + pidToDebug:OUTPUT +  "," + pidToDebug:MINOUTPUT) TO PATH("0:/pidLog.txt").
}

FUNCTION impact_eta { //returns the impact time in UT from after the next node, note only works on airless bodies
  PARAMETER posTime IS TIME:SECONDS. //posTime must be in UT seconds (TIME:SECONDS)
  LOCAL stepVal IS 100.
  LOCAL maxScanTime IS SHIP:ORBIT:PERIOD + posTime.
  IF (SHIP:ORBIT:PERIAPSIS < 0) AND (SHIP:ORBIT:TRANSITION <> "escape") {
    LOCAL localBody IS SHIP:BODY.
    LOCAL resetTime IS TIME:SECONDS.
    LOCAL resetCounter IS 0.
    LOCAL scanTime IS posTime.
    LOCAL targetAltitudeHi IS 1 .
    LOCAL targetAltitudeLow IS 0.
    LOCAL pos IS POSITIONAT(SHIP,scanTime).
    LOCAL altitudeAt IS localBody:ALTITUDEOF(POSITIONAT(SHIP,scanTime)).
    UNTIL (altitudeAt < targetAltitudeHi) AND (altitudeAt > targetAltitudeLow) {
      IF altitudeAt > targetAltitudeHi {
        SET scanTime TO scanTime + stepVal.
        SET pos TO POSITIONAT(SHIP,scanTime).
        SET altitudeAt TO localBody:ALTITUDEOF(pos) - ground_track(pos,scanTime):TERRAINHEIGHT.
        IF altitudeAt < targetAltitudeLow {
          SET scanTime TO scanTime - stepVal.
          SET pos TO POSITIONAT(SHIP,scanTime).
          SET altitudeAt TO localBody:ALTITUDEOF(pos) - ground_track(pos,scanTime):TERRAINHEIGHT.
          SET stepVal TO stepVal / 2.
        }
      } ELSE IF altitudeAt < targetAltitudeLow {
        SET scanTime TO scanTime - stepVal.
        SET pos TO POSITIONAT(SHIP,scanTime).
        SET altitudeAt TO localBody:ALTITUDEOF(pos) - ground_track(pos,scanTime):TERRAINHEIGHT.
        IF altitudeAt > targetAltitudeHi {
          SET scanTime TO scanTime + stepVal.
          SET pos TO POSITIONAT(SHIP,scanTime).
          SET altitudeAt TO localBody:ALTITUDEOF(pos) - ground_track(pos,scanTime):TERRAINHEIGHT.
          SET stepVal TO stepVal / 2.
        }
      }
      IF (resetTime + 10) < TIME:SECONDS {//resets loop if it takes more than 10 seconds
        SET scanTime TO posTime.
        SET stepVal TO 100.
        SET resetTime TO TIME:SECONDS.
        SET resetCounter TO resetCounter + 1.
        IF resetCounter >= 3 { SET scanTime TO -1. BREAK. }
      }
      IF maxScanTime < scanTime {//resets loop if it is bigger than one period
        SET scanTime TO posTime.
        SET stepVal TO stepVal / 2.
        SET resetTime TO TIME:SECONDS.
        SET resetCounter TO resetCounter + 1.
        IF resetCounter >= 3 { SET scanTime TO -1. BREAK. }
      }
    }
    RETURN scanTime.
  } ELSE {
    RETURN -1.
  }
}

FUNCTION ground_track {	//returns the geocoordinates of the ship at a given time(UTs) adjusting for planetary rotation over time
  PARAMETER pos,posTime.
  LOCAL localBody IS SHIP:BODY.
  LOCAL rotationalDir IS VDOT(localBody:NORTH:FOREVECTOR,localBody:ANGULARVEL). //the number of radians the body will rotate in one second
  LOCAL posLATLNG IS localBody:GEOPOSITIONOF(pos).
  LOCAL timeDif IS posTime - TIME:SECONDS.
  LOCAL longitudeShift IS rotationalDir * timeDif * CONSTANT:RADTODEG.
  LOCAL newLNG IS MOD(posLATLNG:LNG + longitudeShift ,360).
  IF newLNG < - 180 { SET newLNG TO newLNG + 360. }
  IF newLNG > 180 { SET newLNG TO newLNG - 360. }
  RETURN LATLNG(posLATLNG:LAT,newLNG).
}//function used but included for easy of reference for impact_eta function

FUNCTION warp_control {
	PARAMETER timeIn,easeFactor is 1,warpBase is KUNIVERSE:TIMEWARP,maxRate is KUNIVERSE:TIMEWARP:RAILSRATELIST:LENGTH - 1,railRateList is KUNIVERSE:TIMEWARP:RAILSRATELIST.
	IF ABORT OR (timeIn < easeFactor) {
		IF warpBase:WARP <> 0 {
			SET warpBase:WARP TO 0.
		}
		RETURN TRUE.
	}
	SET easeFactor TO MAX(1,easeFactor).

	IF warpBase:ISSETTLED {
		IF timeIn / railRateList[warpBase:WARP] < easeFactor {
			SET warpBase:WARP TO warpBase:WARP - 1.
		} ELSE IF timeIn / railRateList[warpBase:WARP + 1] > easeFactor {
			SET warpBase:WARP TO MAX(warpBase:WARP + 1,maxRate).
		}
	}

	RETURN FALSE.
}

FUNCTION BURN_TIME_CALC{//need to reformat to remove unneeded *1000 elements as well as change var names to make sense to me
    PARAMETER CMAS,					//Current Mass
	EISP,							//Engine ISP
	MAXT,							//Max Thrust
	CVEL.							//DV
    LOCAL E IS CONSTANT():E.
    LOCAL G IS 9.80665.				// Gravity for ISP Conv
    LOCAL I IS EISP * G.				// ISP in m/s units.
    LOCAL M IS CMAS * 1000.			// Mass in kg.
    LOCAL T IS MAXT * 1000.			// Thrust in N.
    LOCAL F IS T/I.					// Fuel flow in kg/s.
    RETURN (M/F)*(1-E^(-CVEL/I)).	// Burn time in seconds
}

FUNCTION BURN_DIST_CALC{//need to reformat to remove unneeded *1000 elements as well as change var names to make sense to me
	PARAMETER CMAS,										//Current Mass
	EISP,												//Engine ISP
	MAXT,												//Max Thrust
	CVEL.												//DV
	LOCAL E IS CONSTANT():E.
	LOCAL G IS 9.80665.									// Gravity for ISP Conv
	LOCAL I IS EISP * G.									// ISP in m/s units.
	LOCAL M IS CMAS * 1000.								// Mass in kg.
	LOCAL T IS MAXT * 1000.								// Thrust in N.
	LOCAL F IS T/I.										// Fuel Flow in kg/s.
	LOCAL DT IS BURN_TIME_CALC(CMAS,EISP,MAXT,CVEL).		// Burn time in seconds.
	RETURN I*(DT-(M/F))*LN(1-(F*DT/M))-(I*DT)+(CVEL*DT).	// Braking distance, somehow.
}

FUNCTION chute_deploy_all {
	LOCAL chuteList IS LIST().
	FOR par IN SHIP:PARTS {
		IF par:HASMODULE("moduleParachute") {
			chuteList:ADD(par).
		}
	}
	LOCAL chutesDeployed IS 0.
	UNTIL chutesDeployed >= chuteList:LENGTH {
		FOR chute IN chuteList {
			LOCAL moduleParachute IS chute:GETMODULE("moduleParachute").
			IF chute:TAG <> "deployed" AND moduleParachute:HASFIELD("safe to deploy?") {
				IF moduleParachute:GETFIELD("safe to deploy?") = "Safe" {
					moduleParachute:SETFIELD("min pressure",0.01).
					moduleParachute:DOEVENT("deploy chute").
					SET chute:TAG TO "deployed".
					SET chutesDeployed TO chutesDeployed + 1.
				}
			}
		}
		WAIT 0.
	}
}

FUNCTION percent_resource_for_tag {//returns percentage of given resource in tagged tanks
	PARAMETER tankTag, resName IS "LIQUIDFUEL".
	LOCAL resAmo IS 0.
	LOCAL resCap IS 0.
	FOR tank IN SHIP:PARTSTAGGED(tankTag) {
		FOR res IN tank:RESOURCES {
			IF res:NAME = resName {
				SET resAmo TO resAmo + res:AMOUNT.
				SET resCap TO resCap + res:CAPACITY.
			}
		}
	}
	RETURN ((resAmo * 100) / resCap).
}

FUNCTION resorce_amount_for_tagged {//returns percentage of given resource in tagged tanks
	PARAMETER tankTag, resName IS "LIQUIDFUEL".
	LOCAL resAmo IS 0.
	FOR tank IN SHIP:PARTSTAGGED(tankTag) {
		FOR res IN tank:RESOURCES {
			IF res:NAME = resName {
				SET resAmo TO resAmo + res:AMOUNT.
			}
		}
	}
	RETURN resAmo.
}

FUNCTION parts_with_res {
	PARAMETER resName.
	FOR res IN SHIP:RESOURCES {
		IF res:NAME = resName {
			RETURN res:PARTS.
		}
	}
	RETURN LIST().
}

LOCAL functionData IS LEX("angleOldTime",TIME:SECONDS,"angleOldVec",v(0,0,0)).
FUNCTION angle_delta {
	PARAMETER currentVec,resetVec IS FALSE.
	LOCAL localTime IS TIME:SECONDS.

	LOCAL deltaTime IS localTime - functionData["angleOldTime"].
	LOCAL deltaAngle IS VANG(currentVec, functionData["angleOldVec"]).
	SET functionData["angleOldTime"] TO localTime.
	SET functionData["angleOldVec"] TO currentVec.

	IF resetVec {
		RETURN 0.
	} ELSE {
		RETURN deltaAngle/deltaTime.
	}
}

FUNCTION tag_docking_ports {//tags all docking ports found with a tree scan that stops looking farther along a branch once a port is found
	PARAMETER myPart,//part to start scan from
	nameTag,//tag for docking port
	scanUp IS TRUE.//direction of scan to find docking port, for internal use by the function only

	IF myPart:ISTYPE("dockingport") {
		SET myPart:TAG TO nameTag.
		IF scanUp {//scan down the tree once port highest up the tree has be found
			FOR child IN myPart:CHILDREN {
				RETURN tag_docking_ports(child,nameTag,FALSE).
			}
		}
		RETURN TRUE.
	} ELSE {
		IF scanUp {
			IF myPart:HASPARENT {//scan up tree until root part then reverse scan direction
				RETURN tag_docking_ports(myPart:PARENT,nameTag,scanUp).
			} ELSE {
				RETURN tag_docking_ports(myPart,nameTag,FALSE).
			}
		} ELSE {
			LOCAL foundPort IS FALSE.
			FOR child IN myPart:CHILDREN {
				SET foundPort TO tag_docking_ports(child,nameTag,scanUp) OR foundPort.
			}
			RETURN foundPort.
		}
	}
}

FUNCTION docking_ports_near {//returns a list of docking ports found with a tree scan that stops looking farther along a branch once a port is found
	PARAMETER myPart,//part to start scan from
	scanUp IS TRUE.//direction of scan to find docking port, for internal use by the function only

	IF myPart:ISTYPE("dockingport") {
		LOCAL returnList IS LIST(myPart).
		IF scanUp {//scan down the tree once port highest up the tree has be found
			FOR child IN myPart:CHILDREN {
				FOR port IN docking_ports_near(child,FALSE) {
					returnList:ADD(port).
				}
			}
		}
		RETURN returnList.
	} ELSE {
		IF scanUp {
			IF myPart:HASPARENT {//scan up tree until root part then reverse scan direction
				RETURN docking_ports_near(myPart:PARENT,scanUp).
			} ELSE {
				RETURN docking_ports_near(myPart,FALSE).
			}
		} ELSE {
			LOCAL returnList IS LIST().
			FOR child IN myPart:CHILDREN {
				FOR port IN docking_ports_near(child,scanUp) {
					returnList:ADD(port).
				}
			}
			RETURN returnList.
		}
	}
}
//decoupler module is: ModuleDecouple
//think about adding a blacklist of modules/part names
FUNCTION parts_with_module_near {//returns a list of parts containing the named module found with a tree scan that stops looking farther along a branch once a port is found
	PARAMETER myPart,//part to start scan from
	myModule IS "moduleDecouple",//the module to scan for
	scanUp IS TRUE.//direction of scan, for internal use by the function only
	//returnList IS LIST().//the list that will have all found parts, for internal use by the function only 

	IF myPart:HASMODULE(myModule) {
		LOCAL returnList IS LIST(myPart).
		//returnList:ADD(myPart).
		IF scanUp {//scan down the tree once part highest up the tree has be found
			FOR child IN myPart:CHILDREN {
				//parts_with_module_near(child,myModule,FALSE,returnList).
				FOR par IN parts_with_module_near(child,myModule,FALSE) {
					returnList:ADD(par).
				}
			}
		}
		RETURN returnList.
	} ELSE {
		IF scanUp {
			IF myPart:HASPARENT {//scan up tree until root part then reverse scan direction
				//parts_with_module_near(myPart:PARENT,myModule,scanUp,returnList).
				RETURN parts_with_module_near(myPart:PARENT,myModule,scanUp).
			} ELSE {
				//parts_with_module_near(myPart,myModule,FALSE,returnList).
				RETURN parts_with_module_near(myPart,myModule,FALSE).
			}
		} ELSE {
			LOCAL returnList IS LIST().
			FOR child IN myPart:CHILDREN {
				//parts_with_module_near(child,myModule,scanUp,returnList).
				FOR par IN parts_with_module_near(child,myModule,scanUp) {
					returnList:ADD(par).
				}
			}
			RETURN returnList.
		}
	}
	//RETURN returnList.
}

FUNCTION number_concatnation {
	PARAMETER string,cha.//expects " " as the base string to start with
	LOCAL returnString TO string.
	IF cha:MATCHESPATTERN("[0-9-.]") {
		IF cha:MATCHESPATTERN("[0-9]") {
			RETURN returnString + cha.
		} ELSE IF cha = "-" {
			IF returnString:CONTAINS("-"){
				RETURN " " + returnString:REMOVE(0,1).
			} ELSE {
				RETURN cha + returnString:REMOVE(0,1).
			}
		} ELSE IF cha = "." {
			IF returnString:CONTAINS(".") {
				RETURN returnString.
			} ELSE {
				RETURN returnString + cha.
			}
		}
	} ELSE IF (cha = TERMINAL:INPUT:BACKSPACE) AND (returnString:LENGTH > 1)  {
		RETURN returnString:REMOVE(returnString:LENGTH - 1,1).
	} ELSE {
		RETURN returnString.
	}
}

LOCAL oldThings IS LEX().
FUNCTION print_delta {
	PARAMETER thing,key.
	IF oldThings:KEYS:CONTAINS(key) {
		LOCAL localTime IS TIME:SECONDS.
		LOCAL deltaTime IS localTime - oldThings[key]["time"].
		LOCAL delta is (oldThings[key]["thing"] - thing) / deltaTime.
		SET oldThings[key]["time"] TO localTime.
		SET oldThings[key]["thing"] TO thing.
		PRINT key + ": " + delta.
	} ELSE {
		oldThings:ADD(key,LEX("thing",thing,"time",TIME:SECONDS)).
	}
}

FUNCTION circularize_at_UT {
  PARAMETER UTs.
  LOCAL upVec IS (POSITIONAT(SHIP,UTs) - SHIP:BODY:POSITION).
  LOCAL vecNodePrograde IS VELOCITYAT(SHIP,UTs):ORBIT:NORMALIZED.
  LOCAL vecNodeNormal IS VCRS(vecNodePrograde,upVec):NORMALIZED.
  LOCAL vecNodeRadial IS VCRS(vecNodeNormal,vecNodePrograde):NORMALIZED.
  
  LOCAL velTarget IS SQRT(SHIP:BODY:MU / upVec:MAG).
  LOCAL vecTarget IS (VXCL(upVec,vecNodePrograde):NORMALIZED * velTarget) - vecNodePrograde.
  
  LOCAL nodePrograde IS VDOT(vecTarget,vecNodePrograde:NORMALIZED).
  LOCAL nodeRadial IS VDOT(vecTarget,vecNodeRadial:NORMALIZED).
  
  RETURN NODE(UTs,nodeRadial,0,nodePrograde).
}

FUNCTION remove_by_vlaue {
	PARAMETER listA, listB.
	FROM { LOCAL i IS listA:LENGTH - 1. } UNTIL i < 0 STEP { SET i TO i - 1. } DO {
		IF listB:CONTAINS(listA[i]) {
			listA:REMOVE(i).
		}
	}
}

FUNCTION current_mach_number {
	LOCAL currentPresure IS MAX(BODY:ATM:ALTITUDEPRESSURE(SHIP:ALTITUDE),0.0000001).
	RETURN SQRT(2 / BODY:ATM:ADIABATICINDEX * SHIP:Q / currentPresure).
}

FUNCTION kill {
	SET SHIP:CONTROL:TRANSLATION to v(0,0,0).
	SET SHIP:CONTROL:ROTATION to v(0,0,0).
	SET SHIP:CONTROL:PILOTMAINTHROTTLE to 0.
	LOCK THROTTLE to 0.
	LOCK STEERING to "kill".
	UNLOCK THROTTLE.
	UNLOCK STEERING.
	UNLOCK ALL.
	SET SHIP:CONTROL:NEUTRALIZE TO TRUE.
	CLEARVECDRAWS().
	CLEARGUIS().
}

FUNCTION thrust_balancer {
	PARAMETER engList,balanceAroundVec,baseLimit IS 100.
	LOCAL torqueSumVec IS v(0,0,0).
	FOR eng IN engList {
		LOCAL leverVec IS VXCL(balanceAroundVec, eng:POSITION).
		SET torqueSumVec TO torqueSumVec + leverVec * eng:MAXTHRUST.
	}
	
	LOCAL badEngList IS LIST().
	LOCAL badTorqueSumVec IS v(0,0,0).
	FOR eng IN engList {
		IF VDOT(torqueSumVec,eng:POSITION) > 0 {
			badEngList:ADD(eng).
			LOCAL leverVec IS VXCL(balanceAroundVec,eng:POSITION).
			SET badTorqueSumVec TO badTorqueSumVec + leverVec * eng:MAXTHRUST.
		} ELSE {
			SET eng:THRUSTLIMIT TO baseLimit.
		}
	}
	
	LOCAL thrustLim IS (1 - torqueSumVec:MAG / badTorqueSumVec:MAG) * baseLimit.
	FOR eng IN badEngList {
		SET eng:THRUSTLIMIT TO thrustLim.
	}
}

FUNCTION circ_at_pe {
	LOCAL nodeTime IS TIME:SECONDS + ETA:PERIAPSIS.
	LOCAL velAtPE IS VELOCITYAT(SHIP,nodeTime):ORBIT:MAG.
	LOCAL circularVel IS SQRT(BODY:MU / (SHIP:ORBIT:PERIAPSIS + BODY:RADIUS)).
	RETURN NODE(nodeTime,0,0,velAtPE - circularVel).
}

FUNCTION circ_at_ap {
	LOCAL nodeTime IS TIME:SECONDS + ETA:APOAPSIS.
	LOCAL velAtPE IS VELOCITYAT(SHIP,nodeTime):ORBIT:MAG.
	LOCAL circularVel IS SQRT(BODY:MU / (SHIP:ORBIT:APOAPSIS + BODY:RADIUS)).
	RETURN NODE(nodeTime,0,0,velAtPE - circularVel).
}

FUNCTION message_ques {
	LOCAL mQueue IS QUEUE().
	LOCAL coreM IS CORE:MESSAGES.
	UNTIL coreM:EMPTY {
		mQueue:PUSH(coreM:POP()).
	}
	LOCAL shipM IS SHIP::MESSAGES.
	UNTIL shipM {
		mQueue:PUSH(shipM:POP()).
	}
	RETURN qQueue.
}

FUNCTION interp_z_val {//takes in 5 vectors
	PARAMETER p0,p1,p2,p3,pSeak.
	
	LOCAL xRangeA IS p1:x - p0:X.
	LOCAL xRangeB IS p3:X - p2:X.
	LOCAL xFracDistA IS (p1:x - pSeak:x) / xRangeA.
	LOCAL xFracDistB IS (p3:x - pSeak:x) / xRangeB.
	LOCAL xHeightA IS xFracDistA * p0:z + (1 - xFracDistA) * p1:z.
	LOCAL xHeightB IS xFracDistB * p2:z + (1 - xFracDistB) * p3:z.
	
	LOCAL yRangeA IS p2:y - p0:y.
	LOCAL yRangeB IS p3:y - p1:y.
	LOCAL yFracDistA IS (p2:y - pSeak:y) / yRangeA.
	LOCAL yFracDistB IS (p3:y - pSeak:y) / yRangeB.
	LOCAL yHeightA IS yFracDistA * xHeightA + (1 - yFracDistA) * xHeightB.
	LOCAL yHeightB IS yFracDistB * xHeightA + (1 - yFracDistB) * xHeightB.
	
	RETURN (yHeightA + yHeightB) / 2.
}

//points are assumed to be in this configuration with p0 having the lowest x/y values and p3 having the largest x/y values
// points are assumed to be in a reteculangular formation
// 5th vector is the point who's z is being interpolated from the others and is assumed to fall within the shape defined by the other 4
//  the * represents the point
//
//  p2     p3
//    *      *
//
//  p0     p1
//    *      *

//"I am the Bone of my Research Knowledge is my Body and Grants are my Blood.
//I have written over a Thousand Papers, Unknown to Emeritus, Nor known to Tenure.
//Have withstood Peer Review to create many Publications Yet those Methods will never prove Anything.
//So, as I Pray-- Unlimited Science Works"