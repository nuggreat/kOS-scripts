// start from root part

FUNCTION get_all_collections {
	LOCAL collections TO LIST().
	LOCAL partQueue TO QUEUE(SHIP:ROOT:PART).
	UNTIL partQueue:EMPTY {
		collections:ADD(get_collection(partQueue:POP(),partQueue)).
	}
	RETURN collections.
}

FUNCTION get_collection {
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
	LOCAL partCollection TO part_collection_init(firstPart).
	UNTIL parentParts:EMPTY {
		LOCAL parentPart TO parentParts:POP().
		add_part_to_collection(parentPart,partCollection).
		FOR childPart IN parentPart:CHILDREN {
			IF childPart:ISTYPE("Separator") {
				boundryParts:PUSH(childPart).
			} ELSE {
				parentParts:PUSH(childPart).
			}
		}
	}
	RETURN partCollection.
}

FUNCTION part_collection_init {
	PARAMETER collectionRoot.
	RETURN LEX(
		"collectionRoot",collectionRoot,
		"parts",LIST(),
		"resources",LEX(),
		"engines",LIST(),
	).
}

FUNCTION add_part_to_collection {
	PARAMETER localPart, partCollection.
	partCollection["parts"]:ADD(localPart).
	
	IF localPart:RESOURCES:LENGTH <> 0 {
		LOCAL stageResources TO partCollection["resources"].
		FOR res IN localPart:RESOURCES {
			IF res:ENABLED {
				IF stageResources:HASKEY(res:NAME) {
					LOCAL resStruct TO stageResources[res:NAME]
					resStruct["parts"]:ADD(localPart).
					SET resStruct["amount"] TO resStruct["amount"] + res:AMOUNT.
					SET resStruct["capacity"] TO resStruct["capacity"] + res:CAPACITY.
				} ELSE {
					stageResources:ADD(res:NAME,LEX(
						"parts",LIST(localPart),
						"amount",res:AMOUNT,
						"capacity",res:CAPACITY,
						"density",res:DENSITY
					).
				}
			}
		}
	}
	
	IF localPart:ISTYPE("engine") {
		partCollection["engines"]:ADD(localPart).
	}
}

FUNCTION engine_collections_by_stage {
	LOCAL enginesByStage TO LEX().
	FOR eng IN SHIP:ENGINES {
		IF enginesByStage:HASKEY(eng:STAGE) {
			enginesByStage[eng:STAGE]:ADD(eng).
		} ELSE {
			enginesByStage:ADD(eng:STAGE, eng).
		}
	}
	LOCAL engineCollections TO LIST().
	UNTIL enginesByStage:LENGTH = 0 {
		LOCAL lowest TO enginesByStage:KEYS[0].
		FOR key IN enginesByStage:KEYS {
			IF key < lowest {
				SET lowest TO key.
			}
		}
		engineCollections:ADD(enginesByStage[lowest]).
		enginesByStage:REMOVE(key).
	}
}

FUNCTION engine_collections_by_stage {
	LOCAL engineCollections TO LIST().
	LOCAL stageToIdxMap IS LEX().
	LOCAL stages IS 1.
	FOR eng IN SHIP:ENGINES {
		LOCAL engStage TO eng:STAGE.
		IF stageToIdxMap:HASKEY(engStage) {
			engineCollections[stageToIdxMap[engStage]]:ADD(eng).
		} ELSE {
			IF engineCollections:LENGTH <> 0 {
				LOCAL i TO 0.
				UNTIL i >= stages {
					
				}
			} ELSE {
				engineCollections:ADD(LIST(eng)).
				stageToIdxMap:ADD(engStage,0).
			}
		}
	}
}