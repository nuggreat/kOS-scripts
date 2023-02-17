RUNONCEPATH("0:/game of life/lib_game_of_life_engine.ks").
RUNONCEPATH("0:/game of life/lib_conway_rules.ks").

LOCAL gameState IS game_init(TRUE,101,101,4).
LOCAL rules IS conways_game_of_life_init().

// gameState:advanceState(rules["randomState"]@,FALSE).
// gameState:exportState(TRUE,TRUE,FALSE).

LOCAL pastStates IS LIST().
LOCAL maxPastStates IS 10.

gameState:inject(expanding_pattern(),50-12,50-17,TRUE).
LOCAL newState IS gameState:exportState(TRUE,TRUE,TRUE).

pastStates:ADD(newState).

RCS OFF.
SAS OFF.
LOCAL stelLimit IS 2000.
UNTIL RCS OR (gameState:getCount() >= stelLimit) {
	gameState:advanceState(rules["rules"]@).
	// gameState:exportState(TRUE,TRUE,FALSE).
	LOCAL newState IS gameState:exportState(TRUE,TRUE,TRUE).
	IF pastStates:CONTAINS(newState) {
		BREAK.
	} ELSE {
		pastStates:ADD(newState).
		UNTIL pastStates:LENGTH <= maxPastStates {
			pastStates:REMOVE(0).
		}
	}
}
gameState:logElapsed().
gameState:restoreTerminal().
// 12

FUNCTION expanding_pattern {//a 25x by 35y image, should be centered in terminal (centerX - 12,centerY - 17)
	RETURN LIST(
	"     ███         ███     ",
	"     █  █        █  █    ",
	"     █      █    █       ",
	"     █     ███   █       ",
	"     █     █ ██  █       ",
	"     █      ███  █       ",
	"      █  █  ███   █      ",
	"        █   ███          ",
	"         █     ██        ",
	"          ██             ",
	"          █              ",
	"           ██            ",
	" █        █ █ █        █ ",
	"█     █ █ █ █ ██  █     █",
	"█     ███   █ █ ███     █",
	"█████ █   ██  █   █ █████",
	"        █ █  ██ █        ",
	"       ██ █ █ █ ██       ",
	"        █ ██  █ █        ",
	"█████ █   █  ██   █ █████",
	"█     ███ █ █   ███     █",
	"█     █  ██ █ █ █ █     █",
	" █        █ █ █        █ ",
	"            ██           ",
	"              █          ",
	"             ██          ",
	"        ██     █         ",
	"          ███   █        ",
	"      █   ███  █  █      ",
	"       █  ███      █     ",
	"       █  ██ █     █     ",
	"       █   ███     █     ",
	"       █    █      █     ",
	"    █  █        █  █     ",
	"     ███         ███     ").
}