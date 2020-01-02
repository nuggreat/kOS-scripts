//NOTE: launch from a steep slope may mess up clearance calculation and cause a crash during launch
PARAMETER targetAP IS 26,doInclined IS FALSE,targetInclination IS 0,skipConfirm IS FALSE.
FOR lib IN LIST("lib_navball2","lib_rocket_utilities","lib_formating","lib_warp_control") { IF EXISTS("1:/lib/" + lib + ".ksm") { RUNPATH("1:/lib/" + lib + ".ksm"). } ELSE { RUNPATH("1:/lib/" + lib + ".ks"). }}
SET targetAP TO targetAP * 1000.
SAS OFF.
ABORT OFF.
CLEARSCREEN.
LOCAL targetVspeed IS 50.
//kp,ki,kd,min,max
LOCAL ascentThrottlePID IS PIDLOOP(1,0.1,0.01,0.01,1).
LOCAL circThrottlePID IS PIDLOOP(1,0.1,0.01,0.001,1).

LOCAL targetPitch IS 90.
LOCAL targetHeading IS 90.
LOCAL rangeScanDuration IS 96000 / CONFIG:IPU.
LOCAL rangeSafty IS 2.5.//the increase to the base range for fixed inclination launches
LOCAL rangeData IS LEX().//to store the results of the range scan
LOCAL LANdata IS LAN_calculations(targetInclination).
LOCAL doLaunch IS TRUE.
IF doInclined {
	IF targetInclination:ISTYPE("scalar") {
		LOCAL launchRange IS launch_range(LANdata,targetAP,rangeSafty).
		SET targetHeading TO launchRange["launchAz"].
		SET rangeData TO range_scan(targetHeading,launchRange["arc"]).
		SET LANdata TO LAN_calculations(targetInclination).//recalculation needed because of duration of scan
	} ELSE {
		LOCAL targetOrbit IS targetInclination.
		IF targetOrbit:ISTYPE("vessel") {
			SET targetOrbit TO targetOrbit:ORBIT.
		}
		IF LANdata["canReach"] { SET rangeScanDuration TO rangeScanDuration * 2. }

		LOCAL leadTime IS burn_duration(isp_calc(),speed_given_ap((SHIP:ALTITUDE + BODY:RADIUS),targetAP)).
		LOCAL crossEstimates IS UTs_of_orbit_cross(SHIP:GEOPOSITION:LAT,targetOrbit,leadTime + rangeScanDuration).
		LOCAL crossTimes IS UTs_of_orbit_cross(SHIP:GEOPOSITION:LAT,targetOrbit,leadTime).

		LOCAL crossTime IS crossTimes[0].
		LOCAL warpPrintHeight IS 4.

		IF LANdata["canReach"] {
			LOCAL launchMode IS user_ui(0,crossEstimates,skipConfirm).
			IF launchMode = 0 {
				LOCAL launchRangeNorth IS launch_range(LAN_calculations(targetOrbit:INCLINATION),targetAP,rangeSafty).
				LOCAL northRangeData IS range_scan(launchRangeNorth["launchAz"],launchRangeNorth["arc"],0,"North Launch Window Analysis: ").
				LOCAL launchRangeSouth IS launch_range(LAN_calculations(-targetOrbit:INCLINATION),targetAP,rangeSafty).
				LOCAL southRangeData IS range_scan(launchRangeSouth["launchAz"],launchRangeSouth["arc"],1,"South Launch Window Analysis: ").
				IF northRangeData["slope"] < southRangeData["slope"] {
					SET rangeData TO northRangeData.
					rangeData:ADD("isNorth",TRUE).
					PRINT "Launching to the North".
				} ELSE {
					SET rangeData TO southRangeData.
					rangeData:ADD("isNorth",FALSE).
					PRINT "Launching to the South".
					SET crossTime TO crossTimes[1].
				}
				SET warpPrintHeight TO 5.
			} ELSE IF launchMode = 1 {
				LOCAL launchRange IS launch_range(LAN_calculations(targetOrbit:INCLINATION),targetAP,rangeSafty).
				SET rangeData TO range_scan(launchRange["launchAz"],launchRange["arc"],0,"North Launch Window Analysis: ").
				rangeData:ADD("isNorth",TRUE).
			} ELSE IF launchMode = 2 {
				LOCAL launchRangeSouth IS launch_range(LAN_calculations(-targetOrbit:INCLINATION),targetAP,rangeSafty).
				SET rangeData TO range_scan(launchRangeSouth["launchAz"],launchRangeSouth["arc"],1,"South Launch Window Analysis: ").
				rangeData:ADD("isNorth",FALSE).
				SET crossTime TO crossTimes[1].
			} ELSE {
				SET doLaunch TO FALSE.
			}
		} ELSE {
			LOCAL launchMode IS user_ui(1,crossEstimates,skipConfirm).
			IF launchMode = 0 {
				LOCAL launchRange IS launch_range(LAN_calculations(targetOrbit:INCLINATION),targetAP,rangeSafty).
				SET rangeData TO range_scan(targetHeading,launchRange["arc"],0,"Launch Window Analysis: ").
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
			WARPTO(crossTime - 10).
			UNTIL (crossTime - TIME:SECONDS) < 0.1 {
				PRINT time_formating(TIME:SECONDS - crossTime,0,0,TRUE) + "     " AT(19,warpPrintHeight).
				WAIT 0.
			}
		}
	}
} ELSE {//follow the 90 degree heading if no inclination is specified
	//LOCAL launchMode IS user_ui(2,LIST(),skipConfirm).
	WHEN ALT:RADAR > 100 THEN { GEAR OFF. LOCK STEERING TO HEADING(heading_of_vector(SHIP:VELOCITY:ORBIT),targetPitch). }//delay prograde following to improve launch for launches from a place with a high slope
	LOCAL ts IS TIME:SECONDS.
	SET rangeData TO range_scan(targetHeading,rangeSafty * 2,0,"Launch Range Analysis: ").
	PRINT TIME:SECONDS - ts.
}

IF doLaunch {
LOCAL rangeClearence IS rangeData["slope"] + 0.01.
LOCK STEERING TO HEADING(targetHeading,targetPitch).
LOCAL throt IS 0.
LOCK THROTTLE TO throt.
IF GEAR {
	GEAR OFF.
	WAIT 0.
	DEPLOYDRILLS OFF.
	WAIT 0.
}

UNTIL APOAPSIS > targetAP {//launch
	LOCAL radVec IS BODY:POSITION - SHIP:POSITION.
	LOCAL shipAcc IS MAX(SHIP:AVAILABLETHRUST/SHIP:MASS,0.00001).//the max is a catch for a no thrust case to prevent divide by 0 crash
	LOCAL localGrav IS BODY:MU / radVec:SQRMAGNITUDE.
	LOCAL shipVel IS SHIP:VELOCITY:ORBIT.
	LOCAL centrifugalAcc IS VXCL(UP:VECTOR,shipVel):SQRMAGNITUDE / radVec:MAG.
	LOCAL altError IS (shipAcc - (localGrav - centrifugalAcc)) * MAX(1 - ((ALT:RADAR - 50)/100),rangeClearence).// added to compositGrav to force clearance of a given slope
	LOCAL compositGrav IS MAX(localGrav - centrifugalAcc + altError,0).
	SET ascentThrottlePID:SETPOINT TO speed_given_ap(radVec:MAG,targetAP)/shipAcc.
	SET throt TO ascentThrottlePID:UPDATE(TIME:SECONDS,shipVel:MAG/shipAcc).
	SET targetPitch TO MAX(ARCSIN(MIN(1,compositGrav/shipAcc)),0).
	IF doInclined {
		SET targetHeading TO azimuth(LANdata["LAN"],LANdata["inc"],targetAP).
	}
	WAIT 0.
	CLEARSCREEN.
	PRINT "tpitch: " + ROUND(targetPitch,2).
	PRINT "comGrav: " + ROUND(compositGrav,2).
	PRINT "acc: " + ROUND(shipAcc,2).
	PRINT "localGrav: " + ROUND(localGrav,2).
	PRINT "centrifugalAcc: " + ROUND(centrifugalAcc,2).
	PRINT "altError: " + ROUND(altError,2).
	PRINT "vSpeed: " + ROUND(SHIP:VERTICALSPEED,2).
	PRINT "ap: " + ROUND(APOAPSIS).
	PRINT "throttle error: " + ROUND(ascentThrottlePID:ERROR,2).
	PRINT "throttle Vale: " + ROUND(throt,2).
}
LOCK THROTTLE TO 0.

LOCK STEERING TO PROGRADE.
WAIT 0.
SET circThrottlePID:SETPOINT TO 0.
SET throt TO 0.
WHEN throt > 0.1 THEN { LOCK THROTTLE TO throt. }
LOCAL currentISP IS isp_calc().
LOCAL warpConObj IS warp_control_init(2).
LOCAL done IS FALSE.
UNTIL done {//assumes only a single stage is needed for circularization
	LOCAL circVel IS SQRT(BODY:MU / (SHIP:ORBIT:APOAPSIS + BODY:RADIUS)).
	LOCAL burnDv IS circVel - SHIP:VELOCITY:ORBIT:MAG.
	LOCAL etaAP IS signed_eta_ap().
	LOCAL burnDuration IS burn_duration(currentISP,burnDv).
	SET circThrottlePID:SETPOINT TO burnDuration + 1.
	SET throt TO circThrottlePID:UPDATE(TIME:SECONDS,etaAP).
	WAIT 0.
	CLEARSCREEN.
	IF warpConObj["execute"]:CALL(etaAP - 30 - burnDuration) AND ABS(burnDv) < 0.1 {
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
			PRINT " Analysis: 0%  ":PADRIGHT(TERMINAL:WIDTH - 19) AT(19,1).
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
		LOCAL tgtInc IS targetThing.
		IF myLat < 0 { SET myLng TO myLng + 180. }

		IF ABS(myLat) > ABS(tgtInc) {//checks that target inclination can be reached
			LOCAL trueLAN IS MOD(myLng - 90 + BODY:ROTATIONANGLE + 720,360).
			RETURN LEX("lan",trueLAN,"inc",ABS(myLat),"canReach",FALSE).
		} IF ABS(myLat) > (180 - ABS(tgtInc)) {
			LOCAL trueLAN IS MOD(myLng + 90 + BODY:ROTATIONANGLE + 720,360).
			RETURN LEX("lan",trueLAN,"inc",180 - ABS(myLat),"canReach",FALSE).

		} ELSE {
			LOCAL equitoralLng IS ARCSIN(TAN(myLat) / TAN(tgtInc)).
			LOCAL tarLAN IS CHOOSE myLng - equitoralLng IF tgtInc <= 0 ELSE (myLng + equitoralLng) + 180.

			LOCAL trueLAN IS MOD(tarLAN + BODY:ROTATIONANGLE + 720,360).

			RETURN LEX("lan",trueLAN,"inc",ABS(tgtInc),"canReach",TRUE).
		}
	} ELSE {
		LOCAL tgtInc IS targetThing:INCLINATION.
		IF (tgtInc > ABS(myLat)) AND (ABS(myLat) < (180 - tgtInc)) {//check that target orbital plane can be reached
			RETURN LEX("lan",targetThing:LAN,"inc",tgtInc,"canReach",TRUE).
		} ELSE {
			RETURN LAN_calculations(tgtInc).
		}
	}
}

FUNCTION azimuth {
	PARAMETER targetLAN,targetInc,targetAP,headingOfDiff IS TRUE.
	LOCAL sufaceLAN IS targetLAN - BODY:ROTATIONANGLE.//lan converted to a surface longitude

	LOCAL lanVec IS (LATLNG(0,sufaceLAN):POSITION - BODY:POSITION):NORMALIZED.//vector pointing to the LAN
	LOCAL targetNormal IS ANGLEAXIS(-targetInc,lanVec) * V(0,-1,0).//computing the normal vector of the desired orbit
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
	LOCAL sma IS (PERIAPSIS + targetAP) / 2 + BODY:RADIUS.
	RETURN SQRT((BODY:MU * (2 * sma - currentRad)) / (sma * currentRad)).
}

FUNCTION launch_range {
	PARAMETER LANdata,targetAP,rangeSafty.
	LOCAL targetHeading IS azimuth(LANdata["LAN"],LANdata["inc"],targetAP).
	LOCAL launchRange IS ABS(targetHeading - azimuth(LANdata["LAN"],LANdata["inc"],targetAP,FALSE)).	//the range over which the craft might fly relative to the targetHeading
	IF launchRange > 180 {
		SET launchRange TO 360 - launchRange.
	}
	SET launchRange TO launchRange + rangeSafty.
	RETURN LEX("launchAz",targetHeading,"arc",launchRange).
}

FUNCTION range_scan {//scans along the launch path for the highest peaks that need to be cleared
	PARAMETER initalHeading,launchRange,printHeight IS 0,printPrefix IS "".

	LOCAL halfCirc IS BODY:RADIUS * CONSTANT:PI.//1/2 the circumference of the body
	LOCAL distToDegConstant IS 180 / halfCirc.

	LOCAL maxDist IS halfCirc / 5.//scan for 1/10th the radius of the body for upcoming high points
	LOCAL distStep IS 250.//distance increment in meters
	LOCAL distStepFrac IS maxDist / distStep.

	LOCAL startPos IS SHIP:GEOPOSITION.
	LOCAL startHeight IS startPos:TERRAINHEIGHT.
	LOCAL highest IS startHeight.
	LOCAL slope IS 0.
	LOCAL posDist IS 0.

	LOCAL headingStart IS initalHeading - launchRange.
	LOCAL headingEnd IS initalHeading + launchRange.
	LOCAL headingStep IS 0.2.

	LOCAL sinSPlat IS SIN(startPos:LAT).
	LOCAL cosSPlat IS COS(startPos:LAT).

	LOCAL startLng IS startPos:LNG.

	FROM {LOCAL dist IS distStep. } UNTIL dist > maxDist STEP { SET dist TO dist + distStep. } DO {
		PRINT (printPrefix + ROUND((dist / maxDist) * 100,2) + "%"):PADRIGHT(TERMINAL:WIDTH) AT(0,printHeight).

		//all the steps to compute the new latlng that don't need the heading done here to improve efficiency
		LOCAL degTravle IS dist * distToDegConstant.
		LOCAL sinDegTcosSPlat IS SIN(degTravle) * cosSPlat.
		LOCAL cosDegT IS COS(degTravle).
		LOCAL newLatP1 IS sinSPlat*cosDegT .

		FROM { LOCAL head IS headingStart. } UNTIL head > headingEnd STEP { SET head TO head + headingStep. } DO {
			//PRINT "clearance scan progress: " + ROUND((dist / maxDist + ((head - headingStart) / headingRange) / distStepFrac) * 100,2) + "%    " AT(0,0).
			//heading dependent calculations
			LOCAL newLat IS ARCSIN(newLatP1 + sinDegTcosSPlat*COS(head)).
			LOCAL newLng IS CHOOSE startLng + ARCTAN2(SIN(head)*sinDegTcosSPlat,cosDegT-sinSPlat*SIN(newLat)) IF ABS(newLat) <> 90 ELSE 0.
			LOCAL newPos IS LATLNG(newLat,newLng).

			IF (newPos:TERRAINHEIGHT - startHeight) / dist > slope {
				SET highest TO newPos:TERRAINHEIGHT.
				SET slope TO (newPos:TERRAINHEIGHT - startHeight) / dist.
				SET posDist TO dist.
			}
		}
	}
	PRINT printPrefix + "100%    " AT(0,printHeight).
	RETURN LEX("highest",highest,"slope",slope,"dist",posDist).
}

FUNCTION UTs_of_orbit_cross {//returns the UTs of when the craft can launch into the orbital plane
	PARAMETER myLat,tgtOrbit,leadTime.
	LOCAL tarInc IS tgtOrbit:INCLINATION.
	LOCAL tarLan IS tgtOrbit:LAN - tgtOrbit:BODY:ROTATIONANGLE.
	LOCAL startTime IS TIME:SECONDS.
	LOCAL myLng IS SHIP:GEOPOSITION:LNG.

	IF tarInc < ABS(myLat) {
		IF myLat > 0 {
			SET myLat TO tarInc.
		} ELSE {
			SET myLat TO -tarInc.
		}
	}
	LOCAL baseLng IS ARCSIN(TAN(myLat) / TAN(tarInc)).
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

FUNCTION normal_of_orbit {//returns the normal of a crafts/bodies orbit, will point north if orbiting clockwise on equator
	PARAMETER object.
	RETURN VCRS(object:VELOCITY:ORBIT:NORMALIZED, (object:BODY:POSITION - object:POSITION):NORMALIZED):NORMALIZED.
}