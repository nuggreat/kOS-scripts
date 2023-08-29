LOCAL moveSets IS LIST().
LOCAL board IS LIST().
LOCAL tiles IS 25.
LOCAL setLength IS SQRT(tiles).
LOCAL scoreMasks IS LIST().
LOCAL doMove IS LEXICON().
IF tiles = 9 {
	SET moveSets TO LIST(
		LIST(
		  "rd", "rdl", "dl",
		 "rdu","rdlu","dlu",
		  "ru", "rlu", "lu"
		),
		LIST(
		    "",    "",   "",
		  "rd", "rdl", "dl",
		  "ru", "rlu", "lu"
		),
		LIST(
		  "",   "",   "",
		  "", "rd", "dl",
		  "", "ru", "lu"
		)
	).
	// SET possibleMoves TO LIST(
	  // "rd", "rdl", "dl",
	 // "rdu","rdlu","dlu",
	  // "ru", "rlu", "lu"
	// ).
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
	SET scoreMasks TO LIST(
		LIST(0,1,2),
		LIST(0,1,2,3,6),
		LIST(0,1,2,3,4,5,6,7,8)
	).
	
} ELSE IF tiles = 16 {
	SET moveSets TO LIST(
		LIST(
		  "rd", "rdl", "rdl", "dl",
		 "rdu","rdlu","rdlu","dlu",
		 "rdu","rdlu","rdlu","dlu",
		  "ru", "rlu", "rlu", "lu"
		),
		LIST(
			"",    "",    "",   "",
		 " rd", "rdl", "rdl"," dl",
		 "rdu","rdlu","rdlu","dlu",
		  "ru", "rlu", "rlu", "lu"
		),
		LIST(
		 "",   "",    "",   "",
		 "", "rd", "rdl"," dl",
		 "","rdu","rdlu","dlu",
		 "", "ru", "rlu", "lu"
		),
		LIST(
		 "",   "",    "",   "",
		 "",   "",    "",   "",
		 "", "rd", "rdl"," dl",
		 "", "ru", "rlu", "lu"
		),
		LIST(
		 "",   "",   "",   "",
		 "",   "",   "",   "",
		 "",   "", "rd"," dl",
		 "",   "", "ru", "lu"
		)
	).
	// SET possibleMoves TO LIST(
	  // "rd", "rdl", "rdl", "dl",
	 // "rdu","rdlu","rdlu","dlu",
	 // "rdu","rdlu","rdlu","dlu",
	  // "ru", "rlu", "rlu", "lu"
	// ).
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
		LIST( 0, 1, 2, 3, 4, 5, 6, 7, 8,12),
		LIST( 0, 1, 2, 3, 4, 5, 6, 7, 8, 9,12,13),
		LIST( 0, 1, 2, 3, 4, 5, 6, 7, 8, 9,10,11,12,13,14,15)
	).
	
} ELSE IF tiles = 25 {
	SET moveSets TO LIST(
		LIST(
		  "rd", "rdl", "rdl", "rdl", "dl",
		 "rdu","rdlu","rdlu","rdlu","dlu",
		 "rdu","rdlu","rdlu","rdlu","dlu",
		 "rdu","rdlu","rdlu","rdlu","dlu",
		  "ru", "rlu", "rlu", "rlu", "lu"
		),
		LIST(
		    "",    "",    "",    "",   "",
		  "rd", "rdl", "rdl", "rdl", "dl",
		 "rdu","rdlu","rdlu","rdlu","dlu",
		 "rdu","rdlu","rdlu","rdlu","dlu",
		  "ru", "rlu", "rlu", "rlu", "lu"
		),
		LIST(
		 "",    "",    "",    "",   "",
		 "",  "rd", "rdl", "rdl", "dl",
		 "", "rdu","rdlu","rdlu","dlu",
		 "", "rdu","rdlu","rdlu","dlu",
		 "",  "ru", "rlu", "rlu", "lu"
		),
		LIST(
		 "",    "",    "",    "",   "",
		 "",    "",    "",    "",   "",
		 "",  "rd", "rdl", "rdl", "dl",
		 "", "rdu","rdlu","rdlu","dlu",
		 "",  "ru", "rlu", "rlu", "lu"
		),
		LIST(
		 "","",    "",    "",   "",
		 "","",    "",    "",   "",
		 "","",  "rd", "rdl", "dl",
		 "","", "rdu","rdlu","dlu",
		 "","",  "ru", "rlu", "lu"
		),
		LIST(
		 "","",    "",    "",   "",
		 "","",    "",    "",   "",
		 "","",    "",    "",   "",
		 "","",  "rd", "rdl", "dl",
		 "","",  "ru", "rlu", "lu"
		),
		LIST(
		 "","","",    "",   "",
		 "","","",    "",   "",
		 "","","",    "",   "",
		 "","","",  "rd", "dl",
		 "","","",  "ru", "lu"
		)
	).
	// SET possibleMoves TO LIST(
	  // "rd", "rdl", "rdl", "rdl", "dl",
	 // "rdu","rdlu","rdlu","rdlu","dlu",
	 // "rdu","rdlu","rdlu","rdlu","dlu",
	 // "rdu","rdlu","rdlu","rdlu","dlu",
	  // "ru", "rlu", "rlu", "rlu", "lu"
	// ).
	SET doMove TO LEXICON(
		"r",  1,
		"d",  5,
		"l", -1,
		"u", -5
	).
	SET board TO LIST(
		"+----+----+----+----+----+",
		"|    |    |    |    |    |",// 0, 1, 2, 3, 4
		"+----+----+----+----+----+",
		"|    |    |    |    |    |",// 5, 6, 7, 8, 9
		"+----+----+----+----+----+",
		"|    |    |    |    |    |",//10,11,12,13,14
		"+----+----+----+----+----+",
		"|    |    |    |    |    |",//15,16,17,18,19
		"+----+----+----+----+----+",
		"|    |    |    |    |    |",//20,21,22,23,24
		"+----+----+----+----+----+"
	).
	SET scoreMasks TO LIST(
		LIST( 0, 1, 2, 3, 4),
		LIST( 0, 1, 2, 3, 4, 5,10,15,20),
		LIST( 0, 1, 2, 3, 4, 5, 6, 7, 8, 9,10,15,20),
		LIST( 0, 1, 2, 3, 4, 5, 6, 7, 8, 9,10,11,15,16,20,21),
		LIST( 0, 1, 2, 3, 4, 5, 6, 7, 8, 9,10,11,12,13,14,15,16,20,21),
		LIST( 0, 1, 2, 3, 4, 5, 6, 7, 8, 9,10,11,12,13,14,15,16,17,20,21,22),
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
LOCAL boardLength IS board:LENGTH.

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
LOCAL lastMove IS "noMove".
LOCAL maskIDX IS 0.
LOCAL scoreMask IS scoreMasks[maskIDX].
LOCAL moveSet IS moveSets[maskIDX].
LOCAL movesAfter IS LEXICON (
	"u",moveSet:JOIN(","):REPLACE("d",""):SPLIT(","),
	"r",moveSet:JOIN(","):REPLACE("l",""):SPLIT(","),
	"d",moveSet:JOIN(","):REPLACE("u",""):SPLIT(","),
	"l",moveSet:JOIN(","):REPLACE("r",""):SPLIT(","),
	"noMove",moveSet
).
LOCAL moveResults IS LIST(FALSE,score_field(dataSet,scoreMask),"").
LOCAL depthPersist IS 5.

UNTIL done {
	LOCAL haveBetter IS FALSE.
	LOCAL depth IS depthPersist.
	PRINT "working" AT(0,boardLength + 0).
	UNTIL FALSE {
		PRINT "Depth: " + depth + "   " AT(0,boardLength + 1).
		LOCAL results IS find_better_score(dataIDX,lastMove,moveResults[1],dataSet,scoreMask,depth,"").
		IF results[0] {
			SET moveResults TO results.
			BREAK.
		} ELSE {
			SET depth TO depth + 5.
		}
	}
	IF moveResults[2]:LENGTH > depthPersist {
		SET depthPersist TO depthPersist + 1.
	} ELSE {
		SET depthPersist TO MAX(depthPersist - 1,5).
	}
	PRINT "done   " + CHAR(7) AT(0,boardLength + 0).
	PRINT "Score: " + moveResults[1] + "     " AT(0,boardLength + 2).
	SET fullMoveSequence TO fullMoveSequence + moveResults[2].
	RCS OFF.
	
	FOR move IN moveResults[2] {
		LOCAL stepVal IS dataIDX + doMove[move].
		LOCAL tmp IS dataSet[stepVal].
		SET dataSet[stepVal] TO dataSet[dataIDX].
		SET dataSet[dataIDX] TO tmp.
		SET dataIDX TO stepVal.
		PRINT " Move: " + move AT(0,boardLength + 3).
		display_set(dataSet).
	}
	PRINT ("totalMoves: " + fullMoveSequence:LENGTH) AT(0,boardLength + 5).
	
	IF moveResults[1] = 0 {
		SET maskIDX TO maskIDX + 1.
		IF scoreMasks:LENGTH <= maskIDX {
			SET done TO TRUE.
			PRINT "full move sequence: " + fullMoveSequence.
		} ELSE {
			SET scoreMask TO scoreMasks[maskIDX].
			SET moveSet TO moveSets[maskIDX].
			SET movesAfter["u"] TO moveSet:JOIN(","):REPLACE("d",""):SPLIT(",").
			SET movesAfter["r"] TO moveSet:JOIN(","):REPLACE("l",""):SPLIT(",").
			SET movesAfter["d"] TO moveSet:JOIN(","):REPLACE("u",""):SPLIT(",").
			SET movesAfter["l"] TO moveSet:JOIN(","):REPLACE("r",""):SPLIT(",").
			SET moveResults[1] TO score_field(dataSet,scoreMask).
		}
	}
	
	// IF bestMoveResult[0] <> 0 {
		// LOCAL bestMove IS bestMoveResult[1][0].
		// LOCAL stepVal IS dataIDX + doMove[bestMove].
		// LOCAL tmp IS dataSet[stepVal].
		// SET dataSet[stepVal] TO dataSet[dataIDX].
		// SET dataSet[dataIDX] TO tmp.
		// SET fullMoveSequence TO fullMoveSequence + bestMove.
		// SET nextMoveSet TO movesAfter[bestMove][stepVal].
		// SET dataIDX TO stepVal.
		// PRINT " Move: " + bestMove AT(0,boardLength + 0).
		// PRINT "Score: " + bestMoveResult[0] + "     " AT(0,boardLength + 1).
	// } ELSE {
	
	// }
}

FUNCTION display_set {
	PARAMETER fieldState.
	FROM { LOCAL i IS 0. } UNTIL i >= tiles STEP { SET i TO i + 1. } DO {
		PRINT (MOD(fieldState[i] + 1,tiles)):TOSTRING():PADLEFT(2) AT(MOD(2 + i * 5,setLength * 5),FLOOR(i / setLength) * 2 + 1).
		// PRINT (fieldState[i]):TOSTRING():PADLEFT(2) AT(MOD(2 + i * 5,setLength * 5),FLOOR(i / setLength) * 2 + 1).
	}
	SET RCS TO SAS.
	WAIT UNTIL RCS.
}

FUNCTION find_better_score {
	PARAMETER idxOld,lastMove,scoreToBeat,oldState,scoreMask,recursiveCount,moveSequence.
	FOR move IN movesAfter[lastMove][idxOld] {
		LOCAL newState IS oldState:COPY().
		
		LOCAL idxNew IS idxOld + doMove[move].
		SET newState[idxNew] TO oldState[idxOld].
		SET newState[idxOld] TO oldState[idxNew].
		
		LOCAL newScore IS score_field(newState,scoreMask).
		IF newScore < scoreToBeat {
			RETURN LIST(TRUE,newScore,moveSequence + move).
		} ELSE {
			IF recursiveCount > 0 {
				LOCAL result IS find_better_score(idxNew,move,scoreToBeat,newState,scoreMask,recursiveCount - 1,moveSequence + move).
				IF result[0] {
					RETURN result.
				}
			}
		}
	}
	RETURN LIST(FALSE).
}

FUNCTION score_field {
	PARAMETER fieldState,scoreMask.
	LOCAL scoreValue IS 0.
	FROM { LOCAL i IS 0. } UNTIL i >= tiles STEP { SET i TO i + 1. } DO {
		LOCAL targetLocation IS fieldState[i].
		IF scoreMask:CONTAINS(targetLocation) {
			LOCAL horizontalDistance IS ABS(MOD(i,5) - MOD(targetLocation,5)).
			LOCAL verticalDistance IS ABS(FLOOR(i / 5) - FLOOR(targetLocation / 5)).
			SET scoreValue TO scoreValue + horizontalDistance + verticalDistance.
		}
	}
	RETURN scoreValue.
}