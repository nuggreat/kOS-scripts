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

FUNCTION engine_torque {
	PARAMETER eng.
	RETURN VCRS((SHIP:POSITION - eng:POSITION),(eng:FACING:VECTOR * eng:AVAILABLETHRUST)).
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

FUNCTION rotate_vec_into_solar_raw {
  PARAMETER rawRawVec.
  LOCAL rawToSolar IS LOOKDIRUP(SOLARPRIMEVECTOR,v(0,1,0)).
  RETURN rawRawVec * rawToSolar.
}

FUNCTION burn_vec_constructor {
	PARAMETER burnTime,burnRadial,burnNormal,burnPrograde,localBody IS SHIP:BODY.
	// LOCAL localBody IS ORBITAT(SHIP,nodeTime):BODY.
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

FUNCTION ground_track2 {	//returns the geocoordinates of the vector at a given time(UTs) adjusting for planetary rotation over time, only works for non tilted spin on bodies 
	PARAMETER pos,posTime,localBody IS SHIP:BODY.
	LOCAL timeDif IS  posTime - TIME:SECONDS.
	LOCAL degShift IS (-360 / localBody:ROTATIONPERIOD) * timeDif.
	LOCAL newPos IS ANGLEAXIS(degShift,localBody:ANGULARVEL) * (pos - localBody:POSITION).
	RETURN localBody:GEOPOSITIONOF(newPos + localBody:POSITION).
}

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

FUNCTION string_cat2 {
	PARAMETER inStr.
	SET inStr TO " " + inStr + " ".
	SET spltStr TO inStr:SPLIT("{}").
	LOCAL retStr IS "".
	SET i TO 0.
	LOCAL iMax IS spltStr:LENGTH - 1.
	LOCAL done IS FALSE.
	LOCAL terminator IS LEX().
	UNTIL done {
		PARAMETER arg IS terminator.
		IF arg <> terminator {
			IF i < iMax { 
				SET retStr TO retStr + spltStr[i] + arg.
			} ELSE {
				SET retStr TO retStr + arg.
			}
		} ELSE {
			SET retStr TO retStr + spltStr[i].
			SET done TO TRUE.
		}
		SET i TO i + 1.
	}
	SET retStr TO retStr:REMOVE(0,1).
	SET retStr TO retStr:REMOVE(retStr:LENGTH - 1,1).
	RETURN retStr.
}

FUNCTION string_cat {
	PARAMETER inStr.
	LOCAL i IS 0.
	LOCAL terminator IS LEX().
	LOCAL escapeChar IS CHAR(0).
	LOCAL escapeStr IS "{" + escapeChar.
	UNTIL FALSE {
		PARAMETER arg IS terminator.
		LOCAL repStr IS "{" + i + "}".
		IF arg <> terminator {
			IF inStr:CONTAINS(repStr) {
				SET inStr TO inStr:REPLACE(repStr,escapeChar + (arg:TOSTRING():REPLACE("{",escapeStr))).
				SET i TO i + 1.
			} ELSE {
				BREAK.
			}
		} ELSE {
			BREAK.
		}
	}
	RETURN inStr:REPLACE(escapeChar,"").
}

FUNCTION ternary_search {
	PARAMETER f, left, right, absPrecision.
	UNTIL FALSE {
		LOCAL rightLeftDiff IS right - left.
		IF ABS(rightLeftDiff) < absPrecision {
			RETURN (left + right) / 2.
		}
		LOCAL leftThird IS left + (rightLeftDiff) / 3.
		LOCAL rightThird IS right - (rightLeftDiff) / 3.
		IF f(leftThird) < f(rightThird) {
			SET left TO leftThird.
		} ELSE {
			SET right TO rightThird.
		}
	}
}

FUNCTION position_at_surface {
	PARAMETER thing,dt.
	LOCAL vi IS thing:VELOCITY:SURFACE.
	LOCAL rad IS thing:POSITION - thing:BODY:POSITION.
	LOCAL ac IS rad:NORMALIZED * (thing:BODY:MU / rad:SQRMAGNITUDE).
	RETURN thing:POSITION + vi * dt + ac * t^2 / 2.
}

FUNCTION delta_init {
    PARAMETER initalX.
    LOCAL oldT IS TIME:SECONDS.
    LOCAL oldX IS initalX.
    LOCAL deltaX IS initalX - initalX.
	LOCAL deltaT IS 0.
    RETURN {
        PARAMETER newX, newT IS TIME:SECONDS.
        SET deltaT TO newT - oldT.
        IF deltaT <> 0 {
            SET deltaX TO (newX - oldX) / deltaT.
            SET oldT TO newT.
            SET oldX TO newX.
        }
		RETURN deltaX.
    }.
}

FUNCTION inerta_vector {
    LOCAL am IS SHIP:ANGULARMOMENTUM.
    LOCAL av TO SHIP:ANGULARVEL * SHIP:FACING:INVERSE.//x = pitch(w = pos, s = neg), y = yaw(d = pos, a = neg), z  = roll(q = pos, e = neg)
    
    //PRINT "pitch inertia: " +  (am:X / av:X).
    //PRINT "yaw   inertia: " + (-am:Z / av:Y).
    //PRINT "roll  inertia: " +  (am:Y / av:Z).
    //WAIT 0.
	RETURN v((am:X / av:X),(-am:Z / av:Y),(am:Y / av:Z)).//x = pitch, y = yaw, z = roll
}

FUNCTION moi_getter_init {
	PARAMETER lowPassCoef IS 50.
	LOCAL warpStruct IS KUNIVERSE:TIMEWARP.
	LOCAL lowPassHighVal IS (lowPassCoef - 1) / lowPassCoef.
	LOCAL lowPassLowVal IS 1 - lowPassHighVal.
	LOCAL angVel IS SHIP:ANGULARVEL * SHIP:FACING:INVERSE.
	LOCAL angMom IS SHIP:ANGULARMOMENTUM.
	UNTIL (angVel:X * angVel:Y * angVel:Z * angMom:X * angMom:Y * angMom:Z) <> 0 {
		WAIT 0.
		SET angVel TO SHIP:ANGULARVEL * SHIP:FACING:INVERSE.
		SET angMom TO SHIP:ANGULARMOMENTUM.
	}
	LOCAL MoIvec IS v(
		(angMom:X / angVel:X), //pitch axis
		(-angMom:Z / angVel:Y),//yaw   axis
		(angMom:Y / angVel:Z)  //roll  axis
	).
	RETURN {
		PARAMETER newAngVel IS SHIP:ANGULARVEL * SHIP:FACING:INVERSE, newAngMom IS SHIP:ANGULARMOMENTUM.
		IF	((warpStruct:WARP = 0) OR (warpStruct:MODE <> "RAILS")) AND
			((newAngVel:X * newAngVel:Y * newAngVel:Z * newAngMom:X * newAngMom:Y * newAngMom:Z) <> 0)
		{
			LOCAL newMoIvec IS v(
				(newAngMom:X / newAngVel:X), //pitch axis
				(-newAngMom:Z / newAngVel:Y),//yaw   axis
				(newAngMom:Y / newAngVel:Z)  //roll  axis
			).
			SET MoIvec TO MoIvec * lowPassHighVal + newMoIvec * lowPassLowVal.
		}
		RETURN LEX (
			"Pitch",MoIvec:X,
			"Yaw",MoIvec:Y,
			"Roll",MoIvec:Z,
		).
	}
}

FUNCTION low_pass_filter_init {
	PARAMETER initalVal,lowPassCoef IS 50.
	LOCAL lowPassHighVal IS (lowPassCoef - 1) / lowPassCoef.
	LOCAL lowPassLowVal IS 1 - lowPassHighVal.
	LOCAL pastVal IS initalVal.
	RETURN {
		PARAMETER newVal.
		SET pastVal TO pastVal * lowPassHighVal + newVal * lowPassLowVal.
		RETURN pastVal.
	}.
}

FUNCTION circ_at_pe {
	LOCAL nodeTime IS TIME:SECONDS + ETA:PERIAPSIS.
	LOCAL rad IS BODY:RADIUS + SHIP:ORBIT:PERIAPSIS.
    LOCAL velAtPE IS SQRT(BODY:MU * (2 / rad - 1 / SHIP:ORBIT:SEMIMAJORAXIS)).
	LOCAL circularVel IS SQRT(BODY:MU / rad).
	RETURN NODE(nodeTime,0,0,circularVel - velAtPE).
}

FUNCTION circ_at_ap {
    LOCAL nodeTime IS TIME:SECONDS + ETA:APOAPSIS.
	LOCAL rad IS BODY:RADIUS + SHIP:ORBIT:APOAPSIS.
    LOCAL velAtAP IS SQRT(BODY:MU * (2 / rad - 1 / SHIP:ORBIT:SEMIMAJORAXIS)).
    LOCAL circularVel IS SQRT(BODY:MU / rad).
    RETURN NODE(nodeTime,0,0,circularVel - velAtAP).
}

FUNCTION circ_node_at {
	PARAMETER atAP.
	LOCAL nodeTime IS TIME:SECONDS + (CHOOSE ETA:APOAPSIS IF atAP ELSE ETA:PERIAPSIS).
	LOCAL radAt IS BODY:RADIUS + CHOOSE SHIP:ORBIT:APOAPSIS IF atAP ELSE SHIP:ORBIT:PERIAPSIS.
	LOCAL spdAt IS VELOCITYAT(SHIP,nodeTime):ORBIT:MAG.
    LOCAL spdAt IS SQRT(BODY:MU * (2 / radAt - 1 / SHIP:ORBIT:SEMIMAJORAXIS)).
	LOCAL circularVel IS SQRT(SHIP:BODY:MU / (radAt)).
	RETURN NODE(nodeTime,0,0,circularVel - spdAt).
}

FUNCTION circularize_at_UT {
  PARAMETER UTs.
  LOCAL localBody IS ORBITAT(SHIP,UTs):BODY.
  LOCAL upVec IS (POSITIONAT(SHIP,UTs) - localBody:POSITION).
  LOCAL vecCurrentVel IS VELOCITYAT(SHIP,UTs):ORBIT.
  LOCAL vecNodePrograde IS vecCurrentVel:NORMALIZED.
  LOCAL vecNodeNormal IS VCRS(vecNodePrograde,upVec:NORMALIZED):NORMALIZED.
  LOCAL vecNodeRadial IS VCRS(vecNodeNormal,vecNodePrograde):NORMALIZED.
  
  LOCAL speedTarget IS SQRT(localBody:MU / upVec:MAG).
  LOCAL vecTarget IS (VXCL(upVec,vecNodePrograde):NORMALIZED * speedTarget) - vecCurrentVel.
  
  LOCAL nodePrograde IS VDOT(vecTarget,vecNodePrograde).
  LOCAL nodeRadial IS VDOT(vecTarget,vecNodeRadial).
  
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

FUNCTION better_write {//verify data is written to a json file
	PARAMETER writePath,writeData.
	WRITEJSON(writePath,writeData).
	IF EXISTS(writePath) {
		LOCAL writtenData IS READJSON(writePath).
		RETURN is_equal(writtenData,writeData).
	} ELSE {
		RETURN FALSE.
	}
}

FUNCTION is_equal {//recursive by value equality test.
	PARAMETER j,k.
	IF j:ISTYPE("lexicon") AND k:ISTYPE("lexicon") {
		FOR key IN j:KEYS {
			IF NOT k:HASKEY(key) {
				RETURN FALSE.
			}
		}
		FOR key IN k:KEYS {
			IF NOT (j:HASKEY(key) AND is_equal(a[key],b[key])){
				RETURN FALSE.
			}
		}
	} ELSE IF j:ISTYPE("enumerable") AND k:ISTYPE("enumerable") {
		IF j:LENGTH = k:LENGTH {
			LOCAL iJ is j:ITERATOR.
			LOCAL iK IS k:ITERATOR.
			UNTIL NOT(iJ:NEXT AND iK:NEXT) {
				IF NOT is_equal(iJ:VALUE,iK:VALUE) {
					RETURN FALSE.
				}
			}
			RETURN TRUE.
		}
	} ELSE IF j:TYPENAME = k:TYPENAME {
		RETURN a = b.
	}
	RETURN FALSE.
}

FUNCTION deep_copy {
	PARAMETER thing, depth IS 5.
	IF depth > 0 {
		IF thing:ISTYPE("Lexicon") {
			LOCAL newLex IS LEX().
				FOR key IN thing:KEYS {
					newLex:ADD(key,deep_copy(thing[key],depth - 1)).
				}
			RETURN newLex.
		} ELSE IF thing:ISTYPE("List") {
			LOCAL newList IS LIST().
				FOR i IN thing {
					newList:ADD(deep_copy(i,depth - 1)).
				}
			RETURN newList.
		} ELSE IF thing:ISTYPE("Queue") {
			LOCAL newQueue IS QUEUE().
			LOCAL i IS thing:ITERATOR.
			UNTIL NOT i:NEXT {
				newQueue:PUSH(deep_copy(i,depth - 1)).
			}
			RETURN newQueue.
		} ELSE IF thing:ISTYPE("Stack") {
			LOCAL newStack IS STACK().
			LOCAL i IS thing:REVERSEITERATOR.
			UNTIL NOT i:NEXT {
				newStack:PUSH(deep_copy(i,depth - 1)).
			}
			RETURN newStack.
		} ELSE IF thing:ISTYPE("Uniqueset") {
			LOCAL newUniqueset IS UNIQUESET().
			LOCAL i IS thing:ITERATOR.
			UNTIL NOT i:NEXT {
				newUniqueset:ADD(deep_copy(i,depth - 1)).
			}
			RETURN newUniqueset.
		}
	}
	RETURN thing.
}

FUNCTION SteeringByGrav {//steering vector for ideal suborbital hop(in theory)
	PARAMETER posVec.//target landing location accounting for body rotation
	
	LOCAL upv IS UP:VECTOR.
	
	LOCAL desiredAcc IS (posVec:NORMALIZED+upv):NORMALIZED.
	LOCAL twr IS MAXTHRUST/(bg*MASS).
	LOCAL sinA IS upv*desiredAcc.
	
	LOCAL mlt is SQRT(twr * twr + sinA * sinA - 1) - sinA.
	RETURN desiredAcc * mlt + upv.
}

FUNCTION static_atm_temp {
	LOCAL jPerKgK IS (CONSTANT:IDEALGAS() / BODY:ATM:MOLARMASS).
	LOCAL atmDencity IS (SHIP:Q * 2) / VELOCITY:SURFACE:SQRMAGNITUDE.
	LOCAL atmTemp IS (BODY:ATM:ALTITUDEPRESSURE(ALTITUDE)) / (jPerKgK * atmDencity).
	RETURN atmTemp.
}

FUNCTION current_mach_number {
	LOCAL currentPresure IS BODY:ATM:ALTITUDEPRESSURE(SHIP:ALTITUDE).
	RETURN CHOOSE SQRT(2 / BODY:ATM:ADIABATICINDEX * SHIP:Q / currentPresure) IF currentPresure > 0 ELSE 0.
}

FUNCTION get_primary {
	PARAMETER startingBody.
	LOCAL tmpBody IS startingBody.
	UNTIL NOT tmpBody:HASBODY {
		SET tmpBody TO tmpBody:BODY.
	}
	RETURN tmpBody.
	
	IF startingBody:HASBODY {
		RETURN get_primary(startingBody:BODY).
	} ELSE {
		RETURN startingBody.
	}
}

FUNCTION kill {
	SET SHIP:CONTROL:TRANSLATION to v(0,0,0).
	SET SHIP:CONTROL:ROTATION to v(0,0,0).
	SET SHIP:CONTROL:PILOTMAINTHROTTLE to 0.
	LOCK THROTTLE to 0.
	LOCK STEERING to "kill".
	UNLOCK THROTTLE.
	UNLOCK STEERING.
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

FUNCTION better_trigger {//an improvement to the builtin when then trigger of kOS
    PARAMETER condition,
    codeBody,
    shouldPersist.
    LOCAL conLex IS LEX().
    conLex:ADD("triggerClear",FALSE).
    conLex:ADD("triggerNotSuspended",TRUE).
    conLex:ADD("triggerPersist",shouldPersist).
    conLex:ADD("triggerAlive",TRUE).

    WHEN conLex:triggerClear OR (conLex:triggerNotSuspended AND condition()) THEN {
        IF conLex:triggerClear {
            SET conLex:triggerAlive TO FALSE.
        } ELSE {
            codeBody().
            IF shouldPersist {
                PRESERVE.
            } ELSE {
                SET conLex:triggerAlive TO FALSE.
            }
        }
    }
    RETURN conLex.
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