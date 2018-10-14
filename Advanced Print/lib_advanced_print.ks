@LAZYGLOBAL OFF.

LOCAL beeper IS GETVOICE(0).//setting up sound for for
SET beeper:WAVE TO "sine".

LOCAL unit IS 0.1.
LOCAL unitLong IS 0.3.
LOCAL doPrint IS FALSE.
LOCAL doSound IS TRUE.
LOCAL tRow IS 0.//row tracking for print
LOCAL tCol IS 0.//column tracking for print

//note(freq,duration,keydownLength,volume)
LOCAL beepDot IS NOTE(440,unit).
LOCAL beepDash IS NOTE(440,unitLong).
LOCAL beepNul IS NOTE(440,unit,unit,0).
LOCAL beepNulLong IS NOTE(440,unitLong,unitLong,0).

LOCAL markTime IS TIME:SECONDS.//var needed for adv_wait function

FUNCTION adv_print_config {
	PARAMETER unitIn IS 0.1,doPrintIn IS FALSE,doSoundIn IS TRUE,noteFreq IS 440,volumeIn IS 1.
	SET unit TO unitIn.
	SET unitLong TO unitIn * 3.
	SET doPrint TO doPrintIn.
	SET doSound TO doSoundIn.
	SET beeper:VOLUME TO volumeIn.
	SET beepDot TO NOTE(noteFreq,unit).
	SET beepDash TO NOTE(noteFreq,unitLong).
	SET beepNul TO NOTE(noteFreq,unit,unit,0).
	SET beepNulLong TO NOTE(noteFreq,unitLong,unitLong,0).
}

FUNCTION adv_print {
	PARAMETER stringIn.
	LOCAL plainText IS parse(stringIn,symbals_to_text,char_to_code:KEYS).
	LOCAL coddedText IS parse(plainText,char_to_code).
	LOCAL compositions IS compose(coddedText).
	IF doSound {
		beeper:PLAY(compositions["sound"]).
	}
	IF doPrint {
		SET markTime TO TIME:SECONDS.
		SET tRow TO 0.
		SET tCol TO 0.
		LOCAL printString IS "".
		LOCAL delayTime IS 0.
		FOR moment IN compositions["text"] {
			SET printString TO printString + moment[0].
			SET delayTime TO delayTime + moment[1].
			IF (moment[0] = "|") {
				terminal_print(printString).
				SET printString TO "".
				IF doSound {	adv_wait(delayTime). }
				SET delayTime TO 0.
			}
		}
		terminal_print("END").
	}
}

LOCAL FUNCTION parse {
	PARAMETER stringIn,replaceLex,validList IS LIST().
	LOCAL returnString IS "".
	FOR char IN stringIn {
		IF validList:CONTAINS(char) {
			SET returnString TO returnString + char.
		} ELSE IF replaceLex:KEYS:CONTAINS(char) {
			SET returnString TO returnString + replaceLex[char].
		}
	}
	RETURN returnString.
}

LOCAL FUNCTION compose {
	PARAMETER stringIn.

	LOCAL interpretCode IS LEX(
		".",dot@,
		"-",dash@,
		" ",space_char@,
		"|",space_letter@,
		"\",space_word@
	).
	LOCAL compositionSound IS LIST().
	LOCAL compositionText IS LIST().
	FOR char IN stringIn {
		interpretCode[char]:CALL(compositionSound,compositionText).
	}
	RETURN LEX("sound",compositionSound,"text",compositionText).
}

LOCAL FUNCTION adv_wait {
	PARAMETER pause.
	SET markTime TO markTime + pause.
	WAIT UNTIL TIME:SECONDS >= markTime.
}

LOCAL FUNCTION terminal_print {
	PARAMETER printString.
	IF TERMINAL:WIDTH < (tCol + printString:LENGTH) {
		SET tRow TO tRow + 1.
		SET tCol TO 0.
	}
	PRINT printString AT(tCol,tRow).
	SET tCol TO tCol + printString:LENGTH.
}

LOCAL FUNCTION dot {
	PARAMETER compS,compT.
	compS:ADD(beepDot).
	compT:ADD(LIST(".",unit)).
}

LOCAL FUNCTION dash {
	PARAMETER compS,compT.
	compS:ADD(beepDash).
	compT:ADD(LIST("---",unitLong)).
}

LOCAL FUNCTION space_char {
	PARAMETER compS,compT.
	compS:ADD(beepNul).
	compT:ADD(LIST(" ",unit)).
}

LOCAL FUNCTION space_letter {
	PARAMETER compS,compT.
	compS:ADD(beepNulLong).
	compT:ADD(LIST("|",unitLong)).
}

LOCAL FUNCTION space_word {
	PARAMETER compS,compT.
	compS:ADD(beepNul).
	compT:ADD(LIST("/",unit)).
}

LOCAL symbals_to_text IS LEX(
	"<","greater than",
	">","less than",
	"=","equal",
	"!","not",
	"@","at",
	"&","and",
	"|","or",
	".","point",
	"#","supercalifragilisticexpialidocious",
	"%","abcdefghijklmnopqrstuvwxyz0123456789").

LOCAL char_to_code IS LEX(
	"A",". -|",
	"B","- . . .|",
	"C","- . - .|",
	"D","- . .|",
	"E",".|",
	"F",". . - .|",
	"G","- - .|",
	"H",". . . .|",
	"I",". .|",
	"J",". - - -|",
	"K","- . -|",
	"L",". - . .|",
	"M","- -|",
	"N","- .|",
	"O","- - -|",
	"P",". - - .|",
	"Q","- - . -|",
	"R",". - .|",
	"S",". . .|",
	"T","-|",
	"U",". . -|",
	"V",". . . -|",
	"W",". - -|",
	"X","- . . -|",
	"Y","- . - -|",
	"Z","- - . .|",
	"0","- - - - -|",
	"1",". - - - -|",
	"2",". . - - -|",
	"3",". . . - -|",
	"4",". . . . -|",
	"5",". . . . .|",
	"6","- . . . .|",
	"7","- - . . .|",
	"8","- - - . .|",
	"9","- - - - .|",
	" ","\|").