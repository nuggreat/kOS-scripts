@LAZYGLOBAL OFF.

LOCAL beeper IS GETVOICE(0).//setting up sound for for
SET beeper:WAVE TO "sine".

LOCAL unit IS 0.1.
LOCAL unitLong IS 0.3.
LOCAL doPrint IS FALSE.
LOCAL doSound IS TRUE.
LOCAL doHud IS FALSE.
LOCAL hudLocation IS 2.
LOCAL hudSize IS 40.
LOCAL hudColor IS WHITE.
LOCAL tRow IS 0.//row tracking for print
LOCAL tCol IS 0.//column tracking for print

//note(freq,duration,keydownLength,volume)
LOCAL beepDot IS NOTE(440,unit).
LOCAL beepDash IS NOTE(440,unitLong).
LOCAL beepNul IS NOTE(440,unit,unit,0).
LOCAL beepNulLong IS NOTE(440,unitLong,unitLong,0).

LOCAL markTime IS TIME:SECONDS.//var needed for adv_wait function

FUNCTION adv_print_config {
	PARAMETER unitIn IS 0.1,doPrintIn IS FALSE,doHudIn IS FALSE,doSoundIn IS TRUE,
		noteFreqDot IS 440,noteFreqDash IS 440,volumeIn IS 1,
		hudColorIn IS WHITE,hudSizeIn IS 40,hudLocationIn IS 2.
	adv_print_config_timeing(unitIn).
	adv_print_config_print(doPrintIn).
	adv_print_config_hud(doHudIn,hudColorIn,hudSizeIn,hudLocationIn).
	adv_print_config_sound(doSoundIn,noteFreqDot,noteFreqDash,volumeIn).
}

FUNCTION adv_print_config_do {
	PARAMETER doPrintIn IS FALSE, doHudIn IS FALSE, doSoundIn IS TRUE.
	SET doPrint TO doPrintIn.
	SET doHud TO doHudIn.
	SET doSound TO doSoundIn.
}

FUNCTION adv_print_config_timeing {
	PARAMETER unitIn IS 0.1.
	SET unit TO MAX(unitIn,0.05).
	SET unitLong TO unitIn * 3.
}

FUNCTION adv_print_config_print {
	PARAMETER doPrintIn IS TRUE.
	SET doPrint TO doPrintIn.
}

FUNCTION adv_print_config_hud {
	PARAMETER doHudIn IS TRUE,hudColorIn IS WHITE,hudSizeIn IS 40,hudLocationIn IS 2.
	SET doHud TO doHudIn.
	SET hudColor TO hudColorIn.
	SET hudSize TO hudSizeIn.
	SET hudLocation TO hudLocationIn.
}

FUNCTION adv_print_config_sound {
	PARAMETER doSoundIn IS TRUE,noteFreqDot IS 440,noteFreqDash IS 440,volumeIn IS 1.
	SET doSound TO doSoundIn.
	SET beeper:VOLUME TO volumeIn.
	SET beepDot TO NOTE(noteFreqDot,unit).
	SET beepDash TO NOTE(noteFreqDash,unitLong).
	SET beepNul TO NOTE(noteFreqDot,unit,unit,0).
	SET beepNulLong TO NOTE(noteFreqDot,unitLong,unitLong,0).
}

FUNCTION adv_print {
	PARAMETER stringIn.
	LOCAL plainText IS parse(stringIn,symbals_to_text,char_to_code:KEYS).
	LOCAL coddedText IS parse(plainText,char_to_code).
	LOCAL compositions IS compose(coddedText).
	IF doSound {
		beeper:PLAY(compositions["sound"]).
	}
	IF doPrint OR doHud {
		SET markTime TO TIME:SECONDS.
		SET tRow TO 0.
		SET tCol TO 0.
		LOCAL printString IS "".
		LOCAL delayTime IS 0.
		CLEARSCREEN.
		FOR moment IN compositions["text"] {
			SET printString TO printString + moment[0].
			SET delayTime TO delayTime + moment[1].
			IF (moment[0] = "|") {
				IF doPrint { terminal_print(printString). }
				IF doHud { hud_print(printString,delayTime). }
				SET printString TO "".
				IF doSound OR doHud { adv_wait(delayTime). }
				SET delayTime TO 0.
			}
		}
		IF doPrint { terminal_print("END"). }
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

FUNCTION hud_print {
	PARAMETER printString,pause.
	LOCAL localString IS printString:REMOVE(printString:LENGTH - 1,1).
	HUDTEXT(localString,pause,hudLocation,hudSize,hudColor,FALSE).
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