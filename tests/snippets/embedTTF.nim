import sdl2
import sdl2/ttf

const fontData = staticRead("assets/monofont.ttf")

proc loadEmbeddedFont(fontSize: cint): FontPtr =
  let rw = rwFromConstMem(fontData.cstring, fontData.len.cint)
  if rw == nil:
    echo "Nem sikerült az RWops a betűtípushoz: ", getError()
    return nil

  # A font betöltése RWops-ból (az utolsó paraméter '1', így az SDL bezárja az rw-t)
  let font = ttf.openFontRW(rw, 1, fontSize)
  if font == nil:
    echo "Nem sikerült a font megnyitása: ", ttf.getError()
    return nil

  return font
