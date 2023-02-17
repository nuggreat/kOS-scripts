LOCAL termWidth IS 102*2+1.
LOCAL termHeight IS 51*2+1.
LOCAL realTimeDraw IS TRUE.
SET TERMINAL:WIDTH TO termWidth.
SET TERMINAL:HEIGHT TO termHeight + 2.

IF realTimeDraw {
	CLEARSCREEN.
	FROM { LOCAL i IS 0. } UNTIL i >= termHeight+2 STEP { SET i TO i + 1. } DO {
		PRINT " ".
	}
}

LOCAL drawMap IS LIST(
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

LOCAL scaleFactor IS 0.5.
draw(1,-3,1,-1,realTimeDraw,27).

FUNCTION draw {
	PARAMETER xMax,xMin,yMax,yMin,realTimeDraw,cycles IS 100.
	SET cycles TO MAX(cycles,drawMap[0]:LENGTH).
	LOCAL cyclesScaling IS (cycles + 1) / drawMap[0]:LENGTH.
	//x axis is real numbers
	//y axis is imaginary numbers
	LOCAL data IS LIST().
	LOCAL xStep IS (xMax - xMin) / (termWidth - 1).
	LOCAL yStep IS (yMax - yMin) / (termHeight - 1).
	
	IF realTimeDraw {
		PRINT "█" AT(0,0).
	}
	
	FROM { LOCAL h IS 0. } UNTIL h >= termHeight STEP { SET h TO h + 1. } DO {
		LOCAL row IS LIST().
		data:ADD(row).
		LOCAL imaginaryComponent IS h * yStep + yMin.
		LOCAL localDrawMap IS drawMap[MOD(h,2)].
		FROM { LOCAL w IS 0. } UNTIL w >= termWidth STEP { SET w TO w + 2. } DO {
			PRINT "█" AT(w,h).
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
	RETURN data.
}

FUNCTION dither_print {
	PARAMETER iChar,w,h.
	PRINT drawMap[iChar][0] AT(w,h).
	PRINT drawMap[iChar][1] AT(w,h+1).
}

FUNCTION contained_test {
	PARAMETER cc,maxCycles.
	LOCAL zz IS LEXICON("real",0, "imaginary",0).
	FROM { LOCAL i IS 0. } UNTIL i >= maxCycles STEP { SET i TO i + 1. } DO {
		IF imaginary_magnitude(zz) > 10 {
			RETURN maxCycles - i.
		} ELSE {
			SET zz TO imaginary_add(imaginary_mult(zz,zz),cc).
		}
	}
	RETURN 0.
}


FUNCTION imaginary_add {
	PARAMETER numA,numB.
	RETURN LEXICON("real",numA["real"] + numB["real"], "imaginary",numA["imaginary"] + numB["imaginary"]). 
}

FUNCTION imaginary_mult {
	PARAMETER numA,numB.
	LOCAL aa IS numA["real"] * numB["real"].
	LOCAL bb IS numA["real"] * numB["imaginary"] + numA["imaginary"] * numB["real"].
	LOCAL cc IS numA["imaginary"] * numB["imaginary"].
	RETURN LEXICON("real",aa - cc, "imaginary",bb).
}

FUNCTION imaginary_magnitude {
	PARAMETER num.
	RETURN SQRT(num["real"]^2 + num["imaginary"]^2).
}