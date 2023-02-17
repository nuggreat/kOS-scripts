a short history of tractors in ukrainian by marina lewyeka

// LOCAL termWidth IS 102*2+1.
// LOCAL termHeight IS 51*2+1.
// LOCAL realTimeDraw IS TRUE.
// SET TERMINAL:WIDTH TO termWidth.
// SET TERMINAL:HEIGHT TO termHeight + 2.

// LOCAL termWidth IS 451.
// LOCAL termHeight IS 125.
// LOCAL realTimeDraw IS TRUE.
LOCAL termWidth IS TERMINAL:WIDTH.
LOCAL termHeight IS TERMINAL:HEIGHT - 2.
IF MOD(termHeight,2) = 0 {
	SET termHeight TO termHeight - 1.
}
LOCAL realTimeDraw IS FALSE.
LOCAL patternDither IS TRUE.

IF (realTimeDraw AND (MOD(termWidth,2) = 1)) {
	SET termWidth TO termWidth - 1.
}

CLEARSCREEN.
FROM { LOCAL i IS 0. } UNTIL i >= termHeight STEP { SET i TO i + 1. } DO {
	PRINT " ".
}

LOCAL ditherSet IS LIST(" ","░","▒","▓","█").
LOCAL drawMap IS LIST().

IF patternDither {
SET drawMap TO  LIST(
	LIST(
		"  ",
		"░ ",
		"░░",
		"▒░",
		"▒▒",
		"▓▒",
		"▓▓",
		"█▓",
		"██"
	),
	LIST(
		"  ",
		" ░",
		"░░",
		"░▒",
		"▒▒",
		"▒▓",
		"▓▓",
		"▓█",
		"██"
	)
).
} ELSE {
  SET drawMap TO LIST(0,1,2,3,4,5,6,7,8,9,"a","b","c","d","e","f","g","h","i","j","k","l","m","n","o","p","q","r","s","t","u","v","w","x","y","z").
}

LOCAL scaleFactor IS 1 / (termWidth / 4).
LOCAL xOffset IS -1.
LOCAL yOffset IS 0.
LOCAL xMin IS -termWidth / 2 * scaleFactor + xOffset.
LOCAL xMax IS  termWidth / 2 * scaleFactor + xOffset.
LOCAL yMin IS -termHeight * scaleFactor + yOffset.
LOCAL yMax IS  termHeight * scaleFactor + yOffset.
// PRINT xMin  +"," + xMax.
// PRINT yMin + "," + yMax.
// WAIT UNTIL FALSE.
draw(xMax,xMin,yMax,yMin,realTimeDraw,36).

FUNCTION draw {
	PARAMETER xMax,xMin,yMax,yMin,realTimeDraw,cycles IS 100.
	SET cycles TO MAX(cycles,drawMap[0]:LENGTH).
	LOCAL cyclesScaling IS (cycles + 1) / drawMap[0]:LENGTH.
	//x axis is real numbers
	//y axis is imaginary numbers
	LOCAL data IS LIST().
	LOCAL xStep IS (xMax - xMin) / (termWidth - 1).
	LOCAL yStep IS (yMax - yMin) / (termHeight - 1).
	
	LOCAL widthInc IS 1.
	IF realTimeDraw {
		PRINT "█" AT(0,0).
		SET widthInc TO CHOOSE 2 IF patternDither ELSE 1.
	}
	LOCAL localDrawMap IS LIST().
	LOCAL hStep IS 100 / termHeight.
	LOCAL wStep IS hStep / termWidth.
	LOCAL frac IS 0.
	FROM { LOCAL h IS 0. } UNTIL h >= termHeight STEP { SET h TO h + 1. } DO {
		LOCAL row IS LIST().
		data:ADD(row).
		LOCAL imaginaryComponent IS h * yStep + yMin.
		IF realTimeDraw {
			SET localDrawMap TO drawMap[MOD(h,2)].
		} ELSE {
			SET frac TO h * hStep.
			PRINT "█" AT(0,h).
		}
		FROM { LOCAL w IS 0. } UNTIL w >= termWidth STEP { SET w TO w + widthInc. } DO {
			IF realTimeDraw {
				PRINT "█" AT(w,h).
			} ELSE {
				PRINT ROUND(frac + w * wStep,3) + "     " AT(0,0).
			}
			LOCAL realComponent IS w * xStep + xMin.
			LOCAL cc IS LEXICON("real",realComponent,"imaginary",imaginaryComponent).
			LOCAL containedResult IS contained_test(cc,cycles).
			row:ADD(containedResult).
			IF realTimeDraw {
				//PRINT (CHOOSE drawMap[FLOOR(containedResult / cyclesScaling)] IF containedResult > 0 ELSE " ") AT(w,h).
				//dither_print(FLOOR(containedResult/cyclesScaling),w,h).
				PRINT localDrawMap[FLOOR(containedResult/cyclesScaling)] AT(w,h).
			}
		}
	}
	IF NOT realTimeDraw {
		PRINT "100        " AT(0,0).
		dither(data,cycles).
	}
	RETURN data.
}

FUNCTION contained_test {
	PARAMETER cc,maxCycles.
	LOCAL cReal IS cc["real"].
	LOCAL cImaginary IS cc["imaginary"].
	LOCAL zReal IS 0.
	LOCAL zImaginary IS 0.
	LOCAL tempReal IS 0.
	LOCAL tempImaginary TO 0.
	FROM { LOCAL i IS 0. } UNTIL i >= maxCycles STEP { SET i TO i + 1. } DO {
		IF (zReal * zReal + zImaginary * zImaginary) > 4 {
			RETURN maxCycles - i.
		} ELSE {
			SET tempReal TO zReal + zImaginary * zImaginary.
			SET tempImaginary TO zReal * zImaginary * 2.
			SET zReal TO tempReal + cReal.
			SET zImaginary TO tempImaginary + cImaginary.
		}
	}
	RETURN 0.
}

// FUNCTION contained_test {
	// PARAMETER cc,maxCycles.
	// LOCAL zz IS LEXICON("real",0, "imaginary",0).
	// FROM { LOCAL i IS 0. } UNTIL i >= maxCycles STEP { SET i TO i + 1. } DO {
		// IF imaginary_square_magnitude(zz) > 4 {
			// RETURN maxCycles - i.
		// } ELSE {
			// SET zz TO imaginary_add(imaginary_mult(zz,zz),cc).
		// }
	// }
	// RETURN 0.
// }

// FUNCTION imaginary_add {
	// PARAMETER numA,numB.
	// RETURN LEXICON("real",numA["real"] + numB["real"], "imaginary",numA["imaginary"] + numB["imaginary"]). 
// }

// FUNCTION imaginary_mult {
	// PARAMETER numA,numB.
	// LOCAL aa IS numA["real"] * numB["real"].
	// LOCAL bb IS numA["real"] * numB["imaginary"] + numA["imaginary"] * numB["real"].
	// LOCAL cc IS numA["imaginary"] * numB["imaginary"].
	// RETURN LEXICON("real",aa - cc, "imaginary",bb).
// }

// FUNCTION imaginary_square_magnitude {
	// PARAMETER num.
	// RETURN num["real"]^2 + num["imaginary"]^2.
// }

FUNCTION dither {
	PARAMETER dataSet,cycles.
	LOCAL maxYvalue IS dataSet:LENGTH.
	LOCAL maxXvalue IS dataSet[0]:LENGTH.
	LOCAL scaleFactor IS (cycles + 0) / (ditherSet:LENGTH - 1).
	LOCAL maxDither IS ditherSet:LENGTH - 1.
	PRINT "copying" AT(0,0).
	LOCAL ditheredData IS list_deep_copy(dataSet).
	PRINT "rendering" AT(0,0).
	// LOCAL ditherKernel IS LIST(
		// LIST(0,1),
		// LIST(1,0)
	// ).
	LOCAL ditherKernel IS LIST(
		LIST(0,0,0,7,5),
		LIST(3,5,7,5,3),
		LIST(1,3,5,3,1)
	).
	// LOCAL ditherKernel IS LIST(
		// LIST(0,0,0,8,4),
		// LIST(2,4,8,4,2)
	// ).
	// LOCAL ditherKernel IS LIST (
		// LIST( 0, 0, 0, 0, 0,16, 8, 4, 2, 1),
		// LIST( 1, 2, 4, 8,16, 8, 4, 2, 1, 0),
		// LIST( 0, 1, 2, 4, 8, 4, 2, 1, 0, 0),
		// LIST( 0, 0, 1, 2, 4, 2, 1, 0, 0, 0),
		// LIST( 0, 0, 0, 1, 2, 1, 0, 0, 0, 0),
		// LIST( 0, 0, 0, 0, 1, 0, 0, 0, 0, 0)
	// ).
	LOCAL kernelYmax IS ditherKernel:LENGTH.
	LOCAL kernelXmax IS ditherKernel[0]:LENGTH.
	LOCAL widthOffset IS kernal_tune(ditherKernel).
	// PRINT widthOffset.
	
	FROM { LOCAL h IS 0. } UNTIL h >= termHeight STEP { SET h TO h + 1. } DO {
		FROM { LOCAL w IS 0. } UNTIL w >= termWidth STEP { SET w TO w + 1. } DO {
			LOCAL dataPoint IS ditheredData[h][w] / scaleFactor.
			LOCAL pointValue IS MAX(MIN(ROUND(dataPoint),maxDither),0).
			LOCAL pointError IS (dataPoint - pointValue).
			// PRINT dataPoint AT(0,0).
			// PRINT pointValue AT(0,1).
			// PRINT pointError AT(0,2).
			// PRINT dataSet[h][w] AT(0,3).
			// SET RCS TO SAS.
			// WAIT UNTIL RCS.
			PRINT ditherSet[pointValue] AT(w,h).
			SET pointError TO pointError * scaleFactor.
			FROM { LOCAL i IS 0. } UNTIL i >=kernelYmax STEP { SET i TO i + 1. } DO {
				LOCAL yChord IS i + h.
				// PRINT "ych" + yChord.
				IF yChord >= maxYvalue {
					BREAK.
				} ELSE {
					LOCAL kernalLine IS ditherKernel[i].
					FROM { LOCAL j IS 0. } UNTIL j >= kernelXmax STEP { SET j TO j + 1. } DO {
						LOCAL xChord IS j + w + widthOffset.
						// PRINT "xch" + xChord.
						IF xChord >= 0 AND xChord < maxXvalue {
							SET ditheredData[yChord][xChord] TO MAX(MIN((ditheredData[yChord][xChord] + pointError * kernalLine[j]),cycles),0).
						}
					}
				}
			}
		}
	}
}

FUNCTION kernal_tune {
	PARAMETER kernel.
	LOCAL divisor IS 0.
	FOR i IN kernel {
		FOR j IN i {
			SET divisor TO divisor + j.
		}
	}
	FROM { LOCAL i IS kernel:LENGTH - 1. } UNTIL i < 0 STEP { SET i TO i - 1. } DO {
		FROM { LOCAL j IS kernel[0]:LENGTH - 1. } UNTIL j < 0 STEP { SET j TO j - 1. } DO {
			SET kernel[i][j] TO kernel[i][j] / divisor.
		}
	}
	LOCAL widthOffset IS 1.
	FOR i IN kernel[0] {
		IF i = 0 {
			SET widthOffset TO widthOffset - 1.
		} ELSE {
			BREAK.
		}
	}
	RETURN widthOffset.
}

FUNCTION list_deep_copy {
	PARAMETER toCopy, depth IS 5.
	IF depth >= 0 {
		IF toCopy:ISTYPE("list") {
			LOCAL newList IS LIST().
			FOR i IN toCopy {
				newList:ADD(list_deep_copy(i,depth - 1)).
			}
		}
	}
	RETURN toCopy.
}