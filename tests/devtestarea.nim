import strutils
import os

##########################


type
  ChunkRef = ref object of RootObj
    val: string
    next: ChunkRef

  ChunkPosObj = object
    chunk: ChunkRef
    pos: int

  LineRef = ref object of RootObj
    start: ChunkPosObj
    stop: ChunkPosObj
    prev: LineRef
    next: LineRef
  
  TextContainerRef = ref object of RootObj
    rootLine: LineRef
    rootChunk: ChunkRef
    chunkSize: int

    lineCursor: LineRef
    currentLine: int

    numLines:int



##########################

var
  rootChunk = new ChunkRef
  chunkPrev, chunkThis: ChunkRef
  chunkCursor:int
  
  numRead:int
  fileSize = 64 * 6 + 10
  chunkSize = 256

  screenW = 20
  rootLine = new LineRef
  linePrev, lineThis: LineRef
  lineCursor: int

  numLines:int=1


#! watch /l/r
proc createTestChunk(prev,this:ChunkRef, num:int)=
  this.val = repeat('x',(num div 2)-1) & "\n" & repeat('z',(num div 2)) & "\n"

  if prev != nil:
    prev.next = this

  #echo "testchunk ", numRead, ", ", num
  #os.sleep(100)


chunkThis = rootChunk
chunkPrev = nil
while numRead < fileSize:
  echo numRead, " : ", fileSize
  if numRead + chunkSize < fileSize:
    createTestChunk(chunkPrev,chunkThis, chunkSize)
    numRead += chunkThis.val.len #chunkSize
  else:
    echo "(fileSize - numRead) ", (fileSize - numRead)
    createTestChunk(chunkPrev,chunkThis, (fileSize - numRead))
    numRead += chunkThis.val.len # fileSize - numRead

  chunkPrev = chunkThis
  chunkThis = new ChunkRef
echo numRead, " : ", fileSize

# test chunk buffer
chunkThis = rootChunk
var debugi:int
while chunkThis != nil:
  debugi.inc()
  stdout.write debugi,' ',chunkThis.val
  chunkThis = chunkThis.next
echo "\n"




echo "\n\ncreating lines"
chunkThis = rootChunk
chunkCursor = 0
lineThis = rootLine
lineThis.start.chunk = rootChunk
lineThis.start.pos = 0
var lineLen: int
#echo '#',chunkThis.val
for ci in 1..numRead:
  #echo ci
  if chunkThis.val[chunkCursor] == '\n':
    echo " -- newline ", ci
    lineThis.stop.chunk = chunkThis
    lineThis.stop.pos = chunkCursor #todo \n\r - setLineEnding
    if ci == numRead: # end of buffer, lineThis.next must be nil
      echo "ci == numRead"
      break
    lineThis.next = new LineRef
    lineThis.next.prev = lineThis

    numLines.inc()

    chunkCursor += 1
    
    # calc next lines start
    echo " lineLen ", lineLen
    lineThis = lineThis.next
    lineLen = 0

    if chunkThis.val.high >= chunkCursor: # same chunk
      lineThis.start.chunk = chunkThis
      lineThis.start.pos = chunkCursor
      chunkThis.val[chunkCursor] = ($numLines)[0] #debug
    else:
      if chunkThis.next == nil:
        lineThis.stop.chunk = chunkThis # todo watch for it!
        lineThis.stop.pos = chunkCursor
        echo "\n break @ newline"
        break
      chunkThis = chunkThis.next
      lineThis.start.chunk = chunkThis
      lineThis.start.pos = 0
      chunkCursor = 0
      chunkThis.val[chunkCursor] = ($numLines)[0] #debug
    

    #[ if chunkCursor > chunkThis.val.high: # oops, jump to next chunk!
      chunkThis = chunkThis.next
      chunkCursor = 0
      if chunkThis == nil:
        lineThis.stop.chunk = chunkThis # todo watch for it!
        lineThis.stop.pos = chunkCursor
        break ]#
  else:

    stdout.write chunkThis.val[chunkCursor] #! ---------

    lineLen += 1
    

    if lineLen == screenW: # todo chunk-end error
      echo " lineLen == screenW   chunkCursor: ",chunkCursor, "/",chunkThis.val.high
      lineThis.stop.chunk = chunkThis
      lineThis.stop.pos = chunkCursor

      chunkCursor += 1
      numLines.inc()

      if chunkThis.val.high >= chunkCursor: # same chunk
        echo "chunkThis.val.high <= chunkCursor", chunkThis.val.high, " <= ", chunkCursor
        lineThis.next = new LineRef
        lineThis.next.prev = lineThis
        lineThis = lineThis.next
        lineLen = 0
        
        lineThis.start.chunk = chunkThis
        lineThis.start.pos = chunkCursor
        chunkThis.val[chunkCursor] = ($numLines)[0] #debug
      else: # next chunk or end
        echo "next chunk or end"
        if chunkThis.next == nil:
          lineThis.stop.chunk = chunkThis # todo watch for it!
          lineThis.stop.pos = chunkCursor
          echo "- break @ screenW -"
          break
        lineThis.next = new LineRef
        lineThis.next.prev = lineThis
        lineThis = lineThis.next
        lineLen = 0

        chunkThis = chunkThis.next
        lineThis.start.chunk = chunkThis
        lineThis.start.pos = 0
        chunkCursor = 0
        chunkThis.val[chunkCursor] = ($numLines)[0] #debug

    else:
      chunkCursor += 1
      if chunkCursor > chunkThis.val.high:
        echo " if chunkCursor > chunkThis.val.high:"
        if chunkThis.next == nil:
          lineThis.stop.chunk = chunkThis
          lineThis.stop.pos = chunkCursor
          echo "\n break @ chunkThis.next == nil"
          break
        chunkThis = chunkThis.next
        chunkCursor = 0
    
  
# finally:
lineThis.stop.chunk = chunkThis
lineThis.stop.pos = chunkCursor

echo "numlines ", numLines
####################################################x



echo "\n\n________________________"
echo "output:\n"
lineThis = rootLine
while lineThis != nil:
  chunkThis = lineThis.start.chunk
  chunkCursor = lineThis.start.pos

  if lineThis.start.chunk == lineThis.stop.chunk:
    #echo '#',chunkThis.val
    stdout.write('>', chunkThis.val[
      lineThis.start.pos .. lineThis.stop.pos], '\n') # todo line endings!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    lineThis = lineThis.next

  else:
    #if chunkThis == nil: echo "chunkThis nil error"
    # first chunk to the end
    stdout.write('e', chunkThis.val[
      lineThis.start.pos .. lineThis.start.chunk.val.high]) # todo line endings!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    chunkThis = chunkThis.next
    while chunkThis != lineThis.stop.chunk:
      stdout.write('m', chunkThis.val)
      chunkThis = chunkThis.next

    stdout.write('-', chunkThis.val[
        0 .. lineThis.stop.pos])

    lineThis = lineThis.next
    #if chunkThis == lineThis.stop.chunk: break # do..while


#-------------------------------------------

var text1 = new TextContainerRef
text1.rootChunk = rootChunk
text1.rootLine = rootLine
text1.lineCursor = rootLine
text1.currentLine = 1
text1.numLines = numLines

proc seekToLine*(this:TextContainerRef, lineNum:int)=
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
  


proc getLine*(this:TextContainerRef, lineNum:int):string=
  var
    chunkThis: ChunkRef
    chunkCursor: int
    lineThis: LineRef

  echo "getLine ", lineNum

  seekToLine(this, lineNum)


  lineThis = this.lineCursor

  chunkThis = lineThis.start.chunk
  chunkCursor = lineThis.start.pos

  if lineThis.start.chunk == lineThis.stop.chunk:
    #echo '#',chunkThis.val
    stdout.write('>', chunkThis.val[
      lineThis.start.pos .. lineThis.stop.pos], '\n') # todo line endings!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    lineThis = lineThis.next

  else:
    #if chunkThis == nil: echo "chunkThis nil error"
    # first chunk to the end
    stdout.write('e', chunkThis.val[
      lineThis.start.pos .. lineThis.start.chunk.val.high]) # todo line endings!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    chunkThis = chunkThis.next
    while chunkThis != lineThis.stop.chunk:
      stdout.write('m', chunkThis.val)
      chunkThis = chunkThis.next

    stdout.write('-', chunkThis.val[
        0 .. lineThis.stop.pos])

    #lineThis = lineThis.next
    #if chunkThis == lineThis.stop.chunk: break # do..while

echo text1.getLine(9)