import os
import unicode

const debug = 1

type
  ChunkRef* = ref object of RootObj
    val*: string
    next*: ChunkRef

  ChunkPosObj* = object
    chunk*: ChunkRef
    pos*: int

  LineRef* = ref object of RootObj
    start*: ChunkPosObj
    stop*: ChunkPosObj
    prev*: LineRef
    next*: LineRef
    len*: int # needed to strip newlines
  
  TextContainerRef* = ref object of RootObj
    rootChunk*: ChunkRef
    lastChunk*: ChunkRef # needed for add

    rootLine*: LineRef
    lastLine*: LineRef # needed for add

    lineCursor*: LineRef # part of the cursor -> seekToLine
    currentLine*: int # part of the cursor -> seekToLine
    chunkCursor*: ChunkPosObj # part of the cursor

    numLines*:int

    chunkSize*: int

    isUTF8*: bool

#[ var
  TextContainer_chunkSize* = 256 ]#
##############################################
##############################################
##############################################

proc newTextContainer*(chunkSize = 256):TextContainerRef=
  result = new TextContainerRef
  result.chunkSize = chunkSize
  result.rootChunk = new ChunkRef
  result.lastChunk = result.rootChunk
  result.numLines = 0

proc newUTF8TextContainer*(chunkSize = 256):TextContainerRef=
  result = new TextContainerRef
  result.chunkSize = chunkSize
  result.rootChunk = new ChunkRef
  result.lastChunk = result.rootChunk
  result.numLines = 0
  result.isUTF8 = true


#[ 
 ######  ########  ########    ###    ######## ######## 
##    ## ##     ## ##         ## ##      ##    ##       
##       ##     ## ##        ##   ##     ##    ##       
##       ########  ######   ##     ##    ##    ######   
##       ##   ##   ##       #########    ##    ##       
##    ## ##    ##  ##       ##     ##    ##    ##       
 ######  ##     ## ######## ##     ##    ##    ######## 
 ]#


proc createLines*(
  this:TextContainerRef,
  fromLine:LineRef = nil,
  lineW:int=80):int=
  ## fromLine - the line that changed
#[ 
  create lines from fromLine.start.
  link to fromline.prev if not nil (is rootLine)
  stop at chunk.next = nil?:
  if newLine found - it is possible the rest is unchanged?
  how much lines to calc if it could be huge?
  store direct newLines? - lot of RAM and redundancy.
  recalc ALL? - can be time consuming.
  run max n milliseconds? compare line.next to spec pointer?
    t0 = epochTime()
    maxRuntime = ?.float
    ...
    if epochTime() - t0 >= maxRunTime: finalyze, break
  ---------------------------------------
  create lines:
    check if rune == newline?:
      begin newline
      advance cursor
    else:
      lineThis.len += 1
      
      if lineThis.len == screenW:
        begin newline
        advance cursor
      else:
        advance cursor
          if no more chunks: BREAK

  CHUNKS MUST BE UTF8 and NEWLINE BEWEARE
 ]#
  const debug = 0
  when debug > 0: echo "\n__________________________________\ncreateLines"
  var
    chunkCursor: ChunkRef
    chunkValCursor: int
    lineThis: LineRef = fromLine
    numLines: int

  if lineThis == nil:
    if this.rootLine == nil: # lets init lines
      this.rootLine = new LineRef
      this.rootLine.start.chunk = this.rootChunk
      this.rootLine.start.pos = 0
    lineThis = this.rootLine
    if lineThis == nil:
      when debug > 0: echo "createLines{ ","nil error"
      return

  lineThis.len = 0 # reset
  chunkCursor = lineThis.start.chunk
  chunkValCursor = lineThis.start.pos
  when debug > 0:
    echo "createLines{ ","chunkValCursor = lineThis.start.pos = ",chunkValCursor
    echo "createLines{ ","chunkCursor.val = ",chunkCursor.val

  # START ----------------------------
  while true:
    # check for \newli\ne
    if chunkCursor.val[chunkValCursor] == '\n' or
      chunkCursor.val[chunkValCursor] == '\r':

        #TODO shorten!
        if chunkCursor.val.high > chunkValCursor: # possible cr-lf or lf-cr
          if chunkCursor.val[chunkValCursor .. chunkValCursor+1] == "\n\r" or
            chunkCursor.val[chunkValCursor .. chunkValCursor+1] == "\r\n":
              chunkValCursor += 1
              when debug > 0: echo "createLines{ "," found newline"
          #else:
          #  chunkValCursor += 1
        
        # oldline
        lineThis.stop.chunk = chunkCursor
        lineThis.stop.pos = chunkValCursor

        # newline
        chunkValCursor += 1 # next lines 1st char
        lineThis.next = new LineRef
        lineThis.next.prev = lineThis
        lineThis = lineThis.next
        numLines.inc()

        # newline start pos
        #echo "chunkValCursor ",chunkValCursor

        if chunkCursor.val.high >= chunkValCursor: # same chunk
          lineThis.start.chunk = chunkCursor
          lineThis.start.pos = chunkValCursor
          # chunkCursor.val[chunkValCursor] = ($numLines)[0] #debug
        else:
          if chunkCursor.next == nil:
            lineThis.prev.next = nil
            #lineThis.stop.chunk = chunkCursor 
            #lineThis.stop.pos = chunkValCursor #! include newline chars, watch for it!
            when debug > 0: echo "createLines{ "," break, after newline"
            break #! >>>BREAK<<<
          when debug > 0:
            echo "createLines{ ", "stepp"
            if chunkCursor == chunkCursor.next: quit("circ stepp error", QuitFailure)
          chunkCursor = chunkCursor.next
          lineThis.start.chunk = chunkCursor
          lineThis.start.pos = 0
          chunkValCursor = 0
          #chunkCursor.val[chunkValCursor] = ($numLines)[0] #debug


    else: #! IT IS A CHARACTER :) ----------------
      #echo "c  chunkValCursor ",chunkValCursor

      lineThis.len += 1 #runeLenAt(chunkCursor.val, chunkValCursor)

      when debug > 1: echo "createLines{ ","lineThis.len / lineW ",numLines,": ",lineThis.len, "/", lineW
      if lineThis.len == lineW: 
        when debug > 1: 
          echo "createLines{ ","lineW; lineThis.len == screenW   chunkValCursor: ",chunkValCursor, "/",chunkCursor.val.high
          echo "createLines{ ","lineW; chunkCursor.val",chunkCursor.val
        lineThis.stop.chunk = chunkCursor
        lineThis.stop.pos = chunkValCursor + (runeLenAt(chunkCursor.val, chunkValCursor) - 1)

        chunkValCursor += runeLenAt(chunkCursor.val, chunkValCursor)
        numLines.inc()

        if chunkCursor.val.high > chunkValCursor: #*** same chunk
          when debug > 0: 
            echo "createLines{ ","lineW; chunkCursor.val.high >= chunkValCursor: ", chunkCursor.val.high, " >= ", chunkValCursor
          lineThis.next = new LineRef
          lineThis.next.prev = lineThis
          lineThis = lineThis.next
          lineThis.len = 0
          
          lineThis.start.chunk = chunkCursor
          lineThis.start.pos = chunkValCursor
          #chunkCursor.val[chunkValCursor] = ($numLines)[0] #!debug
        else: #*** next chunk or end
          when debug > 0: echo "createLines{ ","lineW; next chunk or end"
          if chunkCursor.next == nil:
            lineThis.stop.chunk = chunkCursor # todo watch for it!
            lineThis.stop.pos = chunkCursor.val.high
            when debug > 0: echo "createLines{ ","lineW; - break @ screenW - stop:",lineThis.stop.pos
            break #! >>>BREAK<<<
          lineThis.next = new LineRef
          lineThis.next.prev = lineThis
          lineThis = lineThis.next
          lineThis.len = 0

          chunkCursor = chunkCursor.next
          lineThis.start.chunk = chunkCursor
          lineThis.start.pos = 0
          chunkValCursor = 0
          if chunkCursor == chunkCursor.next:
            echo "\n lineW; CIRCULAR CHUNKS ERROR 1\n"
            quit(QuitFailure)
          #chunkCursor.val[chunkValCursor] = ($numLines)[0] #!debug

      else: #*** not lineW
        chunkValCursor += runeLenAt(chunkCursor.val, chunkValCursor)
        if chunkValCursor > chunkCursor.val.high: # nextchunk
          when debug > 0:
            echo "createLines{ ","not lineW; if chunkValCursor > chunkCursor.val.high: ",chunkValCursor," > ",chunkCursor.val.high
          if chunkCursor.next == nil:
            lineThis.stop.chunk = chunkCursor
            lineThis.stop.pos = chunkCursor.val.high
            when debug > 0: echo "createLines{ ","not lineW; break @ chunkCursor.next == nil stop:",lineThis.stop.pos
            break #! >>>BREAK<<<
          if chunkCursor == chunkCursor.next:
            echo "\n not lineW; CIRCULAR CHUNKS ERROR 2\n"
            #quit(QuitFailure)
            os.sleep(5000)
          chunkCursor = chunkCursor.next
          chunkValCursor = 0
    
    when debug > 0:
      if numLines > 200: quit("numlines too big", QuitFailure)
  


  this.lineCursor = this.rootLine
  this.currentLine = 1
  when debug > 0: echo "createLines{ ","numlines ", numLines
  
  if fromLine == nil:
    this.numLines = numLines
    this.lastLine = lineThis

  return numLines
  ####################################################runeLenAtCursor

#[ 
         ###    ########  ########  
        ## ##   ##     ## ##     ## 
       ##   ##  ##     ## ##     ## 
      ##     ## ##     ## ##     ## 
      ######### ##     ## ##     ## 
      ##     ## ##     ## ##     ## 
      ##     ## ########  ########  
 ]#
# TODO UTF8 AND newline chunk check!!!!!!!!!!!!!!!!!!!!!!!!!!!!
proc add*(this:TextContainerRef, val:string)=
  const debug = 0
  var
    #thisChunk = this.lastChunk
    cursor, nextCursor: int
    v:string # = newStringOfCap(6)
    numAdded:int
    nextChunk: ChunkRef

  # fillup lastchunk
  if this.lastChunk.val.len > 0:
    while this.lastChunk.val.len < this.chunkSize and
      nextCursor <= val.high:

        let runeLenAtCursor = runeLenAt(val, cursor)
        
        # newline check
        if runeLenAtCursor == 1:
          if val[nextCursor] == '\n' or
            val[nextCursor] == '\r':
              nextCursor += 1
              numAdded += 1
              if nextCursor < val.high and (val[nextCursor] == '\n' or
                val[nextCursor] == '\r'):
                  nextCursor += 1
                  numAdded += 1
          else: # just an ASCII char
            nextCursor += 1
            numAdded += runeLenAtCursor # 1
        else: # UTF8 multibyte
          nextCursor = (cursor + runeLenAtCursor)
          numAdded += runeLenAtCursor
        
        #v = val[cursor .. nextCursor - 1]
        #echo v, ", ", numAdded, "/", cursor
        this.lastChunk.val = this.lastChunk.val & val[cursor .. nextCursor - 1]

        cursor = nextCursor
        
    # end while...



  # add new chunks
  # middle chunks
  while this.chunkSize < (val.len - numAdded):
    when debug > 0: echo "add{ ","middle chunks: val.len:", val.len,", numAdded:", numAdded
    #? new chunk
    if this.lastChunk.val.len > 0:
      when debug > 0: echo "add{ ","middle chunks: new chunk"
      nextChunk = new ChunkRef
      this.lastChunk.next = nextChunk
      this.lastChunk = nextChunk
      #nextCursor = 0
      #cursor = 0
    # ........
    
    # get endPos in nextCursor
    nextCursor = cursor + (this.chunkSize - 1) #! ***
    # utf8 check
    if (uint8(val[nextCursor - 2]) and 240) == 240:
      nextCursor = nextCursor - 3
      numAdded += this.chunkSize - 3
    elif (uint8(val[nextCursor - 1]) and 224) == 224:
      nextCursor = nextCursor - 2
      numAdded += this.chunkSize - 2
    elif (uint8(val[nextCursor]) and 192) == 192:
      nextCursor = nextCursor - 1
      numAdded += this.chunkSize - 1
    else:
      numAdded += this.chunkSize
    # newline check
    if val.high < nextCursor:
      if val[nextCursor] == '\n' or val[nextCursor] == '\r':
        numAdded += 1
        nextCursor += 1
        if val.high < nextCursor and val.len < nextCursor + 1 and val[nextCursor] == '\n' or val[nextCursor] == '\r':
          numAdded += 1
          nextCursor += 1

    this.lastChunk.val = this.lastChunk.val & val[cursor .. nextCursor ] #! ch - 1
    when debug > 0:
      v = val[cursor .. nextCursor]
      stdout.write v

    cursor = nextCursor + 1 #! ***

  # end while...


  #nextCursor += 1
  while numAdded < val.len:
    # new chunk
    if this.lastChunk.val.len >= this.chunkSize:
      nextChunk = new ChunkRef
      this.lastChunk.next = nextChunk
      this.lastChunk = nextChunk
      #nextCursor = 0
      #cursor = 0
    # ........

    let runeLenAtCursor = runeLenAt(val, cursor)
    nextCursor = (cursor + runeLenAt(val, cursor) )

    this.lastChunk.val = this.lastChunk.val & val[cursor .. nextCursor - 1]
    when debug > 0: 
      v = val[cursor .. nextCursor - 1]
      stdout.write v

    cursor = nextCursor
    numAdded += runeLenAtCursor

  # end while...
  

#[ 
                             #######        #                       
  ####  ###### ###### #    #    #     ####  #       # #    # ###### 
 #      #      #      #   #     #    #    # #       # ##   # #      
  ####  #####  #####  ####      #    #    # #       # # #  # #####  
      # #      #      #  #      #    #    # #       # #  # # #      
 #    # #      #      #   #     #    #    # #       # #   ## #      
  ####  ###### ###### #    #    #     ####  ####### # #    # ###### 
                                                                    
 ]#

proc seekToLine*(this:TextContainerRef, lineNum:int)=
  const debug = 0

  when debug > 0 :
    echo "__________________________________"
    echo "seekToLine ",lineNum
  # wheter begin from 0 or from currentLine:
  var distance: int
  if lineNum > this.currentLine:
    distance = lineNum - this.currentLine
    if distance < lineNum:
      for i in 1..distance:
        this.lineCursor = this.lineCursor.next
      this.currentLine += distance
  else:
    distance = this.currentLine - lineNum
    if distance < lineNum:
      for i in 1..distance:
        this.lineCursor = this.lineCursor.prev
      this.currentLine -= distance
  
  this.chunkCursor = this.lineCursor.start

  when debug > 0:
    echo "seekToLine{ ","seek result:"
    echo "seekToLine{ chunk addr: ",$(cast[int](this.chunkCursor.chunk.addr))
    echo "seekToLine{ chunk  val: ",this.chunkCursor.chunk.val
    echo "__________________________________\n"
#_____________________________________seekToLine




proc seekToLine*(this:TextContainerRef, lineNum:int, pos:int)=
  ## moves chunkCursor to position
  ## used by insert()
  const debug = 0

  when debug > 0 :
    echo "__________________________________"
    echo "seekToLine & pos: ",lineNum, ", ", pos," - cl: ", this.currentLine

  if lineNum == 1 and pos == 0:
    this.lineCursor = this.rootLine
    this.chunkCursor = this.lineCursor.start
    return

  #* seek to line:
  # wheter begin from 0 or from currentLine:
  var distance: int
  if lineNum > this.currentLine:
    distance = lineNum - this.currentLine
    if distance < lineNum:
      when debug > 0 : echo "seekTo Line&Pos{ ","distance < lineNum"
      for i in 1..distance:
        this.lineCursor = this.lineCursor.next
        when debug > 1 : echo "seekTo Line&Pos{ ","lineCursor.next"
      this.currentLine += distance
  else:
    distance = this.currentLine - lineNum
    if distance < lineNum:
      for i in 1..distance:
        this.lineCursor = this.lineCursor.prev
      this.currentLine -= distance
  
  when debug > 0 :
    echo "seekToLine & pos: pos:",this.lineCursor.start.pos," - cl: ", this.currentLine


  #* seek to pos in line:
  this.chunkCursor = this.lineCursor.start #!
  when debug > 0 :
    echo "seekTo Line&Pos{ ","currentLine: ", this.currentLine
    echo "seekTo Line&Pos{ ","this.chunkCursor.chunk.val.len: ", this.chunkCursor.chunk.val.len

  if pos > 0: # then seek
    if this.isUTF8:
        # step one rune at time
        # look out for runes divided between chunks (end/start)
        when debug > 0 : echo "seekTo Line&Pos{ ","this.chunkCursor.chunk.val.high ", this.chunkCursor.chunk.val.high
        for pi in 0..pos-1:
          when debug > 1 : 
            echo "seekTo Line&Pos{ ","pi ",pi, " pos ", this.chunkCursor.pos
            echo "seekTo Line&Pos{ ",this.chunkCursor.pos," pos+= ",runeLenAt(
                  this.chunkCursor.chunk.val,
                  this.chunkCursor.pos)
          # advance pos - as cursor
          this.chunkCursor.pos += runeLenAt(
                  this.chunkCursor.chunk.val,
                  this.chunkCursor.pos)
          # check chunk end, get next chunk if needed
          if this.chunkCursor.pos >= this.chunkCursor.chunk.val.high:
            if this.chunkCursor.chunk.next == nil: break
            this.chunkCursor.chunk = this.chunkCursor.chunk.next
            #[ while this.chunkCursor.chunk == nil or this.chunkCursor.chunk.val.len == 0:
              this.chunkCursor.chunk = this.chunkCursor.chunk.next ]#
            this.chunkCursor.pos = 0
            #[ when debug > 0:
              echo "seekTo Line&Pos{ ", this.chunkCursor.chunk.val ]#
          #if this.chunkCursor.chunk == nil : break 
          when debug > 1:
            echo this.chunkCursor.pos," = ",
                  this.chunkCursor.chunk.val[this.chunkCursor.pos .. 
                    this.chunkCursor.pos + runeLenAt(this.chunkCursor.chunk.val,
                              this.chunkCursor.pos) - 1]

    else: # ANSI
        var neededPos = pos
        while true:
          if this.chunkCursor.pos + neededPos > this.chunkCursor.chunk.val.high:
            when debug > 0 : echo "seekTo Line&Pos{ ","seek nextchunk"

            neededPos -= (this.chunkCursor.chunk.val.high - this.chunkCursor.pos) + 1 #! high vs len
            this.chunkCursor.chunk = this.chunkCursor.chunk.next
            this.chunkCursor.pos = 0

          else:
            when debug > 0 : echo "seekTo Line&Pos{ ","seek: this chunk"

            this.chunkCursor.pos += neededPos #if neededPos <= this.chunkCursor.chunk.val.high: neededPos else: this.chunkCursor.chunk.val.high
            break
      
  when debug > 0:
    echo "seekTo Line&Pos{ ","seek result:"
    echo "seekTo Line&Pos{ chunk addr: ",$(cast[int](this.chunkCursor.chunk.addr))
    echo this.chunkCursor.pos," = ",
      this.chunkCursor.chunk.val[this.chunkCursor.pos .. 
        this.chunkCursor.pos + runeLenAt(this.chunkCursor.chunk.val,
                  this.chunkCursor.pos) - 1]
    echo "seekTo Line&Pos{ ","__________________________________\n"
#_____________________________________seekToLine


#[ 
                     #                       
  ####  ###### ##### #       # #    # ###### 
 #    # #        #   #       # ##   # #      
 #      #####    #   #       # # #  # #####  
 #  ### #        #   #       # #  # # #      
 #    # #        #   #       # #   ## #      
  ####  ######   #   ####### # #    # ###### 
                                             
 ]#
proc getLine*(this:TextContainerRef,
              lineNum:int,
              trimNewLine:bool=true):string=
  var
    chunkThis: ChunkRef
    chunkCursor: int
    lineThis: LineRef

  when debug > 0 :
    echo "__________________________________"
    echo "getLine{ ","lineNum: ", lineNum

  seekToLine(this, lineNum)


  lineThis = this.lineCursor

  chunkThis = lineThis.start.chunk
  chunkCursor = lineThis.start.pos

  if lineThis.start.chunk == lineThis.stop.chunk:
    when debug > 1 : stdout.write("getLine > ","same-chunk: ", chunkThis.val[
      lineThis.start.pos .. lineThis.stop.pos], '\n') # todo line endings!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

    result = chunkThis.val[
      lineThis.start.pos .. lineThis.stop.pos]
    lineThis = lineThis.next

  else:
    # first chunk to the end .......
    when debug > 1 : stdout.write("getLine > ","multi-chunk: ", chunkThis.val[
      lineThis.start.pos .. lineThis.start.chunk.val.high]) # todo line endings!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

    result = chunkThis.val[
      lineThis.start.pos .. lineThis.start.chunk.val.high]

    # middle chunks ................
    chunkThis = chunkThis.next
    
    while chunkThis != lineThis.stop.chunk:
      when debug > 1 : stdout.write("getLine > ","multi-chunk: ", chunkThis.val)

      result = result & chunkThis.val
      chunkThis = chunkThis.next

    # end chunk ....................
    when debug > 1 : stdout.write("getLine > ","  end-chunk: ", chunkThis.val[
        0 .. lineThis.stop.pos])

    result = result & chunkThis.val[
        0 .. lineThis.stop.pos]

  if trimNewLine and result.len > 0:
    if result[result.high] == '\n' or result[result.high] == '\r':
      result.setLen(result.high)
      if result[result.high] == '\n' or result[result.high] == '\r':
        result.setLen(result.high)
#____________________________________getLine



#[ 
proc chunkUTF8EndPos*(val:string):int=
  ## return the valid, UTF8 string end-position
  result = val.high
  if (uint8(val[val.high - 2]) and 240) == 240:
    result = val.high - 3
  if (uint8(val[val.high - 1]) and 240) == 224:
    result = val.high - 2
  if (uint8(val[val.high]) and 240) == 192:
    result = val.high - 1
     ]#

#[ proc lastUTF8Pos*(val:string):tuple[pos,len:int]=
  ## input must be a valid UTF8 string,
  ## (junk from end should be trimmed by now)
  ## good for popLastUTF8
  result = (val.high,1)
  if (uint8(val[val.high - 3]) and 240) == 240:
    result = (val.high - 3, 4)
  if (uint8(val[val.high - 2]) and 240) == 224:
    result = (val.high - 2, 3)
  if (uint8(val[val.high - 1]) and 192) == 192:
    result = (val.high - 1, 2) ]#


proc lastUTF8Pos*(val:string):tuple[str:string,pos:int]=
  ## input must be a valid UTF8 string,
  ## (junk from end should be trimmed by now)
  ## good for popLastUTF8
  result = ($val[val.high], val.high)
  if (uint8(val[val.high - 1]) and 192) == 192:
    result = (val[val.high-1 .. val.high], val.high - 1)

  elif (uint8(val[val.high - 2]) and 240) == 224:
    result = (val[val.high-2 .. val.high], val.high - 2)

  elif (uint8(val[val.high - 3]) and 240) == 240:
    result = (val[val.high-3 .. val.high], val.high - 3)



#[ 
#### ##    ##  ######  ######## ########  ######## 
 ##  ###   ## ##    ## ##       ##     ##    ##    
 ##  ####  ## ##       ##       ##     ##    ##    
 ##  ## ## ##  ######  ######   ########     ##    
 ##  ##  ####       ## ##       ##   ##      ##    
 ##  ##   ### ##    ## ##       ##    ##     ##    
#### ##    ##  ######  ######## ##     ##    ##    
 ]#
proc insert*(this:TextContainerRef, lineNum:int, pos:int, val:string)=
  ##! correct UTF8 compatible pos should be given
  #TODO REQUIRES screen-getline
  const debug = 2
  #[ 
    find the chunk pos
    *chunkFreeSpace = MaxChunkSize - chunk.val.len 
    is val runelen == 1?
      would chunk be gretaer than chunksize?
      get lastRunePos from chunk.val end
      lastRune = chunk.val[lastRunePos .. chunk.val.high]
      chunk.val = chunk.val[0 .. pos-1] & val & chunk.val[pos .. lastRunePos]
      nuchunk = new ChunkRef
      nuchunk.next = chunk.next
      chunk.next = nuchunk
      ?recalcLines(fromline:this.lineCursor)
      ?recalcChangedLines(from)
        search for next newline character in old
        when reached, check if still usable (start and stop would be the same)
        ?bool <- is search timeouted and dont bother

        ?or, dont search, but if reached, then search old...?

    else:
      is val greater than chunkFreeSpace?
        add as many as possible
        nuchunk = new ChunkRef
        nuchunk.next = chunk.next
        chunk.next = nuchunk
        chunk = chunk.next
        reset chunkFreeSpace

   ]#
  if val.len == 0: return # maybe not necessary
  # maybe not necessary
  #[ if this.currentLine != lineNum:
    seekToLine(this, lineNum, pos) ]#
  seekToLine(this, lineNum, pos)
  # this:TextContainerRef's cursor should be set by now
  var chunkFreeSpace = this.chunkSize - this.chunkCursor.chunk.val.len
  
  when debug > 0:
    echo "insert{ ","seek result:"
    echo "insert{ chunk addr: ",$(cast[int](this.chunkCursor.chunk.addr))
    echo "insert{ chunk val: ",this.chunkCursor.chunk.val
    echo "insert{ ","__________________________________"

  if val.runeLen == 1:
    if chunkFreeSpace > 0: #? benchmark other values?
      this.chunkCursor.chunk.val = this.chunkCursor.chunk.val[
        0 .. this.chunkCursor.pos] & val & this.chunkCursor.chunk.val[
        (this.chunkCursor.pos + runeLenAt(this.chunkCursor.chunk.val, this.chunkCursor.pos)) .. this.chunkCursor.chunk.val.high]
    else:
      # for safety, just add new chunks,
      # do not start an avalanche
      # check next chunk, add to if has space, else add chunk
      
      if this.chunkCursor.chunk.next.val.len < this.chunkSize:
        this.chunkCursor.chunk.next.val = val & this.chunkCursor.chunk.next.val
      else:
        var nuchunk = new ChunkRef
        nuchunk.next = this.chunkCursor.chunk.next
        this.chunkCursor.chunk.next = nuchunk
        nuchunk.val = val

  else: #* if more utf8ch to add ..................
    var endPos, startPos: int # copy from-to, inclusive
    var stringEnd: string # the right part of the string from the insertion point

    chunkFreeSpace = this.chunkSize - (this.chunkCursor.pos + 1)
    when debug > 0:
      echo "insert{ "," ... insert debug UTF8 string ... "
      echo "insert{ ","chunkFreeSpace: ",chunkFreeSpace," (",this.chunkSize,"-",(this.chunkCursor.pos + 1),")"
    
    #* if chunkFreeSpace > 0: ........
    if chunkFreeSpace > 0:
      when debug > 0: echo "insert{ ","chunkFreeSpace > 0:"
      when debug > 0:
        echo "insert{ ","runeLenAt: ", runeLenAt(this.chunkCursor.chunk.val, this.chunkCursor.pos)
        echo "insert{ runeAt: ",runeAt(this.chunkCursor.chunk.val, this.chunkCursor.pos)
      
      # store the rest of the old chunk
      #[ if not this.isUTF8:
        stringEnd = this.chunkCursor.chunk.val[
            this.chunkCursor.pos .. this.chunkCursor.chunk.val.high]
      else:
        stringEnd = this.chunkCursor.chunk.val[
            this.chunkCursor.pos .. this.chunkCursor.chunk.val.high ] ]#
      stringEnd = this.chunkCursor.chunk.val[
            this.chunkCursor.pos .. this.chunkCursor.chunk.val.high]


      # add as many chars as possible
      if val.high > (chunkFreeSpace - 1):
        endPos = chunkFreeSpace #val.high - (chunkFreeSpace - 1) 
        
        # find val utf8 char end
        if this.isUTF8:
            if (uint8(val[endPos]) and 240) == 240 or
              (uint8(val[endPos]) and 224) == 224 or
              (uint8(val[endPos]) and 192) == 192
              : endPos -= 1

            if ((endPos >= 1) and ((uint8(val[endPos - 1]) and 240) == 240)) or
              ((endPos >= 1) and ((uint8(val[endPos - 1]) and 224) == 224))
              : endPos -= 2
  
            if (endPos >= 2) and ((uint8(val[endPos - 2]) and 240) == 240)
              : endPos -= 3
      else: 
        endPos = val.high
      when debug > 0: echo "insert{ "," UTF8 check endPos, val.high ", endPos, ", ", val.high

      # ADD
      # i use startPos to mark the end of the remaining chars
      # the left side from the insert point
      var startPos = this.chunkCursor.pos - 1 
      if startPos <= 0: # bound check
        this.chunkCursor.chunk.val = val[0..endPos]
      else:
        this.chunkCursor.chunk.val = this.chunkCursor.chunk.val[
          0 .. startPos] & val[0..endPos]

      when debug > 0: echo "insert{ "," last chunk filled up; ... insert debug 2 ... "


    #* else if no space left on chunk
    else:
      endPos = -1 #! for loop logic below


    #* add the rest to new chunks
    when debug > 0:
      if this.chunkSize < val.high - endPos + 1:
        echo "insert{ ","add middle chunks - this.chunkSize ",this.chunkSize
    while this.chunkSize < val.high - endPos + 1:
      when debug > 0:
        echo "insert{ ","this.chunkSize < val.high - endPos + 1: ",this.chunkSize ," < ", val.high - endPos + 1
      var nuchunk = new ChunkRef
      nuchunk.next = this.chunkCursor.chunk.next
      this.chunkCursor.chunk.next = nuchunk
      
      startPos = endPos + 1
      endPos += this.chunkSize
      #[ while (endPos < val.high) and
        ((val[endPos].uint8 and 0b1000_000.uint8) != 0.uint8):
          endPos.inc() ]#
      if ((endPos >= 2) and ((uint8(val[endPos - 2]) and 240) == 240)) or
        ((endPos >= 1) and ((uint8(val[endPos - 1]) and 224) == 224)) or
        (uint8(val[endPos]) and 192) == 192
        : endPos += 1
      elif ((endPos >= 1) and ((uint8(val[endPos - 1]) and 240) == 240)) or
        (uint8(val[endPos]) and 224) == 224
        : endPos += 2
      elif (uint8(val[endPos]) and 240) == 240
      : endPos += 3

      nuchunk.val = val[startPos .. endPos]

      this.chunkCursor.chunk = nuchunk # stepp
      this.chunkCursor.pos = nuchunk.val.high
    when debug > 0: echo "insert{ "," END middle chunks ... insert debug 22 ... "
    
    
    if endPos < val.high:
      when debug > 0: echo "insert{ "," add remaining chunks"
      var nuchunk = new ChunkRef
      nuchunk.next = this.chunkCursor.chunk.next
      this.chunkCursor.chunk.next = nuchunk
      
      startPos = endPos + 1 # wich is 0 if nothing added or chunkFreeSpace == 0
      endPos = val.high
      nuchunk.val = val[startPos .. endPos]

      this.chunkCursor.chunk = nuchunk # stepp
      this.chunkCursor.pos = nuchunk.val.high
    when debug > 0: echo "insert{ "," END remaining chunks ... insert debug 3 ... "
    

    when debug > 0:
      echo "stringEnd", stringEnd
      echo "stringEnd.len", stringEnd.len
    if stringEnd.len > 0:
      # add origi chunks remaining chars
      startPos = 0
      # if chunk not full
      if this.chunkCursor.chunk.val.len < this.chunkSize:
        when debug > 0: echo "insert{ "," chunk has ", (this.chunkSize - this.chunkCursor.chunk.val.len), " free space."
        # remaining space in current chunk
        endPos = this.chunkSize - this.chunkCursor.chunk.val.len - 1
        when debug > 0: echo "endPos: ", endPos
        if endPos > stringEnd.high: endPos = stringEnd.high
        when debug > 0: echo "endPos: ", endPos
      else:
        when debug > 0: echo "insert{ "," chunk has no free space left"
        var nuchunk = new ChunkRef
        nuchunk.next = this.chunkCursor.chunk.next
        this.chunkCursor.chunk.next = nuchunk
        this.chunkCursor.chunk = nuchunk
        #?
        endPos = this.chunkSize - this.chunkCursor.chunk.val.len - 1
        when debug > 0: echo "endPos: ", endPos
        if endPos > stringEnd.high: endPos = stringEnd.high
        when debug > 0: echo "endPos: ", endPos

      while true:
        when debug > 0:
          echo "loop"
          if endPos < startPos:
            quit("\n ERROR: endPos < startPos" & $endPos & "," & $startPos, QuitFailure)
        # UTF8 check
        if endPos < stringEnd.high and this.isUTF8:
            #[ if (uint8(stringEnd[endPos]) and 240) == 240 or
              (uint8(stringEnd[endPos]) and 224) == 224 or
              (uint8(stringEnd[endPos]) and 192) == 192
              : endPos -= 1

            if (uint8(stringEnd[endPos - 1]) and 240) == 240 or
              (uint8(stringEnd[endPos - 1]) and 224) == 224
              : endPos -= 2

            if (uint8(stringEnd[endPos - 2]) and 240) == 240
              : endPos -= 3 ]#
            if ((endPos >= 2) and ((uint8(stringEnd[endPos - 2]) and 240) == 240)) or
              ((endPos >= 1) and ((uint8(stringEnd[endPos - 1]) and 224) == 224)) or
              (uint8(stringEnd[endPos]) and 192) == 192
              : endPos += 1
            elif ((endPos >= 1) and ((uint8(stringEnd[endPos - 1]) and 240) == 240)) or
              (uint8(stringEnd[endPos]) and 224) == 224
              : endPos += 2
            elif (uint8(stringEnd[endPos]) and 240) == 240
            : endPos += 3

            when debug > 0:
              if endPos > stringEnd.high: quit("stringEnd ERROR")
            if endPos > stringEnd.high: endPos = stringEnd.high

        when debug > 1: echo "insert{ ","startPos-endPos ",startPos,"-",endPos, " of ",stringEnd.high 
        this.chunkCursor.chunk.val = this.chunkCursor.chunk.val &
          stringEnd[startPos .. endPos]

        if endPos < stringEnd.high:
          var nuchunk = new ChunkRef
          nuchunk.next = this.chunkCursor.chunk.next
          this.chunkCursor.chunk.next = nuchunk
          this.chunkCursor.chunk = nuchunk

          startPos = endPos + 1
          endPos = startPos + this.chunkSize #? - this.chunkCursor.chunk.val.len #? - 1
          if endPos > stringEnd.high: endPos = stringEnd.high
          when debug > 1: echo "insert{ ","nuchunk startPos-endPos ",startPos,"-",endPos, " of ",stringEnd.high 
        else: break
      
    when debug > 0: echo "insert{ "," stringEnd added ... insert debug 4 ... "

  echo "__________________________________\n"







#[ 
########  ######## ##       ######## ######## ######## 
##     ## ##       ##       ##          ##    ##       
##     ## ##       ##       ##          ##    ##       
##     ## ######   ##       ######      ##    ######   
##     ## ##       ##       ##          ##    ##       
##     ## ##       ##       ##          ##    ##       
########  ######## ######## ########    ##    ######## 
 ]#

proc delete*(this:TextContainerRef, 
  fromLineNum:int, fromLinePos:int,
  toLineNum:int, toLinePos:int)=
  # work with chunks
  # seekto from pos
  # if delete 1: change chunk
  # else
  #   get startchunk
  #   get stopchunk
  #   same chunk? - erase from-to
  #   else
  #     erase startchunk to end
  #     erase middle chunks
  #     erase stop chunk til stoppos

  const debug = 2

  var startPos, endPos:int # chunk CHAR positions

  seekToLine(this, fromLineNum, fromLinePos)
  
  #* if delete empty line
  # remove line chunks and relink chunks
  # it can be \n\n, or \n\r somwhere in a chunk
  # or buffer already empty?
  endPos = 0
  if this.lineCursor.len == 0: # todo reread
    if this.chunkCursor.chunk.val.len != 0: # may never be 0 ...?
      #! startPos and endPos are newLine exclusive!!!
      # bound chk
      startPos = if this.chunkCursor.pos > 0: this.chunkCursor.pos - 1 else: 0

      if this.chunkCursor.chunk.val[this.chunkCursor.pos] == '\n' or
      this.chunkCursor.chunk.val[this.chunkCursor.pos] == '\r':
        endPos += 1

        if this.chunkCursor.chunk.val.len != 1:
          if this.chunkCursor.chunk.val[this.chunkCursor.pos+1] == '\n' or
          this.chunkCursor.chunk.val[this.chunkCursor.pos+1] == '\r':
            endPos += 1

      if endPos > this.chunkCursor.chunk.val.high: # bound chk
        endPos = this.chunkCursor.chunk.val.high


      if not (startPos == 0 and endPos == 0): # endPos may never be 0 ?...

        if startPos == 0: # left-trim, endPos > 0 !
          this.chunkCursor.chunk.val = 
            this.chunkCursor.chunk.val[endPos..this.chunkCursor.chunk.val.high]

        elif endPos == this.chunkCursor.chunk.val.high: # right-trim
          if startPos == 0: # one in a million...
            # this.chunkCursor.chunk.val = ""
            # chunk removal problem.

            this.lineCursor.prev.stop.chunk.next = this.chunkCursor.chunk.next
            `=destroy`(this.chunkCursor.chunk)

            #* MOVE BUFFER-CURSORS *#
            this.lineCursor = this.lineCursor.prev
            this.chunkCursor = this.lineCursor.stop

          else:
            this.chunkCursor.chunk.val = this.chunkCursor.chunk.val[0..startPos]

        else: # delete from middle
          this.chunkCursor.chunk.val =
            this.chunkCursor.chunk.val[0..startPos] & 
            this.chunkCursor.chunk.val[endPos..this.chunkCursor.chunk.val.high]

#[     if this.lineCursor.next != nil: # not last line
      this.lineCursor.next.prev = this.lineCursor.prev
    else: # it is the last line
      if this.lineCursor.prev != nil: # but not the first
        this.lineCursor.prev.next = nil
      else: # text is totally empty
        this.rootLine = nil
        this.lineCursor = nil ]#

  #* else - delete from not empty Line
  var
    chunkPosFrom: ChunkPosObj
    chunkPosTo: ChunkPosObj
    
  
  chunkPosFrom = this.chunkCursor

  #* if only 1 rune  - start+stop should be on same chunk
  if fromLineNum == toLineNum and fromLinePos == toLinePos:
      when debug > 0: echo "delete{ ","if only 1 rune  - start+stop should be on same chunk"
      let runeL = chunkPosFrom.chunk.val.runeLenAt(chunkPosFrom.pos)
      startPos = chunkPosFrom.pos - 1
      if startPos < 0: startPos = 0 # bound
      endPos = chunkPosFrom.pos + runeL

      if endPos >= chunkPosFrom.chunk.val.high: # right-trim only
        chunkPosFrom.chunk.val.setLen(chunkPosFrom.chunk.val.len - runeL)
      elif startPos == 0: # left-trim only
        chunkPosFrom.chunk.val = chunkPosFrom.chunk.val[runeL..chunkPosFrom.chunk.val.high]
      else:
        chunkPosFrom.chunk.val = chunkPosFrom.chunk.val[0..startPos] &
            chunkPosFrom.chunk.val[endPos..chunkPosFrom.chunk.val.high]
  
  else: #* multiple runes
    when debug > 0: echo "delete{ ", "multiple runes"
    seekToLine(this, fromLineNum, fromLinePos)
    chunkPosFrom = this.chunkCursor
    let fromLine = this.lineCursor #! save for chunk delete logic

    seekToLine(this, toLineNum, toLinePos)
    chunkPosTo = this.chunkCursor

    when debug > 0: 
      echo "delete{ ", cast[int](chunkPosFrom)
      echo "delete{ ", cast[int](chunkPosTo)
      echo cast[int](chunkPosFrom.chunk), "=",chunkPosFrom.chunk.val
      echo cast[int](chunkPosTo.chunk), "=",chunkPosTo.chunk.val

    #* if same chunk + multiple runes
    if chunkPosFrom.chunk == chunkPosTo.chunk:
      when debug > 0:
        echo "delete{ ","same chunk before: ",chunkPosFrom.chunk.val
      # init vars
      startPos = chunkPosFrom.pos - 1
      if startPos < 0: startPos = 0 # bound

      let runeL = chunkPosTo.chunk.val.runeLenAt(chunkPosTo.pos)
      endPos = chunkPosTo.pos + runeL
      if endPos > chunkPosTo.chunk.val.high: endPos = chunkPosTo.chunk.val.high
      

      if startPos == 0: # left-trim
        chunkPosFrom.chunk.val = chunkPosFrom.chunk.val[endPos..chunkPosFrom.chunk.val.high]
      elif endPos >= chunkPosFrom.chunk.val.high: # right-trim only
        #chunkPosFrom.chunk.val.setLen(chunkPosFrom.chunk.val.len - runeL)
        chunkPosFrom.chunk.val = chunkPosFrom.chunk.val[0..endPos-1] #!TEST
      else:  
        chunkPosFrom.chunk.val = chunkPosFrom.chunk.val[0..startPos] &
            chunkPosFrom.chunk.val[endPos..chunkPosFrom.chunk.val.high]
      when debug > 0:
        echo "delete{ ",startPos," - ",endPos," start-end"
        echo "delete{ ","same chunk after:  ",chunkPosFrom.chunk.val



    else: #*multiple runes + multiple chunks
      when debug > 0: echo "delete{ ", "multiple runes + multiple chunks"
      # if start == 0 - delete chunk, else start..val.high
      # delete middle chunks - well, step them over...
      # chunkPosTo endpos..val.high
      var prevChunk: ChunkRef = nil


      startPos = chunkPosFrom.pos - 1
      if startPos < 0: startPos = 0


      if startPos == 0 and fromLineNum > 1:
        when debug > 0: echo "delete{ ", "startPos == 0"
        if fromLine.prev != nil:
          prevChunk = fromLine.prev.start.chunk #! chunk delete logic
        else:
          prevChunk = fromLine.start.chunk
        #?prevChunk.next = chunkPosTo.chunk # todo endPos == high

        #[ if prevChunk == chunkPosTo.chunk:
          echo cast[int](prevChunk), prevChunk.val
          echo cast[int](chunkPosTo.chunk), chunkPosTo.chunk.val
          echo cast[int](chunkPosFrom.chunk), chunkPosFrom.chunk.val
          quit("circular loop forbidden error 2a", QuitFailure)
        if prevChunk == chunkPosTo.chunk.next:
          echo cast[int](prevChunk), prevChunk.val
          echo cast[int](chunkPosTo.chunk.next), chunkPosTo.chunk.next.val
          echo cast[int](chunkPosFrom.chunk), chunkPosFrom.chunk.val
          quit("circular loop forbidden error 3a", QuitFailure)  ]# 

        # get that nasty prev chunk - if i dont added chunk.prev =)
        while prevChunk.next != chunkPosFrom.chunk:
          prevChunk = prevChunk.next
          when debug > 0:
            echo "delete{ ", "seek"
            if prevChunk == nil: quit("seek error", QuitFailure)
      #else:
      # val = val[end..high]
      # ? can we skip to end chunk - or must delete them?
      else:
        when debug > 0: echo "delete{ ", "startPos != 0"
        #[ if prevChunk == chunkPosTo.chunk:
          echo cast[int](prevChunk), prevChunk.val
          echo cast[int](chunkPosTo.chunk), chunkPosTo.chunk.val
          quit("circular loop forbidden error 2bb", QuitFailure)
        if chunkPosFrom.chunk == chunkPosTo.chunk:
          echo cast[int](prevChunk), prevChunk.val
          echo cast[int](chunkPosTo.chunk.next), chunkPosTo.chunk.next.val
          echo cast[int](chunkPosFrom.chunk), chunkPosFrom.chunk.val
          quit("circular loop forbidden error 3bb", QuitFailure)  ]# 
        prevChunk = chunkPosFrom.chunk
        chunkPosFrom.chunk.val = chunkPosFrom.chunk.val[0..startPos]

      #[ if prevChunk == chunkPosTo.chunk:
        echo cast[int](prevChunk), prevChunk.val
        echo cast[int](chunkPosTo.chunk), chunkPosTo.chunk.val
        quit("circular loop forbidden error 2", QuitFailure)
      if prevChunk == chunkPosTo.chunk.next:
        echo cast[int](prevChunk), prevChunk.val
        echo cast[int](chunkPosTo.chunk.next), chunkPosTo.chunk.next.val
        echo cast[int](chunkPosFrom.chunk), chunkPosFrom.chunk.val
        quit("circular loop forbidden error 3", QuitFailure)  ]#       

      # if endpos == val.high?
      when debug > 0:
        echo "delete{ ", "chunkPosTo.chunk.val.runeLen: ",chunkPosTo.chunk.val.runeLen
        echo "delete{ ", "chunkPosTo.pos: ", chunkPosTo.pos


      let runeL = chunkPosTo.chunk.val.runeLenAt(chunkPosTo.pos)
      endPos = chunkPosTo.pos + runeL

      if endPos > chunkPosTo.chunk.val.high: #??? should not occur
        endPos = chunkPosTo.chunk.val.high

      if endPos == chunkPosTo.chunk.val.high: # cut it out
        when debug > 0: echo "delete{ ","endPos is val.high"
        prevChunk.next = chunkPosTo.chunk.next
        # now we could stop
      else:
        when debug > 0: echo "delete{ ","endPos is ", endPos
        chunkPosTo.chunk.val = chunkPosTo.chunk.val[endPos .. chunkPosTo.chunk.val.high]
        prevChunk.next = chunkPosTo.chunk

      if fromLineNum <= 1 and fromLinePos == 0:
        this.rootChunk = prevChunk.next
        prevChunk = nil

      #[ if prevChunk.next == prevChunk:
        quit("circular loop forbidden error", QuitFailure) ]#
  when debug > 0: echo "end delete\n"
#[ 
######## ########  ######  ######## 
   ##    ##       ##    ##    ##    
   ##    ##       ##          ##    
   ##    ######    ######     ##    
   ##    ##             ##    ##    
   ##    ##       ##    ##    ##    
   ##    ########  ######     ##    
 ]#

when isMainModule:
  import strutils

  echo """
  ___  ___  __  ___ 
   |  |__  /__`  |  
   |  |___ .__/  |  
                  """

  ##########################


  proc circhkChunks(this:TextContainerRef)=
    var
      thisChunk: ChunkRef = this.rootChunk
    echo "\n##### circhkChunks ######"
    while thisChunk != nil:
      echo $(cast[int](thisChunk))
      if thisChunk == thisChunk.next:
        quit("CIRCULAR CHECK FAILED")
      thisChunk = thisChunk.next
    echo "\nCIRCULAR CHECK PASSED\n------------------------"






  proc dumpChunks(this:TextContainerRef)=
    var
      thisChunk: ChunkRef = this.rootChunk
    echo "\n##### DUMPCHUNKS ######"
    while thisChunk != nil:
      echo thisChunk.val
      thisChunk = thisChunk.next
    echo "\n------------------------"


  proc dumpLines(this:TextContainerRef)=
    var
      lineThis = this.rootLine
      chunkThis: ChunkRef
      outLine: string
      lineNum: int = 0
      lineNumStr:string

    echo "\n######## DUMP-LINES ##########"
    while lineThis != nil:

      lineNum += 1
      lineNumStr = $lineNum
      while lineNumStr.len < 4:
        lineNumStr = " " & lineNumStr

      chunkThis = lineThis.start.chunk

      if lineThis.start.chunk == lineThis.stop.chunk:

        outLine = chunkThis.val[
          lineThis.start.pos .. lineThis.stop.pos]
        # strip newline characters
        if outLine[outLine.high] == '\n' or
        outLine[outLine.high] == '\r':
          outline.setLen(outLine.high)
          if outLine.len > 0 and
          (outLine[outLine.high] == '\n' or
          outLine[outLine.high] == '\r'):
            outline.setLen(outLine.high)
        echo lineNumStr,'\t', outLine

      else: # multi chunk spreading line
        
        # first chunk to the end
        outLine = chunkThis.val[
          lineThis.start.pos .. lineThis.start.chunk.val.high]
        # middle chunks's whole string
        chunkThis = chunkThis.next
        while chunkThis != lineThis.stop.chunk:
          outLine = outline & chunkThis.val
          chunkThis = chunkThis.next
        # finally last chunk to stop pos
        outLine = outLine & chunkThis.val[
                            0 .. lineThis.stop.pos]
        # strip newline characters
        if outLine[outLine.high] == '\n' or
        outLine[outLine.high] == '\r':
          outline.setLen(outLine.high)
          if  outLine.len > 0 and
          (outLine[outLine.high] == '\n' or
          outLine[outLine.high] == '\r'):
            outline.setLen(outLine.high)
        echo lineNumStr,'\t', outLine

      lineThis = lineThis.next

    echo "\n_____________________________\n"
  ##########################

  # CONTROL PANEL

  const
    test1 = false
    test2 = false
    test3 = false
    test4 = true
    test5 = false
    test6 = false
    test7 = false


  when test1:
    var tc = newUTF8TextContainer()

    tc.add("őúéáűtest ####\n")

    tc.add("őúéáűtestőúéáűtestőúéáűtestőúéáűtestőúéáűtestőúéáűtestőúéáűtestőúéáűtestőúéáűte|stőúéáűtestőúéáűtestőúéáűtestőúéáűtestőúéáűtestőúéáűtestőúéáűtestőúéáűtestőúéáű|testőúéáűtestőúéáűtestőúéáűtestőúéáűtestőúéáűtestőúéáűtestőúéáűtestőúéáűtestőúéáűtestőúéáűtestőúéáűtestőúéáűtestőúéáűtestőúéáűtestőúéáűtestőúéáűtestőúéáűtestőúéáűtestőúéáűtest ####\n")

    tc.add("\n Lorem ipsum dolor sit amet, consectetur adipiscing elit. Vivamus condimentum sagittis.Lacus, laoreet luctus ligula laoreet ut. Vestibulum ullamcorper accumsan velit vel vehicula. Proin tempor lacus arcu. Nunc at elit condimentum, semper nisi et condimentum mi. In venenatis blandit nibh at sollicitudin. Vestibulum dapibus mauris at orci maximus pellentesque. Nullam id elementum ipsum. Suspendisse cursus lobortis viverra. Proin et erat at mauris tincidunt porttitor vitae ac....dui. ####")

  #[   tc.add("""
  Donec vulputate lorem tortor, nec fermentum nibh bibendum vel. Lorem ipsum dolor sit amet, consectetur adipiscing elit. Praesent dictum luctus massa, non euismod lacus. Pellentesque condimentum dolor est, ut dapibus lectus luctus ac. Ut sagittis commodo arcu. Integer nisi nulla, facilisis sit amet nulla quis, eleifend suscipit purus. Class aptent taciti sociosqu ad litora torquent per conubia nostra, per inceptos himenaeos. Aliquam euismod ultrices lorem, sit amet imperdiet est tincidunt vel. Phasellus dictum justo sit amet ligula varius aliquet auctor et metus. Fusce vitae tortor et nisi pulvinar vestibulum eget in risus. Donec ante ex, placerat a lorem eget, ultricies bibendum purus. Nam sit amet neque non ante laoreet rutrum. Nullam aliquet commodo urna, sed ullamcorper odio feugiat id. Mauris nisi sapien, porttitor in condimentum nec, venenatis eu urna. Pellentesque feugiat diam est, at rhoncus orci porttitor non.

  ;""") ]#

    echo "\n\n---- DUMP 1 -----------------"
    tc.dumpChunks()


    echo "\n\n---- LINES 1 -----------------"
    tc.createLines()


    echo "\n\n---- DUMP LINES 1 -------------"
    tc.dumpLines()

    echo "\n\n---- Get LINE 1 -------------"
    echo tc.getLine(3)

    echo "\n\n---- INSERT 2 -------------"
    tc.insert(3,74, "_### GERONIMOOO :D ###_")
    echo "\n\n---- LINES 2 -----------------"
    tc.createLines()
    echo "\n\n---- DUMP LINES 2 -------------"
    tc.dumpLines()
    #----------------------------------------

  when test2:
    var tc2 = newUTF8TextContainer(8)

    tc2.add("őőúú-ááűű-óóíí-ööéé-úúőő-őőúú-ááűű-óóíí-ööéé-úúőő-őőúú-ááűű-óóíí-ööéé-úúőő-őőúú-ááűű-óóíí-ööéé-úúőő-őőúú-ááűű-óóíí-ööéé-úúőő=")
    tc2.createLines(lineW=10)
    tc2.dumpLines()

    tc2.insert(3,2,"#:*:*:*:*:#")
    tc2.createLines(lineW=10)
    tc2.dumpLines()

    tc2.add("xxxx-yyyy-cccc-WWWW=")
    tc2.createLines(tc2.lastLine, lineW=10)
    tc2.dumpLines()


  when test3:
    var tc3 = newUTF8TextContainer(32)

    tc3.add("őőúú-ááűű-óóíí-ööéé-úúőő-őőúú-ááűű-óóíí-ööéé-úúőő-őőúú-ááűű-óóíí-ööéé-úúőő-őőúú-ááűű-óóíí-ööéé-úúőő-őőúú-ááűű-óóíí-ööéé-úúőő=")
    tc3.createLines(lineW=20)
    tc3.dumpLines()
    echo "\n_____________________________________"
    tc3.insert(1,0,"1234-5678-****-****=")
    tc3.createLines(lineW=20)
    tc3.dumpLines()
    echo "\n_____________________________________"
    tc3.add("xxxx-yyyy-cccc-WWWW=")
    tc3.createLines(tc3.lastLine, lineW=20)
    tc3.dumpLines()
    echo "\n_____________________________________"

#[     tc3.delete(3,2,4,2)
    tc3.createLines(lineW=20)
    tc3.dumpLines() ]#

    tc3.delete(2,0,2,4)
    tc3.createLines(lineW=20)
    tc3.dumpLines()
    echo "\n_____________________________________"










  when test4:
    import random

    randomize()

    #let buffstr = "űéáűőúöüóí123456789o*-+&@_=%!#"
    let buffstr =  "űéáűőúöüóíűéáűőúöüóíűéáűőúöüóő"

    var
      tc3 = newUTF8TextContainer(32)
      lineW:int=20
      rndLine,rndPos:int
      rndLine2,rndPos2:int
      rnd1:int
      addstr:string
      line1: LineRef
      numLines:int

    tc3.add("őőúú-ááűű-óóíí-ööéé-úúőő-őőúú-ááűű-óóíí-ööéé-úúőő-őőúú-ááűű-óóíí-ööéé-úúőő-őőúú-ááűű-óóíí-ööéé-úúőő-őőúú-ááűű-óóíí-ööéé-úúőő=")
    echo "\nXXXXXX dumpChunks XXXXXX"
    tc3.dumpChunks()
    numLines = tc3.createLines(lineW=20)
    tc3.numLines = numLines
    echo "XXXXXX DUMPLINES XXXXXX"
    tc3.dumpLines()
    echo "\n_____________________________________"
    
    
    
    #[ echo "#####################"
    echo "DEBUG 1"
    echo "#####################"
    tc3.delete(6,0,7,19)
    numLines = tc3.createLines(lineW=20)
    tc3.dumpLines()
    echo "\n_____________________________________"
    #quit(QuitSuccess) ]#



    #[ echo "#####################"
    echo "DEBUG 2"
    echo "#####################"
    echo getLine(tc3,2)
    tc3.insert(2, 4, "|áéőééűűö|")
    numLines = tc3.createLines(lineW=20)
    tc3.dumpLines()
    #quit(QuitSuccess) ]#



    var
      rndMax_add:int=120
      roundsMax:int=100

    for irounds in 0..roundsMax:
      echo "#####################"
      echo "  round ", irounds
      echo "#####################"

      circhkChunks(tc3)


      rnd1 = rand(rndMax_add) + 1
      addStr = ""
      for i in 0..rnd1:
        #addStr.add($buffstr.runeAt(rand(buffstr.runeLen - 1)))
        addStr.add(
          runeSubStr(
            buffstr,
            rand(buffstr.runeLen - 1),
            1
            )
          )

      if rand(1) == 1: addStr.add("\n")

      # TODO lineLen()
      rndLine = rand(tc3.numLines)
      tc3.seekToLine(rndLine)
      line1 = tc3.lineCursor
      rndPos = if tc3.lineCursor.len > 0: rand(tc3.lineCursor.len - 1) else: 0

      echo "insert: numLines:",tc3.numLines,"; line:", rndLine,", pos:", rndPos,", ", addStr
      tc3.insert(rndLine, rndPos, addStr)
      numLines = tc3.createLines(fromLine=line1,lineW=20)
      tc3.numLines = rndLine + numLines - 1
      tc3.dumpLines()
      tc3.dumpChunks()
      echo "\n_____________________________________"


      # rnd delete-----------
      rndLine = rand(tc3.numLines - 1) + 1
      tc3.seekToLine(rndLine)
      line1 = tc3.lineCursor
      rndPos = if tc3.lineCursor.len > 0: rand(tc3.lineCursor.len - 1) else: 0

      rndLine2 = rand(tc3.numLines - rndLine) + rndLine
      tc3.seekToLine(rndLine2)
      if rndLine != rndLine2:
        rndPos2 = if tc3.lineCursor.len > 0: rand(tc3.lineCursor.len - 1) else: 0
      else:
        rndPos2 = rand(tc3.lineCursor.len - rndPos - 1) + rndPos
        if rndPos2 < rndPos:
          rndPos2 = rndPos

      echo "delet ",rndLine,"/",rndPos, "; ", rndLine2,"/",rndPos2

      tc3.delete(rndLine,rndPos,rndLine2,rndPos2)
      #numLines = tc3.createLines(fromLine=line1,lineW=20)
      #tc3.numLines = rndLine + numLines - 1
      numLines = tc3.createLines(lineW=20)
      tc3.dumpLines()
      tc3.dumpChunks()
      echo "\n_____________________________________"
  








  when test5:
    var tc5 = newUTF8TextContainer()

    tc5.add("qwertzuiop\n")
    tc5.add("1234567890\n")
    tc5.add("yxcvbnm,.-\n")

    var numLines = tc5.createLines()

    var testline = 2
    tc5.delete(testline,0,testline,1)
    numLines = tc5.createLines()

    var restr = tc5.getLine(testline)

    echo restr, " == ", "34567890"
    assert(restr == "34567890")
    #..........
    testline = 1
    tc5.delete(testline,0,testline,1)
    numLines = tc5.createLines()
    restr = tc5.getLine(testline)
    echo restr, " == ", "ertzuiop"
    #..........

    tc5.insert(1,0,"aa")
    numLines = tc5.createLines()
    restr = tc5.getLine(testline)
    echo restr, " == ", "aaertzuiop"
    #..........
    tc5.insert(1,10,"aa")
    numLines = tc5.createLines()
    restr = tc5.getLine(testline)
    echo restr, " == ", "aaertzuiopaa"
    #..........
    testline = 1
    tc5.delete(testline,10,testline,10)
    numLines = tc5.createLines()
    restr = tc5.getLine(testline)
    echo restr, " == ", "aaertzuiopa"









  when test6:
    import random
    var
      tc6 = newUTF8TextContainer(32)
      lineW:int=20
      rndLine,rndPos:int
      rndLine2,rndPos2:int
      rnd1:int
      addstr:string
      line1: LineRef
      numLines:int

    let
      buffstr =  "űéáűőúöüóíűéáűőúöüóíűéáűőúöüóő"
      rndMax_add = 32*20

    for i in 1..5:
      rnd1 = rand(rndMax_add) + 1
      addStr = ""
      for i in 0..rnd1:
        addStr.add(
          runeSubStr(
            buffstr,
            rand(buffstr.runeLen - 1),
            1
            )
          )

      tc6.add(addStr)
      echo "\nXXXXXX dumpChunks XXXXXX"
      tc6.dumpChunks()
      numLines = tc6.createLines(lineW=20)
      tc6.numLines = numLines
      echo "XXXXXX DUMPLINES XXXXXX"
      tc6.dumpLines()
      echo "\n_____________________________________"
      
      tc6.delete(2,2,8,6)
      echo "\nXXXXXX dumpChunks XXXXXX"
      tc6.dumpChunks()
      numLines = tc6.createLines(lineW=20)
      tc6.numLines = numLines
      echo "XXXXXX DUMPLINES XXXXXX"
      tc6.dumpLines()
      echo "\n_____________________________________"










  when test7:
    import random
    var
      tc7 = newUTF8TextContainer(32)
      lineW:int=20
      rndLine,rndPos:int
      rndLine2,rndPos2:int
      rnd1:int
      addstr:string
      line1: LineRef
      numLines:int

    let
      buffstr =  "űéáűőúöüóíűéáűőúöüóíűéáűőúöüóő"
      rndMax_add = 32*20


    rnd1 = rand(rndMax_add) + 1
    addStr = ""
    for i in 0..rnd1:
      addStr.add(
        runeSubStr(
          buffstr,
          rand(buffstr.runeLen - 1),
          1
          )
        )

    tc7.add(addStr)
    echo "\nXXXXXX dumpChunks XXXXXX"
    tc7.dumpChunks()
    numLines = tc7.createLines(lineW=20)
    tc7.numLines = numLines
    echo "XXXXXX DUMPLINES XXXXXX"
    tc7.dumpLines()
    echo "\n_____________________________________"
    
    tc7.delete(2,2,8,6)
    echo "\nXXXXXX dumpChunks XXXXXX"
    tc7.dumpChunks()
    numLines = tc7.createLines(lineW=20)
    tc7.numLines = numLines
    echo "XXXXXX DUMPLINES XXXXXX"
    tc7.dumpLines()
    echo "\n_____________________________________"



    for i in 1..5:
      rnd1 = rand(rndMax_add) + 1
      addStr = ""
      for i in 0..rnd1:
        addStr.add(
          runeSubStr(
            buffstr,
            rand(buffstr.runeLen - 1),
            1
            )
          )

      tc7.insert(2,2,addStr)
      #[ echo "\nXXXXXX dumpChunks XXXXXX"
      tc7.dumpChunks() ]#
      numLines = tc7.createLines(lineW=20)
      tc7.numLines = numLines
      echo "XXXXXX DUMPLINES XXXXXX"
      tc7.dumpLines()
      echo "\n_____________________________________"
      
      tc7.delete(1,2,9,6)
      #[ echo "\nXXXXXX dumpChunks XXXXXX"
      tc7.dumpChunks() ]#
      numLines = tc7.createLines(lineW=20)
      tc7.numLines = numLines
      echo "XXXXXX DUMPLINES XXXXXX"
      tc7.dumpLines()
      echo "\n_____________________________________"

      