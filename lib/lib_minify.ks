LOCAL cr TO CHAR(13).
LOCAL lf TO CHAR(10).
LOCAL crlf TO cr + lf.
LOCAL tab TO CHAR(9).
LOCAL nul TO CHAR(0).
LOCAL quote TO """".
LOCAL removePaddingAround TO LIST("+", "-", "*", "/", "(", ")", "{", "}", "[", "]", ",", "=", ">", "<").

FUNCTION minify {
	PARAMETER fileSource, fileDest.
	
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
	LOCAL fileContent TO OPEN(fileSource):READALL():STRING.
	LOCAL term TO "".//line termination char(s)
	IF fileContent:CONTAINS(crlf) {//windows line termination
		SET term TO crlf.
	} ELSE IF fileContent:CONTAINS(lf) {//linux line termination
		SET term TO lf.
	} ELSE {
		SET term TO cr.
	}
	SET fileContent TO fileContent:SPLIT(term).
	LOCAL notStrCarry TO TRUE.
	LOCAL contentLength TO fileContent:LENGTH - 1.
	FROM { LOCAL i TO 0. } UNTIL i > contentLength STEP { SET i TO i + 1. } DO {
		LOCAL line TO fileContent[i].
		LOCAL lineLength TO line:LENGTH.

		SET line TO remove_leading_white_space(line, notStrCarry).

		SET line TO remove_comments(line, notStrCarry).
		
		SET line TO removed_padding_around(line, notStrCarry, removePaddingAround).
		
		//update string carry flag
		FROM { LOCAL j TO 0. } UNTIL j >= lineLength STEP { SET j TO j + 1. } DO {
			IF line[j] = """" {
				SET notStrCarry TO NOT notStrCarry.
			}
		}

		SET line TO remove_trailing_white_space(line, notStrCarry).
		
		IF i < contentLength {//writing out line to file
			fileDest:WRITELN(line).
		} ELSE {
			fileDest:WRITE(line).
		}
	}
}

LOCAL FUNCTION remove_leading_white_space {
	PARAMETER line, notStrCarry.
	IF notStrCarry {
		LOCAL lineLength TO line:LENGTH.
		IF (line:STARTSWITH(" ") OR line:STARTSWITH(tab)) {
			FROM { LOCAL j TO 0. } UNTIL j >= lineLength STEP { SET j TO j + 1. } DO {
				IF line[j] <> " " AND line[j] <> tab {
					IF j > 0 {
						SET line TO line:REMOVE(0, j).
						BREAK.
					}
				}
			}
		}
	}
	RETURN line
}

LOCAL FUNCTION remove_comments {
	PARAMETER line, notStrCarry.
	LOCAL lineLength TO line:LENGTH.
	IF line:CONTAINS("//") {
		LOCAL outOfStr TO notStrCarry.
		FROM { LOCAL j TO 1. } UNTIL j >= lineLength STEP { SET j TO j + 1. } DO {
			IF line[j] = quote {
				SET outOfStr TO NOT outOfStr.
			}
			IF outOfStr AND line[j-1] = "/" AND line[j] = "/" {
				SET line TO line:REMOVE(j-1,line:LENGTH - j + 1).
				BREAK.
			}
		}
	}
	RETURN line.
}

LOCAL FUNCTION removed_padding_around {
	PARAMETER line, notStrCarry, charSet.
	IF line:MATCHESPATTERN("([ \t][\+\-\*\/\\\(\){}\[\],=><])|([\+\-\*\/\\\(\){}\[\],=><][ \t])") {
		FOR pChar IN charSet {
			IF line:CONTAINS(" " + pChar) OR line:CONTAINS(pChar + " ") {
				LOCAL outOfStr TO notStrCarry.
				LOCAL changedLine TO FALSE.
				LOCAL limit IS line:LENGTH - 1.
				FROM { LOCAL j TO 0. } UNTIL j >= lineLength STEP { SET j TO j + 1. } DO {
					IF line[j] = """" {
						SET outOfStr TO NOT outOfStr.
						// PRINT "inStr".
					}
					IF outOfStr AND (line[j] = pChar) {//left padding removal
						IF (j < limit) AND (line[j + 1] = " " OR line[j + 1] = tab) {
							SET line TO line:REMOVE(j + 1, 1).
							SET changedLine TO TRUE.
						}
						IF (j > 0) AND (line[j - 1] = " " OR line[j - 1] = tab) {
							SET line TO line:REMOVE(j - 1, 1).
							SET changedLine TO TRUE.
						}
						IF changedLine {
							SET changedLine TO FALSE.
							SET limit TO line:LENGTH - 1.
							SET lineLength TO line:LENGTH.
							SET j TO MAX(j - 1, -1).
						}
					}
				}
			}
		}
	}
	RETURN line.
}

FUNCTION remove_trailing_white_space {
	PARAMETER line, notStrCarry.
	IF notStrCarry AND (line:ENDSWITH(" ") OR line:ENDSWITH(tab)) {
		FROM { LOCAL j TO line:LENGTH - 1. } UNTIL j < 0 STEP { SET j TO j - 1. } DO {
			IF line[j] <> " " OR line[j] <> tab {
				IF j < (line:LENGTH - 1) {
					SET line TO line:REMOVE(j + 1, line:LENGTH - j - 1).
				}
				BREAK.
			}
		}
	}
}