@LAZYGLOBAL OFF.
//LOCAL hill_climb_lex IS LEX().

FUNCTION climb_init {
	PARAMETER climbType,terms,maxStep,initalResults,incStep IS 0,decStep IS 1,minStep IS 0.01,stepExp IS 0.//inc/dec step are the change to x in the maxStep*10^x, inc for improvement, dec for no improvement
	LOCAL climbData IS LEX().
	//climbData:ADD("climbType",climbType).//can only be strings "best","first","grad"
	climbData:ADD("terms",terms).
	climbData:ADD("maxStep",maxStep).
	climbData:ADD("minStep",minStep).
	climbData:ADD("results",initalResults).
	climbData:ADD("incStep",incStep).
	climbData:ADD("decStep",decStep).
	climbData:ADD("stepExp",stepExp).

	LOCAL stepsList IS LIST().
	IF climbType = "grad" {
		LOCAL stepBlank IS LIST().
		UNTIL stepBlank:LENGTH >= terms { stepBlank:ADD(0). }
		climbData:ADD("stepBlank",stepBlank).
		climbData:ADD("climbType","grad").
		//LOCAL posStep IS TRUE.
		LOCAL stepDir IS 1.
		FROM { LOCAL i IS 0. } UNTIL i >= (terms * 2) STEP { SET i TO i + 1. } DO {
			stepsList:ADD(stepBlank:COPY()).
			SET stepsList[i][FLOOR(i / 2)] TO stepDir.
			SET stepDir TO -stepDir.
			//IF posStep {
			//	SET stepsList[i][FLOOR(i / 2)] TO 1.
			//} ELSE {
			//	SET stepsList[i][FLOOR(i / 2)] TO -1.
			//}
			//SET posStep TO NOT posStep.
		}
	} ELSE {
		climbData:ADD("climbType","basic").
		climbData:ADD("firstGood",(climbType = "first")).
		FROM { LOCAL i IS 1. } UNTIL i > terms STEP { SET i TO i + 1. } DO {
			stepsList:ADD(i).
			stepsList:ADD(-i).
		}
	}
	SET climbData["stepsList"] TO stepsList.
	RETURN climbData.
}
//hill_climb_lex:ADD("basic",climb_basic@).
//hill_climb_lex:ADD("grad",climb_grad@).

LOCAL hill_climb_type IS LEX("basic",climb_basic@,"grad",climb_grad@).
FUNCTION climb_hill {
	PARAMETER thing,scoreFunc,stepFunc,climbData.
	LOCAL tmpFunc IS hill_climb_type[climbData["climbType"]]@.
	//PRINT climbData["climbType"].
	//PRINT tmpFunc:TYPENAME.
	//PRINT tmpFunc:SUFFIXNAMES.
	//RCS OFF.
	//WAIT UNTIL RCS.
	RETURN tmpFunc(thing,scoreFunc@,stepFunc@,climbData).
}

LOCAL FUNCTION climb_basic {
	PARAMETER thing,scoreFunc,stepFunc,climbData.
	LOCAL bestDir IS 0.
	LOCAL bestScore IS climbData["results"].
	LOCAL bestScoreValue IS bestScore["score"].
	LOCAL stepMag IS climbData["maxStep"] * 10^climbData["stepExp"].

	FOR stepDir IN climbData["stepsList"] {
		stepFunc(thing,stepDir,stepMag).
		LOCAL tmpScore IS scoreFunc(thing).
		IF tmpScore["score"] < bestScoreValue {
			SET bestScore TO tmpScore.
			SET bestDir TO stepDir.
			IF climbData["firstGood"] {
				stepFunc(thing,stepDir,-stepMag).
				BREAK.
			}
		}
		stepFunc(thing,stepDir,-stepMag).
	}

	IF bestDir <> 0 {
		stepFunc(thing,bestDir,stepMag).
		SET climbData["results"] TO bestScore.
		SET climbData["stepExp"] TO MIN(climbData["stepExp"] + climbData["incStep"],0).
		RETURN FALSE.
	} ELSE {
		IF stepMag < climbData["minStep"] {
			RETURN TRUE.
		} ELSE {
			SET climbData["stepExp"] TO climbData["stepExp"] - climbData["decStep"].
			RETURN FALSE.
		}
	}
}

LOCAL FUNCTION climb_grad {
	PARAMETER thing,scoreFunc,stepFunc,climbData.
//	LOCAL stepsList IS climbData["stepsList"].
	LOCAL stepMag IS climbData["maxStep"] * 10^climbData["stepExp"].
	LOCAL bestDiff IS 0.
	LOCAL preScore IS climbData["results"]["score"].
	LOCAL goodSteps IS LIST().
	LOCAL maxSteps IS climbData["stepsList"]:LENGTH.

	FROM { LOCAL i IS 0. } UNTIL i >= maxSteps STEP { SET i TO i + 1. } DO {
		LOCAL stepDir IS climbData["stepsList"][i].
		stepFunc(thing,stepDir,stepMag).

		LOCAL tmpScore IS scoreFunc(thing)["score"].
		IF tmpScore < preScore {
			LOCAL diff IS preScore - tmpScore.
			IF diff > bestDiff { SET bestDiff TO diff. }
			goodSteps:ADD(LIST(diff,i)).
		}
		stepFunc(thing,stepDir,-stepMag).
	}

	IF goodSteps:LENGTH > 0 {
		LOCAL stepVec IS climbData["stepBlank"]:COPY().
		FOR goodStep IN goodSteps {
			LOCAL diffVal IS goodStep[0] / bestDiff.
			LOCAL stepDir IS climbData["stepsList"][goodStep[1]].
			FROM { LOCAL i IS 0. } UNTIL i >= climbData["terms"] STEP { SET i TO i + 1. } DO {
				SET stepVec[i] TO stepVec[i] + stepDir[i] * diffVal.
			}
		}
		stepFunc(thing,stepVec,stepMag).
		SET climbData["stepExp"] TO MIN(climbData["stepExp"] + climbData["incStep"],0).
		SET climbData["results"] TO scoreFunc(thing).
		RETURN FALSE.
	} ELSE {
		IF stepMag < climbData["minStep"] {
			RETURN TRUE.
		} ELSE {
			SET climbData["stepExp"] TO climbData["stepExp"] - climbData["decStep"].
			RETURN FALSE.
		}
	}
}

FUNCTION closest_approach_hill {
	PARAMETER object1, object2,
	startTime.
	LOCAL objects IS LEX("obj1",object1,"obj2",object2,"UTS",startTime).
	LOCAL climbData IS climb_init("fist",2,object2:ORBIT:PERIOD / 360,ca_score(objects),0,1,1,0).
	LOCAL done IS FALSE.
	UNTIL done {
		SET done TO climb_hill(objects,ca_score@,ca_step@,climbData).
	}
	RETURN LEX("dist",climbData["results"]["score"],"time",objects["UTS"]).
}

LOCAL FUNCTION ca_score {
	PARAMETER objects.
	RETURN LEX("score",(POSITIONAT(objects["obj1"],objects["UTS"]) - POSITIONAT(objects["obj2"],objects["UTS"])):MAG).
}

LOCAL FUNCTION ca_step {
	PARAMETER objects,stepDir,stepMag.
	IF stepDir > 0 {
		SET objects["UTS"] TO objects["UTS"] + stepMag.
	} ELSE {
		SET objects["UTS"] TO objects["UTS"] - stepMag.
	}
}

FUNCTION node_step_full_grad {
	PARAMETER targetNode,stepDir,stepMag.
	SET targetNode:ETA TO targetNode:ETA + stepDir[0] * stepMag.
	SET targetNode:PROGRADE TO targetNode:PROGRADE + stepDir[1] * stepMag.
	SET targetNode:NORMAL TO targetNode:NORMAL + stepDir[2] * stepMag.
	SET targetNode:RADIALOUT TO targetNode:RADIALOUT + stepDir[3] * stepMag.
}

//hill_climb_lex:ADD("stepOrder",LEX()).

LOCAL node_step_lex IS LEX().
FUNCTION node_step_init {
	PARAMETER stepOrder IS LIST("eta","pro","norm","rad").
	//LOCAL stepLex IS hill_climb_lex["stepOrder"].
	node_step_lex:CLEAR().
	LOCAL numKey IS 1.
	FOR nStep IN stepOrder {
		IF nStep = "eta" {
			node_step_lex:ADD(numKey,{ PARAMETER targetNode,stepMag. SET targetNode:ETA TO targetNode:ETA + stepMag. }).
			node_step_lex:ADD(-numKey,{ PARAMETER targetNode,stepMag. SET targetNode:ETA TO targetNode:ETA - stepMag. }).
		} ELSE IF nStep = "pro" {
			node_step_lex:ADD(numKey,{ PARAMETER targetNode,stepMag. SET targetNode:PROGRADE TO targetNode:PROGRADE + stepMag. }).
			node_step_lex:ADD(-numKey,{ PARAMETER targetNode,stepMag. SET targetNode:PROGRADE TO targetNode:PROGRADE - stepMag. }).
		} ELSE IF nStep = "norm" {
			node_step_lex:ADD(numKey,{ PARAMETER targetNode,stepMag. SET targetNode:NORMAL TO targetNode:NORMAL + stepMag. }).
			node_step_lex:ADD(-numKey,{ PARAMETER targetNode,stepMag. SET targetNode:NORMAL TO targetNode:NORMAL - stepMag. }).
		} ELSE IF nStep = "rad" {
			node_step_lex:ADD(numKey,{ PARAMETER targetNode,stepMag. SET targetNode:RADIALOUT TO targetNode:RADIALOUT + stepMag. }).
			node_step_lex:ADD(-numKey,{ PARAMETER targetNode,stepMag. SET targetNode:RADIALOUT TO targetNode:RADIALOUT - stepMag. }).
		}
		SET numKey TO numKey + 1.
	}
}
node_step_init().

FUNCTION node_step_full { //manipulates the targetNode in one of 4 ways depending on manipType for a value of stepVal
	PARAMETER targetNode,stepDir,stepMag.
	node_step_lex[stepDir](targetNode,stepMag).
}

FUNCTION node_step_dv_only {//manipulates the targetNode in one of the 3 Vectors depending on stepDir for a value of stepMag, used in best,first type hill climbs 
	PARAMETER targetNode,stepDir,stepMag.
	node_step_lex[stepDir](targetNode,stepMag).
}