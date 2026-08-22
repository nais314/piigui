var
    aa: array[0..80, string]
    ai:int=0
    alen:int=0
    bb:string="öüóőúéáűí$öüóőúéáűí$"
    bi:int=0
    cc:string="¤"


for i in 0..aa.high:
    aa[i] = newStringOfCap(4)


while bi < bb.len:

    if (bb[bi].ord().uint8 and 240.uint8) == 240.uint8:

      aa[ai] = bb[bi] &
            bb[bi + 1] &
            bb[bi + 2] &
            bb[bi + 3]
      bi += 4
      ai += 1

    elif (bb[bi].ord().uint8 and 224.uint8) == 224.uint8:

      aa[ai] = bb[bi] &
            bb[bi + 1] &
            bb[bi + 2]

      bi += 3
      ai += 1

    elif (bb[bi].ord().uint8 and 192.uint8) == 192.uint8:

      aa[ai] = bb[bi] &
            bb[bi + 1]

      bi += 2
      ai += 1
    
    else:
      aa[ai] = $(bb[bi])
      bi += 1
      ai += 1

    alen += 1


for i in 0..alen:
    stdout.write(aa[i])
echo "\p"

aa[21..30] = aa[1..10]
#aa[1..10] = "..........".elems

echo $aa[0].len
let ap1 = addr(aa[0])
echo "\p"

aa[0] = $"."

echo $aa[0].len
echo $(cast[int](addr(aa[0]) ) )
echo "\p"
let ap2 = addr(aa[0])
echo ap1 == ap2
echo "\p"


aa[0] = "áéádfnsdfnsmnfsdé"

echo $aa[0].len
echo $(cast[int](addr(aa[0]) ) )
echo "\p"
let ap3 = addr(aa[0])
echo ap1 == ap3
echo "\p"

echo ap1[0..1]


