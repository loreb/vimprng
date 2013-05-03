" http://burtleburtle.net/bob/rand/isaac.html#IBAA
" IA was extended to IBAA. In addition to being fast, easy to memorize, and
" immune to Gaussian elimination, IBAA was required to have no detectable bias
" for the entire cycle length. Short cycles must be very rare.

" {{{ bitwise shifts; check 32 bits.
if 0x7fffffff <= 0 || 0x7fffffff+1 >= 0
    throw "this algorithm is for 32 bit machines"
endif
let s:p2 = [1]
for i in range(30)
    let s:p2 += [ s:p2[i] * 2 ]
endfor
if s:p2[3] != 8 | throw "p2 bug" | endif
function! s:lshift(x, nbits)
    return a:x * s:p2[a:nbits]
endfunction
function! s:rshift(x, nbits)
    if a:x < 0
        if ! a:nbits | return a:x | endif
        " nonzero shift: sign bit would be cleared anyway
        let shifted1 = or(0x40000000, and(a:x, 0x7fffffff) / 2)
        return s:rshift(shifted1, a:nbits-1)
    endif
    return a:x / s:p2[a:nbits]
endfunction
" }}}

let s:ALPHA = 8
let IBAA_SIZE  = s:lshift(1, s:ALPHA)
function! s:ind(x)
    return and(a:x, g:IBAA_SIZE-1)
endfunction

" #define barrel(a)  (((a)<<19)^((a)>>13)) /* beta=32,shift=19 */
function! s:barrel(x)
    let a = a:x
    return xor(s:lshift(a,19), s:rshift(a,13))
endfunction

function! s:ibaa(m, r, aa, bb)
    " What was the difference between arrays and pointers again?
    let a = a:aa[0] | let b = a:bb[0]
    for i in range(g:IBAA_SIZE)
        let x = a:m[i]
        let a = s:barrel(a) + a:m[s:ind(i + (g:IBAA_SIZE/2))] " set a
        " a=b=c isn't in vim
        let y = a:m[s:ind(x)] + a + b
        let a:m[i] = y    " set m
        let b = a:m[s:ind(s:rshift(y,s:ALPHA))] + x
        let a:r[i] = b    " set r
    endfor
    let a:aa[0] = a | let a:bb[0] = b
endfunction
" '''
" My default initialization routine is randinit() in rand.c. I haven't
" discussed randinit(), I have less faith in it than in ISAAC. In this paper,
" I've only discussed ISAAC once properly initialized, not how to properly
" initialize it. It's properly initialized if nothing is known about its
" internal state.
" '''
"
" So we can just use /dev/urandom? Almost.
" ISAAC has no bad seeds -- period.
" IA needs ate least 16 bits set.
" IBAA... dunno, [0]x256 makes it loop, but setting a single bit is ok
" for as long as I had the patience to run the C implementation,
" so I'll assume that all 0 is the only troublesome case.
function! s:notenoughbits(a)
    for n in a:a
        if n != 0
            return 0
        endif
    endfor
    return 1
endfunction

let s:m = range(256)
let s:r = range(256)
let s:aa = [0]
let s:bb = [0]
let s:numsleft = 0

function! IBAA()
    " some 16x slower than Xkcd221()
    if 0 == s:numsleft
        call s:ibaa(s:m, s:r, s:aa, s:bb)
        let s:numsleft = g:IBAA_SIZE-1
    else
        let s:numsleft -= 1
    endif
    return s:r[s:numsleft]
endfunction

function! IBAA_seed(seed)
    if len(a:seed) != g:IBAA_SIZE
        throw printf("IBAA(m[%d]) - length should be %d",
                    \ len(a:seed), g:IBAA_SIZE)
    endif
    let s:aa[0] = 0
    let s:bb[0] = 0
    let s:numsleft = 0
    let m = copy(a:seed)
    while s:notenoughbits(m)
        for i in range(len(m))
            let m[i] += i*i*i " better than 1, i, ...
        endfor
        for i in range(666)
            call IBAA()
        endfor
    endwhile
    let s:m = m
endfunction

if len($DEBUG) > 0
    echomsg 'testing IBAA()...'
    call IBAA_seed(range(256))
    let warmup = 12345
    echomsg printf("warmup %d rounds...", warmup)
    for i in range(warmup)
        call IBAA()
    endfor
    " test data {{{
    let wanted = [
                \ 1778449315, 1566280888, 1116118831,
                \ 2054235872, 848832882, 1770339195,
                \ 3080959872, 612917819, 2310929935,
                \ 1068970748, 1918688281, 572417091,
                \ 1239394021, 3175636223, 294734875,
                \ 3155219633, 416283213, 2337365552,
                \ 1571371386, 3969463018, 2547068744,
                \ 993574717, 3682002470, 1491034408,
                \ 2557189921, 698263036, 2031470587,
                \ 3080138925, 352488858, 2387782676,
                \ 1835839711, 1968243581, 1688216692,
                \ 3811435559, 1383665580, 1864404653,
                \ 3215651274, 1959463885, 1411616282,
                \ 3228126457, 3641579160, 25554217,
                \ 2156077424, 1040614612, 3394148364,
                \ 3340799350, 3553938464, 3393409749,
                \ 250295465, 2662439113, 4067602781,
                \ 1193770240, 965727730, 3481119891,
                \ 1038371218, 2273732975, 318756867,
                \ 3780985966, 1877884961, 2657624104,
                \ 2239145679, 590141163, 515458549,
                \ 4236085761, 3469479623, 3064199769,
                \ 4138581185, 523093546, 2112177051,
                \ 3735671000, 2148504109, 2244656191,
                \ 3016406790, 446783242, 1833229831,
                \ 1726770277, 1980148632, 2454245630,
                \ 812391457, 3642147676, 3371768304,
                \ 203868564, 2221588044, 3969728524,
                \ 1728368283, 1689611570, 3025335057,
                \ 3856145832, 1036733787, 2530569092,
                \ 301958437, 1327765046, 3193122080,
                \ 483206211, 2853593777, 3127165941,
                \ 1741380899, 4228393767, 2650238116,
                \ 1660528869, 641748231, 1694207550,
                \ 4292060258, 1630226721, 2142751699,
                \ 930692748, 4085895126, 3433022149,
                \ 1922468848, 883683468, 3529501410,
                \ 403211763, 2844175911, 1115377934,
                \ 3162589706, 3618050591, 608730384,
                \ 1987094705, 2269557454, 3023991049,
                \ 26803548, 294359368, 3882485232,
                \ 4240564460, 862848331, 1445929329,
                \ 1850638800, 3553231464, 3877146230,
                \ 656648929, 2821712416, 3425889017,
                \ 795695293, 828973644, 2883472866,
                \ 1966735513, 1921777339, 4177282296,
                \ 3527354777, 2447830327, 4199474201,
                \ 737223651, 1841449006, 797290167,
                \ 2139020541, 3463855363, 834568498,
                \ 2070527530, 1266581390, 3536268021,
                \ 1795013496, 4014568913, 2842928693,
                \ 2524214379, 3425289903, 2023936254,
                \ 3607842632, 1702522870, 150450542,
                \ 3300269203, 2357008831, 4197076974,
                \ 2627303600, 910928285, 1582271109,
                \ 3705405228, 1269031201, 818593659,
                \ 727501471, 1503662154, 523620957,
                \ 884731724, 3300353945, 2963886183,
                \ 352343427, 3237985820, 1052233404,
                \ 3061481259, 1565139108, 2043099023,
                \ 2215842146, 3992583316, 3615605591,
                \ 2216525935, 290832401, 448721117,
                \ 2354794158, 2717866036, 294687455,
                \ 3379623430, 1856868424, 163384909,
                \ 3323301492, 2835574302, 3662143083,
                \ 3295561512, 3371498592, 830838428,
                \ 893897850, 2646574412, 2378803066,
                \ 2990289274, 1273288359, 3512882818,
                \ 1049815808, 1099757366, 2261192868,
                \ 3997621776, 1843479969, 481578828,
                \ 3916800576, 3662397929, 1494917359,
                \ 2332892785, 1300742662, 2230302103,
                \ 3093683875, 162146999, 2285221185,
                \ 1564891527, 870542602, 2793273142,
                \ 3482947259, 2592513869, 2215397170,
                \ 4183870860, 1814974909, 2671253046,
                \ 1272836669, 208323186, 164908575,
                \ 2435899526, 3468974713, 466108311,
                \ 1309915837, 3502353462, 4253255935,
                \ 3482933177, 2016069704, 3995847411,
                \ 927543513, 1468068765, 384750159,
                \ 2441682398, 1992582957, 2861159388,
                \ 2557845792, 822920831, 3231160672,
                \ 3727364720, 2567782872, 1459094269,
                \ 3004995338, 1070081394, 3120462194,
                \ 984822282, 1410505767, 2596051202,
                \ 925164684, 4128088087, 1731459018,
                \ 3564432482, 2956010699, 2625776922,
                \ 1772071325, 3772832066, 3452635844,
                \ 17915938, 3363784459, 110434362,
                \ 1036801870, 2713876602, 2353898939,
                \ 3010903463, 150968655, 1525706122,
                \ 995119979, 1575781950, 3186393603,
                \ 1724599707, 625250046, 100842630,
                \ 3470371294, 3403186595, 84508751,
                \ 3976070338, 1535071779, 3795943272,
                \ 1209798136, 3539242851, 2905027337,
                \ 3374135709, 610816198, 1207604782,
                \ 1016098245, 2049726545, 3212516948,
                \ 3148085285, 2844151550, 1452514813,
                \ 533152365, 2637021467, 1578366139,
                \ 1698860989, 822116226, 730596731,
                \ 4212425541, 1488264556, 3575938676,
                \ 3721186221, 3358645695, 137136614,
                \ 2701689036, 1531510887, 2549660908,
                \ 540347158, 2985971461, 2370727829,
                \ 2668966534, 2595318369, 441054160,
                \ 644989897, 1210402109, 107705925,
                \ 867680219, 1388944626, 1478235307,
                \ 159993396, 865498678, 2492598945,
                \ 86304370, 2975943609, 2657233677,
                \ 3517138814, 129485723, 2863513675,
                \ 973001539, 2706546254, 3039102976,
                \ 3404352853, 2341369578, 4065974737,
                \ 2147318431, 2364067879, 185996344,
                \ 2739229923, 986791140, 3935042484,
                \ 1794216917, 1476298856, 2478871602,
                \ 3122553511, 1013025040, 887743093,
                \ 2802026618, 899924400, 3973059947,
                \ 1482021191, 2481656297, 1982317134,
                \ 249761532, 1468488337, 158606065,
                \ 3025229099, 743742255, 2926518074,
                \ 468273721, 493903062, 3624893354,
                \ 3912015565, 616869623, 3756523621,
                \ 365424276, 1592606995, 3042180528,
                \ 1787103942, 3751115730, 1643737390,
                \ 2084794947, 3985092520, 3472510329,
                \ 1787692401, 2188114007, 1326124066,
                \ 3459428314, 1340594070, 3641028405,
                \ 1347866435, 2133926277, 4274294749,
                \ 4200640778, 591958799, 2723050673,
                \ 1211911690, 3518744699, 3707550806,
                \ 325758883, 2969111685, 1596360550,
                \ 2069480299, 789771377, 2555381933,
                \ 496399292, 4026554267, 3976843269,
                \ 1601135759, 1825242682, 158797316,
                \ 4233795178, 406155156, 549877519,
                \ 3277731069, 822267126, 4186661324,
                \ 642394043, 4000795209, 1270545641,
                \ 3405389492, 2764723292, 3649505930,
                \ 2000822747, 414707484, 2951997756,
                \ 3469153881, 1995508956, 1057771090,
                \ 1049257047, 3656866590, 1416023012,
                \ 2186457991, 605392506, 4001100248,
                \ 3201416542, 533133938, 3790552484,
                \ 3910087485, 562243813, 3975073013,
                \ 941237516, 2486836192, 2729112361,
                \ 3382456131, 808428685, 3637045550,
                \ 1870701240, 1834641903, 1592389821,
                \ 169669751, 3648621333, 3559186845,
                \ 4092774611, 3810451601, 1736777604,
                \ 4212009234, 3968843656, 3635215089,
                \ 1314737058, 4051074159, 2701625604,
                \ 4000052918, 3333383132, 630671063,
                \ 2852648683, 834847958, 4120586051,
                \ 903527948, 1026357023, 3255998186,
                \ 2332449355, 688118652, 2075722693,
                \ 639738863, 1188043618, 3024209546,
                \ 1855418859, 2155685534, 3652121300,
                \ 2082155408, 2930101796, 636504582,
                \ 3485589142, 2156722549, 3486019911,
                \ 2654190143, 3846877872, 1940309014,
                \ 3658548549, 2241242804, 184073761,
                \ 370507183, 3322034353, 831585927,
                \ 2467149153, 3496323396, 310389852,
                \ 1661023038, 541647581, 1421264361,
                \ 1588683621, 3977668382, 1070086248,
                \ 548535735, 2819739532, 1191103580,
                \ 221864651, 2682000363, 977990249,
                \ 1122068675, 722392936, 1014613606,
                \ 1900449672, 985014030, 65041719,
                \ 2581952046, 1799886636, 2118106023,
                \ 903113420, 1120266958, 3742188767,
                \ 1131442915, 806022385, 241392662,
                \ 499801710, 2366834845, 2385443175,
                \ 691916623, 364810420, 439400809,
                \ 2393636744, 740719830, 2393227323,
                \ 2973458932, 2168844786, 441690541,
                \ 2179459023, 2751078438, 3901926396,
                \ 1520548082, 3533698382, 584163218,
                \ 2414778878, 3213961448, 743837677,
                \ 832999633, 2624160949, 1952694679,
                \ 49748775, 2554408743, 4058383680,
                \ 2612944957, 1099604806, 2634992921,
                \ 288559484, 3427043388, 4209691710,
                \ 3562583507, 220718399, 367036714,
                \ 2304512386, 4057651320, 2991735858,
                \ 1451736917, 1205014181, 2064580315,
                \ 4149409342, 1513803351, 3145592347,
                \ 3668363202, 3796840794, 2197226496,
                \ 2571659581, 901394053, 3768579453,
                \ 1021297569, 572155636, 1746428853,
                \ 690845669, 820241493, 2955572874,
                \ 3293128338, 3456160758, 1633912136,
                \ 3848263640, 943083929, 1968684618,
                \ 47356411, 1637639596, 3173647166,
                \ 3332302371, 4213572006, 1603509884,
                \ 2383409093, 524552638, 4035598976,
                \ 3268857422, 1761233102, 4078536330,
                \ 796555667, 1647304328, 2155435380,
                \ 393679010, 2072006984, 481414814,
                \ 2645139034, 1714787831, 2427378084,
                \ 1531942932, 2588134159, 3997108492,
                \ 2492948636, 2602353141, 303023580,
                \ 2050782392, 1807241099, 1905937432,
                \ 3484277732, 121879224, 2749856809,
                \ 4291400773, 980894831, 4213284604,
                \ 587321166, 2112880812, 772296958,
                \ 1451071403, 1243976251, 664620124,
                \ 2251630694, 2096692250, 2057021302,
                \ 3814626113, 551194867, 444317992,
                \ 456088983, 1012094834, 144254613,
                \ 1831310256, 216869010, 1933095275,
                \ 451589177, 3165662931, 3982061810,
                \ 2031329264, 4154725054, 682475804,
                \ 672551862, 2001984272, 2126280458,
                \ 3668362505, 2867209028, 3703677069,
                \ 318052366, 3064404046, 2308455496,
                \ 3504713162, 389688032, 1477619459,
                \ 2738532280, 3870467502, 3279887093,
                \ 3385001095, 1220183143, 2872251732,
                \ 200701008, 955194010, 2691784164,
                \ 3089000459, 154084198, 2129276620,
                \ 3702873707, 1296767321, 2538865515,
                \ 888154678, 1211651262, 378518340,
                \ 3334223961, 193494827, 456631910,
                \ ]
    " }}}
    for i in range(len(wanted))
        let expected = wanted[i]
        let actual   = IBAA()
        if actual == expected
            continue
        endif
        throw printf('IBAA#%d: wanted %d, got %d', i, expected, actual)
    endfor
    echomsg printf('ok (%d samples)', len(wanted))
    unlet warmup
    unlet wanted
endif

" {{{ Original C code for reference.
" /*
"  * ^ means XOR, & means bitwise AND, a<<b means shift a by b.
"  * barrel(a) shifts a 19 bits to the left, and bits wrap around
"  * ind(x) is (x AND 255), or (x mod 256)
"  */
" typedef  unsigned int  u4;   /* unsigned four bytes, 32 bits */
" #define ALPHA      (8)
" #define SIZE       (1<<ALPHA)
" #define ind(x)     ((x)&(SIZE-1))
" #define barrel(a)  (((a)<<19)^((a)>>13)) /* beta=32,shift=19 */
"
" static void ibaa(m,r,aa,bb)
" u4 *m;   /* Memory: array of SIZE ALPHA-bit terms */
" u4 *r;   /* Results: the sequence, same size as m */
" u4 *aa;  /* Accumulator: a single value */
" u4 *bb;  /* the previous result */
" {
"   register u4 a,b,x,y,i;
"
"   a = *aa; b = *bb;
"   for (i=0; i<SIZE; ++i)
"   {
"     x = m[i];
"     a = barrel(a) + m[ind(i+(SIZE/2))];    /* set a */
"     m[i] = y = m[ind(x)] + a + b;          /* set m */
"     r[i] = b = m[ind(y>>ALPHA)] + x;       /* set r */
"   }
"   *bb = b; *aa = a;
" }
" }}}

