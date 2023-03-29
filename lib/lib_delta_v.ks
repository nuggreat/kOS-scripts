//staging rules
// an engine is presumed decoupled once it no longer has the required resources to function.
// all engines with the same stage number are presumed activated at the same time
// any engine with the same stage number as a decoupler is presumed activated at the same time as said decoupler
//  presuming it is not removed by said decoupler
// if there are no active engines staging is presumed to advance until there are active engines
// fairing removal is not accounted for







// start from root part

FUNCTION get_all_sections {
	LOCAL sections TO LIST().
	LOCAL partQueue TO QUEUE(SHIP:ROOT:PART).
	UNTIL partQueue:EMPTY {
		sections:ADD(get_section(partQueue:POP(),partQueue)).
	}
	RETURN sections.
}

FUNCTION get_section {
	// all resources in a given stage are assumed accessible by parts in that stage
	//  docking ports are ignored by this system
	PARAMETER firstPart,boundryParts.
	LOCAL parentParts TO QUEUE().
	//walk up until decopler/separator
	// if firstPart is not decopler/separator and has parent parts
	UNTIL firstPart:ISTYPE("Separator") OR (NOT firstPart:HASPARENT) {//walking up the tree to the start
		SET firstPart TO firstPart:PARENT.
	}
	parentParts:PUSH(firstPart).
	LOCAL partSection TO part_section_init(firstPart).
	UNTIL parentParts:EMPTY {
		LOCAL parentPart TO parentParts:POP().
		add_part_to_section(parentPart,partSection).
		FOR childPart IN parentPart:CHILDREN {
			IF childPart:ISTYPE("Separator") {
				boundryParts:PUSH(childPart).
			} ELSE {
				parentParts:PUSH(childPart).
			}
		}
	}
	RETURN partSection.
}

FUNCTION part_section_init {
	PARAMETER sectionRoot.
	RETURN LEX(
		"sectionRoot",sectionRoot,
		"parts",LIST(),
		"resources",LEX(),
		"engines",LIST(),
		"fullWetMass",0,
		"dryMass".
	).
}

FUNCTION add_part_to_section {
	PARAMETER localPart, partSection.
	partSection["parts"]:ADD(localPart).
	// LOCAL partFullMass TO localPart:DRYMASS.
	LOCAL partResources TO localPart:RESOURCES.
	IF partResources:LENGTH <> 0 {
		LOCAL stageResources TO partSection["resources"].
		FROM { LOCAL i IS partResources:LENGTH - 1. } UNTIL i < 0 STEP { SET i TO i + 1. } DO {
			LOCAL res IS partResources[i]
			// SET partFullMass TO partFullMass + res:CAPACITY * res:DENSITY.
			IF res:ENABLED {
				IF stageResources:HASKEY(res:NAME) {
					LOCAL resStruct TO stageResources[res:NAME]
					resStruct["parts"]:ADD(localPart).
					resStruct["resStructs"]:ADD(res).
					SET resStruct["amount"] TO resStruct["amount"] + res:AMOUNT.
					SET resStruct["capacity"] TO resStruct["capacity"] + res:CAPACITY.
				} ELSE {
					stageResources:ADD(res:NAME,LEX(
						"parts",LIST(localPart),
						"resStructs",LIST(res).
						"amount",res:AMOUNT,
						"capacity",res:CAPACITY,
						"density",res:DENSITY
					).
				}
			}
		}
	}
	// SET partSection["fullWetMass"] TO partSection["fullWetMass"] + partFullMass.
	
	IF localPart:ISTYPE("engine") {
		partSection["engines"]:ADD(localPart).
	}
}

//map from engine stage numbers to the section that has said engine
FUNCTION engine_sections_by_stage {
	LOCAL engineSections TO LIST().
	LOCAL stageToIdxMap IS LEX().
	LOCAL stages IS 1.
	FOR eng IN SHIP:ENGINES {
		LOCAL engStage TO eng:STAGE.
		IF stageToIdxMap:HASKEY(engStage) {
			engineSections[stageToIdxMap[engStage]]:ADD(eng).
		} ELSE {
			insertion_sort(engineSections, LIST(eng), { PARAMETER i. RETURN -(i[0]:STAGE). }).
			FOR key IN stageToIdxMap {
				IF key < engStage {
					SET stageToIdxMap[key] TO stageToIdxMap[key] + 1.
				}
			}
			stageToIdxMap:ADD(engStage, idx).
		}
	}
}

FUNCTION insertion_into_sorted {// inserts items into an already sorted list with lowest evaluated item at 0th index
	PARAMETER theList, item, evaluation.
	LOCAL itemValue IS evaluation(item).
	LOCAL theLength TO theList:LENGTH.

	IF theLength = 0 {
		theList:ADD(item).
		RETURN 0.
	} ELSE {
		LOCAL inc IS MAX(FLOOR(theLength / 2),1).
		LOCAL i IS MAX(inc - 1,0).
		UNTIL FALSE {
			SET inc TO MAX(FLOOR(inc/2),0).
			IF inc <= 0 {
				BREAK.
			}
			
			IF evaluation(theList[i]) < itemValue {
				SET i TO MIN(i + inc,theLength).
			} ELSE {
				SET i TO MAX(i - inc,0).
			}
		} 
		UNTIL FALSE {
			IF evaluation(theList[i]) < itemValue {
				SET i TO MIN(i + 1,theLength).
				IF (i >= theLength) OR (evaluation(theList[i]) >= itemValue) {
					theList:INSERT(i,item).
					BREAK.
				}
			} ELSE {
				IF i <= 0 {
					theList:INSERT(i,item).
					BREAK.
				}
				SET i TO MAX(i - 1,0).
			}
		}
		RETURN i.
	}
}

// for a given set of engines in a stage use the resource consumed suffix to work if there is between section fuel flow
// if so work out the limiting resource pool and calculate the net time for that pool
// possibly detect drop tanks
FUNCTION build_stage {
	PARAMETER sections, engInStage.
	
	//getting the list of sections that have listed engines.
	LOCAL localEngInStage TO engInStage:COPY.
	LOCAL sectionsWithEngines TO LIST().
	UNTIL localEngInStage:LENGTH = 0 {
		LOCAL section TO section_with_engine(localEngInStage[0],sections).
		FOR eng IN section["engines"] {
			LOCAL engUID IS eng:UID.
			FROM { LOCAL i TO 0. } UNTIL i >= localEngInStage:LENGTH STEP { SET i TO i + 1 } DO {
				IF engUID = localEngInStage[i]:UID {
					localEngInStage:REMOVE(i).
					BREAK.
				}
			}
		}
		sectionsWithEngines:ADD(section).
	}
	//
}

FUNCTION section_with_engine {
	PARAMETER eng, sections.
	LOCAL engUID IS eng:UID.
	FOR section in sections {
		FOR sectionEng IN section["engines"] {
			IF engUID = sectionEng:UID {
				RETURN section.
			}
		}
	}
}

FUNCTION within_range {
	PARAMETER valA, valB, epsilon.
	RETURN ABS(valA - valB) < epsilon
}