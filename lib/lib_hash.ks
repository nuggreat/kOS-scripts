SET CONFIG:IPU TO 2000.

FUNCTION hash_file {
  PARAMETER fPath,hashType IS "simple",hexReturn IS TRUE, reduced IS FALSE.
  RETURN generate_hash(OPEN(PATH(fPath)):READALL():STRING,hashType,hexReturn,reduced).
}

FUNCTION generate_hash {//the pre-processing for SHA_1 and SHA_2 functions
  PARAMETER inStr,hashType IS "sha-1",hexReturn IS TRUE, reduced IS FALSE.
  LOCAL bitsPerChar IS 0.
  LOCAL bitThreshold IS 0.
  FROM { local i IS inStr:LENGTH - 1. } UNTIL i < 0 STEP { SET i TO i - 1. } DO {
    IF UNCHAR(inStr[i]) > bitThreshold {
      SET bitsPerChar TO FLOOR(LOG10(UNCHAR(inStr[i])) / LOG10(2)) + 1.//how many bits needed to hold the given char, might not be a 2^x number of bits
      SET bitsPerChar TO 2^CEILING(LOG10(bitsPerChar) / LOG10(2)).
      SET bitThreshold TO 2^bitsPerChar - 1.
    }
  }
  //PRINT bitsPerChar.
  print "size check".

  LOCAL bitStr IS "".
  FROM { local i IS inStr:LENGTH - 1. } UNTIL i < 0 STEP { SET i TO i - 1. } DO {
    SET bitStr TO num_to_bin(UNCHAR(inStr[i]),bitsPerChar) + bitStr.
  }
  LOCAL inSrtLength IS bitStr:LENGTH.
  print "string generation".

  SET bitStr TO bitStr + "1".

  UNTIL MOD(bitStr:LENGTH,512) = 448 { SET bitStr TO bitStr + "0". }
  SET bitStr TO bitStr + num_to_bin(inSrtLength,64).

  //PRINT bitStr.
  LOCAL result IS "0000".
  IF hashType = "simple" {
    SET result to simple_hash(bitStr,reduced).
  } ELSE IF hashType = "sha-1" {
    SET result TO SHA_1(bitStr,reduced).
  } ELSE IF hashType = "sha-2" {
    SET result TO SHA_2(bitStr,reduced).
  }
  RETURN (CHOOSE bin_to_hex(result) IF hexReturn ELSE result).
}

LOCAL simpleHashData IS LEX(
  "h0",hex_to_bin("6665983E"),
  "h1",hex_to_bin("A4A68A65"),
  "h2",hex_to_bin("7A3CDD00"),
  "h3",hex_to_bin("E6083229")
).

FUNCTION simple_hash {
  PARAMETER bitStr,reduced.

  LOCAL h0 IS simpleHashData:h0.
  LOCAL h1 IS simpleHashData:h1.
  LOCAL h2 IS simpleHashData:h2.
  LOCAL h3 IS simpleHashData:h3.

  LOCAL iMax IS bitStr:LENGTH - 1.
  FROM { local i IS 0. } UNTIL i > iMax STEP { SET i TO i + 512. } DO {

    LOCAL wordList IS LIST().
    LOCAL jMax IS i + 512.
    FROM { LOCAL j IS i. } UNTIL j >= jMax STEP { SET j TO j + 32. } DO {
      wordList:ADD(bitStr:SUBSTRING(j,32)).
    }


    LOCAL aSeg IS h0.
    LOCAL bSeg IS h1.
    LOCAL cSeg IS h2.
    LOCAL dSeg IS h3.

    FROM { LOCAL w IS 0. } UNTIL w >= 16 STEP { SET w TO w + 1. } DO {
      LOCAL tmpSeg IS bin_XOR(bin_rotate_left(dSeg,1),wordList[w]).
      SET dSeg TO cSeg.
      SET cSeg TO bSeg.
      SET bSeg TO aSeg.
      SET aSeg TO tmpSeg.
    }

    SET h0 TO bin_ADD(h0,aSeg).
    SET h1 TO bin_ADD(h1,bSeg).
    SET h2 TO bin_ADD(h2,cSeg).
    SET h3 TO bin_ADD(h3,dSeg).
  }
  RETURN h0 + h1 + h2 + h2.
}

//constants needed for SHA_1

LOCAL sha1Data IS LEX(
  "h0",hex_to_bin("67452301"),
  "h1",hex_to_bin("EFCDAB89"),
  "h2",hex_to_bin("98BADCFE"),
  "h3",hex_to_bin("10325476"),
  "h4",hex_to_bin("C3D2E1F0"),
  "kList",LIST(
    hex_to_bin("5A827999"),
    hex_to_bin("6ED9EBA1"),
    hex_to_bin("8F1BBCDC"),
    hex_to_bin("CA62C1D6")
  )
).

LOCAL FUNCTION SHA_1 {//an implementation of the SHA-1 algorithm
  PARAMETER bitStr,reduced.
  LOCAL h0 IS sha1Data:h0.
  LOCAL h1 IS sha1Data:h1.
  LOCAL h2 IS sha1Data:h2.
  LOCAL h3 IS sha1Data:h3.
  LOCAL h4 IS sha1Data:h4.
  LOCAL k0 IS sha1Data:kList[0].
  LOCAL k1 IS sha1Data:kList[1].
  LOCAL k2 IS sha1Data:kList[2].
  LOCAL k3 IS sha1Data:kList[3].

  LOCAL wMax IS CHOOSE 16 IF reduced ELSE 80.
  LOCAL w0 IS wMax / 4.
  LOCAL w1 IS w0 * 2.
  LOCAL w3 IS w0 * 3.

  LOCAL iMax IS bitStr:LENGTH - 1.
  FROM { local i IS 0. } UNTIL i > iMax STEP { SET i TO i + 512. } DO {
    //print ROUND((i / iMax) * 100,4).

    LOCAL wordList IS LIST().
    LOCAL jMax IS i + 512.
    FROM { LOCAL j IS i. } UNTIL j >= jMax STEP { SET j TO j + 32. } DO {
      wordList:ADD(bitStr:SUBSTRING(j,32)).
    }


    IF NOT reduced {
      FROM { LOCAL j IS 16. } UNTIL j >=80 STEP { SET j TO j + 1. } DO {
        //LOCAL tmpWord IS bin_XOR(wordList[j - 3],wordList[j - 8]).
        //SET tmpWord TO bin_XOR(tmpWord,wordList[j - 14]).
        //SET tmpWord TO bin_XOR(tmpWord,wordList[j - 16]).
        //SET tmpWord TO bin_rotate_left(tmpWord,1).
        //wordList:ADD(tmpWord).
        wordList:ADD(bin_rotate_left(bin_XOR(bin_XOR(bin_XOR(wordList[j - 3],wordList[j - 8]),wordList[j - 14]),wordList[j - 16]),1)).
      }
    }

    LOCAL f IS "".
    LOCAL k IS "".
    LOCAL aSeg IS h0.
    LOCAL bSeg IS h1.
    LOCAL cSeg IS h2.
    LOCAL dSeg IS h3.
    LOCAL eSeg IS h4.
    LOCAL tmpSeg IS "".
    FROM { LOCAL w IS 0. } UNTIL w >= wMax STEP { SET w TO w + 1. } DO {
      IF w < w1 {
        IF w < w0 {
          //LOCAL bANDc IS bin_AND(bSeg,cSeg).
          //LOCAL NOTbANDd IS bin_AND(bin_NOT(bSeg),dSeg).
          //SET f TO bin_OR(bANDc,NOTbANDd).
          SET f TO bin_OR(bin_AND(bSeg,cSeg),bin_AND(bin_NOT(bSeg),dSeg)).
          SET k TO k0.
        } ELSE {
          //LOCAL bXORc IS bin_XOR(bSeg,cSeg).
          //SET f TO bin_XOR(bXORc,dSeg).
          SET f TO bin_XOR(bin_XOR(bSeg,cSeg),dSeg).
          SET k TO k1.
        }
      } ELSE {
        IF w < w3 {
          //LOCAL bANDc IS bin_AND(bSeg,cSeg).
          //LOCAL bANDd IS bin_AND(bSeg,dSeg).
          //LOCAL cANDd IS bin_AND(cSeg,dSeg).
          //SET f TO bin_OR(bin_OR(bANDc,bANDd),cANDd).
          SET f TO bin_OR(bin_OR(bin_AND(bSeg,cSeg),bin_AND(bSeg,dSeg)),bin_AND(cSeg,dSeg)).
          SET k TO k2.
        } ELSE {
          //LOCAL bXORc IS bin_XOR(bSeg,cSeg).
          //SET f TO bin_XOR(bXORc,dSeg).
          SET f TO bin_XOR(bin_XOR(bSeg,cSeg),dSeg).
          SET k TO k3.
        }
      }
      //SET tmpSeg TO bin_rotate_left(aSeg,5).
      //SET tmpSeg TO bin_ADD(tmpSeg,f).
      //SET tmpSeg TO bin_ADD(tmpSeg,eSeg).
      //SET tmpSeg TO bin_ADD(tmpSeg,k).
      //SET tmpSeg TO bin_ADD(tmpSeg,wordList[w]).
      SET tmpSeg TO bin_ADD_multi(LIST(bin_rotate_left(aSeg,5),f,eSeg,k,wordList[w])).
      SET eSeg TO dSeg.
      SET dSeg TO cSeg.
      SET cSeg TO bin_rotate_left(bSeg,30).
      SET bSeg TO aSeg.
      SET aSeg TO tmpSeg.
    }
    SET h0 TO bin_ADD(h0,aSeg).
    SET h1 TO bin_ADD(h1,bSeg).
    SET h2 TO bin_ADD(h2,cSeg).
    SET h3 TO bin_ADD(h3,dSeg).
    SET h4 TO bin_ADD(h4,eSeg).
  }
  RETURN (h0 + h1 + h2 + h3 + h4).
}

//constants needed for SHA_2
LOCAL sha2Data IS LEX(
  "h0",hex_to_bin("6A09E667"),
  "h1",hex_to_bin("BB67AE85"),
  "h2",hex_to_bin("3C6EF372"),
  "h3",hex_to_bin("A54FF53A"),
  "h4",hex_to_bin("510E527F"),
  "h5",hex_to_bin("9B05688C"),
  "h6",hex_to_bin("1F83D9AB"),
  "h7",hex_to_bin("5BE0CD19"),
  "kList",LIST()
).

FOR k IN LIST(
"428A2F98","71374491","B5C0FBCF","E9B5DBA5","3956C25B","59F111F1","923F82A4","AB1C5ED5",
"D807AA98","12835B01","243185BE","550C7DC3","72BE5D74","80DEB1FE","9BDC06A7","C19BF174",
"E49B69C1","EFBE4786","0FC19DC6","240CA1CC","2DE92C6F","4A7484AA","5CB0A9DC","76F988DA",
"983E5152","A831C66D","B00327C8","BF597FC7","C6E00BF3","D5A79147","06CA6351","14292967",
"27B70A85","2E1B2138","4D2C6DFC","53380D13","650A7354","766A0ABB","81C2C92E","92722C85",
"A2BFE8A1","A81A664B","C24B8B70","C76C51A3","D192E819","D6990624","F40E3585","106AA070",
"19A4C116","1E376C08","2748774C","34B0BCB5","391C0CB3","4ED8AA4A","5B9CCA4F","682E6FF3",
"748F82EE","78A5636F","84C87814","8CC70208","90BEFFFA","A4506CEB","BEF9A3F7","C67178F2") {
  sha2Data:kList:ADD(hex_to_bin(k)).
}

LOCAL FUNCTION SHA_2 {//an implementation of the SHA-256 algorithm
  PARAMETER bitStr,reduced.
  LOCAL h0 IS sha2Data:h0.
  LOCAL h1 IS sha2Data:h1.
  LOCAL h2 IS sha2Data:h2.
  LOCAL h3 IS sha2Data:h3.
  LOCAL h4 IS sha2Data:h4.
  LOCAL h5 IS sha2Data:h5.
  LOCAL h6 IS sha2Data:h6.
  LOCAL h7 IS sha2Data:h7.

  LOCAL wMax IS CHOOSE 16 IF reduced ELSE 64.
  LOCAL iMax IS bitStr:LENGTH - 1.
  FROM { local i IS 0. } UNTIL i > iMax STEP { SET i TO i + 512. } DO {

    LOCAL wordList IS LIST().
    LOCAL jMax IS i + 512.
    FROM { LOCAL j IS i. } UNTIL j >= jMax STEP { SET j TO j + 32. } DO {
      wordList:ADD(bitStr:SUBSTRING(j,32)).
    }

    IF NOT reduced {
      FROM { LOCAL j IS 16. } UNTIL j >= 64 STEP { SET j TO j + 1. } DO {
        LOCAL s0 IS wordList[j - 15].
        //LOCAL tmp1a IS bin_rotate_left(s0,25).//equivalent to a rotate right of 7
        //LOCAL tmp1b IS bin_rotate_left(s0,14).//equivalent to a rotate right of 18
        //LOCAL tmp1c IS bin_rotate_left(s0,29).//equivalent to a rotate right of 3
        //LOCAL tmp1 IS bin_XOR(tmp1a,tmp1b).
        //SET tmp1 TO bin_XOR(tmp1,tmp1c).
        LOCAL tmp1 IS bin_XOR(bin_XOR(bin_rotate_left(s0,25),bin_rotate_left(s0,14)),bin_rotate_left(s0,29)).

        LOCAL s1 IS wordList[j - 2].
        //LOCAL tmp2a IS bin_rotate_left(s1,15).//equivalent to a rotate right of 17
        //LOCAL tmp2b IS bin_rotate_left(s1,13).//equivalent to a rotate right of 19
        //LOCAL tmp2c IS bin_rotate_left(s1,22).//equivalent to a rotate right of 10
        //LOCAL tmp2 IS bin_XOR(tmp2a,tmp2b).
        //SET tmp2 TO bin_XOR(tmp2,tmp2c).
        LOCAL tmp2 IS bin_XOR(bin_XOR(bin_rotate_left(s1,15), bin_rotate_left(s1,13)),bin_rotate_left(s1,22)).

        //LOCAL tmpWord IS bin_ADD(wordList[j - 16],tmp1).
        //SET tmpWord TO bin_ADD(tmpWord,wordList[j - 7]).
        //SET tmpWord TO bin_ADD(tmpWord,tmp2).
        //wordList:ADD(tmpWord).
        wordList:ADD(bin_ADD_multi(LIST(wordList[j - 16],tmp1,wordList[j - 7],tmp2))).
      }
    }

    LOCAL aSeg IS h0.
    LOCAL bSeg IS h1.
    LOCAL cSeg IS h2.
    LOCAL dSeg IS h3.
    LOCAL eSeg IS h4.
    LOCAL fSeg IS h5.
    LOCAL gSeg IS h6.
    LOCAL hSeg IS h7.
    LOCAL tmpSeg1 IS "".
    LOCAL tmpSeg2 IS "".
    FROM { LOCAL w IS 0. } UNTIL w >= wMax STEP { SET w TO w + 1. } DO {
      //LOCAL s1 IS bin_rotate_left(eSeg,28).
      //SET s1 TO bin_XOR(s1,bin_rotate_left(eSeg,21)).
      //SET s1 TO bin_XOR(s1,bin_rotate_left(eSeg,7)).
      //LOCAL ch IS bin_AND(eSeg,fSeg).
      //SET ch TO bin_XOR(ch,bin_AND(bin_NOT(eSeg),gSeg)).
      //LOCAL tmp1 IS bin_ADD(hSeg,s1).
      //SET tmp1 TO bin_ADD(tmp1,ch).
      //SET tmp1 TO bin_ADD(tmp1,sha2Data:kList[w]).
      //SET tmp1 TO bin_ADD(tmp1,wordList[w]).

      LOCAL tmp1 IS bin_ADD_multi(LIST(hSeg,bin_XOR(bin_XOR(bin_rotate_left(eSeg,28),bin_rotate_left(eSeg,21)),bin_rotate_left(eSeg,7)),bin_XOR(bin_AND(eSeg,fSeg),bin_AND(bin_NOT(eSeg),gSeg)),sha2Data:kList[w],wordList[w])).

      //LOCAL s0 IS bin_rotate_left(aSeg,30).
      //SET s0 TO bin_XOR(s0,bin_rotate_left(aSeg,19)).
      //SET s0 TO bin_XOR(s0,bin_rotate_left(aSeg,10)).
      //LOCAL maj IS bin_AND(aSeg,bSeg).
      //SET maj TO bin_XOR(maj,bin_AND(aSeg,cSeg)).
      //SET maj TO bin_XOR(maj,bin_AND(bSeg,cSeg)).
      //LOCAL tmp2 IS bin_ADD(s0,maj).
      LOCAL tmp2 IS bin_ADD(bin_XOR(bin_XOR(bin_rotate_left(aSeg,30),bin_rotate_left(aSeg,19)),bin_rotate_left(aSeg,10)),bin_XOR(bin_XOR(bin_AND(aSeg,bSeg),bin_AND(aSeg,cSeg)),bin_AND(bSeg,cSeg))).

      SET hSeg TO gSeg.
      SET gSeg TO fSeg.
      SET fSeg TO eSeg.
      SET eSeg TO bin_ADD(dSeg,tmp1).
      SET dSeg TO cSeg.
      SET cSeg TO bSeg.
      SET bSeg TO aSeg.
      SET aSeg TO bin_ADD(tmp1,tmp2).
    }
    SET h0 TO bin_ADD(h0,aSeg).
    SET h1 TO bin_ADD(h1,bSeg).
    SET h2 TO bin_ADD(h2,cSeg).
    SET h3 TO bin_ADD(h3,dSeg).
    SET h4 TO bin_ADD(h4,eSeg).
    SET h5 TO bin_ADD(h5,fSeg).
    SET h6 TO bin_ADD(h6,gSeg).
    SET h7 TO bin_ADD(h7,hSeg).
  }
  RETURN (h0 + h1 + h2 + h3 + h4 + h5 + h6 + h7).
}

LOCAL FUNCTION bin_rotate_left {
  PARAMETER binStr,rotate.
  SET rotate TO MOD(rotate,binStr:LENGTH).
  RETURN binStr:SUBSTRING(rotate,binStr:LENGTH - rotate) + binStr:SUBSTRING(0,rotate).
}

LOCAL FUNCTION bin_NOT {
  PARAMETER bin.
  LOCAL returnStr IS "".
  FROM { LOCAL i IS bin:LENGTH - 1. } UNTIL i < 0 STEP { SET i TO i - 1. } DO {
    SET returnStr TO (CHOOSE "1" IF (bin[i] = "0") ELSE "0") + returnStr.
  }
  RETURN returnStr.
}

LOCAL FUNCTION bin_OR {
  PARAMETER bin1,bin2.
  LOCAL returnStr IS "".
  FROM { LOCAL i IS bin1:LENGTH - 1. } UNTIL i < 0 STEP { SET i TO i - 1. } DO {
    SET returnStr TO (CHOOSE "1" IF ((bin1[i] = "1") OR (bin2[i] = "1")) ELSE "0") + returnStr.
  }
  RETURN returnStr.
}

LOCAL FUNCTION bin_OR_multi {
  PARAMETER binList.
  LOCAL returnStr IS "".
  LOCAL bins IS binList:LENGTH - 1.
  FROM { LOCAL i IS binList[0]:LENGTH - 1. } UNTIL i < 0 STEP { SET i TO i - 1. } DO {
    LOCAL bitVal IS "0".
    FROM { LOCAL j IS bins. } UNTIL j < 0 STEP { SET j TO j - 1. } DO {
      IF binList[j][i] = "1" {
        SET bitVal TO "1".
        BREAK.
      }
    }
    SET returnStr TO bitVal + returnStr.
  }
  RETURN returnStr.
}

LOCAL FUNCTION bin_AND {
  PARAMETER bin1,bin2.
  LOCAL returnStr IS "".
  FROM { LOCAL i IS bin1:LENGTH - 1. } UNTIL i < 0 STEP { SET i TO i - 1. } DO {
    SET returnStr TO (CHOOSE "1" IF ((bin1[i] = "1") AND (bin2[i] = "1")) ELSE "0") + returnStr.
  }
  RETURN returnStr.
}

LOCAL FUNCTION bin_AND_multi {
  PARAMETER binList.
  LOCAL returnStr IS "".
  LOCAL bins IS binList:LENGTH - 1.
  FROM { LOCAL i IS binList[0]:LENGTH - 1. } UNTIL i < 0 STEP { SET i TO i - 1. } DO {
    LOCAL bitVal IS "1".
    FROM { LOCAL j IS bins. } UNTIL j < 0 STEP { SET j TO j - 1. } DO {
      IF binList[j][i] = "0" {
        SET bitVal TO "0".
        BREAK.
      }
    }
    SET returnStr TO bitVal + returnStr.
  }
  RETURN returnStr.
}

LOCAL FUNCTION bin_XOR {
  PARAMETER bin1,bin2.
  LOCAL returnStr IS "".
  FROM { LOCAL i IS bin1:LENGTH - 1. } UNTIL i < 0 STEP { SET i TO i - 1. } DO {
    SET returnStr TO MOD(bin1[i]:TONUMBER() + bin2[i]:TONUMBER(),2) + returnStr.
  }
  RETURN returnStr.
}

LOCAL FUNCTION bin_XOR_multi {//Exclusive Or for 3 or more binary strings
  PARAMETER binList.
  LOCAL returnStr IS "".
  LOCAL bins IS binList:LENGTH - 1.
  //LOCAL bitVal IS 0.
  FROM { LOCAL i IS binList[0]:LENGTH - 1. } UNTIL i < 0 STEP { SET i TO i - 1. } DO {
    LOCAL bitVal IS binList[0][i]:TONUMBER().
    FROM { LOCAL j IS bins. } UNTIL j < 1 STEP { SET j TO j - 1. } DO {
      SET bitVal TO bitVal + binList[j][i]:TONUMBER().
    }

    SET returnStr TO MOD(bitVal,2) + returnStr.
  }
  RETURN returnStr.
}

LOCAL FUNCTION bin_ADD {//add 2 bin strings, will discard any overflow, bin string must be same length
  PARAMETER bin1,bin2.
  LOCAL returnStr IS "".
  LOCAL carry IS 0.
  FROM { LOCAL i IS bin1:LENGTH - 1. } UNTIL i < 0 STEP { SET i TO i - 1. } DO {
    LOCAL sum IS bin1[i]:TONUMBER() + bin2[i]:TONUMBER() + carry.
    SET carry TO FLOOR(sum / 2).
    SET returnStr TO MOD(sum,2) + returnStr.
  }
  RETURN returnStr.
}

LOCAL FUNCTION bin_ADD_multi {//add 3 or more bin strings, will discard any overflow, bin string must be same length
  PARAMETER binList.
  LOCAL returnStr IS "".
  LOCAL bins IS binList:LENGTH - 1.
  LOCAL carry IS 0.
  FROM { LOCAL i IS binList[0]:LENGTH - 1. } UNTIL i < 0 STEP { SET i TO i - 1. } DO {
    LOCAL sum IS carry.
    FROM { LOCAL j IS bins. } UNTIL j < 0 STEP { SET j TO j - 1. } DO {
      SET sum TO sum + binList[j][i]:TONUMBER.
    }
    SET carry TO FLOOR((sum) / 2).
    SET returnStr TO MOD(sum,2) + returnStr.
  }
  RETURN returnStr.
}

LOCAL FUNCTION num_to_bin {//converts a number to a binary string of a given length, assumes said number is an intiger
  PARAMETER num,maxBits,doSign IS FALSE.
  LOCAL returnStr IS "".
  LOCAL sign IS num > 0.
  IF doSign {
    SET maxBits TO maxBits - 1.
  }
  SET num TO ABS(num).
  LOCAL sign IS num < 0.
  UNTIL returnStr:LENGTH >= maxBits {
    SET returnStr TO MOD(num,2) + returnStr.
    SET num TO FLOOR(num / 2).
  }
  IF doSign {
    RETURN (CHOOSE ("0" + returnStr) IF sign ELSE ("1" + returnStr)).
  } ELSE {
    RETURN returnStr.
  }
}

LOCAL FUNCTION bin_to_num {//converts a binary string to an intiger
  PARAMETER bin,isSigned IS FALSE.
  LOCAL returnNum IS 0.
  LOCAL binMax IS bin:LENGTH - 1.
  LOCAL endBit IS 0.
  IF isSigned {
    SET endBit TO 1.
  }
  FROM { LOCAL i IS binMax. } UNTIL i < endBit STEP { SET i TO i - 1. } DO {
    SET returnNum TO returnNum + (CHOOSE 2^(binMax - i) IF (bin[i] = "1") ELSE 0).
  }
  IF isSigned {
    RETURN (CHOOSE returnNum IF bin[0] = "0" ELSE -returnNum).
  } ELSE {
    RETURN returnNum.
  }
}

LOCAL FUNCTION bin_to_hex {
  PARAMETER bin.
  LOCAL returnStr IS "".
  LOCAL iMax IS bin:LENGTH - 1.
  FROM { LOCAL i IS 0. } UNTIL i > iMax STEP { SET i TO i + 4. } DO {
    LOCAL binVal IS bin_to_num(bin:SUBSTRING(i,4)).
    IF binVal < 10 {//the 0 through 9 range
      SET returnStr TO returnStr + CHAR(binVal + 48).
    } ELSE {//the A through F range
      SET returnStr TO returnStr + CHAR(binVal + 55).
    }
  }
  RETURN returnStr.
}

LOCAL FUNCTION hex_to_bin {
  PARAMETER hexString.
  LOCAL returnStr IS "".
  //FOR charter IN hexString {
  FROM { LOCAL i IS hexString:LENGTH - 1. } UNTIL i < 0 STEP { SET i TO i - 1. } DO {
    LOCAL charVal IS UNCHAR(hexString[i]) - 48.
    IF charVal >= 10 {
      SET charVal TO charVal - 7.
    }
    IF charVal > 15 {//if using lower case letters
      SET charVal TO charVal - 32.
    }
    SET returnStr TO num_to_bin(charVal,4) + returnStr.
  }
  RETURN returnStr.
}