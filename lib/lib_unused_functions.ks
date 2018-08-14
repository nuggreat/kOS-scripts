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
	PARAMETER myHeading,myPitch,myRoll.
	LOCAL returnDir IS HEADING(myHeading,myPitch).
	RETURN ANGLEAXIS(myRoll,returnDir:FOREVECTOR) * returnDir.
}


FUNCTION pseudo_throttle {
	PARAMETER throt, tConfig.  //tConfig LIST(LIST(triger level for engine set, list of engines to cycle))
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

FUNCTION altitude_to_time { //returns the UT in seconds of when the orbit reaches the given altitude, returns -1 when target altitude is above/below orbit
	PARAMETER targetAltitude.

	LOCAL returnTime IS -1.
	IF targetAltitude < SHIP:ORBIT:APOAPSIS AND targetAltitude > SHIP:ORBIT:PERIAPSIS {

		LOCAL localBody IS SHIP:BODY.
		LOCAL highPoint IS ETA:APOAPSIS + TIME:SECONDS.
		LOCAL lowPoint IS ETA:PERIAPSIS + TIME:SECONDS.

		IF SHIP:ALTITUDE < targetAltitude AND SHIP:VERTICALSPEED > 0 {
			SET lowPoint TO TIME:SECONDS.
		} ELSE IF SHIP:ALTITUDE > targetAltitude AND SHIP:VERTICALSPEED < 0 {
			SET highPoint TO TIME:SECONDS.
		}

		LOCAL midPoint IS (lowPoint + highPoint) / 2.
		LOCAL midPointAlt IS localBody:ALTITUDEOF(POSITIONAT(SHIP,midPoint)) - targetAltitude.
		UNTIL ABS(midPointAlt) < 1 {
			IF midPointAlt > 0 {
				SET highPoint TO midPoint.
			} ELSE {
				SET lowPoint TO midPoint.
			}
			SET midPoint TO (lowPoint + highPoint) / 2.
			SET midPointAlt TO localBody:ALTITUDEOF(POSITIONAT(SHIP,midPoint)) - targetAltitude.
		}
		SET returnTime TO midPoint.
	}
	RETURN returnTime.
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

FUNCTION pid_debug {
	PARAMETER pidToDebug.
	CLEARSCREEN.
	PRINT "Setpoint: " + ROUND(pidToDebug:SETPOINT,2).
	PRINT "   Error: " + ROUND(pidToDebug:ERROR,2).
	PRINT "       P: " + ROUND(pidToDebug:PTERM,3).
	PRINT "       I: " + ROUND(pidToDebug:ITERM,3).
	PRINT "       D: " + ROUND(pidToDebug:DTERM,3).
	PRINT "     Max: " + ROUND(pidToDebug:MAXOUTPUT,2).
	PRINT "  Output: " + ROUND(pidToDebug:OUTPUT,2).
	PRINT "     min: " + ROUND(pidToDebug:MINOUTPUT,2).
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
        SET altitudeAt TO localBody:ALTITUDEOF(pos) - ground_track(scanTime,pos):TERRAINHEIGHT.
        IF altitudeAt < targetAltitudeLow {
          SET scanTime TO scanTime - stepVal.
          SET pos TO POSITIONAT(SHIP,scanTime).
          SET altitudeAt TO localBody:ALTITUDEOF(pos) - ground_track(scanTime,pos):TERRAINHEIGHT.
          SET stepVal TO stepVal / 2.
        }
      } ELSE IF altitudeAt < targetAltitudeLow {
        SET scanTime TO scanTime - stepVal.
        SET pos TO POSITIONAT(SHIP,scanTime).
        SET altitudeAt TO localBody:ALTITUDEOF(pos) - ground_track(scanTime,pos):TERRAINHEIGHT.
        IF altitudeAt > targetAltitudeHi {
          SET scanTime TO scanTime + stepVal.
          SET pos TO POSITIONAT(SHIP,scanTime).
          SET altitudeAt TO localBody:ALTITUDEOF(pos) - ground_track(scanTime,pos):TERRAINHEIGHT.
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
  PARAMETER posTime,pos.
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

FUNCTION BURN_TIME_CALC{//need to reformat to remove uneeded *1000 elements as well as change var names to make sense to me
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

FUNCTION BURN_DIST_CALC{//need to reformat to remove uneeded *1000 elements as well as change var names to make sense to me
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

FUNCTION wait_until_steering_aligned {//wait until steering is aligned with what it is locked to
	PARAMETER careAboutRoll IS FALSE, steadyTime IS 10, maxError IS 1.
	LOCAL resumeTime IS TIME:SECONDS + steadyTime.
	LOCK steerError TO ABS(STEERINGMANAGER:ANGLEERROR).
	IF careAboutRoll {
		LOCK steerError TO ABS(STEERINGMANAGER:ANGLEERROR) + ABS(STEERINGMANAGER:ROLLERROR).
	}
	UNTIL resumeTime < TIME:SECONDS {
		IF steerError > maxError {
			SET resumeTime TO TIME:SECONDS + steadyTime.
		}
		WAIT 0.
		CLEARSCREEN.
		PRINT "error: " + ROUND(steerError,2).
		PRINT "alignment done in: " + ROUND(resumeTime - TIME:SECONDS,2) + "s".
	}
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
	LOCAL LFamount IS 0.
	LOCAL LFcapacity IS 0.
	FOR tank IN SHIP:PARTSTAGGED(tankTag) {
		FOR res IN tank:RESOURCES {
			IF res:NAME = resName {
				SET LFamount TO LFamount + res:AMOUNT.
				SET LFcapacity TO LFcapacity + res:CAPACITY.
			}
		}
	}
	RETURN ((LFamount * 100) / LFcapacity).
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
				tag_docking_ports(child,nameTag,FALSE).
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

FUNCTION number_concatnation {
	PARAMETER char,string.
	LOCAL returnString TO string.
	IF LIST("0","1","2","3","4","5","6","7","8","9","-","."):CONTAINS(char) {
		IF LIST("0","1","2","3","4","5","6","7","8","9"):CONTAINS(char) {
			RETURN returnString + char.
		} ELSE IF char = "-" {
			IF returnString:CONTAINS("-"){
				returnString:REMOVE(0).
				RETURN returnString.
			} ELSE {
				RETURN char + returnString.
			}
		} ELSE IF char = "." {
			IF returnString:CONTAINS(".")
				RETURN returnString.
			} ELSE {
				RETURN returnString + char.
			}
		}
	} ELSE IF (char = TERMINAL:INPUT:BACKSPACE) AND (returnString:LENGTH > 0)  {
		RETURN returnString:REMOVE(returnString:LENGTH - 1).
	} ELSE {
		RETURN returnString.
	}
}