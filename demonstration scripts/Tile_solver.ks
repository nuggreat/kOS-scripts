LOCAL possibleMoves IS LIST().
LOCAL board IS LIST().
LOCAL tiles IS 25.
LOCAL setLength IS SQRT(tiles).
LOCAL doMove IS LEXICON().
LOCAL scoreMasks IS LIST().
IF tiles = 9 {
	SET possibleMoves TO LIST(
	  "rd", "rdl", "dl",
	 "rdu","rdlu","dlu",
	  "ru", "rlu", "lu"
	).
	SET doMove TO LEXICON(
		"r",  1,
		"d",  3,
		"l", -1,
		"u", -3
	).
	SET board TO LIST(
		"+----+----+----+",
		"|    |    |    |",
		"+----+----+----+",
		"|    |    |    |",
		"+----+----+----+",
		"|    |    |    |",
		"+----+----+----+"
	).
	SET scoreMasks TO LIST(LIST(0,1,2,3,4,5,6,7,8,9)).
	
} ELSE IF tiles = 16 {
	SET possibleMoves TO LIST(
	  "rd", "rdl", "rdl", "dl",
	 "rdu","rdlu","rdlu","dlu",
	 "rdu","rdlu","rdlu","dlu",
	  "ru", "rlu", "rlu", "lu"
	).
	SET doMove TO LEXICON(
		"r",  1,
		"d",  4,
		"l", -1,
		"u", -4
	).
	SET board TO LIST(
		"+----+----+----+----+",
		"|    |    |    |    |",
		"+----+----+----+----+",
		"|    |    |    |    |",
		"+----+----+----+----+",
		"|    |    |    |    |",
		"+----+----+----+----+",
		"|    |    |    |    |",
		"+----+----+----+----+"
	).
	SET scoreMasks TO LIST(
		LIST( 0, 1, 2, 3),
		LIST( 0, 1, 2, 3, 4, 8,12),
		LIST( 0, 1, 2, 3, 4, 5, 6, 7, 8, 9,10,11,12,13,14,15)
	).
	
} ELSE IF tiles = 25 {
	SET possibleMoves TO LIST(
	  "rd", "rdl", "rdl", "rdl", "dl",
	 "rdu","rdlu","rdlu","rdlu","dlu",
	 "rdu","rdlu","rdlu","rdlu","dlu",
	 "rdu","rdlu","rdlu","rdlu","dlu",
	  "ru", "rlu", "rlu", "rlu", "lu"
	).
	SET doMove TO LEXICON(
		"r",  1,
		"d",  5,
		"l", -1,
		"u", -5
	).
	SET board TO LIST(
		"+----+----+----+----+----+",
		"|    |    |    |    |    |",
		"+----+----+----+----+----+",
		"|    |    |    |    |    |",
		"+----+----+----+----+----+",
		"|    |    |    |    |    |",
		"+----+----+----+----+----+",
		"|    |    |    |    |    |",
		"+----+----+----+----+----+",
		"|    |    |    |    |    |",
		"+----+----+----+----+----+"
	).
	SET scoreMasks TO LIST(
		LIST( 0, 1, 2, 3, 4),
		LIST( 0, 1, 2, 3, 4, 5,10,15,20),
		LIST( 0, 1, 2, 3, 4, 5, 6, 7, 8, 9,10,15,20),
		LIST( 0, 1, 2, 3, 4, 5, 6, 7, 8, 9,10,11,15,16,20,21),
		LIST( 0, 1, 2, 3, 4, 5, 6, 7, 8, 9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24)
	).
	
} ELSE {
	CLEARSCREEN.
	PRINT tiles + " is not a allowed number of tiles".
	PRINT 1/0.
}

// LOCAL scoreTemplate IS LIST(16*16,"").
CLEARSCREEN.
FOR line IN board {
	PRINT Line.
}


LOCAL movesAfter IS LEXICON (
	"u",possibleMoves:JOIN(","):REPLACE("d",""):SPLIT(","),
	"r",possibleMoves:JOIN(","):REPLACE("l",""):SPLIT(","),
	"d",possibleMoves:JOIN(","):REPLACE("u",""):SPLIT(","),
	"l",possibleMoves:JOIN(","):REPLACE("r",""):SPLIT(",")
).

// LOCAL dataStart IS LIST(
	// 1,2,3,
	// 4,5,6,
	// 7,8,0
// ).

// LOCAL dataStart IS LIST(
	 // 0, 2, 3, 4,
	 // 5, 6, 7, 8,
	 // 9,10,11,12,
	// 13,14,15, 1
// ).

LOCAL dataStart IS LIST(
	 00,22,10,02,08,
	 11,18,03,09,21,
	 17,01,23,04,20,
	 16,19,12,06,14,
	 15,05,24,07,13
).
SET dataSet TO dataStart:COPY().


LOCAL dataIDX IS 0.
FROM { LOCAL i IS 0. } UNTIL i >= tiles STEP { SET i TO i + 1. } DO {
	IF dataSet[i] = 0 {
		SET dataIDX TO i.
		SET dataSet[i] TO 24.
	} ELSE {
		SET dataSet[i] TO dataSet[i]- 1.
	}
}
// PRINT dataIDX.
// display_set(dataSet).

LOCAL fullMoveSequence IS "".
LOCAL done IS FALSE.
LOCAL nextMoveSet IS possibleMoves[dataIDX].
LOCAL maskIDX IS 0.
LOCAL scoreMask IS scoreMasks[maskIDX].
LOCAL lastScore IS score_field(dataSet,scoreMask).
LOCAL bestMoveResult IS LIST(lastScore,"").
SET lastScore TO FLOOR(lastScore).
LOCAL boardLength IS board:LENGTH.
LOCAL depth IS 1.
LOCAL misses IS 0.
LOCAL doMisses IS TRUE.
UNTIL done {

	IF nextMoveSet:LENGTH = 1 {
		LOCAL forcedMove IS nextMoveSet[0].
		LOCAL stepVal IS dataIDX + doMove[forcedMove].
		LOCAL tmp IS dataSet[stepVal].
		SET dataSet[stepVal] TO dataSet[dataIDX].
		SET dataSet[dataIDX] TO tmp.
		SET fullMoveSequence TO fullMoveSequence + forcedMove.
		SET nextMoveSet TO movesAfter[forcedMove][stepVal].
		SET dataIDX TO stepVal.
		SET lastScore TO FLOOR(MIN(score_field(dataSet,scoreMask),lastScore)).
	}
	PRINT "Depth: " + CEILING(depth) + "   " AT(0,boardLength + 0).
	SET bestMoveResult TO LIST(16*16,"").
	FOR move IN nextMoveSet {
		LOCAL moveResult IS do_step(dataIDX,move,dataSet:COPY(),scoreMask,depth,"").
		IF moveResult[0] < bestMoveResult[0] {
			SET bestMoveResult TO moveResult.
		}
	}
	
	IF FLOOR(bestMoveResult[0]) <> 0 {
		IF bestMoveResult[0] < lastScore {
			LOCAL bestMove IS bestMoveResult[1][0].
			FOR move IN bestMoveResult[1] {
				LOCAL stepVal IS dataIDX + doMove[move].
				LOCAL tmp IS dataSet[stepVal].
				SET dataSet[stepVal] TO dataSet[dataIDX].
				SET dataSet[dataIDX] TO tmp.
				SET fullMoveSequence TO fullMoveSequence + move.
				SET nextMoveSet TO movesAfter[move][stepVal].
				SET dataIDX TO stepVal.
				SET lastScore TO FLOOR(MIN(score_field(dataSet,scoreMask),lastScore)).
				PRINT " Move: " + move AT(0,boardLength + 1).
				display_set(dataSet).
			}
			PRINT "Score: " + (ROUND(bestMoveResult[0],2)):TOSTRING():PADRIGHT(4) + " "+ (ROUND(lastScore,2)):TOSTRING():PADRIGHT(4) + " " AT(0,boardLength + 2).
			SET depth TO MAX(ROUND(depth - 0.5,1),0).
			IF doMisses {
				SET misses TO 0.
			}
		} ELSE {
			IF doMisses {
				SET misses TO misses + 1.
			}
			SET depth TO depth + CEILING(misses / 2).
		}
	} ELSE {
		SET maskIDX TO maskIDX + 1.
		IF maskIDX = (scoreMasks:LENGTH - 1) {
			SET doMisses TO FALSE.
			SET misses TO 2.
		}
		IF scoreMasks:LENGTH <= maskIDX {
			SET done TO TRUE.
			PRINT "full move sequence: " + fullMoveSequence.
			PRINT "Found".
			RCS OFF.
			WAIT UNTIL RCS AND SAS.
		} ELSE {
			SET scoreMask TO scoreMasks[maskIDX].
			SET lastScore TO score_field(dataSet,scoreMask).
		}
	}
	PRINT ("totalMoves: " + fullMoveSequence:LENGTH) AT(0,boardLength + 3).
	display_set(dataSet).
}

FUNCTION display_set {
	PARAMETER fieldState.
	FROM { LOCAL i IS 0. } UNTIL i >= tiles STEP { SET i TO i + 1. } DO {
		PRINT (MOD(fieldState[i] + 1,tiles)):TOSTRING():PADLEFT(2) AT(MOD(2 + i * 5,setLength * 5),FLOOR(i / setLength) * 2 + 1).
		// PRINT (fieldState[i]):TOSTRING():PADLEFT(2) AT(MOD(2 + i * 5,setLength * 5),FLOOR(i / setLength) * 2 + 1).
	}
	// SET RCS TO SAS.
	// WAIT UNTIL RCS.
}

FUNCTION do_step {
	PARAMETER idx,move,fieldState,scoreMask,recursiveCount,moveSequence.
	
	LOCAL stepVal IS idx + doMove[move].
	LOCAL tmp IS fieldState[stepVal].
	SET fieldState[stepVal] TO fieldState[idx].
	SET fieldState[idx] TO tmp.
	SET moveSequence TO moveSequence + move.
	
	IF recursiveCount > 0 {
		LOCAL bestMove IS LIST(score_field(fieldState,scoreMask),moveSequence).
		IF bestMove[0] <> 0 {
			FOR nextMove IN movesAfter[move][stepVal] {
				LOCAL moveResult IS do_step(stepVal,nextMove,fieldState:COPY(),scoreMask,recursiveCount - 1,moveSequence).
				IF moveResult[0] < bestMove[0] {
					SET bestMove TO moveResult.
				}
			}
		}
		RETURN bestMove.
	} ELSE {
		RETURN LIST(score_field(fieldState,scoreMask),moveSequence).
	}
}

FUNCTION score_field {
	PARAMETER fieldState,scoreMask.
	LOCAL scoreValue IS 0.
	FROM { LOCAL i IS 0. } UNTIL i >= tiles STEP { SET i TO i + 1. } DO {
		LOCAL targetLocation IS fieldState[i].
		LOCAL horizontalDistance IS ABS(MOD(i,5) - MOD(targetLocation,5)).
		LOCAL verticalDistance IS ABS(FLOOR(i / 5) - FLOOR(targetLocation / 5)).
		// IF scoreMask:CONTAINS(targetLocation) {
			// LOCAL horizontalDistance IS ABS(MOD(i,5) - MOD(targetLocation,5)).
			// LOCAL verticalDistance IS ABS(FLOOR(i / 5) - FLOOR(targetLocation / 5)).
			// SET scoreValue TO scoreValue + (horizontalDistance + verticalDistance).
		// }
		IF scoreMask:CONTAINS(targetLocation) {
			SET scoreValue TO scoreValue + (horizontalDistance + verticalDistance).
		} ELSE {
			SET scoreValue TO scoreValue + (horizontalDistance + verticalDistance)/250.
		}
	}
	RETURN scoreValue.
}