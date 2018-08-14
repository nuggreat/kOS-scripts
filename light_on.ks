FOR par IN SHIP:PARTS {
	IF par:HASMODULE("moduleLight") {
		LOCAL lightModule IS par:GETMODULE("moduleLight").
		IF lightModule:HASEVENT("Lights On") {
			lightModule:DOEVENT("Lights On").
		}
	}
}