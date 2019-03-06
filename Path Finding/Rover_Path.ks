PARAMETER endPoint,unitDist IS 200,maxSpeed IS MAX(25,5),minSpeed IS 5,closeToDist IS 450.
FOR lib IN LIST("lib_geochordnate","lib_formating") { IF EXISTS("1:/lib/" + lib + ".ksm") { RUNONCEPATH("1:/lib/" + lib + ".ksm"). } ELSE { RUNONCEPATH("1:/lib/" + lib + ".ks"). }}
LOCAL srfGrav IS SHIP:BODY:MU / SHIP:BODY:RADIUS^2.
CLEARSCREEN.
ABORT OFF.
SET CONFIG:IPU TO 2000.
LOCAL varConstants IS LEX().
LOCAL nodeTree IS LEX().
LOCAL nodeQue IS LIST().

LOCAL destData IS mis_types_to_geochordnate(endPoint).
LOCAL dest IS destData["chord"].
LOCAL destName IS destData["name"].
LOCAL doRoving IS FALSE.
LOCAL pruneCountDown IS 1000.
IF dest:ISTYPE("geocoordinates") { SET doRoving TO TRUE.}

IF doRoving {

LOCAL initalDist IS dist_between_coordinates(dest,SHIP:GEOPOSITION).
//LOCAL unitDist IS initalDist / 5^CEILING(LN(initalDist / MIN(100,(closeToDist / 2))) / LN(5)).
SET varConstants TO LEX(
	//"unitDist",unitDist,
	"maxDist",(unitDist),
	"rootTwo",SQRT(2),
	"unitDistDeg",(unitDist*180) / (SHIP:BODY:RADIUS * CONSTANT:PI),
	"dest",dest,
	"northRef",distance_heading_to_latlng(deg_protect(dest:HEADING + 90),SHIP:BODY:RADIUS / 2 * CONSTANT:PI,SHIP:GEOPOSITION),
	"nodeCluster",LIST(LIST( 1, 0),LIST( 1, 1),LIST( 0, 1),LIST(-1, 1),LIST(-1, 0),LIST(-1,-1),LIST( 0,-1),LIST( 1,-1))
	//"nodeCluster",LIST(LIST( 1, 0),LIST( 0, 1),LIST(-1, 0),LIST( 0,-1))
	).

LOCAL starNodeChord IS SHIP:GEOPOSITION.
nodeTree:ADD("0,0",LEX("latLng",starNodeChord)).
LOCAL localNode IS nodeTree["0,0"].
localNode:ADD("distToDest",dist_between_coordinates(starNodeChord,varConstants["dest"])).
localNode:ADD("alt",starNodeChord:TERRAINHEIGHT).
localNode:ADD("slope",slope_calculation(starNodeChord)).
localNode:ADD("preNewVec",V(0,0,0)).
localNode:ADD("preDist",1).
localNode:ADD("totalDist",1).
localNode:ADD("grade",0).
localNode:ADD("curvature",0).
//localNode:ADD("totalDist",1).
localNode:ADD("prevousNodeID","0,0").
localNode:ADD("slopeScore",0).
localNode:ADD("totalSlope",0).
localNode:ADD("nodeScore",0).
nodeQue:ADD("0,0").

LOCAL waypointList IS LIST().
LOCAL startDist IS localNode["distToDest"].
LOCAL endID IS "0,0".
LOCAL closestDist IS startDist - 0.01.
PRINT "   closest Dist: " + ROUND(closestDist) AT(0,3).
LOCAL vecWidth IS 500.
IF MAPVIEW { SET vecWidth TO 0.5. }
LOCAL bestVec IS VECDRAW(SHIP:POSITION,SHIP:UP:VECTOR * 2000, GREEN,"",1,TRUE,vecWidth).
LOCAL nodeVec IS VECDRAW(SHIP:POSITION,SHIP:UP:VECTOR * 2000, YELLOW,"",1,TRUE,vecWidth).
LOCAL endVecDraw IS VECDRAW(dest:POSITION,(dest:POSITION - SHIP:BODY:POSITION):NORMALIZED * 2000,RED,"",1,TRUE,vecWidth).
LOCAL done IS FALSE.
LOCAL startTime IS TIME:SECONDS.

ON MAPVIEW {
	IF NOT done {
		LOCAL vecWidth IS 500.
		IF MAPVIEW { SET vecWidth TO 0.5. }
		SET bestVec:WIDTH TO vecWidth.
		SET nodeVec:WIDTH TO vecWidth.
		SET endVecDraw:WIDTH TO vecWidth.
		PRESERVE.
	}
}

UNTIL done OR ABORT {
	LOCAL nodeID IS nodeQue[0].
	nodeQue:REMOVE(0).
	LOCAL nodeDist IS nodeTree[nodeID]["distToDest"].
	IF nodeDist < closeToDist {
		IF back_propogation_check(nodeID) {
			SET done TO TRUE.
			SET waypointList TO back_propogation_waypoint_list(nodeID).
			SET endID TO nodeID.
		} ELSE {//if back prop check fails then remove all nodes that fail said check from node list
			SET closestDist TO startDist - 0.01.
			SET nodeDist TO startDist.
			prune_que().
		}
	} ELSE {
		evaluate_node_cluster(nodeID).
	}
	IF nodeDist < closestDist {
		SET closestDist TO nodeDist.
		LOCAL pointPos IS nodeTree[nodeID]["latLng"]:POSITION.
		SET bestVec:START TO pointPos.
		SET bestVec:VEC TO (pointPos - SHIP:BODY:POSITION):NORMALIZED * 2000.
		PRINT "   closest Dist: " + si_formating(closestDist,"m") + " " AT(0,3).
		PRINT " Time Remaining: " + ROUND(closestDist / ((startDist - closestDist) / (TIME:SECONDS - startTime))) + "    " AT(0,4).
	}
	LOCAL pointPos IS nodeTree[nodeID]["latLng"]:POSITION.
	SET nodeVec:START TO pointPos.
	SET nodeVec:VEC TO (pointPos - SHIP:BODY:POSITION):NORMALIZED * 2000.
	PRINT "number of Nodes: " + nodeQue:LENGTH + "      " AT(0,2).
}

LOCAL vecDrawList IS LIST().
SET done TO FALSE.
ON MAPVIEW {
	IF NOT done {
		LOCAL vecWidth IS 200.
		IF MAPVIEW { SET vecWidth TO 0.05. }
		LOCAL drawLength IS vecDrawList:LENGTH.
		FROM {LOCAL i IS 0. } UNTIL i >= drawLength STEP { SET i TO i + 1. } DO { 
			SET vecDrawList[i]:WIDTH TO vecWidth.
		}
		//FOR vecD IN vecDrawList { SET vecD:WIDTH TO vecWidth. PRINT vecD. WAIT 1.}
		PRESERVE.
	}
}
IF NOT ABORT {
	waypointList:ADD(dest).
	PRINT "elapsed time: " + ROUND(TIME:SECONDS - startTime) AT(0,7).
	PRINT "  tree size: " + nodeTree:LENGTH AT(0,8).
	PRINT "  path size: " + waypointList:LENGTH AT(0,9).
	render_points(waypointList,vecDrawList).
//	path_scroll(endID).
	
	RCS OFF.
	WAIT UNTIL RCS.

	SET waypointList TO smooth_points(waypointList).
	render_points(waypointList,vecDrawList).
	
	SET waypointList TO smooth_points(waypointList,TRUE).
	render_points(waypointList,vecDrawList).

	SET waypointList TO smooth_points(waypointList,TRUE).
	render_points(waypointList,vecDrawList).
	

	RCS OFF.
	//SAS OFF.
	WAIT UNTIL RCS.
	SET done TO TRUE.
	CLEARVECDRAWS().

	SET CONFIG:IPU TO 200.
	IF NOT SAS {
		COPYPATH("0:/Rover_Path_execution.ks","1:/").
		RUNPATH("1:/Rover_Path_execution",maxSpeed,minSpeed,closeToDist,waypointList,unitDist / 4,destName).
	}
}}
ABORT OFF.
CLEARVECDRAWS().

FUNCTION render_points  {
	PARAMETER pointList,vecDrawList.
	vecDrawList:CLEAR().
	CLEARVECDRAWS().
	LOCAL prevousPoint IS SHIP:GEOPOSITION.
	LOCAL totalDist IS 0.
	FOR point IN pointList {
		WAIT 0.
		LOCAL pointPos IS point:POSITION.
		LOCAL adjustPos IS pointPos + ((pointPos - SHIP:BODY:POSITION):NORMALIZED * 20).
		LOCAL prePos IS prevousPoint:POSITION.
		LOCAL adjPrePos IS prePos + ((prePos - SHIP:BODY:POSITION):NORMALIZED * 20).
		LOCAL vecWidth IS 200.
		IF MAPVIEW { SET vecWidth TO 0.05. }
		vecDrawList:ADD(VECDRAW(adjPrePos,(adjustPos - adjPrePos),green,"",1,TRUE,vecWidth)).
		SET totalDist to totalDist + dist_between_coordinates(prevousPoint,point).
		SET prevousPoint TO point.
	}
	PRINT "path length: " + si_formating(totalDist,"m") AT(0,10).
	//WAIT 5.
}

FUNCTION back_propogation_check {
	PARAMETER initalNodeID.
	LOCAL nodeID IS initalNodeID.
	LOCAL checkedNodes IS 0.
	LOCAL maxNodes IS nodeTree:LENGTH.
	LOCAL done IS FALSE.
	UNTIL nodeID = "0,0" OR done {
		IF nodeTree:HASKEY(nodeID) AND checkedNodes < maxNodes {
			SET nodeID TO nodeTree[nodeID]["prevousNodeID"].
			SET checkedNodes TO checkedNodes + 1.
		} ELSE {
			SET done TO TRUE.
		}
	}
	RETURN nodeID = "0,0".
}

FUNCTION prune_que {
	LOCAL queLength IS nodeQue:LENGTH.
	FROM { LOCAL i IS queLength - 1. } UNTIL i < 0 STEP { SET i TO i - 1. } DO {
		PRINT "pruned: " + ROUND((1 - i / queLength) * 100,2) + "%    " AT(0,6).
		IF NOT back_propogation_check(nodeQue[i]) {
			nodeQue:REMOVE(i).
		}
	}
}

FUNCTION back_propogation_waypoint_list {
	PARAMETER initalNodeID.
	LOCAL nodeID IS initalNodeID.
	LOCAL returnList IS LIST(nodeTree[nodeID]["latLng"]).
	UNTIL nodeID = "0,0" {
		SET nodeID TO nodeTree[nodeID]["prevousNodeID"].
		PRINT "node ID: " + nodeID + "    " AT(0,1).
		//WAIT 0.2.
		returnList:INSERT(0,nodeTree[nodeID]["latLng"]).
	}
	RETURN returnList.
}

FUNCTION smooth_points {
	PARAMETER pointList,isFinal IS FALSE.
	LOCAL pointLength IS pointList:LENGTH - 1.
	LOCAL returnList IS LIST(pointList[0]).
	FROM { LOCAL i IS 1. } UNTIL i >= pointLength STEP { SET i TO i + 1. } DO {
		IF isFinal {
			LOCAL posTemp IS (pointList[i - 1]:POSITION + pointList[i]:POSITION + pointList[i + 1]:POSITION)/3.
			returnList:ADD(SHIP:BODY:GEOPOSITIONOF(posTemp)).
		} ELSE {
			LOCAL posTemp IS (pointList[i - 1]:POSITION + pointList[i + 1]:POSITION)/2.
			returnList:ADD(SHIP:BODY:GEOPOSITIONOF(posTemp)).
		}
	}
	returnList:ADD(pointList[pointLength]).
	RETURN returnList.
}

FUNCTION evaluate_node_cluster {
	PARAMETER preNodeID.
	LOCAL nodeID IS preNodeID:SPLIT(",").
	FOR point IN varConstants["nodeCluster"] {
		LOCAL newNodeID IS newID(nodeID,point).
		IF evaluate_node(preNodeID,newNodeID[0],newNodeID[1]) {
			add_node_to_que(newNodeID[0]).
		}
	}
}

FUNCTION newID {
	PARAMETER xyVal,changeList.
	LOCAL xVal IS xyVal[0]:TONUMBER() + changeList[0].
	LOCAL yVal IS xyVal[1]:TONUMBER() + changeList[1].
	RETURN LIST(xVal + "," + yVal,LIST(xVal,yVal)).
}

FUNCTION add_node_to_que {
	PARAMETER nodeID.
	LOCAL queLength IS nodeQue:LENGTH.
	IF queLength = 0 {
		nodeQue:ADD(nodeID).
	} ELSE {
		LOCAL nodeScore IS nodeTree[nodeID]["nodeScore"].
		LOCAL queIncrement IS MAX(FLOOR(queLength / 2),1).
		LOCAL queIndex IS MAX(queIncrement - 1,0).
		LOCAL divCounter IS FLOOR(LN(queLength) / LN(2)).
		UNTIL FALSE {
			IF divCounter > 0 {
				SET divCounter TO divCounter - 1.
				SET queIncrement TO MAX(FLOOR(queIncrement/2),1).
				IF nodeTree[nodeQue[ROUND(queIndex)]]["nodeScore"] < nodeScore {
					SET queIndex TO MIN(queIndex + queIncrement,queLength).
				} ELSE {
					SET queIndex TO MAX(queIndex - queIncrement,0).
				}
				IF divCounter <= 0 {
					SET queIndex TO ROUND(queIndex).
				}
			} ELSE {
				IF nodeTree[nodeQue[queIndex]]["nodeScore"] < nodeScore {
					SET queIndex TO MIN(queIndex + 1,queLength).
					IF (queIndex >= queLength) OR (nodeTree[nodeQue[queIndex]]["nodeScore"] >= nodeScore) {
						nodeQue:INSERT(queIndex,nodeID).
						BREAK.
					}
				} ELSE {
					IF queIndex <= 0 {
						nodeQue:INSERT(queIndex,nodeID).
						BREAK.
					}
					SET queIndex TO MAX(queIndex - 1,0).
				}
			}
		}
	}
}

FUNCTION evaluate_node {
	PARAMETER preNodeID,newNodeIDstr,newNodeIDnum.
	LOCAL preNode IS nodeTree[preNodeID].
	LOCAL isBetter IS FALSE.
	IF nodeTree:HASKEY(newNodeIDstr) {
		IF preNode["prevousNodeID"] <> newNodeIDstr {// AND back_check(newNodeIDstr) {
		//IF NOT back_propogation_check(preNodeID) {
		//IF preNodeID = nodeTree[newNodeIDstr]["prevousNodeID"] {
			LOCAL localNode IS nodeTree[newNodeIDstr].
			LOCAL preNodeChord IS preNode["latLng"].
			LOCAL newPreDist IS dist_between_coordinates(preNodeChord,localNode["latLng"]).
			LOCAL newTotalDist IS preNode["totalDist"] + newPreDist.
			LOCAL newGrade IS ARCTAN((preNode["alt"] - localNode["alt"]) / newPreDist).
			LOCAL newNodeScoreSlope IS node_score_slope(preNode["grade"],newGrade,localNode["slope"],localNode["curvature"],newPreDist).
			LOCAL newNodeTotalSlope IS newNodeScoreSlope + preNode["totalSlope"].
			LOCAL newNodeScore IS node_score_total(localNode["distToDest"],newTotalDist,newNodeScoreSlope,newNodeTotalSlope).
			
			IF newNodeScore < localNode["nodeScore"] AND limited_back_check(preNodeID,newNodeIDstr) {
				remove_from_que(newNodeIDstr,localNode["nodeScore"]).
				SET localNode["prevousNodeID"] TO preNodeID.
				SET localNode["preDist"] TO newPreDist.
				SET localNode["totalDist"] TO newTotalDist.
				SET localNode["grade"] TO newGrade.
				SET localNode["slopeScore"] TO newNodeScoreSlope.
				SET localNode["totalSlope"] TO newNodeTotalSlope.
				SET localNode["nodeScore"] TO newNodeScore.
				SET isBetter TO TRUE.
			}
		}// ELSE { PRINT "didn't evaulate: " + newNodeIDstr AT(0,0). }
	} ELSE {
		LOCAL center IS preNodeID:SPLIT(",").
		LOCAL northHeading IS inital_heading(preNode["latLng"],varConstants["northRef"]).
		LOCAL newNodeHead IS 0.
		LOCAL newCoef IS 1.
		LOCAL xVal IS center[0]:TONUMBER() - newNodeIDnum[0].
		LOCAL yVal IS center[1]:TONUMBER() - newNodeIDnum[1].
		IF xVal = 0 {
			IF yVal > 0 {
				SET newNodeHead TO northHeading + 0.
			} ELSE {
				SET newNodeHead TO northHeading + 180.
			}
		} ELSE IF xVal > 0 {
			IF yVal > 0 {
				SET newNodeHead TO northHeading + 45.
				SET newCoef TO varConstants["rootTwo"].
			} ELSE IF yVal < 0 {
				SET newNodeHead TO northHeading + 135.
				SET newCoef TO varConstants["rootTwo"].
			} ELSE {
				SET newNodeHead TO northHeading + 90.
			}
		} ELSE {
			IF yVal > 0 {
				SET newNodeHead TO northHeading + 315.
				SET newCoef TO varConstants["rootTwo"].
			} ELSE IF yVal < 0 {
				SET newNodeHead TO northHeading + 225.
				SET newCoef TO varConstants["rootTwo"].
			} ELSE {
				SET newNodeHead TO northHeading + 270.
			}
		}
		LOCAL newNodeChord IS new_node_chord(deg_protect(newNodeHead),preNode["latLng"],newCoef).
		nodeTree:ADD(newNodeIDstr,LEX("latLng",newNodeChord)).
		LOCAL newNode IS nodeTree[newNodeIDstr].
		LOCAL preNodeChord IS preNode["latLng"].
		newNode:ADD("northHeading",northHeading).
		newNode:ADD("distToDest",dist_between_coordinates(newNodeChord,varConstants["dest"])).
		newNode:ADD("alt",newNodeChord:TERRAINHEIGHT).
		newNode:ADD("slope",slope_calculation(newNodeChord)).
		newNode:ADD("curvature",calculate_curviture(newNodeChord,northHeading)).
		//newNode:ADD("preNewVec",newNodeChord:POSITION - preNodeChord:POSITION).
		newNode:ADD("preDist",dist_between_coordinates(preNodeChord,newNodeChord)).
		newNode:ADD("totalDist",preNode["totalDist"] + newNode["preDist"]).
		newNode:ADD("grade",ARCTAN((preNode["alt"] - newNode["alt"]) / newNode["preDist"])).
		newNode:ADD("prevousNodeID",preNodeID).
		newNode:ADD("slopeScore",node_score_slope(preNode["grade"],newNode["grade"],newNode["slope"],newNode["curvature"],newNode["preDist"])).
		newNode:ADD("totalSlope",newNode["slopeScore"] + preNode["totalSlope"]).
		newNode:ADD("nodeScore",node_score_total(newNode["distToDest"],newNode["totalDist"],newNode["slopeScore"],newNode["totalSlope"])).
		
		SET isBetter TO TRUE.
	}
	RETURN isBetter.
}

FUNCTION limited_back_check {
	PARAMETER prevousNodeID,newNodeID.
	LOCAL count IS 0.
	LOCAL nodeGood IS TRUE.
	FROM {LOCAL i IS 0.} UNTIL i >= 10 STEP {SET i TO i + 1.} DO {
		LOCAL preID IS nodeTree[prevousNodeID]["prevousNodeID"].
		IF preID = newNodeID {
			SET nodeGood TO FALSE.
			BREAK.
		} ELSE {
			SET prevousNodeID TO preID.
		}
	}
	RETURN nodeGood.
}

FUNCTION calculate_curviture {
	PARAMETER nodeGeo,northHeading.
	
	LOCAL pointHeadingA TO deg_protect(northHeading).
	LOCAL pointHeadingB TO deg_protect(northHeading + 45).
	LOCAL pointHeadingC TO deg_protect(northHeading + 90).
	LOCAL pointHeadingD TO deg_protect(northHeading + 135).
	
	LOCAL nodeNormal IS surface_normal(nodeGeo).
	LOCAL aVec IS normal_diff(pointHeadingA,nodeGeo,0.5).
	LOCAL bVec IS normal_diff(pointHeadingB,nodeGeo,SQRT(0.5)).
	LOCAL cVec IS normal_diff(pointHeadingC,nodeGeo,0.5).
	LOCAL dVec IS normal_diff(pointHeadingD,nodeGeo,SQRT(0.5)).
	LOCAL sumVec IS aVec + bVec + cVec + dVec + nodeNormal.
	RETURN VANG(nodeNormal,sumVec).
}

FUNCTION normal_diff {
	PARAMETER head,geo,coef.
	RETURN surface_normal(new_node_chord(head,geo,coef)) - surface_normal(new_node_chord(deg_protect(head + 180),geo,coef)).
}

FUNCTION deg_protect {
	PARAMETER deg.
	RETURN MOD(deg + 360,360).
}

FUNCTION remove_from_que {
	PARAMETER nodeID,nodeScore.
	IF nodeQue:CONTAINS(nodeID) {
		LOCAL queLength IS nodeQue:LENGTH.
		LOCAL queIncrement IS MAX(FLOOR(queLength / 2),1).
		LOCAL queIndex IS MAX(queIncrement - 1,0).
		LOCAL divCounter IS FLOOR(LN(queLength) / LN(2)).
		LOCAL queHighScan IS queIndex.
		LOCAL queLowScan IS queIndex.
		UNTIL FALSE {
			IF divCounter > 0 {
				SET divCounter TO divCounter - 1.
				SET queIncrement TO MAX(FLOOR(queIncrement/2),1).
				IF nodeTree[nodeQue[ROUND(queIndex)]]["nodeScore"] < nodeScore {
					SET queIndex TO MIN(queIndex + queIncrement,queLength).
				} ELSE {
					SET queIndex TO MAX(queIndex - queIncrement,0).
				}
				IF divCounter <= 0 {
					SET queHighScan TO ROUND(queIndex).
					IF nodeQue[queHighScan] = nodeID {
						nodeQue:REMOVE(queHighScan).
						BREAK.
					}
					SET queLowScan TO queHighScan.
				}
			} ELSE {
				IF queHighScan < queLength {
					//PRINT "checking high: " + nodeQue[queHighScan] AT(0,7).
					IF nodeQue[queHighScan] = nodeID {

						nodeQue:REMOVE(queHighScan).
						BREAK.
					} ELSE {
						SET queHighScan TO queHighScan + 1.
					}
				}
				IF queLowScan >= 0 {
					//PRINT "checking low: " + nodeQue[queHighScan] AT(0,8).
					IF nodeQue[queLowScan] = nodeID {
						nodeQue:REMOVE(queLowScan).
						BREAK.
					} ELSE {
						SET queLowScan TO queLowScan - 1.
					}
				}
			}
		}
	}
}

FUNCTION node_score_total {
	PARAMETER distToDest,pathLength,slopeScore,totalSlope.
	LOCAL score IS slopeScore.
	SET score TO score + distToDest.
	SET score TO score + pathLength / 2.
	SET score TO score + totalSlope / (pathLength / 2).
	RETURN score.
}

FUNCTION node_score_slope {
	PARAMETER oldGrade,newGrade,localSlope,localCurvature,preDist.
	LOCAL score IS SIN(MIN(ABS(oldGrade - newGrade),90)) * preDist * 20.//was 20
	//LOCAL score IS SIN((ABS(oldGrade - newGrade)/2)) * preDist * 40.
	SET score TO score + SIN(localSlope) * preDist * 25.//was 25
	SET score TO score + SIN(localCurvature) * preDist * 15.//was 15
	RETURN score.//didn't have preSlope
}

FUNCTION new_node_chord {
	PARAMETER nodeHeading,oldNode,degCoef IS 1.//nodeHeading is degrees, oldNode is latLng to calculate new node form
	LOCAL degTravle IS varConstants["unitDistDeg"] * degCoef.//degrees around the body
	LOCAL codDegT IS COS(degTravle).
	LOCAL sinDegTcosOldNlat IS SIN(degTravle)*COS(oldNode:LAT).
	LOCAL sinOldNlat IS SIN(oldNode:LAT).
	LOCAL newLat IS ARCSIN(sinOldNlat*codDegT + sinDegTcosOldNlat*COS(nodeHeading)).
	IF newLat <> 90 {
		LOCAL newLng IS oldNode:LNG + ARCTAN2(SIN(nodeHeading)*sinDegTcosOldNlat,codDegT-sinOldNlat*SIN(newLat)).
		RETURN LATLNG(newLat,newLng).
	} ELSE {
		RETURN LATLNG(newLat,0).
	}
}

FUNCTION path_scroll {
	PARAMETER startID.
	
	LOCAL nodeID IS startID.
	LOCAL pathList IS LIST(nodeID).
	UNTIL nodeID = "0,0" {
		SET nodeID TO nodeTree[nodeID]["prevousNodeID"].
		pathList:INSERT(0,nodeID).
	}
	
	LOCAL nodeVec IS VECDRAW(SHIP:POSITION,SHIP:UP:VECTOR * 5, YELLOW,"",100,TRUE,1).
	LOCAL termIn IS TERMINAL:INPUT.
	LOCAL i IS 0.
	PRINT "node ID: " + pathList[i] + "    " AT(0,1).
	LOCAL done IS FALSE.
	UNTIL done {
		IF termIn:HASCHAR {
			LOCAL char IS termIn:GETCHAR().
			IF char = "+" {
				SET i TO MIN(i + 1,pathList:LENGTH - 1).
			} ELSE IF char = "-" {
				SET i TO MAX(i - 1,0).
			} ELSE IF char = "*" {
				SET i TO MIN(i + 10,pathList:LENGTH - 1).
			} ELSE IF char = "/" {
				SET i TO MAX(i - 10,0).
			} ELSE IF char = "0" {
				SET done TO TRUE.
			}
			LOCAL pointPos IS nodeTree[pathList[i]]["latLng"]:POSITION.
			SET nodeVec:START TO pointPos.
			SET nodeVec:VEC TO (pointPos - SHIP:BODY:POSITION):NORMALIZED * 5.
			PRINT "node ID: " + pathList[i] + "    " AT(0,1).
		}
		WAIT 0.
	}
}

FUNCTION back_propogation_id_list {
	PARAMETER initalNodeID.
	LOCAL nodeID IS initalNodeID.
	RETURN returnList.
}
