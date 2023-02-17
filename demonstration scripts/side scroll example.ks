LOCAL tWidth IS 140.
LOCAL tHeight IS 30.
SET CONFIG:IPU TO 2000.
SET TERMINAL:WIDTH TO tWidth.
SET TERMINAL:HEIGHT TO tHeight.

LOCAL screenData IS LIST().
FROM { LOCAL i IS 0. } UNTIL i >= tHeight STEP { SET i TO i + 1. } DO {
	screenData:ADD(" ":PADRIGHT(tWidth)).
}

RCS OFF.
UNTIL RCS {
	LOCAL rndString IS random_string().
	FROM { LOCAL i IS 0. } UNTIL i >= 5 STEP { SET i TO i + 1. } DO {
		render_screen(screenData,rndString).
		WAIT 0.
	}
}

FUNCTION render_screen {
	PARAMETER screenData,newLine.
	LOCAL twTmp IS tWidth - 1.
	FROM { LOCAL i IS tHeight - 2. } UNTIL i < 0 STEP { SET i TO i - 1. } DO {
		SET screenData[i] TO screenData[i]:SUBSTRING(1,twTmp) + newLine[i].
		PRINT screenData[i] AT(0,i).
	}
}

FUNCTION random_string {
	LOCAL returnString IS "".
	UNTIL returnString:LENGTH >=tHeight {
		SET returnString TO returnString + (CHOOSE "*" IF RANDOM() > 0.25 ELSE " ").
	}
	RETURN returnString.
}