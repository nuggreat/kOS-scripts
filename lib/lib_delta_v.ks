//staging rules
// an engine is presumed decoupled once it no longer has the required resources to function.
// all engines with the same stage number are presumed activated at the same time
// any engine with the same stage number as a decoupler is presumed activated at the same time as said decoupler
//  presuming it is not removed by said decoupler
// if there are no active engines staging is presumed to advance until there are active engines
// fairing removal is not accounted for



LOCAL gg0 TO CONSTANT:g0.
LOCAL ee TO CONSTANT:e.



// start from root part

FUNCTION get_all_sections {
	LOCAL sections TO LIST().
	LOCAL partQueue TO LIST(SHIP:ROOT:PART).
	LOCAL sectionRootToSectionID TO LEX().
	LOCAL sectionID TO 0.
	UNTIL partQueue:EMPTY {
		LOCAL newPendingParts IS LIST().
		LOCAL pendingPart TO partQueue[0].
		
		sections:ADD(get_section(pendingPart, newPendingParts, sectionID)).
		
		sectionRootToSectionID:ADD(pendingPart:UID, sectionID).
		SET sectionID TO sectionID + 1.
		partQueue:REMOVE(0).
		FOR p IN newPendingParts {
			insertion_into_sorted(partQueue, p, { PARAMETER i. RETURN i:STAGE. }).
		}
	}
	
	FOR section IN sections {
		LOCAL subSectionRoots TO section["subSectionIDs"].
		FROM { LOCAL i TO subSectionRoots:LENGTH - 1. } UNTIL i < 0 STEP { SET i TO i - 1. } DO {
			SET subSectionRoots[i] TO sectionRootToSectionID[subSectionRoots[i]:UID].
		}
	}
	
	map_resouce_flow(sections).
	RETURN sections.
}

FUNCTION get_section {
	// all resources in a given stage are assumed accessible by parts in that section
	//  docking ports are ignored by this system
	// walks the tree away from the root part to discover all parts in a section
	// assumes section separation occurs on decopler/separator parts
	PARAMETER firstPart, boundryParts, sectionID.
	LOCAL parentParts TO QUEUE().
	//walk up until decopler/separator
	// if firstPart is not decopler/separator and has parent parts
	UNTIL firstPart:ISTYPE("Separator") OR (NOT firstPart:HASPARENT) {//walking up the tree to the start
		SET firstPart TO firstPart:PARENT.
	}
	parentParts:PUSH(firstPart).
	LOCAL partSection TO part_section_init(firstPart, sectionID).
	UNTIL parentParts:EMPTY {
		LOCAL parentPart TO parentParts:POP().
		add_part_to_section(parentPart,partSection).
		FOR childPart IN parentPart:CHILDREN {
			IF childPart:ISTYPE("Separator") {
				boundryParts:PUSH(childPart).
				partSection["subSectionIDs"]:ADD(childPart).
			} ELSE {
				parentParts:PUSH(childPart).
			}
		}
	}
	RETURN partSection.
}

FUNCTION part_section_init {
	PARAMETER sectionRoot, sectionID.
	RETURN LEX(
		"sectionRoot", sectionRoot,
		"sectionID", sectionID,
		"parts", LIST(),
		"subSectionIDs", LIST(),
		"resources", LEX(),
		"engines", LIST(),
		"fullWetMass", 0.
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
						"density",res:DENSITY,
						"hasInFlow",FALSE,
						"hasOutFlow",FALSE,
						"flowToSections",LIST(),
						"flowFromSections",LIST()
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

//works out the between section flow connections based on engine resources and decoupler information.
//all subSections with the same stage number are assumed to all have resource flow
//resource flow into into a section is assumed to be from the lowest stage numbers
FUNCTION map_resouce_flow {
	PARAMETER sections.
	
	FOR section IN sections {
		LOCAL sectionID TO section["sectionID"].
		LOCAL flowingResources TO LIST().
		FOR eng IN section["engines"] {
			FOR engRes IN eng:CONSUMEDRESOURCES:VALUE {
				IF NOT within_range_ratio(engRes:CAPACITY, section["resources"][engRes:NAME]["capacity"], 0.99) {
					LOCAL sectionRes TO section["resources"][engRes:NAME].
					LOCAL resCapacity TO sectionRes["capacity"].
					LOCAL subSectionIDs TO LIST().
					LOCAL newIDs TO LIST(sectionID).

					LOCAL lowestSubSection TO 1.
					LOCAL highestSubSection TO 0.
					LOCAL flowSectionIDs TO LIST().
					UNTIL within_range_ratio(engRes:CAPACITY, resCapacity, 0.99) {
						IF lowestSubSection > highestSubSection {//need more subsection depth
							flowSectionIDs:CLEAR().
							SET resCapacity TO sectionRes["capacity"].
							LOCAL pendingIDs TO LIST().
							FOR subSectionID IN newIDs {
								FOR newSubSectionID IN sections[subSectionID]["subSectionIDs"] {
									pendingIDs:ADD(newSubSectionID).
									subSectionIDs:ADD(newSubSectionID).
								}
							}
							SET lowestSubSection TO sections[subSectionIDs[0]]["sectionRoot"]:STAGE.
							SET highestSubSection TO lowestSubSection.
							SET newIDs TO pendingIDs.
							FOR subSectionID IN subSectionIDs {
								LOCAL subSectionStage TO sections[subSectionID]["sectionRoot"]:STAGE.
								IF subSectionStage < lowestSubSection {
									SET lowestSubSection TO subSectionStage.
								} ELSE IF subSectionStage > lowestSubSection {
									SET highestSubSection TO subSectionStage.
								}
							}
							
						}
						//adding resource capacity of all subsections in a given stage to total
						FOR subSectionID IN subSectionIDs {
							IF sections[subSectionID]["sectionRoot"]:STAGE = lowestSubSection {
								SET resCapacity TO resCapacity + sections[subSectionID]["resources"][engRes:NAME]["capacity"].
								flowSectionIDs:ADD(subSectionID).
							}
						}
						SET lowestSubSection TO lowestSubSection + 1.
					}
					SET sectionRes["hasInFlow"] TO TRUE.
					FOR subSectionID IN flowSectionIDs {
						LOCAL subSecRes TO sections[subSectionID]["resources"][engRes:NAME].
						SET subSecRes["hasOutFlow"] TO TRUE.
						subSecRes["flowToSections"]:ADD(sectionID).
						
						sectionRes["flowFromSections"]:ADD(subSectionID).
					}
				}
			}
		}
	}
}

//map from engine stage numbers to the section that has said engine
FUNCTION engine_sections_by_stage {
	LOCAL engineCollections TO LIST().
	LOCAL stageToIdxMap IS LEX().
	LOCAL stages IS 1.
	FOR eng IN SHIP:ENGINES {
		LOCAL engStage TO eng:STAGE.
		IF stageToIdxMap:HASKEY(engStage) {
			engineCollections[stageToIdxMap[engStage]]:ADD(eng).
		} ELSE {
			insertion_into_sorted(engineCollections, LIST(eng), { PARAMETER i. RETURN -(i[0]:STAGE). }).
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
	//work out if an engine draws fuel from beyond it's own section
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

FUNCTION net_engine {
	PARAMETER engList.
	LOCAL netThrustCurrent IS 0.
	LOCAL netThrustVac IS 0.
	LOCAL netFlow IS 0.
	LOCAL netFlows IS LEXICON().
	LOCAL currentPressure TO BODY:ATM:ALTITUDEPRESSURE(SHIP:ALTITUDE).
	FOR eng IN engList {
		SET netThrustVac TO netThrustVac + eng:POSSIBLETHRUSTAT(0).
		SET netThrustCurrent TO netThrustCurrent + eng:POSSIBLETHRUSTAT(currentPressure).
		LOCAL thrustLim TO eng:THRUSTLIMIT / 100.
		SET netFlow TO netFlowVac + (engine:POSSIBLETHRUSTAT(0) / (engine:VACUUMISP * gg0)).
		FOR res IN eng:CONSUMEDRESOURCES:VALUES {
			IF netFlows:HASKEY(res:NAME) {
				LOCAL resFlow TO netFlows[res:NAME].
				SET resFlow["abilableMassFlow"] TO resFlow["abilableMassFlow"] + res:MAXMASSFLOW * thrustLim.
				SET resFlow["avilableVolumeFlow"] TO resFlow["avilableVolumeFlow"] + res:MAXFUELFLOW * thrustLim.
				// SET netFlow[] TO netFlow[] + .
			} ELSE {
				netFlows:ADD(res:NAME,LEX(
					"abilableMassFlow", res:MAXMASSFLOW * thrustLim,
					"avilableVolumeFlow", res:MAXFUELFLOW * thrustLim,
				)).
			}
		}
	}
	RETURN LEX (
		"engines", engList.
		"avilableThrust", netThrustCurrent,
		"avilableThrustVac", netThrustVac,
		"massFlow", netFlow,
		"ISP", netThrustCurrent / (netFlow * gg0),
		"consumedResources", netFlows
	).
}

FUNCTION within_range_fixed {
	PARAMETER valA, valB, epsilon.
	RETURN ABS(valA - valB) <= epsilon
}

FUNCTION within_range_ratio {
	PARAMETER valA, valB, epsilon.
	RETURN ABS(valA - valB) <= ((1 - epsilon) * valA).
}