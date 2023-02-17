LOCAL bufferDefault IS LEXICON(
	"top",1,
	"bottom",1,
	"left",1,
	"right",1
).

FUNCTION game_init {
	PARAMETER
	setScreenResolution IS TRUE, //if true will set the terminal dimensions, if false will use current terminal dimensions
	screenX IS 25, //the width of the game space
	screenY IS 25, //the height of the game space
	desiredCharHeight IS 8,

	boardWrap IS FALSE, //if the top/bottom and left/right should wrap around
	resumeFromLog IS FALSE,
	baseLogPath IS "0:/game of life/frames/",
	offScreenBuffers IS bufferDefault. //immutable padding added around game space
		//must be large enough that all rules queries do not exceed game space
		//if the rules query one above,below,left, and right of active cell then all padding directions must be at least 1

	LOCAL oldWidth IS TERMINAL:WIDTH.
	LOCAL oldHeight IS TERMINAL:HEIGHT.
	LOCAL oldCharHeight IS TERMINAL:CHARHEIGHT.
	//terminal configuration
	IF setScreenResolution {
		SET TERMINAL:WIDTH TO screenX * 2.
		SET TERMINAL:HEIGHT TO screenY + 3.
		SET TERMINAL:CHARHEIGHT TO desiredCharHeight.
	} ELSE {
		SET screenX TO FLOOR(TERMINAL:WIDTH / 2,0).
		SET screenY TO TERMINAL:HEIGHT - 3.
		SET TERMINAL:CHARHEIGHT TO desiredCharHeight.
	}

	CLEARSCREEN.//setting up the screen
	FROM { LOCAL i IS 0. } UNTIL i > screenY STEP { SET i TO i + 1. } DO {
		PRINT " ".
	}

	IF boardWrap {
		SET offScreenBuffers TO LEXICON(
			"top",0,
			"bottom",0,
			"left",0,
			"right",0
		).
	}

	LOCAL members IS LEXICON().

	//logging and export related data
	LOCAL startTime IS TIME:SECONDS.
	LOCAL frameCount IS 0.
	LOCAL oldTime IS TIME:SECONDS.
	LOCAL returnString IS "".
	LOCAL deltaPath IS baseLogPath + "delta.txt".
	LOCAL frameLogPath IS baseLogPath + "frame".
	LOCAL logPath IS frameLogPath.

	//frame configuration
	LOCAL sourceIsArrayA IS TRUE.
	LOCAL xStart IS offScreenBuffers["top"].
	LOCAL xEnd IS xStart + screenX.
	LOCAL yStart IS offScreenBuffers["left"].
	LOCAL yEnd IS yStart + screenY.
	LOCAL xLength IS screenX + offScreenBuffers["right"] + offScreenBuffers ["left"].
	LOCAL yLength IS screenY + offScreenBuffers["top"] + offScreenBuffers ["bottom"].

	//frame generation
	LOCAL arrayA IS LIST().
	LOCAL arrayB IS LIST().
	LOCAL rawLine IS ".":PADRIGHT(xLength).
	SET rawLine TO rawLine:REPLACE(" ", ",.").
	SET rawLine TO rawLine:REPLACE(".", "  ").
	LOCAL rawLine IS rawLine:SPLIT(",").

	UNTIL arrayA:LENGTH >= yLength {
		arrayA:ADD(rawLine:COPY()).
		arrayB:ADD(rawLine:COPY()).
	}
	
	//frame query vars
	LOCAL xBase IS 0.
	LOCAL yBase IS 0.
	LOCAL queryFrame IS arrayA.


	//clearing old data or resuming from past run
	IF resumeFromLog {
		UNTIL NOT EXISTS(baseLogPath + "frame" + frameCount:TOSTRING():PADLEFT(5):REPLACE(" ","0") + ".txt") {
			SET frameCount TO frameCount + 1.
		}
	} ELSE {
		LOCAL rootVolume IS PATH(baseLogPath):VOLUME.
		LOCAL workingDirectory IS rootVolume.
		LOCAL fullPath IS "".
		FOR segment IN PATH(baseLogPath):SEGMENTS {
			SET fullPath TO fullPath + segment + "/".
			IF NOT rootVolume:EXISTS(fullPath) {
				rootVolume:CREATEDIR(fullPath).
			}
			SET workingDirectory TO rootVolume:OPEN(fullPath).
		}
		FOR item IN workingDirectory:LEX:KEYS {
			rootVolume:DELETE(fullPath + item).
		}
	}

	LOCAL frame_query IS CHOOSE {
		PARAMETER arg1,arg2,queryType IS "point".
		IF queryType = "point" {
			// arg1 is the x offset from current position
			// arg2 is the y offset from current position
			RETURN queryFrame[MOD(yBase + arg2,yLength)][MOD(xBase + arg1,xLength)].
		} ELSE {// IF queryType = "count" {
			// arg1 is the list of (x,y) pairs offsets from current position
			// arg2 is the type of cell that will increment the counter
			LOCAL neighborCount IS 0.
			FOR offsets IN arg1 {
				IF queryFrame[MOD(yBase + offsets[1],yLength)][MOD(xBase + offsets[0],xLength)] = arg2 {
					SET neighborCount TO neighborCount + 1.
				}
			}
			// FOR offsets IN arg1 {
				// LOCAL yLine IS frame[MOD(yBase + offsets[0],yLength)].
				// FOR xOffset IN offsets[1] {
					// IF yLine[MOD(xBase + offsets[0],xLength)] = arg2 {
						// SET neighborCount TO neighborCount + 1.
					// }
				// }
			// }
			RETURN neighborCount.
		}
	} IF boardWrap ELSE {
		PARAMETER arg1,arg2,queryType.// IS "point".
		IF queryType = "point" {
			// arg1 is the x offset from current position
			// arg2 is the y offset from current position
			RETURN queryFrame[yBase + arg2][xBase + arg1].
		} ELSE {// IF queryType = "count" {
			// arg1 is the list of [x,y] pairs offsets from current position
			// arg2 is the type of cell that will increment the counter
			LOCAL neighborCount IS 0.
			FOR offsets IN arg1 {
				IF queryFrame[yBase + offsets[1]][xBase + offsets[0]] = arg2 {
					SET neighborCount TO neighborCount + 1.
				}
			}
			// FOR offsets IN arg1 {
				// LOCAL yLine IS frame[yBase + offsets[0]].
				// FOR xOffset IN offsets[1] {
					// IF yLine[xBase + xOffset] = arg2 {
						// SET neighborCount TO neighborCount + 1.
					// }
				// }
			// }
			RETURN neighborCount.
		}
	}.

	members:ADD("inject", {
		PARAMETER pattern,xOrigin,yOrigin,doublePattern IS TRUE.
		LOCAL activeFrame IS CHOOSE arrayA IF sourceIsArrayA ELSE arrayB.
		SET xOrigin TO MIN(screenX - 1,MAX(0,xOrigin)) + xStart.
		SET yOrigin TO MIN(screenY - 1,MAX(0,yOrigin)) + yStart.
		LOCAL frameXcord IS 0.
		LOCAL frameYcord IS 0.
		LOCAL yLoopEnd IS pattern:LENGTH.
		LOCAL xLoopEnd IS pattern[0]:LENGTH.
		FROM { LOCAL yy IS 0. } UNTIL yy >= yLoopEnd STEP { SET yy TO yy + 1. } DO {
			IF boardWrap {
				SET frameYcord TO MOD(yOrigin + yy,screenY).
			} ELSE {
				SET frameYcord TO yOrigin + yy.
				IF frameYcord >= screenY {
					BREAK.
				}
			}
			FROM { LOCAL xx IS 0. } UNTIL xx >= xLoopEnd STEP { SET xx TO xx + 1. } DO {
				IF boardWrap {
					SET frameXcord TO MOD(xOrigin + xx,screenX).
				} ELSE {
					SET frameXcord TO xOrigin + xx.
					IF frameXcord >= screenX {
						BREAK.
					}
				}

				LOCAL newCell IS CHOOSE pattern[yy][xx] + pattern[yy][xx] IF doublePattern ELSE pattern[yy][xx].
				SET activeFrame[frameYcord][frameXcord] TO newCell.
			}
		}
	}).
	members:ADD("getCount", {
		RETURN frameCount.
	}).
	members:ADD("logElapsed", {
		LOCAL totalTime IS TIME:SECONDS - startTime.
		LOG "Total Time: " + ROUND(TIME:SECONDS - startTime,2) TO deltaPath.
		LOG "Per Frame:  " + ROUND(totalTime / (frameCount + 1),4) TO deltaPath.
	}).
	members:ADD("advanceState", {
		PARAMETER rules,advanceCount IS TRUE.
		LOCAL newFrame IS CHOOSE arrayB IF sourceIsArrayA ELSE arrayA.
		LOCAL oldFrame IS CHOOSE arrayA IF sourceIsArrayA ELSE arrayB.
		SET queryFrame TO oldFrame.
		// FROM { LOCAL yy IS yStart. } UNTIL yy >= yEnd STEP { SET yy TO yy + 1. } DO {
			// LOCAL yLine IS newFrame[yy].
			// SET yBase TO yy.
			// FROM { LOCAL xx IS xStart. } UNTIL xx >= xEnd STEP { SET xx TO xx + 1. } DO {
				// SET xBase TO xx.
				// SET yLine[xx] TO rules(frame_query@).
			// }
		// }
		SET yBase TO yStart.
		UNTIL yBase >= yEnd {
			LOCAL yLine IS newFrame[yy].
			SET xBase TO xStart.
			UNTIL xBase >= xEnd {
				SET yLine[xx] TO rules(frame_query@).
				SET xBase TO xBase + 1.
			}
			SET yBase TO yBase + 1.
		}
		
		SET sourceIsArrayA TO NOT sourceIsArrayA.
		IF advanceCount {
			SET frameCount TO frameCount + 1.
		}
	}).
	members:ADD("exportState", {
		PARAMETER doRender IS TRUE, doLogging IS TRUE, doReturn IS FALSE.
		LOCAL currentState IS CHOOSE arrayA IF sourceIsArrayA ELSE arrayB.
		IF doLogging {
			SET logPath TO frameLogPath + frameCount:TOSTRING():PADLEFT(5):REPLACE(" ","0") + ".txt".
			SET newTime TO TIME:SECONDS.
			LOG ROUND(newTime - oldTime,2) TO deltaPath.
			SET oldTime TO newTime.
		}
		IF doReturn {
			SET returnString TO "".
		}
		FROM { LOCAL yy IS xStart. } UNTIL yy >= yEnd STEP { SET yy TO yy + 1. } DO {
			LOCAL line IS currentState[yy]:JOIN("").
			// PRINT "newPass" + yy.
			// PRINT line:LENGTH.
			// PRINT xEnd * 2 - 0.
			// PRINT (xLength - xEnd) * 2.
			SET line TO line:REMOVE(xEnd * 2 - 0,(xLength - xEnd) * 2).
			SET line TO line:REMOVE(0,xStart * 2).
			IF doRender {
				PRINT line AT(0,yy-yStart).
			}
			IF doLogging {
				LOG line TO logPath.
			}
			IF doReturn {
				SET returnString TO returnString + line.
			}
		}
		IF doReturn {
			RETURN returnString.
		}
	}).
	members:ADD("restoreTerminal", {
		SET TERMINAL:WIDTH TO oldWidth.
		SET TERMINAL:HEIGHT TO oldHeight.
		SET TERMINAL:CHARHEIGHT TO oldCharHeight.
	}).
	RETURN members.
}