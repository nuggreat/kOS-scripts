PARAMETER targetAP IS 26,doInclined IS FALSE,targetInclination IS 0,skipConfirm IS FALSE.
FOR lib IN LIST("lib_navball2","lib_rocket_utilities","lib_formating","lib_warp_control") { IF EXISTS("1:/lib/" + lib + ".ksm") { RUNPATH("1:/lib/" + lib + ".ksm"). } ELSE { RUNPATH("1:/lib/" + lib + ".ks"). }}
SET targetAP TO targetAP * 1000.
LOCAL northReff IS LATLNG(90,0).
SAS OFF.
ABORT OFF.
CLEARSCREEN.
LOCAL targetVspeed IS 50.
//kp,ki,kd,min,max
LOCAL ascentThrottlePID IS PIDLOOP(1,0.1,0.01,0.01,1).
LOCAL circThrottlePID IS PIDLOOP(1,0.1,0.01,0.001,1).

LOCAL targetPitch IS 90.
LOCAL targetHeading IS 90.
LOCAL rangeScanDuration IS 120000 / CONFIG:IPU.
LOCAL rangeSafty IS 2.5.//the increase to the base range for fixed inclination launches
LOCAL rangeData IS LEX().//to store the results of the range scan
LOCAL LANdata IS LAN_calculations(targetInclination).
LOCAL doLaunch IS TRUE.
//SET CONFIG:IPU TO 2000.
IF doInclined {
	IF targetInclination:ISTYPE("scalar") {
		LOCAL launchRange IS launch_range(targetInclination,targetAP,rangeSafty).
		SET targetHeading TO launchRange["launchAz"].
		SET rangeData TO range_scan(launchRange).
		SET LANdata TO LAN_calculations(targetInclination).//recalculation needed because of duration of scan
	} ELSE {
		LOCAL targetOrbit IS targetInclination.
		IF targetOrbit:ISTYPE("vessel") {
			SET targetOrbit TO targetOrbit:ORBIT.
		}
		IF LANdata["canReach"] { SET rangeScanDuration TO rangeScanDuration * 2. }

		LOCAL leadTime IS burn_duration(isp_calc(),speed_given_ap((SHIP:ALTITUDE + BODY:RADIUS),targetAP)).
		LOCAL crossEstimates IS UTs_of_orbit_cross(targetOrbit,leadTime + rangeScanDuration).
		LOCAL crossTimes IS UTs_of_orbit_cross(targetOrbit,leadTime).

		LOCAL crossTime IS crossTimes[0].
		LOCAL warpPrintHeight IS 5.

		IF LANdata["canReach"] {
			LOCAL launchMode IS user_ui(0,crossEstimates,skipConfirm).
			LOCAL northRangeData IS LEX().
			LOCAL southRangeData IS LEX().
			IF launchMode = 1 OR launchMode = 0 {
				LOCAL launchRangeNorth IS launch_range(targetOrbit:INCLINATION,targetAP,rangeSafty).
				SET northRangeData TO range_scan(launchRangeNorth,0,"North Launch Window Analysis:",FALSE).
			}
			IF (launchMode = 2) OR (launchMode = 0) {
				LOCAL launchRangeSouth IS launch_range(-targetOrbit:INCLINATION,targetAP,rangeSafty).
				SET southRangeData TO range_scan(launchRangeSouth,1,"South Launch Window Analysis:",TRUE).
			}
			IF launchMode = 1 OR ((launchMode = 0) AND (northRangeData["slope"] <= southRangeData["slope"])) {
				SET rangeData TO northRangeData.
				rangeData:ADD("isNorth",TRUE).
				PRINT "Launching to the North".
			} ELSE IF launchMode <> 3 {
				SET rangeData TO southRangeData.
				rangeData:ADD("isNorth",FALSE).
				PRINT "Launching to the South".
				SET crossTime TO crossTimes[1].
			} ELSE {
				SET doLaunch TO FALSE.
			}
		} ELSE {
			LOCAL launchMode IS user_ui(1,crossEstimates,skipConfirm).
			IF launchMode = 0 {
				LOCAL launchRange IS launch_range(targetOrbit:INCLINATION,targetAP,rangeSafty).
				SET rangeData TO range_scan(launchRange,0,"Launch Window Analysis: ").
				rangeData:ADD("isNorth",TRUE).
				SET warpPrintHeight TO 3.
			} ELSE {
				SET doLaunch TO FALSE.
			}
		}

		SET crossTime TO crossTime.
		IF (crossTime - TIME:SECONDS) < 0 { SET crossTime TO crossTime + BODY:ROTATIONPERIOD. }
		PRINT " Launch Window in: ".

		IF doLaunch {
			LOCAL warpConObj IS warp_control_init(2).
			UNTIL (crossTime - TIME:SECONDS) < 0.1 {
				LOCAL crossETA IS crossTime - TIME:SECONDS.
				warpConObj["execute"]:CALL(crossETA - 10).
				PRINT time_formating(-crossETA,0,0,TRUE) + "     " AT(19,warpPrintHeight).
				WAIT 0.
			}
		}
	}
} ELSE {//follow the 90 degree heading if no inclination is specified
	WHEN ALT:RADAR > 100 THEN { GEAR OFF. LOCK STEERING TO HEADING(heading_of_vector(SHIP:VELOCITY:ORBIT),targetPitch). }//delay prograde following to improve launch for launches from a place with a high slope
	LOCAL ts IS TIME:SECONDS.
	LOCAL launchRange IS launch_range(0,targetAP,rangeSafty).
	SET rangeData TO range_scan(launchRange,0,"Launch Range Analysis: ").
	PRINT TIME:SECONDS - ts.
}

IF doLaunch {
LOCAL launchSlope IS rangeData["slope"].
LOCAL slopeHigh IS rangeData["highest"].
LOCK STEERING TO HEADING(targetHeading,targetPitch).
LOCAL throt IS 0.
LOCK THROTTLE TO throt.
IF GEAR {
	GEAR OFF.
	WAIT 0.
	DEPLOYDRILLS OFF.
	WAIT 0.
}

LOCAL bodyMU IS SHIP:BODY:MU.

LOCAL slopeAcc IS 0.
LOCAL tgtVspd IS 0.
UNTIL APOAPSIS > targetAP {//launch
	LOCAL radVec IS BODY:POSITION - SHIP:POSITION.
	LOCAL shipAcc IS MAX(SHIP:AVAILABLETHRUST/SHIP:MASS,0.00001).//the max is a catch for a no thrust case to prevent divide by 0 crash
	LOCAL shipVel IS SHIP:VELOCITY:ORBIT.
	LOCAL shipHorVel IS VXCL(UP:VECTOR,shipVel).
	LOCAL shipVertSpd IS SHIP:VERTICALSPEED.
	
	LOCAL localGrav IS bodyMU / radVec:SQRMAGNITUDE.
	LOCAL centrifugalAcc IS shipHorVel:SQRMAGNITUDE / radVec:MAG.
	LOCAL compositGrav IS localGrav - centrifugalAcc.
	LOCAL altAcc IS shipAcc * MAX(1 - ((ALT:RADAR - 25)/100),0).//must have a minimum altitude before pitch over can happen
	
	IF ALTITUDE < slopeHigh {
		//slopeAcc equation derives from the a^2 + b^2 = c^2 relationship with c = shipAcc, a = grav + requiredVertAcc and b = requiredVertAcc / slope
		//this is done to account require a minimum slope to the launch angle as calculated by
		LOCAL tmpVal IS launchSlope^2 + 1.
		SET slopeAcc TO launchSlope / tmpVal * (SQRT(tmpVal * shipAcc^2 - compositGrav^2) - launchSlope * compositGrav).
		SET tgtVspd TO launchSlope * shipHorVel:MAG.
	} ELSE {
		SET slopeAcc TO 0.
		SET tgtVspd TO localGrav.
	}
	LOCAL vertCorrec IS MIN(MAX(((tgtVspd - shipVertSpd) / 10),-localGrav),shipAcc).// calculates a correction to apply to vertAcc so the vertical velocity matches tgtVspd
	
	LOCAL vertAcc IS MAX(compositGrav + slopeAcc + vertCorrec,altAcc).
	LOCAL tgtSpeed IS speed_given_ap(radVec:MAG,targetAP).
	SET ascentThrottlePID:SETPOINT TO tgtSpeed / shipAcc.
	SET throt TO ascentThrottlePID:UPDATE(TIME:SECONDS,shipVel:MAG/shipAcc).
	SET targetPitch TO MAX(ARCSIN(MIN(1,vertAcc/shipAcc)),0).
	IF doInclined {
		SET targetHeading TO azimuth(LANdata["LAN"],LANdata["inc"],targetAP).
	} ELSE {
		SET targetHeading TO CHOOSE 90 IF ALT:RADAR < 100 ELSE heading_of_vector(PROGRADE:VECTOR).
	}
	WAIT 0.
	CLEARSCREEN.
	PRINT "tpitch: " + ROUND(targetPitch,3).
	PRINT "acc: " + ROUND(shipAcc,3).
	PRINT "vertAcc: " + ROUND(vertAcc,3).
	PRINT "localGrav: " + ROUND(localGrav,3).
	PRINT "centrifugalAcc: " + ROUND(centrifugalAcc,3).
	PRINT "slopeAcc: " + ROUND(slopeAcc,3).
	PRINT "vertCorrect: " + ROUND(vertCorrec,3).
	PRINT "vSpeed: " + ROUND(shipVertSpd,3).
	PRINT "ap: " + ROUND(APOAPSIS).
	PRINT "throttle error: " + ROUND(ascentThrottlePID:ERROR,3).
	PRINT "throttle Val: " + ROUND(throt,3).
}
LOCK THROTTLE TO 0.

LOCK STEERING TO PROGRADE.
WAIT 0.
SET circThrottlePID:SETPOINT TO 0.
SET throt TO 0.
WHEN throt > 0.1 THEN { LOCK THROTTLE TO throt. }
LOCAL currentISP IS isp_calc().
LOCAL warpConObj IS warp_control_init(2).
LOCAL bodyMU IS BODY:MU.
LOCAL bodyRad IS BODY:RADIUS.
LOCAL done IS FALSE.
UNTIL done {//assumes only a single stage is needed for circularization
	LOCAL apRad IS (SHIP:ORBIT:APOAPSIS + bodyRad).
	LOCAL SMA IS SHIP:ORBIT:SEMIMAJORAXIS.
	LOCAL circVel IS SQRT(bodyMU / apRad).
	LOCAL currentAPspd IS SQRT((bodyMU * (2 * SMA - apRad)) / (SMA * apRad)).
	LOCAL burnDv IS circVel - currentAPspd.
	LOCAL etaAP IS signed_eta_ap().
	LOCAL burnDuration IS burn_duration(currentISP,burnDv) + 1.
	SET circThrottlePID:SETPOINT TO burnDuration.
	SET throt TO circThrottlePID:UPDATE(TIME:SECONDS,etaAP).
	WAIT 0.
	CLEARSCREEN.
	IF warpConObj["execute"]:CALL(etaAP - 30 - burnDuration) AND burnDv < (SHIP:AVAILABLETHRUST / (SHIP:MASS * 100)) {
		SET done TO TRUE.
	}
	PRINT "burnDv: " + ROUND(burnDv,2).
	PRINT "eta ap: " + ROUND(etaAP,2).
	PRINT "eta target: " + ROUND(burnDuration,2).
}
LOCK THROTTLE TO 0.
LOCK STEERING TO "kill".
}

FUNCTION user_ui {
	PARAMETER launchType,launchTimes,skipConfirm.
	LOCAL launchMode IS 0.
	IF launchType = 0 {
		PRINT "North Launch Window: ".
		PRINT "South Launch Window: ".
		PRINT "Launch Mode: ".
		PRINT " ".
		LOCAL modeMap IS LIST("Least Dv Launch","North Launch","South Launch","Abort Launch").
		SET launchMode TO user_input(modeMap,launchTimes,21,2,skipConfirm).
		IF launchMode = 0 {
			PRINT " Analysis: 00.000%  ":PADRIGHT(TERMINAL:WIDTH - 19) AT(19,1).
		} ELSE IF launchMode = 1 {
			PRINT "Rejected      ":PADRIGHT(TERMINAL:WIDTH - 21) AT(21,1).
		} ELSE IF launchMode = 2 {
			PRINT "Rejected      ":PADRIGHT(TERMINAL:WIDTH - 21) AT(21,0).
		}
	} ELSE IF launchType = 1 {
		PRINT "Launch Window: ".
		PRINT "Launch Mode: ".
		PRINT " ".
		LOCAL modeMap IS LIST("Initiate Launch","Abort Launch").
		launchTimes:REMOVE(1).
		SET launchMode TO user_input(modeMap,launchTimes,15,1,skipConfirm).
	} ELSE IF launchType = 2 {
		PRINT "Launch Mode: ".
		PRINT " ".
		LOCAL modeMap IS LIST("Initiate Launch","Abort Launch").
		SET launchMode TO user_input(modeMap,launchTimes,15,0,skipConfirm).
		IF launchMode = 0 { PRINT "Pre Launch". }
	}
	RETURN launchMode.
}

FUNCTION user_input {
	PARAMETER modeMap,launchTimes,timePos,modePos,skipConfirm.
	LOCAL launchMode IS 0.
	LOCAL longest IS 0.

	FOR str IN modeMap {
		SET longest TO MAX(longest,str:LENGTH).
	}

	SAS OFF.
	PRINT "Toggle SAS to select current mode." AT(0,2 + modePos).
	PRINT "Toggle RCS to change current mode." AT(0,3 + modePos).
	PRINT modeMap[launchMode]:PADRIGHT(longest) AT(13,modePos).
	UNTIL SAS OR skipConfirm {
		IF RCS {
			RCS OFF.
			SET launchMode TO MOD(launchMode + 1,modeMap:LENGTH).
			PRINT modeMap[launchMode]:PADRIGHT(longest) AT(13,modePos).
		}
		LOCAL i IS 0.
		FOR launchTime IN launchTimes {
			PRINT time_formating(TIME:SECONDS - launchTime,0,0,TRUE) + "     " AT(timePos,i).
			SET i TO i + 1.
		}
		WAIT 0.
	}
	SAS OFF.
	PRINT " ":PADRIGHT(TERMINAL:WIDTH) AT(0,2 + modePos).
	PRINT " ":PADRIGHT(TERMINAL:WIDTH) AT(0,3 + modePos).
	RETURN launchMode.
}

FUNCTION LAN_calculations {//calculate the information needed for the azimuth calculation
	PARAMETER targetThing.
	LOCAL myLng IS SHIP:GEOPOSITION:LNG.
	LOCAL myLat IS SHIP:GEOPOSITION:LAT.
	IF targetThing:ISTYPE("vessel") {
		SET targetThing TO targetThing:ORBIT.
	}
	IF targetThing:ISTYPE("scalar")  {
		LOCAL tarInc IS targetThing.
		LOCAL isNorth IS FALSE.
		IF myLat < 0 {
			SET myLng TO myLng + 180.
			SET isNorth TO TRUE.
		}

		IF ABS(myLat) > ABS(tarInc) {//checks that target inclination can be reached
			LOCAL trueLAN IS MOD(myLng - 90 + BODY:ROTATIONANGLE + 720,360).
			RETURN LEX("lan",trueLAN,"inc",ABS(myLat),"canReach",FALSE,"isNorth",TRUE).
		} IF ABS(myLat) > (180 - ABS(tarInc)) {
			LOCAL trueLAN IS MOD(myLng + 90 + BODY:ROTATIONANGLE + 720,360).
			RETURN LEX("lan",trueLAN,"inc",180 - ABS(myLat),"canReach",FALSE,"isNorth",TRUE).
		} ELSE {
			LOCAL equitoralLng IS ARCSIN(MAX(MIN(TAN(myLat) / TAN(tarInc),1),-1)).
			LOCAL tarLAN IS CHOOSE myLng - equitoralLng IF tarInc <= 0 ELSE (myLng + equitoralLng) + 180.

			LOCAL trueLAN IS MOD(tarLAN + BODY:ROTATIONANGLE + 720,360).

			RETURN LEX("lan",trueLAN,"inc",ABS(tarInc),"canReach",TRUE,"isNorth",isNorth).
		}
	} ELSE {
		LOCAL tarInc IS targetThing:INCLINATION.
		IF (tarInc > ABS(myLat)) AND (ABS(myLat) < (180 - tarInc)) {//check that target orbital plane can be reached
			RETURN LEX("lan",targetThing:LAN,"inc",tarInc,"canReach",TRUE,"isNorth",TRUE).
		} ELSE {
			RETURN LEX("lan",targetThing:LAN,"inc",LAN_calculations(tarInc)["inc"],"canReach",FALSE,"isNorth",TRUE).
		}
	}
}

FUNCTION azimuth {
	PARAMETER targetLAN,targetInc,targetAP,headingOfDiff IS TRUE.
	LOCAL sufaceLAN IS targetLAN - BODY:ROTATIONANGLE.//lan converted to a surface longitude

	LOCAL lanVec IS (LATLNG(0,sufaceLAN):POSITION - BODY:POSITION):NORMALIZED.//vector pointing to the LAN
	//LOCAL targetNormal IS ANGLEAXIS(-targetInc,lanVec) * (LATLNG(-90,0):POSITION - BODY:POSITION):NORMALIZED.//computing the normal vector of the desired orbit
	LOCAL targetNormal IS ANGLEAXIS(-targetInc,lanVec) * -(northReff:POSITION - BODY:POSITION):NORMALIZED.//computing the normal vector of the desired orbit
	LOCAL radVec IS SHIP:POSITION - BODY:POSITION.//current radius as a vector
	LOCAL currentVel IS SHIP:VELOCITY:ORBIT.

	LOCAL targetSpeed IS MAX(speed_given_ap(radVec:MAG,targetAP),currentVel:MAG + 1).//calculating speed at current radius to reach given AP with current PE, also has MAX call so that said speed is always 1 m/s greater than currentVel

	LOCAL targetVel IS VCRS(targetNormal,radVec:NORMALIZED):NORMALIZED * targetSpeed.//desired velocity vector
	SET currentVel TO VXCL(UP:VECTOR,currentVel):NORMALIZED * currentVel:MAG.//current velocity flattened to match targetVel
	LOCAL difVec IS targetVel - currentVel.//difference
	IF headingOfDiff {
		RETURN heading_of_vector(difVec).
	} ELSE {
		RETURN heading_of_vector(targetVel).
	}
}

FUNCTION speed_given_ap {
	PARAMETER currentRad,ap.
	LOCAL sma IS (PERIAPSIS + ap) / 2 + BODY:RADIUS.
	RETURN SQRT((BODY:MU * (2 * sma - currentRad)) / (sma * currentRad)).
}

FUNCTION launch_range {
	PARAMETER tarInc,targetAP,rangeSafty.
	LOCAL LANdata IS LAN_calculations(tarInc).
	LOCAL targetHeading IS azimuth(LANdata["LAN"],LANdata["inc"],targetAP).
	LOCAL launchRange IS ABS(targetHeading - azimuth(LANdata["LAN"],LANdata["inc"],targetAP,FALSE)).	//the range over which the craft might fly relative to the targetHeading
	SET launchRange TO MOD(launchRange + rangeSafty + 360,360).
	RETURN LEX("launchAz",targetHeading,"arc",launchRange,"inc",CHOOSE LANdata["inc"] IF LANdata["isNorth"] ELSE -LANdata["inc"]).
}

FUNCTION range_scan {
	PARAMETER launchData,printHeight IS 0,printPrefix IS "",scanSouth IS FALSE.
	//LOCAL startTime IS TIME:SECONDS.

	LOCAL myLng IS SHIP:GEOPOSITION:LNG.
	LOCAL myLat IS SHIP:GEOPOSITION:LAT.
	LOCAL startHeight IS SHIP:GEOPOSITION:TERRAINHEIGHT.
	IF myLat < 0 { SET myLng TO myLng + 180. }
	LOCAL halfCirc IS (BODY:RADIUS + startHeight) * CONSTANT:PI().//1/2 the circumference of the body
	LOCAL distToDegConstant IS 180 / halfCirc.
	LOCAL degToDistConstant IS halfCirc / 180.

	LOCAL arcRotStart IS - launchData["arc"].
	LOCAL arcRotEnd IS launchData["arc"].
	LOCAL arcRotStep IS 0.2.

	LOCAL maxDist IS halfCirc / 5.
	LOCAL distStep IS 250.
	LOCAL maxDeg IS 36.// will be 1/10th of body circumference for each arc
	LOCAL degStep IS 250 * distToDegConstant.//step in degrees, base of 250m

	LOCAL slope IS 0.
	LOCAL posDist IS 0.
	LOCAL highest IS startHeight.
	LOCAL totalSteps IS CEILING((arcRotEnd - arcRotStart) / arcRotStep).
	LOCAL tarInc IS launchData["inc"].
	LOCAL equitoralLng IS ARCSIN(MAX(MIN(TAN(myLat) / TAN(tarInc),1),-1)).
	LOCAL sufaceLAN IS CHOOSE myLng - equitoralLng IF tarInc <= 0 ELSE (myLng + equitoralLng) + 180.
	LOCAL lanGeoPos IS LATLNG(0,sufaceLAN).
	IF scanSouth {
		SET tarInc TO -tarInc.
	}
	// SET vd TO VECDRAW(BODY:POSITION,(SHIP:POSITION - BODY:POSITION) * 1.1,RED,"",1,TRUE,1).
	
	//the scan arcs are derived from the desired launch orbit
	//scans the projected launch range to determine the steepest slope
	//arcRot loop determines the angle along which to scan
	//deg loop is what scans the given angle out to the maxDeg distance
	FROM { LOCAL arcRot IS arcRotStart. } UNTIL arcRot > arcRotEnd STEP { SET arcRot TO arcRot + arcRotStep. } DO {

		LOCAL ts IS TIME:SECONDS.
		LOCAL lanVec IS (lanGeoPos:POSITION - BODY:POSITION):NORMALIZED.//vector pointing to the LAN
		LOCAL radVec IS (SHIP:POSITION - BODY:POSITION):NORMALIZED.
		LOCAL arcNormal IS ANGLEAXIS(arcRot,radVec) * (ANGLEAXIS(tarInc,lanVec) * V(0,-1,0)).//computing the normal to the arc to scan along

		LOCAL outerProg IS ROUND((arcRot - arcRotStart) / (arcRotStep)) / totalSteps.//percentage progress of outer loop
		PRINT (printPrefix + padding((outerProg * 100),2,3) + "%"):PADRIGHT(TERMINAL:WIDTH) AT(0,printHeight).

		LOCAL threshold IS startHeight.
		FROM { LOCAL deg IS degStep. } UNTIL deg > maxDeg STEP { SET deg TO deg + degStep. } DO {
			IF TIME:SECONDS > ts {//only recalculate the vectors when there is a physics tick
				SET ts TO TIME:SECONDS.
				SET lanVec TO (lanGeoPos:POSITION - BODY:POSITION):NORMALIZED.//vector pointing to the LAN
				// SET vd:START TO BODY:POSITION.
				SET radVec TO (SHIP:POSITION - BODY:POSITION).
				SET arcNormal TO ANGLEAXIS(arcRot,radVec) * (ANGLEAXIS(tarInc,lanVec) * V(0,-1,0)).//computing the normal to the arc to scan along
			}
			
			// LOCAL geoPos IS BODY:GEOPOSITIONOF(ANGLEAXIS(deg,arcNormal) * radVec - radVec).
			// LOCAL newPosHeight IS geoPos:TERRAINHEIGHT.
			// SET vd:VECTOR TO (geoPos:POSITION - BODY:POSITION) * 1.1.
			LOCAL newPosHeight IS BODY:GEOPOSITIONOF(ANGLEAXIS(deg,arcNormal) * radVec - radVec):TERRAINHEIGHT.
			IF newPosHeight > highest {
				SET highest TO newPosHeight.
			}
			//SET highest TO MAX(newPosHeight,highest).
			IF newPosHeight > threshold {
				LOCAL dist IS deg * degToDistConstant.
				IF ((newPosHeight - startHeight) / dist) > slope {
					SET slope TO (newPosHeight - startHeight) / dist.
					SET posDist TO dist.
				}
				SET threshold TO slope * dist + startHeight.
			}
		}
	}
	PRINT (printPrefix + padding(100,2,2) + "%"):PADRIGHT(TERMINAL:WIDTH) AT(0,printHeight).
	//PRINT TIME:SECONDS - startTime.
	RETURN LEX("highest",highest,"slope",slope,"dist",posDist).
}

FUNCTION UTs_of_orbit_cross {//returns the UTs of when the craft can launch into the orbital plane
	PARAMETER tgtOrbit,leadTime.
	WAIT 0.
	LOCAL tarInc IS tgtOrbit:INCLINATION.
	LOCAL tarLan IS tgtOrbit:LAN - tgtOrbit:BODY:ROTATIONANGLE.
	LOCAL startTime IS TIME:SECONDS.
	LOCAL myLat IS SHIP:GEOPOSITION:LAT.
	LOCAL myLng IS SHIP:GEOPOSITION:LNG.

	IF tarInc < ABS(myLat) {
		IF myLat > 0 {
			SET myLat TO tarInc.
		} ELSE {
			SET myLat TO -tarInc.
		}
	}
	LOCAL baseLng IS ARCSIN(MAX(MIN(TAN(myLat) / TAN(tarInc),1),-1)).
	LOCAL northCross IS baseLng + tarLan.//will be the longitude of the crossing point, with a velocity going more north (AN)
	LOCAL southCross IS (tarLan - 180) - baseLng.//will be the longitude of the crossing point, with a velocity going more south (DN)
	RETURN LIST(cross_point_to_UTs(startTime,northCross,myLng,leadTime),cross_point_to_UTs(startTime,southCross,myLng,leadTime)).
}

FUNCTION cross_point_to_UTs {//calculates the time to the given crossing point
	PARAMETER startTime,targetLng,currentLng,leadTime.
	LOCAL lngDiff IS (CHOOSE (targetLng - currentLng) IF VDOT(BODY:ANGULARVEL,V(0,1,0)) < 0 ELSE (currentLng - targetLng)).
	LOCAL timeDiff IS MOD(lngDiff + 360,360) * (BODY:ROTATIONPERIOD / 360) - leadTime.
	IF timeDiff < 0 { SET timeDiff TO timeDiff + BODY:ROTATIONPERIOD. }
	RETURN timeDiff + startTime.
}