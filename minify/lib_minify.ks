LOCAL cr TO CHAR(13).
LOCAL lf TO CHAR(10).
LOCAL crlf TO cr + lf.
LOCAL tab TO CHAR(9).
LOCAL nul TO CHAR(0).
LOCAL quote TO """".
LOCAL removePaddingAround TO LIST("+", "-", "*", "/", "^", "(", ")", "{", "}", "[", "]", ",", "=", ">", "<", " ", tab, lf).
LOCAL whiteSpaceChars TO LIST(" ", tab).

LOCAL subLead TO 30.
LOCAL subTail TO 30. //RCS ON.
LOCAL line TO 0.

FUNCTION minify {
	PARAMETER fileSource, fileDest.
	WAIT 0.
	LOCAL startTime IS TIME:SECONDS.

	IF fileDest:ISTYPE("string") {
		SET fileDest TO PATH(fileDest).
	}
	IF EXISTS(fileDest) {
		SET fileDest TO OPEN(fileDest).
		fileDest:CLEAR.
	} ELSE {
		SET fileDest TO CREATE(fileDest).
	}

	IF fileSource:ISTYPE("string") {
		SET fileSource TO PATH(fileSource).
	}
	LOCAL fileContent TO OPEN(fileSource):READALL() : STRING.
	LOCAL term TO "".//line termination char(s)
	IF fileContent:CONTAINS(crlf) {//windows line termination
		SET term TO crlf.
	} ELSE IF fileContent:CONTAINS(lf) {//linux line termination
		SET term TO lf.
	} ELSE {
		SET term TO cr.
	}
	SET fileContent TO fileContent:REPLACE(term, lf).

	LOCAL contentLength TO fileContent:LENGTH - 1.

	LOCAL i TO 0.

	//start of file white space removal
	LOCAL j TO i.
	UNTIL NOT (j <= contentLength AND whiteSpaceChars:CONTAINS(fileContent[j])) {
		SET j TO j + 1.
	}
	IF j > i {
		SET fileContent TO fileContent:REMOVE(i, j - i).
		SET contentLength TO fileContent:LENGTH - 1.
	}

	LOCAL notInStr IS TRUE.
	LOCAL removeLeadingWhite TO FALSE.
	LOCAL removeTrailingWhite TO FALSE.
	UNTIL i > contentLength {
		LOCAL currentChar TO fileContent[i].
		// PRINT "---------".
		// PRINT fileContent:SUBSTRING(MAX(i - subLead, 0), MIN(subTail + MIN(i, subLead), contentLength - i + subLead + 1)):REPLACE(lf, "!"):REPLACE(" ", "~"):REPLACE(tab, "~").
		// IF currentChar = lf {
			// SET line TO line + 1.
		// }

		IF notInStr {
			//comment removal
			IF currentChar = "/" AND i < contentLength AND fileContent[i + 1] = "/" {
				LOCAL j TO i + 2.
				UNTIL j > contentLength OR fileContent[j] = lf {
					SET j TO j + 1.
				}
				SET fileContent TO fileContent:REMOVE(i, j - i).
				SET i TO i - 1.
				SET contentLength TO fileContent:LENGTH - 1.

			//removal of padding around listed chars
			} ELSE IF removePaddingAround:CONTAINS(currentChar) {
				SET removeLeadingWhite TO i < contentLength AND whiteSpaceChars:CONTAINS(fileContent[i + 1]).
				SET removeTrailingWhite TO i > 0 AND whiteSpaceChars:CONTAINS(fileContent[i - 1]).

			//string detection
			} ELSE IF currentChar = quote {
				SET notInStr TO FALSE.
				SET removeTrailingWhite TO i > 0 AND whiteSpaceChars:CONTAINS(fileContent[i - 1]).
			}
		} ELSE {
			IF currentChar = quote {
				SET notInStr TO TRUE.
				SET removeLeadingWhite TO i < contentLength AND whiteSpaceChars:CONTAINS(fileContent[i + 1]).
			}
		}

		IF removeLeadingWhite {
			SET removeLeadingWhite TO FALSE.
			LOCAL j TO i + 2.
			UNTIL NOT (j <= contentLength AND whiteSpaceChars:CONTAINS(fileContent[j])) {
				SET j TO j + 1.
			}
			SET fileContent TO fileContent:REMOVE(i + 1, j - i - 1).
			SET contentLength TO fileContent:LENGTH - 1.
		}
		IF removeTrailingWhite {
			SET removeTrailingWhite TO FALSE.
			SET fileContent TO fileContent:REMOVE(i - 1, 1).
			SET i TO i - 1.
			SET contentLength TO fileContent:LENGTH - 1.
		}
		// PRINT fileContent:SUBSTRING(MAX(i - subLead, 0), MIN(subTail + MIN(i, subLead), contentLength - i + subLead + 1)):REPLACE(lf, "!"):REPLACE(" ", "~"):REPLACE(tab, "~").
		// PRINT "|":PADRIGHT(MIN(subLead, i)) + "^" + "|":PADLEFT(MIN((subTail) - 1, contentLength - i + 1)).
		// PRINT ROUND(i * 100 / contentLength, 2):TOSTRING():PADRIGHT(5) + "%, line: " + line + " i: " + i.
		// PRINT notInStr.
		// IF line = 6 {
		// IF i = 220 {
			// SET SAS TO FALSE.
		// }
		// SET RCS TO SAS.
		// WAIT UNTIL RCS.

		SET i TO i + 1.
	}
	//end of file white space removal
	SET i TO i - 1.
	LOCAL j TO i.
	UNTIL NOT(j >= 0 AND whiteSpaceChars:CONTAINS(fileContent[j])) {
		SET j TO j - 1.
	}
	IF i - j > 0 {
		SET fileContent TO fileContent:REMOVE(j, i - j).
		SET i TO j.
		SET contentLength TO fileContent:LENGTH - 1.
	}
	fileDest:WRITE(fileContent:REPLACE(lf, term)).
}