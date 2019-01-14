@LAZYGLOBAL OFF.
LOCAL hill_climb_lex IS LEX().

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
		LOCAL posStep IS TRUE.
		FROM { LOCAL i IS 0. } UNTIL i >= (terms * 2) STEP { SET i TO i + 1. } DO {
			stepsList:ADD(stepBlank:COPY()).
			IF posStep {
				SET stepsList[i][FLOOR(i / 2)] TO 1.
			} ELSE {
				SET stepsList[i][FLOOR(i / 2)] TO -1.
			}
			SET posStep TO NOT posStep.
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
hill_climb_lex:ADD("basic",climb_basic@).
hill_climb_lex:ADD("grad",climb_grad@).

FUNCTION climb_hill {
	PARAMETER thing,scoreFunc,stepFunc,climbData.
	LOCAL tmpFunc IS hill_climb_lex[climbData["climbType"]]@.
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