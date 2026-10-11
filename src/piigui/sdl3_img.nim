## SDL3_image (IMG_*) runtime bindings for PiiGUI.
##
## SDL3 core decodes only BMP and PNG. Everything else (JPG, GIF, WEBP, AVIF,
## TGA, QOI, SVG, ...), texture-from-file loading, animations and animated
## cursors live in SDL3_image, for which the sdl3 Nim package ships no wrapper.
## This module binds the subset the toolkit needs. Proc names drop the IMG_
## prefix, except the two generic ones (`imgLoad`, `imgVersion`) which keep it
## to avoid clashing with user code; the rest are meant to be called through the
## module alias, e.g. `img.loadAnimation(...)`.
##
## The shared library is opened once, when a program references any symbol here.
##
## #! Ownership / lifecycle (check these when auditing for leaks or use-after-free)
## - imgLoad / load_IO           -> caller owns the Surface;  free with destroySurface
## - loadTexture / loadTexture_IO -> caller owns the Texture;  free with destroyTexture
## - loadAnimation               -> caller owns the Animation; free with freeAnimation
## - createAnimatedCursor        -> caller owns the returned Cursor; free with
##                                  destroyCursor. The source Animation MUST stay
##                                  alive until then: SDL keeps references to its
##                                  frame surfaces, so a premature freeAnimation
##                                  is a use-after-free.
##
## Not bound on purpose: the per-format loaders (IMG_LoadPNG_IO, ...), the
## Typed_IO and GPU variants, IMG_SavePNG (SDL3 core already exposes `savePNG`),
## and the 3.4.0 animation encoder/decoder API.

import sdl3 as sdl

###########################################################

#*=================================================
#*           SDL3_IMAGE SHARED LIBRARY
#*=================================================
# platform library names, mirroring sdl3.nim's LibName convention
when defined(windows):
  const ImgLibName = "SDL3_image.dll"
elif defined(macosx):
  const ImgLibName = "libSDL3_image.dylib"
else:
  const ImgLibName = "libSDL3_image.so"

#*=================================================
#*                   TYPES
#*=================================================
# IMG_Animation has no counterpart in the sdl3 package. bycopy + pointer
# fields mirror the C struct layout; frames and delays are owned by the
# animation and released by freeAnimation.
type Animation* {.bycopy.} = object
  w*, h*: cint
  count*: cint
  frames*: ptr ptr Surface
  delays*: ptr cint

#*=================================================
#*                IMG_* BINDINGS
#*=================================================
{.push callConv: cdecl, dynlib: ImgLibName.}

#--------------------------------------------
# load
#--------------------------------------------
# IMG_* loaders cover every supported format; core loadSurface/loadPNG do not
proc imgLoad*(file: cstring): ptr Surface {.importc: "IMG_Load".}
proc load_IO*(src: IOStream, closeio: bool): ptr Surface {.importc: "IMG_Load_IO".}
proc loadTexture*(renderer: Renderer, file: cstring): Texture {.importc: "IMG_LoadTexture".}
proc loadTexture_IO*(renderer: Renderer, src: IOStream, closeio: bool): Texture {.importc: "IMG_LoadTexture_IO".}

#--------------------------------------------
# save
#--------------------------------------------
# IMG_SavePNG duplicates SDL3 core's savePNG; kept commented to avoid an
# ambiguous duplicate. Uncomment only if the core binding is ever removed.
#proc savePNG*(surface: ptr Surface, file: cstring): bool {.importc: "IMG_SavePNG".}
proc saveJPG*(surface: ptr Surface, file: cstring, quality: cint): bool {.importc: "IMG_SaveJPG".}

#--------------------------------------------
# format detection
#--------------------------------------------
# all take an SDL_IOStream, not a path: open with ioFromFile/ioFromConstMem first
proc isPNG*(src: IOStream): bool {.importc: "IMG_isPNG".}
proc isJPG*(src: IOStream): bool {.importc: "IMG_isJPG".}
proc isGIF*(src: IOStream): bool {.importc: "IMG_isGIF".}

#--------------------------------------------
# animations
#--------------------------------------------
proc loadAnimation*(file: cstring): ptr Animation {.importc: "IMG_LoadAnimation".}
proc freeAnimation*(anim: ptr Animation) {.importc: "IMG_FreeAnimation".}

#--------------------------------------------
# animated cursors
#--------------------------------------------
# overload of sdl3.nim's createAnimatedCursor(ptr CursorFrameInfo, ...): the
# distinct first-argument type selects the IMG_ version
proc createAnimatedCursor*(anim: ptr Animation, hotX, hotY: cint): Cursor {.importc: "IMG_CreateAnimatedCursor".}

#--------------------------------------------
# diagnostics
#--------------------------------------------
proc imgVersion*(): cint {.importc: "IMG_Version".}

{.pop.}
