//all number are encoded in big endian with the most significant bit/byte in the left most place
// simple is about 1548  bits per second at 2000 IPU
//  SHA-1 is about 80.17 bits per second at 2000 IPU
//SHA-224 is about 37.24 bits per second at 2000 IPU
//SHA-256 is about 37.22 bits per second at 2000 IPU
//SHA-384 is about 30.00 bits per second at 2000 IPU
FUNCTION hash_file {
  PARAMETER fPath,
    hashType IS "simple",
    hexReturn IS TRUE,
    doPrint IS FALSE,
    reduced IS FALSE.
  RETURN hash_string(OPEN(PATH(fPath)):READALL():STRING,hashType,hexReturn,doPrint,reduced).
}

FUNCTION hash_string {//the pre-processing for SHA_1 and SHA_2 functions
  PARAMETER inStr,
    hashType IS "SHA-1",
    hexReturn IS TRUE,
    doPrint IS FALSE,
    reduced IS FALSE.
  LOCAL oldIPU IS CONFIG:IPU.
  SET CONFIG:IPU TO 2000.
  
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
  IF doPrint { print "size check done". }

  LOCAL bitStr IS "".
  FROM { local i IS inStr:LENGTH - 1. } UNTIL i < 0 STEP { SET i TO i - 1. } DO {
    SET bitStr TO int_to_bin(UNCHAR(inStr[i]),bitsPerChar) + bitStr.
  }
  IF doPrint { print "string generation". }

  //PRINT bitStr.
  LOCAL result IS "0000".
  IF hashType = "simple" {
    SET result to simple_hash(bitStr,reduced).
  } ELSE IF hashType = "SHA-1" {
    SET result TO SHA_1(bitStr,reduced).
  } ELSE IF sha2Data:HASKEY(hashType) {
    SET result TO SHA_2(bitStr,reduced,hashType).
  } ELSE IF hashType:CONTAINS("SHA-512/") {
    LOCAL typeNum IS hashType:SPLIT("/")[1]:TONUMBER(512).
    IF typeNum = 384 OR typeNum = 512 {
	  SET hashType TO "SHA-" + typeNum.
      SET result TO SHA_2(bitStr,reduced,hashType).
	} ELSE IF typeNum < 512 {
      sha2Data:ADD(hashType,LEX(
        "h",hash_string(hashType,"SHA-512/t",FALSE),
        "k",sha2Data["SHA-512"]["k"],
        "w",sha2Data["SHA-512"]["w"],
        "s",sha2Data["SHA-512"]["s"],
        "cfg",sha2Data["SHA-512"]["cfg"]
      )).
      SET result TO SHA_2(bitStr,reduced,hashType).
	}
  }
  SET CONFIG:IPU TO oldIPU.
  RETURN (CHOOSE bin_to_hex(result) IF hexReturn ELSE result).
}

LOCAL simpleHashData IS LEX(
  "h",LIST(
    hex_to_bin("6665983E"),
    hex_to_bin("A4A68A65"),
    hex_to_bin("7A3CDD00"),
    hex_to_bin("E6083229")
  ),
  "cfg",LEX(
    "fullRounds",64,
    "reducedRounds",16,
    "wordSize",32,
    "blockSize",512,
    "lengthSize",64
  )
).

LOCAL FUNCTION simple_hash {
  PARAMETER bitStr,reduced.

  //imparting constants
  LOCAL h0 IS simpleHashData:h[0].
  LOCAL h1 IS simpleHashData:h[1].
  LOCAL h2 IS simpleHashData:h[2].
  LOCAL h3 IS simpleHashData:h[3].
  LOCAL blockSize IS sha1Data:cfg:blockSize.
  LOCAL wordSize IS sha1Data:cfg:wordSize.

  //padding input string
  SET bitStr TO bitStr + padd_str(bitStr:LENGTH,blockSize,simpleHashData:lengthSize).
  
  LOCAL iMax IS bitStr:LENGTH - 1.
  FROM { local i IS 0. } UNTIL i > iMax STEP { SET i TO i + blockSize. } DO {

    LOCAL wordList IS LIST().
    LOCAL jMax IS i + blockSize.
    FROM { LOCAL j IS i. } UNTIL j >= jMax STEP { SET j TO j + wordSize. } DO {
      wordList:ADD(bitStr:SUBSTRING(j,wordSize)).
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
PRINT "loading SHA_1 data".
LOCAL sha1Data IS LEX(
  "h",LIST(
   hex_to_bin("67452301"),
   hex_to_bin("EFCDAB89"),
   hex_to_bin("98BADCFE"),
   hex_to_bin("10325476"),
   hex_to_bin("C3D2E1F0")
  ),
  "k",LIST(
    hex_to_bin("5A827999"),
    hex_to_bin("6ED9EBA1"),
    hex_to_bin("8F1BBCDC"),
    hex_to_bin("CA62C1D6")
  ),
  "cfg",LEX(
    "fullRounds",80,
    "reducedRounds",16,
    "wordSize",32,
    "blockSize",512,
    "lengthSize",64
  )
).

LOCAL FUNCTION SHA_1 {//an implementation of the SHA-1 algorithm
  PARAMETER bitStr,reduced.
  
  //importing constants and configuration
  LOCAL h0 IS sha1Data:h[0].
  LOCAL h1 IS sha1Data:h[1].
  LOCAL h2 IS sha1Data:h[2].
  LOCAL h3 IS sha1Data:h[3].
  LOCAL h4 IS sha1Data:h[4].
  LOCAL k0 IS sha1Data:k[0].
  LOCAL k1 IS sha1Data:k[1].
  LOCAL k2 IS sha1Data:k[2].
  LOCAL k3 IS sha1Data:k[3].
  LOCAL blockSize IS sha1Data:cfg:blockSize.
  LOCAL wordSize IS sha1Data:cfg:wordSize.

  LOCAL rounds IS CHOOSE sha1Data:cfg:reducedRounds IF reduced ELSE sha1Data:cfg:fullRounds.
  LOCAL w1 IS rounds / 4.
  LOCAL w2 IS w1 * 2.
  LOCAL w3 IS w1 * 3.
  
  //padding input string
  SET bitStr TO bitStr + padd_str(bitStr:LENGTH,blockSize,sha1Data:cfg:lengthSize).

  LOCAL iMax IS bitStr:LENGTH - 1.
  FROM { local i IS 0. } UNTIL i > iMax STEP { SET i TO i + blockSize. } DO {
    //print ROUND((i / iMax) * 100,4).

    LOCAL wordList IS LIST().
    LOCAL jMax IS i + blockSize.
    FROM { LOCAL j IS i. } UNTIL j >= jMax STEP { SET j TO j + wordSize. } DO {
      wordList:ADD(bitStr:SUBSTRING(j,wordSize)).
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
    FROM { LOCAL w IS 0. } UNTIL w >= rounds STEP { SET w TO w + 1. } DO {
      IF w < w2 {
        IF w < w1 {
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

PRINT "loading SHA_2 data".
PRINT "loading 256".
LOCAL sha2Data IS LEX().
sha2Data:ADD("SHA-256",LEX(
  "h",LIST(),
  "k",LIST(),
  "w",LIST(7,18,3,17,19,10),
  "s",LIST(2,13,22,6,11,25),
  "cfg",LEX(
    "fullRounds",64,
    "reducedRounds",16,
    "wordSize",32,
    "blockSize",512,
    "lengthSize",64
  )
)).
	  
FOR h IN LIST("6A09E667","BB67AE85","3C6EF372","A54FF53A","510E527F","9B05688C","1F83D9AB","5BE0CD19") {
  sha2Data["SHA-256"]["h"]:ADD(hex_to_bin(h)).
}

FOR k IN LIST(
"428A2F98","71374491","B5C0FBCF","E9B5DBA5","3956C25B","59F111F1","923F82A4","AB1C5ED5",
"D807AA98","12835B01","243185BE","550C7DC3","72BE5D74","80DEB1FE","9BDC06A7","C19BF174",
"E49B69C1","EFBE4786","0FC19DC6","240CA1CC","2DE92C6F","4A7484AA","5CB0A9DC","76F988DA",
"983E5152","A831C66D","B00327C8","BF597FC7","C6E00BF3","D5A79147","06CA6351","14292967",
"27B70A85","2E1B2138","4D2C6DFC","53380D13","650A7354","766A0ABB","81C2C92E","92722C85",
"A2BFE8A1","A81A664B","C24B8B70","C76C51A3","D192E819","D6990624","F40E3585","106AA070",
"19A4C116","1E376C08","2748774C","34B0BCB5","391C0CB3","4ED8AA4A","5B9CCA4F","682E6FF3",
"748F82EE","78A5636F","84C87814","8CC70208","90BEFFFA","A4506CEB","BEF9A3F7","C67178F2") {
  sha2Data["SHA-256"]["k"]:ADD(hex_to_bin(k)).
}

PRINT "loading 224".
sha2Data:ADD("SHA-224",LEX(
  "h",LIST(),
  "k",sha2Data["SHA-256"]["k"],
  "w",sha2Data["SHA-256"]["w"],
  "s",sha2Data["SHA-256"]["s"],
  "cfg",sha2Data["SHA-256"]["cfg"]
)).

FOR h IN LIST("C1059ED8","367CD507","3070DD17","F70E5939","FFC00B31","68581511","64F98FA7","BEFA4FA4") {
  sha2Data["SHA-224"]["h"]:ADD(hex_to_bin(h)).
}

PRINT "loading 512".
sha2Data:ADD("SHA-512",LEX(
  "h",LIST(),
  "k",LIST(),
  "w",LIST(1,8,7,19,61,6),
  "s",LIST(28,34,39,14,18,41),
  "cfg",LEX(
    "fullRounds",80,
    "reducedRounds",16,
    "wordSize",64,
    "blockSize",1024,
    "lengthSize",128
  )
)).

FOR h IN LIST(
"6A09E667F3BCC908","BB67AE8584CAA73B","3C6EF372FE94F82B","A54FF53A5F1D36F1", 
"510E527FADE682D1","9B05688C2B3E6C1F","1F83D9ABFB41BD6B","5BE0CD19137E2179") {
  sha2Data["SHA-512"]["h"]:ADD(hex_to_bin(h)).
}

FOR k IN LIST(
"428A2F98D728AE22","7137449123EF65CD","B5C0FBCFEC4D3B2F","E9B5DBA58189DBBC","3956C25BF348B538", 
"59F111F1B605D019","923F82A4AF194F9B","AB1C5ED5DA6D8118","D807AA98A3030242","12835B0145706FBE", 
"243185BE4EE4B28C","550C7DC3D5FFB4E2","72BE5D74F27B896F","80DEB1FE3B1696B1","9BDC06A725C71235", 
"C19BF174CF692694","E49B69C19EF14AD2","EFBE4786384F25E3","0FC19DC68B8CD5B5","240CA1CC77AC9C65", 
"2DE92C6F592B0275","4A7484AA6EA6E483","5CB0A9DCBD41FBD4","76F988DA831153B5","983E5152EE66DFAB", 
"A831C66D2DB43210","B00327C898FB213F","BF597FC7BEEF0EE4","C6E00BF33DA88FC2","D5A79147930AA725", 
"06CA6351E003826F","142929670A0E6E70","27B70A8546D22FFC","2E1B21385C26C926","4D2C6DFC5AC42AED", 
"53380D139D95B3DF","650A73548BAF63DE","766A0ABB3C77B2A8","81C2C92E47EDAEE6","92722C851482353B", 
"A2BFE8A14CF10364","A81A664BBC423001","C24B8B70D0F89791","C76C51A30654BE30","D192E819D6EF5218", 
"D69906245565A910","F40E35855771202A","106AA07032BBD1B8","19A4C116B8D2D0C8","1E376C085141AB53", 
"2748774CDF8EEB99","34B0BCB5E19B48A8","391C0CB3C5C95A63","4ED8AA4AE3418ACB","5B9CCA4F7763E373", 
"682E6FF3D6B2B8A3","748F82EE5DEFB2FC","78A5636F43172F60","84C87814A1F0AB72","8CC702081A6439EC", 
"90BEFFFA23631E28","A4506CEBDE82BDE9","BEF9A3F7B2C67915","C67178F2E372532B","CA273ECEEA26619C", 
"D186B8C721C0C207","EADA7DD6CDE0EB1E","F57D4F7FEE6ED178","06F067AA72176FBA","0A637DC5A2C898A6", 
"113F9804BEF90DAE","1B710B35131C471B","28DB77F523047D84","32CAAB7B40C72493","3C9EBE0A15C9BEBC", 
"431D67C49C100D4C","4CC5D4BECB3E42B6","597F299CFC657E2A","5FCB6FAB3AD6FAEC","6C44198C4A475817") {
  sha2Data["SHA-512"]["k"]:ADD(hex_to_bin(k)).
}

PRINT "loading 512/t".
sha2Data:ADD("SHA-512/t",LEX(
  "h",LIST(),
  "k",sha2Data["SHA-512"]["k"],
  "w",sha2Data["SHA-512"]["w"],
  "s",sha2Data["SHA-512"]["s"],
  "cfg",sha2Data["SHA-512"]["cfg"]
)).

{
  LOCAL const IS hex_to_bin("A5A5A5A5A5A5A5A5").
  FOR h IN sha2Data["SHA-512"]["h"] {
    sha2Data["SHA-512/t"]["h"]:ADD(bin_XOR(const,h)).
  }
}

PRINT "loading 384".
sha2Data:ADD("SHA-384",LEX(
  "h",LIST(),
  "k",sha2Data["SHA-512"]["k"],
  "w",sha2Data["SHA-512"]["w"],
  "s",sha2Data["SHA-512"]["s"],
  "cfg",sha2Data["SHA-512"]["cfg"]
)).

FOR h IN LIST(
"cbbb9d5dc1059ed8","629a292a367cd507","9159015a3070dd17","152fecd8f70e5939", 
"67332667ffc00b31","8eb44a8768581511","db0c2e0d64f98fa7","47b5481dbefa4fa4") {
  sha2Data["SHA-384"]["h"]:ADD(hex_to_bin(h)).
}

LOCAL FUNCTION SHA_2 {//an implementation of the SHA-256 algorithm
  PARAMETER bitStr,reduced,shaType IS "SHA-256".
  
  //importing constants and configuration
  LOCAL typeData IS sha2Data[shaType].
  LOCAL h0 IS typeData:h[0].
  LOCAL h1 IS typeData:h[1].
  LOCAL h2 IS typeData:h[2].
  LOCAL h3 IS typeData:h[3].
  LOCAL h4 IS typeData:h[4].
  LOCAL h5 IS typeData:h[5].
  LOCAL h6 IS typeData:h[6].
  LOCAL h7 IS typeData:h[7].
  LOCAL kList IS typeData:k.
  LOCAL w0r0 IS typeData:w[0].
  LOCAL w0r1 IS typeData:w[1].
  LOCAL w0r2 IS typeData:w[2].
  LOCAL w1r0 IS typeData:w[3].
  LOCAL w1r1 IS typeData:w[4].
  LOCAL w1r2 IS typeData:w[5].
  LOCAL s0r0 IS typeData:s[0].
  LOCAL s0r1 IS typeData:s[1].
  LOCAL s0r2 IS typeData:s[2].
  LOCAL s1r0 IS typeData:s[3].
  LOCAL s1r1 IS typeData:s[4].
  LOCAL s1r2 IS typeData:s[5].
  LOCAL wordSize IS typeData:cfg:wordSize.
  LOCAL blockSize IS typeData:cfg:blockSize.
  
  //padding input string
  SET bitStr TO bitStr + padd_str(bitStr:LENGTH,blockSize,typeData:cfg:lengthSize).

  LOCAL rounds IS CHOOSE typeData:cfg:reducedRounds IF reduced ELSE typeData:cfg:fullRounds.
  LOCAL iMax IS bitStr:LENGTH - 1.
  FROM { local i IS 0. } UNTIL i > iMax STEP { SET i TO i + blockSize. } DO {

    LOCAL wordList IS LIST().
    LOCAL jMax IS i + blockSize.
    FROM { LOCAL j IS i. } UNTIL j >= jMax STEP { SET j TO j + wordSize. } DO {
      wordList:ADD(bitStr:SUBSTRING(j,wordSize)).
    }

    IF NOT reduced {
      FROM { LOCAL j IS 16. } UNTIL j >= rounds STEP { SET j TO j + 1. } DO {
        LOCAL s0 IS wordList[j - 15].
        //LOCAL tmp1a IS bin_rotate_right(s0,w0r0).
        //LOCAL tmp1b IS bin_rotate_right(s0,w0r1).
        //LOCAL tmp1c IS bin_shift_right(s0,w0r2).
        //LOCAL tmp1 IS bin_XOR(tmp1a,tmp1b).
        //SET tmp1 TO bin_XOR(tmp1,tmp1c).
        LOCAL tmp1 IS bin_XOR(bin_XOR(bin_rotate_right(s0,w0r0),bin_rotate_right(s0,w0r1)),bin_shift_right(s0,w0r2)).

        LOCAL s1 IS wordList[j - 2].
        //LOCAL tmp2a IS bin_rotate_right(s1,w1r0).
        //LOCAL tmp2b IS bin_rotate_right(s1,w1r1).
        //LOCAL tmp2c IS bin_rotate_right(s1,w1r2).
        //LOCAL tmp2 IS bin_XOR(tmp2a,tmp2b).
        //SET tmp2 TO bin_XOR(tmp2,tmp2c).
        LOCAL tmp2 IS bin_XOR(bin_XOR(bin_rotate_right(s1,w1r0), bin_rotate_right(s1,w1r1)),bin_shift_right(s1,w1r2)).

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
    FROM { LOCAL w IS 0. } UNTIL w >= rounds STEP { SET w TO w + 1. } DO {
      //LOCAL s1 IS bin_rotate_right(eSeg,s1r0).
      //SET s1 TO bin_XOR(s1,bin_rotate_right(eSeg,s1r1)).
      //SET s1 TO bin_XOR(s1,bin_rotate_right(eSeg,s1r2)).
      //LOCAL ch IS bin_AND(eSeg,fSeg).
      //SET ch TO bin_XOR(ch,bin_AND(bin_NOT(eSeg),gSeg)).
      //LOCAL tmp1 IS bin_ADD(hSeg,s1).
      //SET tmp1 TO bin_ADD(tmp1,ch).
      //SET tmp1 TO bin_ADD(tmp1,kList[w]).
      //SET tmp1 TO bin_ADD(tmp1,wordList[w]).
      LOCAL tmp1 IS bin_ADD_multi(LIST(hSeg,bin_XOR(bin_XOR(bin_rotate_right(eSeg,s1r0),bin_rotate_right(eSeg,s1r1)),bin_rotate_right(eSeg,s1r2)),bin_XOR(bin_AND(eSeg,fSeg),bin_AND(bin_NOT(eSeg),gSeg)),kList[w],wordList[w])).

      //LOCAL s0 IS bin_rotate_right(aSeg,s0r0).
      //SET s0 TO bin_XOR(s0,bin_rotate_right(aSeg,s0r1)).
      //SET s0 TO bin_XOR(s0,bin_rotate_right(aSeg,s0r2)).
      //LOCAL maj IS bin_AND(aSeg,bSeg).
      //SET maj TO bin_XOR(maj,bin_AND(aSeg,cSeg)).
      //SET maj TO bin_XOR(maj,bin_AND(bSeg,cSeg)).
      //LOCAL tmp2 IS bin_ADD(s0,maj).
      LOCAL tmp2 IS bin_ADD(bin_XOR(bin_XOR(bin_rotate_right(aSeg,s0r0),bin_rotate_right(aSeg,s0r1)),bin_rotate_right(aSeg,s0r2)),bin_XOR(bin_XOR(bin_AND(aSeg,bSeg),bin_AND(aSeg,cSeg)),bin_AND(bSeg,cSeg))).

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
  
  IF shaType = "SHA-224" {
    RETURN (h0 + h1 + h2 + h3 + h4 + h5 + h6).
  } ELSE IF shaType = "SHA-384" {
    RETURN (h0 + h1 + h2 + h3 + h4 + h5).
  } ELSE IF shaType:CONTAINS("SHA-512/") {
    IF shaType = "SHA-512/t" {
      RETURN LIST(h0,h1,h2,h3,h4,h5,h6,h7).
	} ELSE {
	  RETURN (h0 + h1 + h2 + h3 + h4 + h5 + h6 + h7):SUBSTRING(0,shaType:SPLIT("/")[1]:TONUMBER()).
	}
  } ELSE { //IF shaType = "SHA-256" {
    RETURN (h0 + h1 + h2 + h3 + h4 + h5 + h6 + h7).
  }
}

LOCAL FUNCTION padd_str {
  PARAMETER bitStrLength,blockSize,lengthSize.
  LOCAL padLength IS (blockSize - lengthSize) - MOD(bitStrLength,blockSize).
  IF padLength < 0 {
	SET padLength TO padLength + blockSize.
  }
  RETURN "1":PADRIGHT(padLength):REPLACE(" ","0") + int_to_bin(bitStrLength,lengthSize).
}

LOCAL FUNCTION bin_rotate_left {
  PARAMETER binStr,rotate.
  SET rotate TO MOD(rotate,binStr:LENGTH).
  RETURN binStr:SUBSTRING(rotate,binStr:LENGTH - rotate) + binStr:SUBSTRING(0,rotate).
}

LOCAL FUNCTION bin_rotate_right {
  PARAMETER binStr,rotate.
  SET rotate TO MOD(rotate,binStr:LENGTH).
  RETURN binStr:SUBSTRING(binStr:LENGTH - rotate,rotate) + binStr:SUBSTRING(0,binStr:LENGTH - rotate).
}

LOCAL FUNCTION bin_shift_left {
  PARAMETER binStr,shift.
  IF binStr:LENGTH > shift {
    RETURN binStr:SUBSTRING(shift,binStr:LENGTH - shift):PADRIGHT(binStr:LENGTH):REPLACE(" ","0").
  } ELSE {
    RETURN "0":PADRIGHT(binStr:LENGTH):REPLACE(" ","0").
  }
}

LOCAL FUNCTION bin_shift_right {
  PARAMETER binStr,shift.
  IF binStr:LENGTH > shift {
    RETURN binStr:SUBSTRING(0,binStr:LENGTH - shift):PADLEFT(binStr:LENGTH):REPLACE(" ","0").
  } ELSE {
    RETURN "0":PADLEFT(binStr:LENGTH):REPLACE(" ","0").
  }
}

LOCAL FUNCTION bin_NOT {
  PARAMETER bin.
  LOCAL returnStr IS "".
  LOCAL bini IS bin:ITERATOR.
  UNTIL NOT bini:NEXT {
    SET returnStr TO returnStr + (CHOOSE "1" IF (bini:VALUE = "0") ELSE "0").
  }
  RETURN returnStr.
}

LOCAL FUNCTION bin_OR {
  PARAMETER bin1,bin2.
  LOCAL returnStr IS "".
  FOR i IN RANGE(bin1:LENGTH) {
    SET returnStr TO returnStr + (CHOOSE "1" IF ((bin1[i] = "1") OR (bin2[i] = "1")) ELSE "0").
  }
  RETURN returnStr.
}

LOCAL FUNCTION bin_OR_multi {
  PARAMETER binList.
  LOCAL returnStr IS "".
  FOR i IN RANGE(binList[0]:LENGTH) {
    LOCAL bitVal IS "0".
    LOCAL binListi IS binList:ITERATOR.
	UNTIL NOT binListi:NEXT {
      IF binListi:VALUE[i] = "1" {
        SET bitVal TO "1".
        BREAK.
      }
    }
    SET returnStr TO returnStr + bitVal.
  }
  RETURN returnStr.
}

LOCAL FUNCTION bin_AND {
  PARAMETER bin1,bin2.
  LOCAL returnStr IS "".
  FOR i IN RANGE(bin1:LENGTH) {
    SET returnStr TO returnStr + (CHOOSE "1" IF ((bin1[i] = "1") AND (bin2[i] = "1")) ELSE "0").
  }
  RETURN returnStr.
}

LOCAL FUNCTION bin_AND_multi {
  PARAMETER binList.
  LOCAL returnStr IS "".
  FOR i IN RANGE(binList[0]:LENGTH) {
    LOCAL bitVal IS "1".
    LOCAL binListi IS binList:ITERATOR.
	UNTIL NOT binListi:NEXT {
      IF binListi:VALUE[i] = "0" {
        SET bitVal TO "0".
        BREAK.
      }
    }
    SET returnStr TO returnStr + bitVal.
  }
  RETURN returnStr.
}

LOCAL FUNCTION bin_XOR {
  PARAMETER bin1,bin2.
  LOCAL returnStr IS "".
  FOR i IN RANGE(bin1:LENGTH) {
    SET returnStr TO returnStr + (CHOOSE "0" IF bin1[i] = bin2[i] ELSE "1").
  }
  RETURN returnStr.
}

LOCAL FUNCTION bin_XOR_multi {//Exclusive Or for 3 or more binary strings
  PARAMETER binList.
  LOCAL returnStr IS "".
  FOR i IN RANGE(binList[0]:LENGTH) {
    LOCAL binListi IS binList:ITERATOR.
	binListi:NEXT.
    LOCAL bitVal IS binListi:VALUE[i].
	UNTIL NOT binListi:NEXT {
	  SET bitVal TO CHOOSE "0" IF binListi:VALUE[i] = bitVal ELSE "1".
    }
    SET returnStr TO returnStr + bitVal.
  }
  RETURN returnStr.
}

LOCAL FUNCTION bin_XOR_multi_2 {//Exclusive Or for 3 or more binary strings
  PARAMETER binList.
  LOCAL returnStr IS binList[0].
  FOR i IN RANGE(2,binList:LENGTH) {
    SET returnStr TO bin_XOR(returnStr,binList[i]).
  }
  RETURN bin_XOR(returnStr,binList[1]).
}

LOCAL FUNCTION bin_ADD {//add 2 bin strings, will discard any overflow, bin strings must be same length
  PARAMETER bin1,bin2.
  LOCAL returnStr IS "".
  LOCAL carry IS 0.
  FOR i IN RANGE(bin1:LENGTH - 1,-1) {
    LOCAL sum IS bin1[i]:TONUMBER() + bin2[i]:TONUMBER() + carry.
    SET carry TO FLOOR(sum / 2).
    SET returnStr TO MOD(sum,2) + returnStr.
  }
  RETURN returnStr.
}

LOCAL FUNCTION bin_ADD_multi {//add 3 or more bin strings, will discard any overflow, bin strings must be same length, is better then bin_ADD once adding 4 or more terms together
  PARAMETER binList.
  LOCAL returnStr IS "".
  LOCAL carry IS 0.
  FOR i IN RANGE(binList[0]:LENGTH - 1,-1) {
    LOCAL sum IS carry.
    LOCAL binListi IS binList:ITERATOR.
	UNTIL NOT binListi:NEXT {
      SET sum TO sum + binListi:VALUE[i]:TONUMBER.
    }
    SET carry TO FLOOR((sum) / 2).
    SET returnStr TO MOD(sum,2) + returnStr.
  }
  RETURN returnStr.
}

LOCAL FUNCTION int_to_bin {//converts a number to a binary string of a given length, assumes said number is an intiger
  PARAMETER num,maxBits,doSign IS FALSE.
  LOCAL returnStr IS "".
  LOCAL sign IS num > 0.
  IF doSign {
    SET maxBits TO maxBits - 1.
  }
  LOCAL sign IS num < 0.
  SET num TO ABS(num).
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

LOCAL FUNCTION bin_to_int {//converts a binary string to an integer
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
    LOCAL binVal IS bin_to_int(bin:SUBSTRING(i,4)).
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
    SET returnStr TO int_to_bin(charVal,4) + returnStr.
  }
  RETURN returnStr.
}

WAIT 0.
LOCAL st IS TIME:SECONDS.
// PRINT hash_string("The quick red fox jumped over the lazy brown dog!").
// PRINT "895F37AE412219693E7030CFCCE2AE1CA1556184".
PRINT hash_file("0:/lib/lib_hash.ks","SHA-512").
//PRINT hash_string("","SHA-512/256").
//PRINT "C672B8D1EF56ED28AB87C3622C5114069BDD3AD7B8F9737498D0C01ECEF0967A".
PRINT ROUND(TIME:SECONDS - st,2).
SET CONFIG:IPU TO 200.