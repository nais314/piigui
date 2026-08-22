import sdl2
import sdl2/image as img

# 1. Beágyazás fordítási időben (a fájlnak a projekt mappájában kell lennie)
const imageData = staticRead("assets/hero.png")

proc loadEmbeddedImage(renderer: RendererPtr): TexturePtr =
  # 2. RWops létrehozása a beágyazott konstans memóriából
  # A string első karakterének címét adjuk át, a mérete pedig a string hossza
  let rw = rwFromConstMem(imageData.cstring, imageData.len.cint)
  if rw == nil:
    echo "Nem sikerült az RWops létrehozása: ", getError()
    return nil

  # 3. Kép betöltése az RWops-ból (a 1-es paraméter automatikusan bezárja az rw-t)
  let texture = img.loadTexture_RW(renderer, rw, 1)
  if texture == nil:
    echo "Nem sikerült a textúra betöltése: ", img.getError()
    return nil

  return texture
