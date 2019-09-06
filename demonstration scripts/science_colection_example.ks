//slightly more advanced science example

LOCAL scienceModules IS LIST().//creating a list to store the science science module

FOR p IN SHIP:PARTS {//looping over all parts in the ship
	IF p:HASMODULE("ModuleScienceExperiment"){//checking each part for the science module
		LOCAL scienceModule IS p:GETMODULE("ModuleScienceExperiment").//creating a local variable to store the science module
		scienceModules:ADD(scienceModule).//adding the found science modules to the list science module
	}
}

FOR sci IN scienceModules {//loop over all science science modules
	sci:DEPLOY.//collect all science experiments
}

WAIT 10.//waiting for 10 seconds to let data be colected

FOR sci IN scienceModules {//loop over all science science modules
	IF sci:RERUNNABLE AND sci:HASDATA {//if the experiment can be run more than once and it has data
		sci:TRANSMIT.//transmitting the data
	}
}