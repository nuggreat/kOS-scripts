//build network
//add or add to network
//
//scan for isolated nodes and start there if they exist else start at node 1
//walk tree
//verfy path if one exists
//
//
//data structure
//  tree will be stored as lexicon
//  current path will be a list added to as each node is visited
//15,16,17,23,25,...

PARAMETER treeStart IS 100,treeEnd IS 101.
SET treeEnd TO MAX(treeStart,treeEnd).
LOCAL treeCurrent IS treeStart.
LOCAL goodTrees IS LIST().

UNTIL treeCurrent > treeEnd {
	LOCAL tree IS generate_tree(treeCurrent).
	LOCAL walkStart IS find_start(tree).
	FROM { LOCAL startOffset IS 0. } UNTIL startOffset > treeCurrent STEP { SET startOffset TO startOffset + 1. } DO {
		PRINT ROUND(startOffset / treeCurrent * 100).
		IF walk_tree(tree,MOD(walkStart + startOffset - 1,treeCurrent) + 1) {
			PRINT treeCurrent + " was good".
			goodTrees:ADD(treeCurrent).
			BREAK.
		}
	}
	//PRINT treeCurrent.
	SET treeCurrent TO treeCurrent + 1.
}
PRINT goodTrees.


FUNCTION generate_tree {
	PARAMETER treeCurrent.
	PRINT "building tree for: " + treeCurrent.
	LOCAL tree IS LEX().
	FROM { LOCAL i IS 1. } UNTIL i > treeCurrent STEP { SET i TO i + 1. } DO {
		tree:ADD(i,LIST()).
	}
	
	LOCAL maxSquared IS treeCurrent * 2 - 1
	LOCAL iSquared IS 0.
	FROM { LOCAL i IS 2. UNTIL } iSquared > maxSquared STEP { SET i TO i + 1. } DO {
		LOCAL iSquared IS (i^2).
		LOCAL half IS iSquared / 2.
		FROM { LOCAL j IS 1. } UNTIL j >= half STEP {SET j TO j + 1. } DO {
			tree[j]:ADD(iSquared - j).
			tree[iSquared - j]:ADD(j).
		}
	}
	
	PRINT "tree build complete.".
	RETURN tree.
}

FUNCTION find_start {
	PARAMETER tree.
	FROM { LOCAL i IS 1. } UNTIL i > treeCurrent STEP { SET i TO i + 1. } DO {
		IF tree[i]:LENGTH = 1 {
			RETURN i.
		}
	}
	RETURN 1.
}

FUNCTION walk_tree {
	PARAMETER tree,walkStart.
	LOCAL currentPath IS LIST(walkStart).
	LOCAL pathLength IS currentPath:LENGTH.
	LOCAL currentVertex IS walkStart.
	LOCAL removedVertex IS -1.
	LOCAL maxPath IS tree:KEYS:LENGTH.
	//LOCAL endPrint IS FALSE.
	//LOCAL lastTime IS TIME:SECONDS + 1.
	//WHEN TIME:SECONDS > lastTime OR endPrint THEN {
	//	IF NOT endPrint {
	//		SET lastTime TO lastTime + 1.
	//		PRINT "done: " + ROUND((currentPath:LENGTH / maxPath) * 100,2) + "%       " AT(0,0).
	//		RETURN TRUE.
	//	}
	//}
	LOCAL currentVertexes IS tree[currentVertex].
	//PRINT "loop Started".
	UNTIL (pathLength = maxPath) OR (pathLength = 0) {
		LOCAL nextVert IS lowest_vertex(removedVertex,currentVertexes,currentPath).
		
		//PRINT "current: " + currentVertex.
		//PRINT "removed: " + removedVertex.
		//PRINT "next: " + nextVert.
		//PRINT "possible: " + currentVertexes.
		//PRINT "current path: " + currentPath.
		//PRINT " ".
		//RCS OFF.
		//WAIT UNTIL RCS.
		
		IF nextVert = 0 {
			currentPath:REMOVE(pathLength - 1).
			SET pathLength TO currentPath:LENGTH.
			IF pathLength = 0 {
				BREAK.
			} ELSE {
				SET removedVertex TO currentVertex.
				SET currentVertex TO currentPath[pathLength - 1].
				SET currentVertexes TO tree[currentVertex].
			}
		} ELSE {
			SET currentVertex TO nextVert.
			currentPath:ADD(currentVertex).
			SET pathLength TO currentPath:LENGTH.
			SET removedVertex TO -1.
			SET currentVertexes TO tree[currentVertex].
		}
	}
	//PRINT currentPath.
	//SET endPrint TO TRUE.
	//WAIT 0.1.
	RETURN (currentPath:LENGTH = maxPath).
}

FUNCTION lowest_vertex {
	PARAMETER below,vertexes,blackList.
	FOR vertex IN vertexes {
		IF (NOT blackList:CONTAINS(vertex)) AND below < vertex {
			RETURN vertex.
		}
	}
	RETURN 0.
}