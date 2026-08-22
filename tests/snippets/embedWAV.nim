import sdl2
import sdl2/mixer

const soundData = staticRead("assets/laser.wav")

proc loadEmbeddedSound(): ChunkPtr =
  let rw = rwFromConstMem(soundData.cstring, soundData.len.cint)
  if rw == nil:
    echo "Nem sikerült az RWops a hanghoz: ", getError()
    return nil

  # Hangminta betöltése (az utolsó paraméter '1' -> automatikus RWops lezárás)
  let chunk = mixer.loadWAV_RW(rw, 1)
  if chunk == nil:
    echo "Nem sikerült a hang betöltése: ", mixer.getError()
    return nil

  return chunk
