import unicode
import sequtils

##[
  store text in chunks
  store style data in chunks together - so changing stylePoint position 
  should not recalculate all of the stylepoints location

  GOALS:
    - char-by-char drawing, styling of lines

  MILESTONES:
    - simple text
    - styled text & html default styles
    - parsed text
]##

const DebugEchoLevel = 1

type

  TextStyle* = ref object of RootObj #TODO

  StylePoint = ref object of RootObj #TODO
    pos:int
    style: TextStyle

  TextChunkRef* = ref object of RootObj
    val*: string
    prev*: TextChunkRef
    next*: TextChunkRef
    stylePoints*: seq[StylePoint] #TODO

  TextChunkPosRef* = ref object of RootObj
    chunk: TextChunkRef
    pos: Natural

  TextBufferRef* = ref object of RootObj
    firstChunk*: TextChunkRef
    lastChunk*: TextChunkRef
    maxChunkSize*: Positive
    newLineStr*: string
    cursorStart*: TextChunkPosRef
    cursorEnd*: TextChunkPosRef

#------------------------------------------------------------------------------

proc newTextChunkRef*(
  val: string = "",
  prev: TextChunkRef = nil,
  next: TextChunkRef = nil,
  stylePoints: seq[StylePoint] = @[]
): TextChunkRef =
  result = new TextChunkRef
  result.val = val
  result.prev = prev
  result.next = next
  result.stylePoints = stylePoints

#------------------------------------------------------------------------------

proc newTextBuffer*(maxChunkSize = 256, newLineStr = ""):TextBufferRef=
  when DebugEchoLevel > 0: echo "BEGIN proc newTextBuffer"
  result = new TextBufferRef
  result.maxChunkSize = maxChunkSize
  result.newLineStr = newLineStr # "" is a special "auto" case -? PARSER ?-
  
  result.firstChunk = newTextChunkRef()
  result.lastChunk = result.firstChunk

  result.cursorStart = new TextChunkPosRef
  result.cursorEnd = new TextChunkPosRef
  result.cursorStart.chunk = result.firstChunk
  result.cursorStart.pos = 0
  result.cursorEnd.chunk = result.firstChunk
  result.cursorEnd.pos = 0
  when DebugEchoLevel > 0: echo "END   proc newTextBuffer"


#------------------------------------------------------------------------------
proc resegmentLargeChunk*(
  textBuffer: TextBufferRef,
  chunk: TextChunkRef
) =
  # -------++++++
  # 0123456789012
  # 13 - 13 # == 0, first array elem
  # 13 - 7 = 6 # remaining
  # 13 - 6 = 7 # insert_pos - array elem from
  
  when DebugEchoLevel > 0:
    debugEcho "\n.........................\nBEGIN resegmentLargeChunk"
    debugEcho "origi: ", chunk.val
    debugEcho "len:",chunk.val.len,
      "max:",textBuffer.maxChunkSize,
      "diff:",(chunk.val.len - textBuffer.maxChunkSize)

  if chunk.val.len <= textBuffer.maxChunkSize: return
  #.....................
  var
    origival = chunk.val
    remaining = (origival.len - textBuffer.maxChunkSize)
    prevchunk, newchunk, nextchunk: TextChunkRef
    insert_pos: int
    isLastChunk = textBuffer.lastChunk == chunk
  prevchunk = chunk
  nextchunk = chunk.next
  #.....................
  while remaining > 0:
    newchunk = newTextChunkRef()
    newchunk.prev = prevchunk
    prevchunk.next = newchunk

    if remaining > textBuffer.maxChunkSize:
      insert_pos = (origival.len - remaining) # 13 - 6 = 7 # 13-3=10
      when DebugEchoLevel > 0:
        debugEcho "insert_pos: ", insert_pos, " remaining: ", remaining
      newchunk.val = origival[
        insert_pos .. (insert_pos + (textBuffer.maxChunkSize - 1))
      ]
      remaining = remaining - textBuffer.maxChunkSize # 6 - 3

    else:
      insert_pos = (origival.len - remaining) # 13 - 6 = 7 # 13-3=10
      when DebugEchoLevel > 0:
        debugEcho "insert_pos: ", insert_pos, " remaining: ", remaining
      newchunk.val = origival[
        insert_pos .. (insert_pos + (remaining - 1))
      ]
      remaining = 0

    when DebugEchoLevel > 0:
      #debugEcho "BEGIN resegmentLargeChunk"
      debugEcho "newchunk: ", newchunk.val, "\n........................"
      prevchunk = newchunk

  newchunk.next = nextchunk
  if isLastChunk: textBuffer.lastChunk = newchunk
  chunk.val.setLen(textBuffer.maxChunkSize)


#------------------------------------------------------------------------------
proc insertTextAt*(
  textBuffer: TextBufferRef,
  posStart: TextChunkPosRef,
  val: tuple[str: sink string, stylePoints: seq[StylePoint]] ) =
  ## some parser should use this
  #TODO insert into selection: delete selection & insert
  #TODO return cursorEnd, TextBuffer.cursorEnd
  #TODO firstChunk, lastChunk checks!
  
  when DebugEchoLevel > 0:
    echo "\n.........................\nBEGIN proc insertTextAt"
    echo "val.stylePoints.len : ", val.stylePoints.len

  if posStart.pos == 0: #*PREPEND
    when DebugEchoLevel > 0: echo "    insertTextAt if posStart.pos == 0:"
    # adjust before val.len changes
    if posStart.chunk.stylePoints.len > 0:
      for e in posStart.chunk.stylePoints:
        e.pos += val.str.len

    if val.stylePoints.len > 0 and posStart.chunk.stylePoints.len > 0: #!TEST
      posStart.chunk.stylePoints = concat(val.stylePoints, posStart.chunk.stylePoints)
    elif val.stylePoints.len > 0:
      posStart.chunk.stylePoints = val.stylePoints 

    posStart.chunk.val = val.str & posStart.chunk.val


  elif posStart.pos == posStart.chunk.val.high + 1: #*APPEND
    when DebugEchoLevel > 0: echo "    insertTextAt if posStart.pos == posStart.chunk.val.high + 1"
    if val.stylePoints.len > 0: #!TEST
      when DebugEchoLevel > 0: echo "add stylePoints insertTextAt"
      for e in val.stylePoints:
        e.pos += posStart.chunk.val.len
      posStart.chunk.stylePoints = concat(posStart.chunk.stylePoints, val.stylePoints)
    
    posStart.chunk.val = posStart.chunk.val & val.str


  else:#*INSERT
    when DebugEchoLevel > 0: echo "    insertTextAt if MIDDLE"
    # 0.......A_____val____B........high

    # add stylePoints:
    if val.stylePoints.len > 0 and posStart.chunk.stylePoints.len > 0: #!TEST
      var
        sp_cur = -1 # lower not found
        icur = 0
      # get insert point "sp_cur"
      # find where to insert sp-s
      for icur in 0..posStart.chunk.stylePoints.high:
        if posStart.chunk.stylePoints[icur].pos < val.stylePoints[0].pos:
          sp_cur = icur # cur is inclusive
        else: break

      if sp_cur == -1: # lower not found
        for e in val.stylePoints:
          posStart.chunk.stylePoints.insert(
            StylePoint(pos:e.pos+posStart.pos,
              style: e.style)
            )
        #[ posStart.chunk.stylePoints = concat(
          val.stylePoints,
          posStart.chunk.stylePoints) ]#
      else:
        if sp_cur < posStart.chunk.stylePoints.high:
          posStart.chunk.stylePoints = concat(
            posStart.chunk.stylePoints[0..sp_cur],
            val.stylePoints,
            posStart.chunk.stylePoints[sp_cur+1 .. posStart.chunk.stylePoints.high]
          )
        else: # logic PATCH
          # if .high position is lower than what to be inserted, then append!
          posStart.chunk.stylePoints = concat(posStart.chunk.stylePoints, val.stylePoints)
        #TODO insert into seq/array
        #TODO chk begin, end, 


    elif val.stylePoints.len > 0 and posStart.chunk.stylePoints.len == 0:
      posStart.chunk.stylePoints = val.stylePoints

    posStart.chunk.val = 
      posStart.chunk.val[0 ..< posStart.pos] &
      val.str &
      posStart.chunk.val[posStart.pos .. posStart.chunk.val.high]
    
  if posStart.chunk.val.len > textBuffer.maxChunkSize:
    textBuffer.resegmentLargeChunk(posStart.chunk)
    when DebugEchoLevel > 0:
      echo "   proc insertTextAt posStart.chunk.val.len > textBuffer.maxChunkSize"
      echo "   ", posStart.chunk.val.len, ", ", textBuffer.maxChunkSize

  when DebugEchoLevel > 0: echo "END   proc insertTextAt"

#------------------------------------------------------------------------------
# deleteText - if selection: delete from-to
#              else delete curso pos
# backspace: step and deleteText
proc deleteText*(
  textBuffer: TextBufferRef,
  posStart: TextChunkPosRef
) =

  when DebugEchoLevel > 0:
    echo "\n.........................\nBEGIN proc deleteTextFrom"
    echo " : "




#------------------------------------------------------------------------------


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
  
  const
    runAppendTest = false
    runAppendTestStyled = true

  proc dumpTextBuffer(tb: TextBufferRef)=
    var cur: TextChunkRef
    cur = tb.firstChunk
    while cur != nil:
      echo cur.val,"\n"
      cur = cur.next


  proc dumpTextBufferStyled(tb: TextBufferRef)=
    when DebugEchoLevel > 0: debugEcho "BEGIN dumpTextBufferStyled"
    var
      cur: TextChunkRef
      sp_cur: int = 0
      val_cur: int = 0
      val_end: int = 0
      remaining: int
    cur = tb.firstChunk
    while cur != nil:
      sp_cur = 0
      val_cur = 0
      if cur.stylePoints.len == 0: # just print all
        when DebugEchoLevel > 0:
          debugEcho "cur.stylePoints.len == 0 | addr cur: ",
            cast[uint](addr(cur)), " val.len: ", cur.val.len
        #standard style
        echo cur.val
        #cur = cur.next
      else: # print from stylepoint to stylepoint
        when DebugEchoLevel > 0:
            debugEcho "cur.stylePoints.len > 0 | addr cur: ",
              cast[uint](addr(cur)), " val.len: ", cur.val.len
        remaining = cur.val.len
        while remaining > 0:
          if cur.stylePoints[sp_cur].pos == val_cur:
            stdout.write "@" #change style
          # how long should we copy? val_end
          if sp_cur == cur.stylePoints.high:
            val_end = cur.val.high
          else:
            val_end = cur.stylePoints[sp_cur + 1].pos - 1
            sp_cur.inc # should not drop out of bound err :)
            
          echo cur.val[val_cur .. val_end]

          remaining = remaining - (val_end - val_cur + 1)

          #val_cur = cur.stylePoints[sp_cur].pos #continue
          val_cur = val_end + 1

      when DebugEchoLevel > 0:
        debugEcho "addr cur: ",
          cast[uint]((cur)),
          " | addr cur next: ",
          cast[uint]((cur.next))       
      cur = cur.next


  var
    textBuffer = newTextBuffer()




  when runAppendTest:
    debugEcho "runAppendTest"

    for i in 0..40:
      insertTextAt(
        textBuffer,
        TextChunkPosRef(chunk: textBuffer.lastChunk,
                        pos: textBuffer.lastChunk.val.len),
        val = (str: $i&":text to sink.",
              stylePoints: @[StylePoint(pos:0,style:new TextStyle),
                             StylePoint(pos:5,style:new TextStyle),
                             StylePoint(pos:8,style:new TextStyle)])
      )

    #[ textBuffer.dumpTextBuffer

    debugEcho "********* runAppendTest  pos: textBuffer.lastChunk.val.len div 2"

    for i in 0..4:
      insertTextAt(
        textBuffer,
        TextChunkPosRef(chunk: textBuffer.lastChunk,
                        pos: textBuffer.lastChunk.val.len div 2),
        val = (str: "text to sink.",
              stylePoints: @[])
      )

    textBuffer.dumpTextBuffer ]#



    #[ debugEcho "******** runAppendTest  pos: 0"

    for i in 0..20:
      insertTextAt(
        textBuffer,
        TextChunkPosRef(chunk: textBuffer.lastChunk,
                        pos: 0),
        val = (str: $i&"text to sink.",
              stylePoints: @[])
      ) ]#

    #textBuffer.dumpTextBuffer
    textBuffer.dumpTextBufferStyled




  when runAppendTestStyled:
    debugEcho "runAppendTest"

    for i in 0..40:
      insertTextAt(
        textBuffer,
        TextChunkPosRef(chunk: textBuffer.lastChunk,
                        pos: textBuffer.lastChunk.val.len),
        val = (str: $i&":text to sink.",
              stylePoints: @[StylePoint(pos:0,style:new TextStyle),
                             StylePoint(pos:5,style:new TextStyle),
                             StylePoint(pos:8,style:new TextStyle)])
      )


    textBuffer.dumpTextBuffer
    textBuffer.dumpTextBufferStyled    