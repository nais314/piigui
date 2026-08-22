import os
import unicode


type
  UTF8Seq* = seq[string]

  TextChunkRef* = ref object of RootObj
    val*: UTF8Seq
    prev*: TextChunkRef
    next*: TextChunkRef

  TextChunkPosObj* = object
    chunk*: TextChunkRef
    pos*: int

  TextLineRef* = ref object of RootObj
    start*: TextChunkPosObj
    stop*: TextChunkPosObj
    prev*: TextLineRef
    next*: TextLineRef
    len*: int # needed to strip newlines
  
  TextContainerRef* = ref object of RootObj
    chunkSize*: int

    rootChunk*: TextChunkRef
    lastChunk*: TextChunkRef # needed for add

    rootLine*: TextLineRef
    lastLine*: TextLineRef # needed for add

    newLineStr*: string

    #[ the cursor ]#
    numLines*:int
    currentLine*: int # part of the cursor -> seekToLine
    lineCursor*: TextLineRef # part of the cursor -> seekToLine
    chunkCursor*: TextChunkPosObj # part of the cursor



proc newTextChunkRef*():TextChunkRef=
  result = new TextChunkRef
  result.val = @[]
  result.prev = nil
  result.next = nil

proc newTextContainer*(chunkSize = 256):TextContainerRef=
  result = new TextContainerRef
  result.chunkSize = chunkSize
  result.rootChunk = newTextChunkRef()
  result.lastChunk = result.rootChunk
  result.rootLine = new TextLineRef
  result.rootLine.start.chunk = result.rootChunk
  result.lastLine = result.rootLine
  result.numLines = 0

template val*(this:TextChunkPosObj):UTF8Seq=
  this.chunk.val
template next*(this:TextChunkPosObj):TextChunkRef=
  this.chunk.next


iterator utf8it*(val:string, this:TextContainerRef):string {.closure.}=
  ## its like unicode utf8 iterator,
  ## but it checks newLine characters, and unifies them
  ## to this.newLineStr, wich is "" if not set
  var
    cursor:int
    utf8ch:string

  while cursor < val.high:
    utf8ch = ""
    #..........
    if (val[cursor].uint8 and 240.uint8) == 240.uint8:
      utf8ch = val[cursor] &
            val[cursor + 1] &
            val[cursor + 2] &
            val[cursor + 3]
      cursor += 4
      #yield utf8ch

    elif (val[cursor].uint8 and 224.uint8) == 224.uint8:
      utf8ch = val[cursor] &
            val[cursor + 1] &
            val[cursor + 2]
      cursor += 3
      #yield utf8ch

    elif (val[cursor].uint8 and 192.uint8) == 192.uint8:
      utf8ch = val[cursor] &
            val[cursor + 1]
      cursor += 2
      #yield utf8ch
    
    else:
      utf8ch = $(val[cursor])
      cursor += 1
      #newLine?
      if utf8ch == "\n" or utf8ch == "\c":
        if cursor <= val.high:
          if val[cursor] in ['\n', '\c']:
            utf8ch.add val[cursor]
            cursor += 1
        if this.newLineStr.len == 0:
          this.newLineStr = utf8ch
        else:
          utf8ch = this.newLineStr # patch in case multiple type texts are mixed

    if utf8ch == "": quit("\nutf8 char empty error",QuitFailure)
    yield utf8ch
    #..........




proc defragmentChunks*(chunk1, chunk2:TextChunkRef)=
  discard






iterator utf8*(buff:seq[uint8]):string=
  var
    cursor:int
    res:string

  while true:
    res = newStringOfCap(4)

    if (buff[cursor] and 240.uint8) == 240.uint8:

      res = buff[cursor].chr &
            buff[cursor + 1].chr &
            buff[cursor + 2].chr &
            buff[cursor + 3].chr
      cursor += 4

    elif (buff[cursor] and 224.uint8) == 224.uint8:

      res = buff[cursor].chr &
            buff[cursor + 1].chr &
            buff[cursor + 2].chr

      cursor += 3

    elif (buff[cursor] and 192.uint8) == 192.uint8:


      res = buff[cursor].chr &
            buff[cursor + 1].chr

      cursor += 2
    
    else:
      res = $(buff[cursor].chr)
      cursor += 1

    yield res

    if cursor > buff.high: break #!





#[ 
 ######  ##     ## ########   ######   #######  ########                
##    ## ##     ## ##     ## ##    ## ##     ## ##     ##   ##     ##   
##       ##     ## ##     ## ##       ##     ## ##     ##   ##     ##   
##       ##     ## ########   ######  ##     ## ########  ###### ###### 
##       ##     ## ##   ##         ## ##     ## ##   ##     ##     ##   
##    ## ##     ## ##    ##  ##    ## ##     ## ##    ##    ##     ##   
 ######   #######  ##     ##  ######   #######  ##     ##               
 ]#
proc inc(cursor: var TextChunkPosObj)=
  cursor.pos += 1
  if cursor.pos > cursor.chunk.val.high:
    cursor.chunk = cursor.chunk.next
    cursor.pos = 0
    if cursor.chunk != nil and cursor.chunk.val.len == 0:  cursor.inc()
    #[ if cursor.chunk == nil:
      echo " xxxxxxxxxxx CHUNK END xxxxxxxxxx"
    else:
      echo "CHUNK VAL: ", cursor.chunk.val ]#






#[ 
         ###    ########  ########  
        ## ##   ##     ## ##     ## 
       ##   ##  ##     ## ##     ## 
      ##     ## ##     ## ##     ## 
      ######### ##     ## ##     ## 
      ##     ## ##     ## ##     ## 
      ##     ## ########  ########  
 ]#
proc add*(this:TextContainerRef, val:string)=
  const debug = 0

  if val.len == 0: return # no work needed

  var
    cursor: int
    #nextCursor: int
    #numAdded:int
    chunkCursor: TextChunkRef
    utf8ch:string
    nuchunk: TextChunkRef



  # init cursor
  chunkCursor = this.lastChunk
  #[ if chunkCursor == nil:
    this.lastChunk = newTextChunkRef()
    chunkCursor = this.lastChunk ]#
  
  utf8ch = newStringOfCap(4)
  
  while cursor < val.high:
    utf8ch = ""
    #..........
    if (val[cursor].uint8 and 240.uint8) == 240.uint8:
      utf8ch = val[cursor] &
            val[cursor + 1] &
            val[cursor + 2] &
            val[cursor + 3]
      cursor += 4

    elif (val[cursor].uint8 and 224.uint8) == 224.uint8:
      utf8ch = val[cursor] &
            val[cursor + 1] &
            val[cursor + 2]
      cursor += 3

    elif (val[cursor].uint8 and 192.uint8) == 192.uint8:
      utf8ch = val[cursor] &
            val[cursor + 1]
      cursor += 2
    
    else:
      utf8ch = $(val[cursor])
      cursor += 1

      #newLine?
      if utf8ch == "\n" or utf8ch == "\c":
        if cursor <= val.high:
          if val[cursor] in ['\n', '\c']:
            utf8ch.add val[cursor]
            cursor += 1
        if this.newLineStr.len == 0:
          this.newLineStr = utf8ch
        else:
          utf8ch = this.newLineStr # patch in case multiple type texts are mixed

    #..........

    if chunkCursor.val.len >= this.chunkSize:
      nuchunk = newTextChunkRef()
      nuchunk.prev = chunkCursor
      chunkCursor.next = nuchunk
      chunkCursor = nuchunk

    chunkCursor.val.add(utf8ch)

    #..........

  this.lastChunk = chunkCursor



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
  fromRoot:bool=true,
  fromLine:TextLineRef = nil,
  maxLineWidth:int=80)=
  #[ 
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
  ]#
  const debug = 3
  when debug > 0: echo "___[createLines]_____________________________________"
  var
    lineCursor: TextLineRef # = fromLine
    chunkCursor: TextChunkPosObj
    chunkCursorPrev: TextChunkPosObj
    lineCount:int = 0
  
  #[ init variables ]#
  if this.rootChunk == nil:
    when debug > 0: echo "createLines > ","nothing to create"
    return


  if fromRoot:
    lineCursor = this.rootLine
    this.currentLine = 0 # will be set on return
  else:
    lineCursor = this.lineCursor


 #[  if lineCursor == nil:
    lineCursor = this.rootLine
    this.currentLine = 0 # will be set on return ]#
    
  if lineCursor == nil:
    when debug > 0: echo "createLines > ","lineCursor == nil"
    this.rootLine = new TextLineRef
    this.rootLine.start.chunk = this.rootChunk
    lineCursor = this.rootLine
    this.currentLine = 0
  else:
    discard
    when debug > 0: echo "createLines > ",lineCursor.start.val
    when debug > 0: echo "createLines > ",lineCursor.start.val[lineCursor.start.pos]
    when debug > 0: echo "createLines currentline = ", this.currentLine
    #lineCount = this.currentLine - 1
  


  lineCursor.len = 0

  #this.rootLine.start.chunk = this.rootChunk

  #this.lineCursor = this.rootLine #! patch
  #chunkCursor.pos = 0
  chunkCursor = lineCursor.start
  #when debug > 0: echo "createLines > ",chunkCursor.val
  #when debug > 0: echo "createLines > ",chunkCursor.val[lineCursor.start.pos]
  when debug > 0: 
    if chunkCursor.val.high < chunkCursor.pos:
      echo chunkCursor.chunk.val
      quit("createLines > chunk pos error")



  while chunkCursor.chunk != nil:
    #* if newline ##paragraph## , begin new line
    if chunkCursor.chunk.val[chunkCursor.pos] == "":
      when debug > 0: 
        echo "createLines > ", "chunkCursor.chunk.val[chunkCursor.pos] == '' ERROR EMPTY"
        echo "createLines > ", chunkCursor.chunk.val[chunkCursor.pos], ", ",chunkCursor.pos, " [",chunkCursor.chunk.val,"]"

      chunkCursor.inc()
      continue
    
    if this.newLineStr != "" and
    chunkCursor.chunk.val[chunkCursor.pos] == this.newLineStr:
    #if chunkCursor.chunk.val[chunkCursor.pos] == this.newLineStr:
      when debug > 1: echo "createLines > ","NEWLIIIIIIIIIIIIINE!!!!!",chunkCursor.chunk.val[chunkCursor.pos],this.newLineStr
      lineCursor.stop = chunkCursor
      lineCount += 1

      chunkCursorPrev = chunkCursor
      chunkCursorPrev.inc()
      # if it was the last chunk
      if chunkCursorPrev.chunk != nil:
        when debug > 0: echo "createLines >>> ",lineCount
        lineCursor.next = new TextLineRef
        lineCursor.next.prev = lineCursor
        lineCursor = lineCursor.next

        chunkCursor = chunkCursorPrev
        lineCursor.start = chunkCursor
      else:
        chunkCursor = chunkCursorPrev




    else: #* if character -------------------------
      lineCursor.len += 1
      #chunkCursor.pos.inc()
      # TODO non-printables
      when debug > 1: echo "createLines > ","lineCursor.len ",lineCursor.len
      if lineCursor.len >= maxLineWidth:
        when debug > 0: echo "createLines > ","lineCursor.len ",lineCursor.len
        lineCount += 1 #! ???
        lineCursor.stop = chunkCursor

        chunkCursorPrev = chunkCursor
        chunkCursorPrev.inc()
        # if it was the last chunk
        if chunkCursorPrev.chunk != nil:
          #lineCount += 1 #! ???
          when debug > 0: echo "createLines > lineCount last chunk: ",lineCount
          lineCursor.next = new TextLineRef
          lineCursor.next.prev = lineCursor
          lineCursor = lineCursor.next

          chunkCursor = chunkCursorPrev
          lineCursor.start = chunkCursor
        else:
          lineCursor.stop = chunkCursor
          chunkCursor = chunkCursorPrev
      else:
        chunkCursorPrev = chunkCursor #! (1)
        chunkCursor.inc()
  


  #lineCursor.stop = chunkCursorPrev
  if lineCursor.stop.chunk == nil:
    when debug > 0: echo "createLines > lineCursor.stop.chunk == nil -----"
    lineCursor.stop = chunkCursorPrev #! (1)
    if lineCursor.start.chunk.val.len > 0 : lineCount += 1
    when debug > 0: echo lineCursor.start.chunk.val
  this.lastLine = lineCursor

  when debug > 0: echo "createLines > lineCount END: ",lineCount
  if lineCount > 0:
    if this.currentLine > 0:
      this.numLines = this.currentLine + lineCount - 1 # 2 + 3 = 5; 2 +3 - 1 = 4 [2,3,4]
    else:
      this.numLines = this.currentLine + lineCount # 0 + 3 = 3
  
  if lineCursor.next != nil: 
    lineCursor.next = nil
    when debug > 1 :
      # quit("lineCursor.next != nil",QuitFailure)
      echo "lineCursor.next != nil"
  when debug > 0: echo "_________________________________[END createLines]___"




#[ 
                             #######        #                       
  ####  ###### ###### #    #    #     ####  #       # #    # ###### 
 #      #      #      #   #     #    #    # #       # ##   # #      
  ####  #####  #####  ####      #    #    # #       # # #  # #####  
      # #      #      #  #      #    #    # #       # #  # # #      
 #    # #      #      #   #     #    #    # #       # #   ## #      
  ####  ###### ###### #    #    #     ####  ####### # #    # ###### 
                                                                    
 ]#
proc seekToLine*(this:TextContainerRef, lineNum:int=0, pos:int=0)=
  ## moves chunkCursor to position
  ## used by insert()
  const debug = 2

  when debug > 0 :
    echo "START seekToLine & pos__________________________________"
    echo "seekToLine & pos: ",lineNum, ", ", pos," - cl: ", this.currentLine

  if lineNum == 0 and pos == 0:
    this.lineCursor = this.rootLine
    this.chunkCursor = this.lineCursor.start
    this.currentLine = 0
    return

  this.lineCursor = this.rootLine
  this.chunkCursor = this.lineCursor.start
  this.currentLine = 0


  #* seek to line:
  # wheter begin from 0 or from currentLine:
  var distance: int
  if lineNum > this.currentLine:
    when debug > 0 : echo "seekTo { ","lineNum > this.currentLine | ", lineNum," > " ,this.currentLine
    distance = lineNum - this.currentLine
    when debug > 0 : echo "seekTo { ","distance > lineNum | ", distance," > " ,lineNum
    for i in 1..distance:
      when debug > 0 : echo "seekTo { ","lineCursor.next"
      this.lineCursor = this.lineCursor.next
    this.currentLine += distance
  elif lineNum < this.currentLine:
    distance = this.currentLine - lineNum
    for i in 1..distance:
      this.lineCursor = this.lineCursor.prev
    this.currentLine -= distance
  
  when debug > 0 : echo "seekTo { ","seekto pos"


  #* seek to pos in line:
  this.chunkCursor = this.lineCursor.start #!
  when debug > 0 : echo "seekTo { ","seekto pos"

  when debug > 0 :
    if this.chunkCursor.chunk == nil: quit(QuitFailure)
    echo "seekToLine & pos: pos:",
          this.lineCursor.start.pos," - cl: ", this.currentLine, "\n"
    echo "seekTo { ","currentLine: ", this.currentLine
    echo "seekTo { ","this.chunkCursor.chunk.val.len: ",
          this.chunkCursor.chunk.val.len

  if pos > 0: # then seek
    var posi = pos
    when debug > 0 :
        echo "seekTo { ","this.lineCursor.start.val.high >= this.lineCursor.start.pos + posi"
        echo "seekTo { ",this.lineCursor.start.val.high," >= ",this.lineCursor.start.pos + posi
        echo "seekTo { ",this.lineCursor.len
    
    if this.lineCursor.start.val.high >= this.lineCursor.start.pos + posi:
      this.chunkCursor.pos += posi

    else:
      while posi > this.chunkCursor.chunk.val.high and
      this.chunkCursor.chunk.next != nil:
        posi -= this.chunkCursor.chunk.val.len
        this.chunkCursor.chunk = this.chunkCursor.chunk.next
        when debug > 0 :
          echo "seekTo { posi:len > ", posi, ", ", this.chunkCursor.chunk.val.len
      this.chunkCursor.pos = posi
      when debug > 0 :
        echo "seekTo { posi:len >>>> ", posi, ", ", this.chunkCursor.chunk.val.len
        echo "seekTo { next nil >>>> ", this.chunkCursor.chunk.next == nil

  when debug > 0 :
    if this.chunkCursor.chunk == nil: quit(QuitFailure)
    echo "seekTo { char: ", this.chunkCursor.val[this.chunkCursor.pos]
    echo "seekTo { ", "this.chunkCursor.pos: ", this.chunkCursor.pos


  when debug > 0 :
    echo "END seekToLine & pos__________________________________"




proc findLine*(neededChunk:TextChunkRef):TextLineRef=
  ## to speed up visible-line recreation
  ## this is a tool to find 
  discard

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
  if val.len == 0: return # maybe not necessary
  const debug = 4

  var
    piece = utf8it
    thePiece: string
    chunkFreeSpace: int
    stringEnd: UTF8Seq # right side of insertion point. (inclusive)
    

  ####
  
  seekToLine(this, lineNum, pos)

  chunkFreeSpace = this.chunkSize - (this.chunkCursor.pos)
  when debug > 0:
    echo "insert > ", "chunkFreeSpace ",chunkFreeSpace," / ", this.chunkSize
    echo "insert > ", "this.chunkCursor.val.len ",this.chunkCursor.val.len
  
  
  #* if chunkFreeSpace > 0: ........
  if chunkFreeSpace > 0:
    stringEnd = this.chunkCursor.chunk.val[
            this.chunkCursor.pos .. this.chunkCursor.chunk.val.high]

    # delete
    this.chunkCursor.chunk.val.setLen(if this.chunkCursor.pos > 0: this.chunkCursor.pos - 1 else: 0)

    for i in this.chunkCursor.pos .. this.chunkSize - 1:
      #this.chunkCursor.chunk.val[i] = piece(val, this)
      thePiece = piece(val, this)
      if thePiece == "": continue
      when debug > 3:
        if thePiece == "": quit("empty at start val ",QuitFailure)
      if thePiece != "": this.chunkCursor.chunk.val.add(thePiece)
      this.chunkCursor.pos += 1
      when debug > 1:
        echo "insert > ", "this.chunkCursor.pos ",this.chunkCursor.pos
        echo "insert > ", "this.chunkCursor.len ",this.chunkCursor.val.len
        echo "insert > ", "i ",i
      if finished(piece): break
    
    
  while not finished(piece):
    when debug > 1:
      echo "insert > ", "middle "
    if this.chunkCursor.val.len >= this.chunkSize:
      when debug > 0: echo "insert > ", "nuchunk"
      # insert new chunk
      var nuchunk = newTextChunkRef()
      nuchunk.next = this.chunkCursor.chunk.next
      nuchunk.prev = this.chunkCursor.chunk
      this.chunkCursor.chunk.next = nuchunk
      if nuchunk.next != nil: nuchunk.next.prev = nuchunk

      this.chunkCursor.chunk = nuchunk
      this.chunkCursor.pos = -1 #? needed?
    
    thePiece = piece(val, this)
    if thePiece == "": continue
    echo thePiece
    when debug > 3:
      if thePiece == "": quit("empty at middle val ",QuitFailure)
    #if thePiece != "": this.chunkCursor.chunk.val.add(thePiece)
    this.chunkCursor.chunk.val.add(thePiece)
    this.chunkCursor.pos += 1
  when debug > 0: echo "insert > ", "FINISHED middle "


  if stringEnd.len > 0:
    for i in 0..stringEnd.high:
      if this.chunkCursor.val.len == this.chunkSize:
        # insert new chunk
        var nuchunk = newTextChunkRef()
        nuchunk.next = this.chunkCursor.chunk.next
        nuchunk.prev = this.chunkCursor.chunk
        this.chunkCursor.chunk.next = nuchunk
        if nuchunk.next != nil: nuchunk.next.prev = nuchunk

        this.chunkCursor.chunk = nuchunk
        this.chunkCursor.pos = -1 #? needed?
      
      when debug > 3:
        if stringEnd[i] == "": quit("empty at stringend",QuitFailure)
      this.chunkCursor.chunk.val.add(stringEnd[i])
      this.chunkCursor.pos += 1

  when debug > 0: echo "insert > ", "FINISHED"







#[ 
########  ######## ##       ######## ######## ######## 
##     ## ##       ##       ##          ##    ##       
##     ## ##       ##       ##          ##    ##       
##     ## ######   ##       ######      ##    ######   
##     ## ##       ##       ##          ##    ##       
##     ## ##       ##       ##          ##    ##       
########  ######## ######## ########    ##    ######## 
 ]#




proc deleteChunksFromTo*(fromChunk,toChunk:TextChunkRef)=
  ## fromChunk,toChunk are deleted too
  #? setup vars for manual delete ??????? wtf?!
  const debug = 1
  if fromChunk == nil or toChunk == nil:
    when debug > 0: echo "delete chunks NIL argument"
    return
  var delStart, delCursor, nextDelCursor, delEnd: TextChunkRef
  delStart = fromChunk
  delEnd = toChunk
  delCursor = delStart
  #delEnd.next = nil
  #delStart.prev = nil
  echo "deletechunks: ",cast[uint](fromChunk)
  echo "deletechunks: ",cast[uint](toChunk)
  # relink - cut out chunks
  if fromChunk.prev != nil:
    fromChunk.prev.next = toChunk.next # mabe ni, but its fine
    if toChunk.next != nil:
      toChunk.next.prev = fromChunk.prev
    # i know, storing prev is a lot of memory, but it makes this sooo easy - believe me, i know!
  else:
    if toChunk.next != nil: # just for sure
      toChunk.next.prev = nil
    #todo this.lastchunk?
  #? manual delete
  #[ while delCursor != nil:
    nextDelCursor = delCursor.next
    `=destroy`(delCursor) #??? does it matter?!
    delCursor = nextDelCursor
  `=destroy` delStart
  `=destroy` delCursor
  `=destroy` nextDelCursor
  `=destroy` delEnd ]#
  # ouch...
#.....................................................      


proc delete*(this:TextContainerRef, 
  fromLineNum:int, fromLinePos:int,
  toLineNum:int, toLinePos:int)=
  const debug = 2

  # todo set this.lineCursor

  var
    startChunkPos: TextChunkPosObj
    endChunkPos: TextChunkPosObj
  
  # getting the from for last - positions the cursor where it should be on the end
  this.seekToLine(toLineNum, toLinePos)
  endChunkPos = this.chunkCursor
  this.seekToLine(fromLineNum, fromLinePos)
  startChunkPos = this.chunkCursor
  when debug > 0:
    echo "delete { char: ", this.chunkCursor.val[this.chunkCursor.pos]
  if startChunkPos.chunk == nil or endChunkPos.chunk == nil:
    quit("NIL ERROR",QuitFailure)
  when debug > 0 :
    echo "delete: ", cast[uint](startChunkPos.chunk)," / ",startChunkPos.pos
    echo "delete: ", cast[uint](endChunkPos.chunk)," / ",endChunkPos.pos

  #todo park this.chunkCursor somwhere...

  if startChunkPos.chunk == endChunkPos.chunk:
    # 4 options: ltrim, rtrim, delete from-to, from start to end
    if startChunkPos.pos == 0: # ltrim candidate
      if endChunkPos.pos == endChunkPos.chunk.val.high: # delet t whole line
        when debug > 0 :
          echo "delete: ","whole line"
        if startChunkPos.chunk.prev != nil:
          startChunkPos.chunk.prev.next = endChunkPos.chunk.next
          `=destroy`(startChunkPos.chunk) #??? does it matter?!
        else:
          if endChunkPos.chunk.next != nil:
            echo "delete: ","whole line new root"
            endChunkPos.chunk.next.prev = nil
            this.rootChunk = endChunkPos.chunk.next
          else:
            echo "delete: ","root = nil"
            this.rootChunk = endChunkPos.chunk.next
            this.rootChunk.val = @[]
      else: # yeah, its ltrim...
        startChunkPos.chunk.val = startChunkPos.chunk.val[
          endChunkPos.pos+1 .. endChunkPos.chunk.val.high]
    elif endChunkPos.pos == endChunkPos.chunk.val.high: # rtrim?
      startChunkPos.chunk.val = startChunkPos.chunk.val[
        0..startChunkPos.pos - 1]
      this.chunkCursor.pos -= 1 #? yeah, just for sure...
    else: # i think all other cases are covered... =)
      # store the right side, because it will be gone
      let temp = endChunkPos.chunk.val[
        endChunkPos.pos + 1 .. endChunkPos.chunk.val.high]
      startChunkPos.chunk.val = startChunkPos.chunk.val[
        0 .. startChunkPos.pos - 1]
      startChunkPos.chunk.val.add(temp)
      this.chunkCursor.pos -= 1 #? yeah, just for sure...
  
  else: # muultiple chunks
    # todo combine remaining chunks
    # poosible cases:
    # start to middle; start to end; middle to middle; middle to end;
    # anda, i should merge the start and end chunks, to have at least 1 full chunk...  
    if startChunkPos.pos == 0:
      when debug > 0: echo "delete chunk: ","startChunkPos.pos ",startChunkPos.pos
      if endChunkPos.pos == endChunkPos.chunk.val.high: # lots of chunks to cut
        deleteChunksFromTo(startChunkPos.chunk, endChunkPos.chunk)
        discard
      else: # startChunk must be deleted...
        deleteChunksFromTo(startChunkPos.chunk, endChunkPos.chunk.prev)
        endChunkPos.chunk.val = endChunkPos.chunk.val[
          endChunkPos.pos + 1 .. endChunkPos.chunk.val.high
        ]
    elif endChunkPos.pos == endChunkPos.chunk.val.high:
      deleteChunksFromTo(startChunkPos.chunk.next, endChunkPos.chunk)
      startChunkPos.chunk.val = startChunkPos.chunk.val[
        0 .. startChunkPos.pos - 1
      ]
    else: # some parts of start and endchunk remain...
      startChunkPos.chunk.val = startChunkPos.chunk.val[
          0 .. startChunkPos.pos - 1
        ]
      endChunkPos.chunk.val = endChunkPos.chunk.val[
          endChunkPos.pos + 1 .. endChunkPos.chunk.val.high
        ]

      if startChunkPos.chunk.next != endChunkPos.chunk:
        # what if there are chunks in between?
        deleteChunksFromTo(startChunkPos.chunk.next,endChunkPos.chunk.prev)
        # i love this prev property, hoever it takes up a lot of memory
    
  # todo
  this.currentLine = 0
  this.lineCursor = this.rootLine
  this.chunkCursor.chunk = this.rootChunk
  this.chunkCursor.pos = 0
  when debug > 0:
    echo "delete > ","END DELETE___________________________"











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
  import random

  echo """
  ___  ___  __  ___ 
   |  |__  /__`  |  
   |  |___ .__/  |  
                  """
  
  proc dumpChunks(this:TextContainerRef)=
    var
      chunkCursor = this.rootChunk
      hasEmpty = false
    echo "__DUMP CHUNKS_____________________"
    while chunkCursor != nil:
      for ch in chunkCursor.val:
        stdout.write ch
        if ch == "":
          hasEmpty = true
          stdout.write "#\n"
      stdout.write '\n'
      chunkCursor = chunkCursor.next
    if hasEmpty: quit("dumpChunks hasempty", QuitFailure)
    echo "_______________________DUMP CHUNKS_"


  proc dumpLines(this:TextContainerRef)=
    var
      lineCursor: TextLineRef
      chunkCursor: TextChunkRef
      res: string
      lineNum: int = 0
      lineNumStr:string
    
    lineCursor = this.rootLine

    while lineCursor != nil:
      #echo "dumplines > ", cast[uint](lineCursor)
      #.............................
      lineNumStr = $lineNum
      while lineNumStr.len < 4:
        lineNumStr = " " & lineNumStr
      lineNumStr &= " "
      lineNumStr &= $lineCursor.len
      lineNumStr &= " " & $lineCursor.start.chunk.val.len

      #.............................
      if lineCursor.start.chunk == lineCursor.stop.chunk:
        # trim newline
        if lineCursor.start.val[lineCursor.stop.pos] == this.newLineStr:
          res = newStringOfCap(lineCursor.len * 4) #[ newStringOfCap(
            lineCursor.stop.pos - lineCursor.start.pos - 1) ]#
          for i in lineCursor.start.pos .. lineCursor.stop.pos - 1:
            res.add(lineCursor.start.val[i])
        else:
          res = newStringOfCap(
            lineCursor.stop.pos - lineCursor.start.pos)
          for i in lineCursor.start.pos .. lineCursor.stop.pos:
            res.add(lineCursor.start.val[i])
      else:
        res = newStringOfCap(lineCursor.len * 4)
        for i in lineCursor.start.pos .. lineCursor.start.val.high:
          res.add(lineCursor.start.val[i])
        chunkCursor = lineCursor.start.next
        #!
        if chunkCursor == nil: quit("line next is nil")
        #!
        while chunkCursor != lineCursor.stop.chunk:
          for i in 0 .. chunkCursor.val.high:
            res.add(chunkCursor.val[i])
          chunkCursor = chunkCursor.next
        #echo lineCursor.stop.pos
        if lineCursor.stop.val[lineCursor.stop.pos] == this.newLineStr and
        lineCursor.stop.pos > 0:
          for i in 0..lineCursor.stop.pos - 1:
            res.add(chunkCursor.val[i])
        else:
          for i in 0..lineCursor.stop.pos:
            res.add(chunkCursor.val[i])
      
      echo lineNumStr," ",res
      lineCursor = lineCursor.next
      lineNum += 1

        



  const
    utfstring = "*öüóőúűáéí"
    runesTest = false
    addTest = false
    randTest = true
  
  randomize()

  when runesTest:
    echo "___runesTest_____________________________________"
    var
      runeSeq: UTF8Seq
      u8Seq: seq[uint8]
      str: string

    #[ for ru in runes(utfstring):
      runeSeq.add(ru) ]#

    for ch in utfstring:
      u8Seq.add(ch.uint8)

    for run in utf8(u8Seq):
      stdout.write(run)
    
    stdout.write '\n'

    str = newString(u8Seq.len * 4)
    var ri:int
    for run in utf8(u8Seq):
      str[ri .. ri + run.high] = run
      ri += run.len
    str.setLen(ri)
    echo str
    stdout.write '\n'

    echo "_____________________________________END runesTest___"




  when addTest:
    echo "__[addTest]_________________________________________"
    var
      text1 = newTextContainer(40)
    randomize()
    for i in 1..160:
      text1.add(runeSubStr(
            utfstring,
            rand(utfstring.runeLen - 1),
            1
            ))

    echo "----- DUMPCHUNKS ------"
    text1.dumpChunks()

    #..................................

    echo "----- DUMPLINES ------"
    text1.createLines(maxLineWidth=40)
    text1.dumpLines()
    #..................................
    echo "----- SEEK ------"
    text1.seekToLine()
    text1.seekToLine(2,0)

    #..................................
    echo "----- INSERT ------"
    text1.insert(2,0,"11111111111111111111111111111122222222222223333")
    echo "----- DUMPCHUNKS ------"
    text1.dumpChunks()
    echo "----- DUMPLINES ------"
    text1.createLines(maxLineWidth=40)
    text1.dumpLines()
    #..................................

    echo "----- DELETE ------"
    text1.delete(2,0,2,3)
    echo "----- DUMPCHUNKS ------"
    text1.dumpChunks()
    echo "----- DUMPLINES ------"
    text1.createLines(maxLineWidth=40)
    text1.dumpLines()
    #..................................    
    echo "_____________________________________[END addTest]__"








  when randTest:
    import random

    randomize()

    let buffstr = "űéáűőúöüóí123456789o*-+&@_=%!#"
    #let buffstr =  "űéáűőúöüóíűéáűőúöüóíűéáűőúöüóő"

    var
      tc3 = newTextContainer(32)
      lineW:int=20
      rndLine,rndPos:int
      rndLine2,rndPos2:int
      rnd1:int
      addstr:string
      line1: TextLineRef
      numLines:int

    var
      rndMax_add:int=64
      roundsMax:int=1000


    tc3.newLineStr = "\n"

    tc3.add("*11111111111*")
    tc3.createLines(maxLineWidth=20)
    tc3.dumpLines()
    #[ tc3.delete(0,0,0,0)
    tc3.dumpChunks()
    tc3.createLines(maxLineWidth=20)
    tc3.dumpLines() ]#


    for irounds in 0..roundsMax:
      echo "#####################"
      echo "  round ", irounds
      echo "#####################"

      var ru:string
      for r in 0..19:
        rnd1 = rand(rndMax_add) + 10
        addStr = ""
        for i in 0..rnd1:
          #addStr.add($buffstr.runeAt(rand(buffstr.runeLen - 1)))
          ru = runeSubStr(
              buffstr,
              rand(buffstr.runeLen - 1),
              1
              )
          if ru != "" :
            addStr.add(
            ru
            )
          else:
            quit("empty at generator",QuitFailure)
        addStr.add('|')
        addStr = "|" & addStr
        if rand(1) == 1: addStr.add("\n")
        #tc3.add(addStr)

      #tc3.dumpChunks()
      #tc3.createLines(maxLineWidth=20)
      echo "tc3.numLines: ",tc3.numLines
      
      
      rndLine = rand(tc3.numLines - 1)
      tc3.seekToLine(rndLine)
      line1 = tc3.lineCursor
      rndPos = if tc3.lineCursor.len > 0: rand(tc3.lineCursor.len - 1) else: 0

      echo "insert: numLines:",tc3.numLines,"; line:", rndLine,", pos:", rndPos,", ", addStr
      tc3.insert(rndLine, rndPos, addStr)
      tc3.dumpChunks()
      #tc3.createLines(fromLine=line1,maxLineWidth=20)
      tc3.createLines(maxLineWidth=20)
      echo "tc3.numLines: ",tc3.numLines
      tc3.dumpLines()
      echo "\n_____________________________________"


      # rnd delete-----------
      echo "\n###################"
      rndLine = rand(tc3.numLines - 1)
      tc3.seekToLine(rndLine)
      line1 = tc3.lineCursor
      if line1 != tc3.rootLine: line1 = line1.prev
      echo line1.start.chunk.val
      echo line1.start.pos
      if line1 != tc3.rootLine: line1 = line1.prev
      echo line1.start.chunk.val
      echo line1.start.pos

      rndPos = if tc3.lineCursor.len > 0: rand(tc3.lineCursor.len - 1) else: 0

      rndLine2 = rand(tc3.numLines - 1 - rndLine) + rndLine
      tc3.seekToLine(rndLine2)
      if rndLine != rndLine2:
        rndPos2 = if tc3.lineCursor.len > 0: rand(tc3.lineCursor.len - 1) else: 0
      else:
        rndPos2 = rand(tc3.lineCursor.len - rndPos - 1) + rndPos
        if rndPos2 < rndPos:
          rndPos2 = rndPos

      
      echo "DELETE: ",rndLine,"/",rndPos, "; ", rndLine2,"/",rndPos2
      echo "###################"

      tc3.delete(rndLine,rndPos,rndLine2,rndPos2)
      echo "line1: ", line1.start.chunk.val
      echo "line1: ", line1.start.pos
      tc3.dumpChunks()
      #tc3.createLines(fromLine=line1,maxLineWidth=20)
      #tc3.numLines = rndLine + numLines - 1
      tc3.createLines(maxLineWidth=20)
      echo "tc3.numLines: ",tc3.numLines
      tc3.dumpLines()
      echo "\n_____________________________________"
  


