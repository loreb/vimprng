" djbdns-1.05/dns_random.c
" '''
" 2007.12.28: I hereby place the djbdns package (in particular,
" djbdns-1.05.tar.gz, with MD5 checksum 3147c5cd56832aa3b41955c7a51cbeb2) into
" the public domain. The package is no longer copyrighted.
" '''
" [http://cr.yp.to/distributors.html]



" All the variables are uint32
if 0x7fffffff <= 0 || 0x7fffffff+1 >= 0
    throw 'uint32'
endif

" Bitwise righ/left shift; the shifts are hardcoded (5,7,9,13).
let s:p2 = [
            \ 0x1,          0x2,        0x4,        0x8,
            \ 0x10,         0x20,       0x40,       0x80,
            \ 0x100,        0x200,      0x400,      0x800,
            \ 0x1000,       0x2000,     0x4000,     0x8000,
            \ 0x10000,      0x20000,    0x40000,    0x80000,
            \ 0x100000,     0x200000,   0x400000,   0x800000,
            \ 0x1000000,    0x2000000,  0x4000000,  0x8000000,
            \ ]
function! s:leftshift(x, b)
    return a:x * s:p2[a:b]
endfunction

function! s:rightshift(x, b)
    if a:x < 0
        let s1 = or(0x40000000, and(0x7fffffff, a:x) / 2)
        return s:rightshift(s1, a:b - 1)
    endif
    return a:x / s:p2[a:b]
endfunction

" The basic idea is that IN is a counter of 12 digits base 2^32,
" initialized via the system clock, and SEED encrypts it to produce OUT.
let s:seed = range(32)
let s:in = range(12)
let s:out = range(8)
let s:outleft = 0

function! s:ROTATE(x,b)
    return or(s:leftshift(a:x, a:b), s:rightshift(a:x, 32 - a:b))
endfunction

"#define MUSH(i,b) x = t[i] += (((x ^ seed[i]) + sum) ^ ROTATE(x,b));
function! s:MUSH(i, b)
    let tmp = xor(s:x, s:seed[a:i]) + s:sum
    let s:t[a:i] += xor(tmp, s:ROTATE(s:x, a:b))
    let s:x = s:t[a:i]
endfunction

" http://cr.yp.to/papers/surf.pdf
function! s:surf()
    let t = range(12)
    let sum = 0

    for i in range(12)
        let t[i] = xor(s:in[i], s:seed[12 + i])
    endfor
    for i in range(8)
        let s:out[i] = s:seed[24 + i]
    endfor
    let s:x = t[11]     " need a few globals to work around C macros
    let s:t = t
    for loop in range(2)
        for r in range(16)
            let sum += 0x9e3779b9
            let s:sum = sum
            " TODO is loop unrolling convenient in vimscript?
            call s:MUSH(0,5) | call s:MUSH(1,7) | call s:MUSH(2,9) | call s:MUSH(3,13)
            call s:MUSH(4,5) | call s:MUSH(5,7) | call s:MUSH(6,9) | call s:MUSH(7,13)
            call s:MUSH(8,5) | call s:MUSH(9,7) | call s:MUSH(10,9) | call s:MUSH(11,13)
        endfor
        for i in range(8)
            let s:out[i] = xor(s:out[i], t[i + 4])
        endfor
    endfor
    unlet s:x | unlet s:t | unlet s:sum
endfunction

function! s:uint32_unpack(s, idx)
    let result = a:s[a:idx + 3]
    for i in range(3)
        let result = result * 256
        let result = a:s[a:idx + 3-i]
    endfor
    return result
endfunction

" void dns_random_init(const char data[128])
function! DnsRandomInit(data)
    for byte in a:data
        if byte < 0 || byte > 255
            throw string(byte) . " should be a byte"
        endif
    endfor

    for i in range(32)
        let s:seed[i] = s:uint32_unpack(a:data, 4 * i)
    endfor

    " djb uses a taia, ie a 16-bit timestamp with nanosecond precision;
    " localtime() is just fine, but it implies that this function
    " gives different results depending on the system clock (testing!)
    for i in range(len(s:in))
        let s:in[i] = localtime()
    endfor
    let s:in[8] = getpid()
    " let s:in[9] = getppid()
    " /* more space s:in 10 and 11, but this is probably enough */
endfunction

" The C version is a bit slow, but still acceptable;
" in vimscript it's slow as hell (~400x slower than Xkcd221 on my machine!),
" thus making it the slowest PRNG of the bunch as of 20130802.
function! DnsRandom()
    if s:outleft == 0
        " XXX This looks like a shortcut by djb: he assumes that s:in[]
        " XXX will not need to be incremented beyond s:in[3],
        " XXX ie we will not surf() more than 2^128 times.
        "if (!++s:in[0]) if (!++s:in[1]) if (!++s:in[2]) ++s:in[3];
        for i in range(12)
            let s:in[i] += 1
            if s:in[i] != 0
                break
            endif
        endfor
        call s:surf()
        let s:outleft = 8
    endif
    let s:outleft -= 1
    return s:out[s:outleft]
endfunction

if len($DEBUG) > 0
    " call DnsRandomInit(testbytes)
    for i in range(len(s:in))
        let s:in[i] = 0
    endfor
    let s:in[0] = 1
    let s:in[1] = 9
    let s:in[2] = 7
    let s:in[3] = 0
    for i in range(len(s:seed))
        let s:seed[i] = i
    endfor
    let s:outleft = 0
    let wanted = [
                \ 731813691,
                \ 3354706272,
                \ 614653646,
                \ 2748364814,
                \ 1848148993,
                \ 2167701255,
                \ 2945658913,
                \ 2710565683,
                \ 916237162,
                \ 1804826917,
                \ 3133563342,
                \ 3796574975,
                \ 1430609941,
                \ 1262885842,
                \ 2796433958,
                \ 1539554801,
                \ 1363204192,
                \ 1422263581,
                \ 3368981480,
                \ 1386189323,
                \ 2220632090,
                \ 3020104515,
                \ 306912488,
                \ 2305735004,
                \ 1188490396,
                \ 3597091892,
                \ 4093313311,
                \ 2773820894,
                \ 489794302,
                \ 1423159923,
                \ 3098307201,
                \ 1032845006,
                \ 1388984481,
                \ 4157113262,
                \ 2317300142,
                \ 3155788332,
                \ 2667094538,
                \ 31505514,
                \ 3439882868,
                \ 16613202,
                \ 2992611973,
                \ 2900754618,
                \ 176416312,
                \ 2472444947,
                \ 2227121757,
                \ 958854850,
                \ 1173018532,
                \ 2084822637,
                \ 2780169426,
                \ 3323090401,
                \ 4270981348,
                \ 3039397697,
                \ 2600003729,
                \ 3623620346,
                \ 382870429,
                \ 2240402290,
                \ 3658095688,
                \ 2775245613,
                \ 3473193322,
                \ 2560141771,
                \ 562226489,
                \ 2361972073,
                \ 1195847886,
                \ 3753181943,
                \ 648503195,
                \ 3994784622,
                \ 2584701009,
                \ 337529205,
                \ 1139611792,
                \ 461168100,
                \ 681851009,
                \ 2740505019,
                \ 1545773287,
                \ 2848146380,
                \ 3469488761,
                \ 1956215387,
                \ 2180945900,
                \ 278473269,
                \ 3091809131,
                \ 3911059301,
                \ 3009486683,
                \ 1375717359,
                \ 1324284474,
                \ 1094407823,
                \ 165458011,
                \ 95971455,
                \ 4177976263,
                \ 494352578,
                \ 3021258809,
                \ 3564747785,
                \ 1676827970,
                \ 205504752,
                \ 674551407,
                \ 4278247991,
                \ 1700308690,
                \ 3589956052,
                \ 163133783,
                \ 2335492027,
                \ 414147790,
                \ 22053965,
                \ 3887142353,
                \ 1868744846,
                \ 1169830354,
                \ 833640852,
                \ 34335458,
                \ 653450551,
                \ 1217982981,
                \ 2343393590,
                \ 1432896503,
                \ 1201102262,
                \ 3455744708,
                \ 2611859997,
                \ 909710782,
                \ 2487193564,
                \ 2831021812,
                \ 900135619,
                \ 1930486957,
                \ 1197600727,
                \ 1052378478,
                \ 1958567258,
                \ 3356622518,
                \ 1618840501,
                \ 3057022780,
                \ 311375174,
                \ 4079741369,
                \ 653908630,
                \ 1584503555,
                \ 1950742055,
                \ 2089518559,
                \ 2734911782,
                \ 4022035747,
                \ 3431449039,
                \ 143757450,
                \ 1115696477,
                \ 4207875562,
                \ 3607886809,
                \ 216417174,
                \ 3190816369,
                \ 1148479176,
                \ 4183244486,
                \ 1725980943,
                \ 3747078667,
                \ 1723173934,
                \ 1262433683,
                \ 187451183,
                \ 4164520629,
                \ 2928901139,
                \ 293798108,
                \ 932899459,
                \ 1333181039,
                \ 2894410785,
                \ 101450214,
                \ 993611550,
                \ 2057176262,
                \ 2437251246,
                \ 21171287,
                \ 1354662686,
                \ 3672116877,
                \ 1529827357,
                \ 4191337719,
                \ 1762084723,
                \ 1743696213,
                \ 2989873639,
                \ 4099885922,
                \ 1124424718,
                \ 3802976620,
                \ 3333329275,
                \ 4293384763,
                \ 4226733747,
                \ 3642011123,
                \ 1357284251,
                \ 2176904279,
                \ 2194316599,
                \ 1081905556,
                \ 1412182612,
                \ 3036644894,
                \ 3798454490,
                \ 4286878007,
                \ 3125172314,
                \ 266733521,
                \ 4115295146,
                \ 2169453798,
                \ 2365472458,
                \ 2918551359,
                \ 2612526495,
                \ 260401451,
                \ 2635596901,
                \ 2027313603,
                \ 1752182572,
                \ 1479593745,
                \ 261047601,
                \ 2791781373,
                \ 2269423362,
                \ 3593414085,
                \ 1289004824,
                \ 2806189557,
                \ 388754245,
                \ 2371743241,
                \ 3301353976,
                \ 4087508276,
                \ 2774768578,
                \ 2316065452,
                \ 1892762301,
                \ 890938617,
                \ 2808361505,
                \ 1578400687,
                \ 3733123268,
                \ 188039448,
                \ 648429197,
                \ 2516744311,
                \ 3510720533,
                \ 2756435827,
                \ 4227179308,
                \ 2498491992,
                \ 1253508946,
                \ 1869401633,
                \ 1455164682,
                \ 4221910759,
                \ 376418751,
                \ 2121008468,
                \ 769884444,
                \ 3015476237,
                \ 1484358953,
                \ 164466089,
                \ 686954153,
                \ 4058051982,
                \ 528109861,
                \ 2547335537,
                \ 1989357284,
                \ 403079822,
                \ 1943581096,
                \ 202789932,
                \ 3442173812,
                \ 1263741411,
                \ 2874321676,
                \ 3047998607,
                \ 93943659,
                \ 3441356203,
                \ 3764187212,
                \ 1597474800,
                \ 2709564900,
                \ 3061847089,
                \ 2973794291,
                \ 3442305640,
                \ 2399868980,
                \ 2871225523,
                \ 2117570483,
                \ 2577088907,
                \ 3951016822,
                \ 178270021,
                \ 622353022,
                \ 3520431547,
                \ 3924637952,
                \ 1649695864,
                \ 1375195637,
                \ 3037475776,
                \ 2933632552,
                \ ]
    for i in range(len(wanted))
        let x = DnsRandom()
        let y = wanted[i]
        if x == y
            continue
        endif
        throw printf("@%i want %d, got %d", i, y, x)
    endfor
    echomsg 'dns_random() works the same as the C version'
    unlet wanted x y
else
    let V = string(getpid()) . string(v:) . string(b:) . reltimestr(reltime())
    let b = range(128)
    for i in range(len(V))
        let b[i % 128] += char2nr(V[i])
    endfor
    for i in range(128)
        let b[i] = and(0xff, b[i])
    endfor
    call DnsRandomInit(b)
    unlet V b
endif


