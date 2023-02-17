LOCAL lf TO CHAR().
LOCAL cr TO CHAR().
LOCAL crlf TO cr + lf.
LOCAL tab TO CHAR().
LOCAL padRemove TO LIST("+", "-", "*", "/", "(", ")", "{", "}", ",", "=", ">", "<").
FUNCTION minify {
	PARAMETER fileSource, fileDest.
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
	SET fileContent TO fileContent:REPLACE(term, term + " "):SPLIT(term).
	FROM { LOCAL i TO 0. } UNTIL i >= fileContent:LENGTH STEP { SET i TO i + 1. } DO {
		LOCAL line TO fileContent[i].

		//remove leading white space
		IF line[0] = " " OR line[0] = tab {
			FROM { LOCAL j TO 0. } UNTIL j >= line:LENGTH STEP { SET j TO j + 1. } DO {
				IF line[j] <> " " AND line[j] <> tab {
					SET line TO line:REMOVE(0, j).
					BREAK.
				}
			}
		}

		//remove comments
		IF line:CONTAINS("//") {
			LOCAL outOfStr TO TRUE.
			FROM { LOCAL j TO 1. } UNTIL j >= line:LENGTH STEP { SET j TO j + 1. } DO {
				IF line[j] = """" {
					SET outOfStr TO NOT outOfStr.
				}
				IF outOfStr AND line[j-1] = "/" AND line[j] = "/" {
					SET line TO line:REMOVE(j-1,line:LENGTH - j + 1).
					BREAK.
				}
			}
		}

		//remove padding around chars found in padRemove list
		FOR pChar IN padRemove {
			IF line:CONTAINS(" " + pChar) OR line:CONTAINS(pChar + " ") {
				LOCAL outOfStr TO TRUE.
				LOCAL changedLine TO FALSE.
				LOCAL limit IS line:LENGTH - 1.
				FROM { LOCAL j TO 0. } UNTIL j >= line:LENGTH STEP { SET j TO j + 1. } DO {
					IF line[j] = """" {
						SET outOfStr TO NOT outOfStr.
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
							SET j TO MAX(j - 2, -1).
						}
					}
				}
			}
		}

		//remove trailing white space
		IF line:ENDSWITH(" ") OR line:ENDSWITH(tab) {
			LOCAL whiteLength TO 0.
			FROM { LOCAL j TO line:LENGTH - 1. } UNTIL j < 0 STEP { SET j TO j - 1. } DO {
				IF line[j] = " " OR line[j] = tab {
					SET whiteLength TO whiteLength + 1.
				} ELSE {
					SET line TO line:REMOVE(j + 1, whiteLength).
					BREAK.
				}
			}
		}
	}
}