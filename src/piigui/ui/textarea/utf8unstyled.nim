#[ xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

# https://zaemis.blogspot.com/2011/06/reading-unicode-utf-8-in-c.html
var utf8len : int = 0
if (uint8(c) and 192) == 192 : utf8len.inc
if (uint8(c) and 224) == 224 : utf8len.inc
if (uint8(c) and 240) == 240 : utf8len.inc 
        
]#
import
  sdl2_nim/sdl,
  sdl2_nim/sdl_image as img,
  sdl2_nim/sdl_gfx_primitives as gfx,
  sdl2_nim/sdl_gfx_primitives_font as font,
  sdl2_nim/sdl_ttf as ttf
import piigui
import piigui/[types,style]
import piigui/layout/flex
import piigui/layout/recalcH as recalcHMod
import piigui/layout/recalcV as recalcVMod
import tables

import os


import unicode

const
  MaxChunkLen = 256
  MaxInputBufferSize = 4096

type
  VisibleLine* = ref object of RootObj
    start*: tuple[chunk: UTF8Chunk, pos: int]
    last*: tuple[chunk: UTF8Chunk, pos: int]
    texture*: sdl.Texture

  VisibleLines* = seq[VisibleLine]

  UTF8Chunk* = ref object of RootObj
    runes*: seq[string] # Rune
    fgColors*: seq[uint8]
    bgColors*: seq[uint8]
    formats*: seq[uint8]
    next*: UTF8Chunk
    prev*: UTF8Chunk

  UTF8Buffer* = ref object of RootObj
    rootChunk*: UTF8Chunk
    currentChunk*: UTF8Chunk
    high*: uint
    #chunkCursor*: int
    visibleLines*: VisibleLines


proc add*(buffer: var UTF8Buffer, 
          str: sink string,
          fgColor,bgColor,format: uint8 ) =
  
  #if str.len > 1 : echo str
  buffer.currentChunk.runes.add(str)
  buffer.currentChunk.fgColors.add(fgColor)
  buffer.currentChunk.bgColors.add(bgColor)
  buffer.currentChunk.formats.add(format)

  # create a new chain-elem
  if buffer.currentChunk.runes.len == MaxChunkLen:
    buffer.currentChunk.next = new UTF8Chunk
    buffer.currentChunk.next.prev = buffer.currentChunk
    buffer.currentChunk = buffer.currentChunk.next
    buffer.high.inc()


# ---------------------------------------------------------------------

proc loadUTF8TextFile*(inFileName: string): UTF8Buffer =
  const debug = 0b1
  result = new UTF8Buffer
  result.visibleLines = @[]

  var
    inFile: File
    chunkCounter:int
    newChunk = new UTF8Chunk
    currentFgColor: uint8 # current "drawing" color
    currentBgColor: uint8 # current "drawing" color
    currentFormat: uint8

  result.rootChunk = newChunk
  result.currentChunk = result.rootChunk
  #.......................

  when debug > 0:
    echo os.getCurrentDir()
    echo os.getFileSize(inFileName)
  try:
    inFile = open(inFileName, fmRead)
  except:
    quit "\nERROR: inFile - cannot open"

  #.......................
  block FILEPROCESSING:
    while true:
      var theBuffer = newSeq[uint8](MaxInputBufferSize)

      echo inFile.getFilePos()
      var numRead = inFile.readBytes(theBuffer,0,MaxInputBufferSize)
      when debug >= 0b1: echo "numRead ", numRead


      # parsers
      # parser puts rune in the bin
      var bufferCursor: int
      var blockStart: int = -1 # if not decoded (end of buffer), must be re-read, re-parsed

      #for bi in 0 .. numRead - 1:
      block PARSEBLOCK:
        var bi = 0 # buffer iterator
        while bi < numRead:

          var str = "" # the Rune

          var utf8len : int = 0
          # utf8len = zero is good for iterators, positions
          # - it should be 1
          if (theBuffer[bi] and 0b11000000) == 0b11000000 : utf8len.inc
          if (theBuffer[bi] and 0b11100000) == 0b11100000 : utf8len.inc
          if (theBuffer[bi] and 0b11110000) == 0b11110000 : utf8len.inc

          if utf8len > 0 and (bi + utf8len) < numRead:
            #its a rune, and fully available in the buffer
            for ri in 0..utf8len:
              str = str & chr(theBuffer[bi + ri])
              
            result.add(
              str,
              currentFgColor,
              currentBgColor,
              currentFormat)
            #echo str
            bi += utf8len + 1

          elif utf8len > 0: # rune spreads to next buffer ..........
            echo "\n --- BLOCKSTART ",bi," ---"
            blockStart = bi
            break PARSEBLOCK

          elif theBuffer[bi] == 27: # ESC ...................
            blockStart = bi

            while not (theBuffer[bi].chr in ['A','B','C','D','F','H','P','Q','R','S','~', 'M']) :
              str = str & theBuffer[bi].chr
              bi.inc()
              if bi == numRead:
                break PARSEBLOCK
            str = str & theBuffer[bi].chr
            blockStart = -1
            
            #TODO result =  esc_parser(str)
            #TODO adjust currentColor, currentStyle

            discard
          else: # .......................................
            #str = $(chr(theBuffer[bi]))
            result.add(
              $(chr(theBuffer[bi])),
              currentFgColor,
              currentBgColor,
              currentFormat)

            bi.inc()
      # check blockStart - if block left unfinished

      if numRead < MaxInputBufferSize:
        break FILEPROCESSING
      else:
        #prepare the next iteration
        if blockStart > -1:
          inFile.setFilePos(((numRead - 1) - blockStart) * -1 , fspCur) #TEST
          blockStart = -1

#----------------------------------------------------------------------

proc dumpBuffer*(buffer: var UTF8Buffer)=
  var chunkCursor = buffer.rootChunk

  block TEST:
    while true:
      for str in chunkCursor.runes:
        stdout.write str
        #stdout.write str, " ", str.len, ", "
        #if str == "\n": break TEST
      if chunkCursor.next != nil:
        chunkCursor = chunkCursor.next
      else:
        break

#----------------------------------------------------------------------

proc dumpVLines*(buffer: var UTF8Buffer)=
  var chunkCursor = buffer.rootChunk
  var newVisibleLine = new VisibleLine
  newVisibleLine.start = (chunkCursor, 0)
  buffer.visibleLines.add(newVisibleLine)

  var nVLW = 0
  var runeW = 0

  block TEST:
    while true:
      var chunkCrs = 0
      for strI in 0..chunkCursor.runes.high:
        runeW = ttf.sizeUTF8(
                chunkCursor.runes[strI].cstring)
        if nVLW + runeW > 640:
          newVisibleLine = new VisibleLine
          newVisibleLine.start = (chunk: chunkCursor, pos: strI)
          buffer.visibleLines.add(newVisibleLine)

        chunkCrs.inc()


      if chunkCursor.next != nil:
        chunkCursor = chunkCursor.next
      else:
        break

#----------------------------------------------------------------------





######################################################

when isMainModule:
  let testfilename = "src/piigui/ui/textarea/SampleTextFile_10kb.txt"

  var testBuffer: UTF8Buffer

  testBuffer = loadUTF8TextFile(testfilename)

  echo testBuffer.high + 1

  echo "-------------------"

  dumpBuffer(testBuffer)


