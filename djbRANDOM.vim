" https://groups.google.com/forum/?hl=en&fromgroups=#!topic/sci.physics/SWhCr8SEVWw
" TLDR: a PRNG by Dan Bernstein ported to vimscript

" The generator shown below is faster than Marsaglia's on my Pentium-100.
" It passes the Diehard tests without trouble.
"
" Use RANDOM for one 32-bit random number. Do not use RANDOM twice in one
" line. You can put a 64-bit seed into random_in[2 and 3]. The effect of
" seed m is to jump ahead by 2^68 m in a single sequence of period 2^132.
" It's easy to determine the seed from the sequence, but not with the sort
" of code that shows up in scientific and statistical applications.
"
" If you want even better speed, compile random_fill() separately with gcc
" -O0 -fomit-frame-pointer. Higher gcc optimization levels produce worse
" code. (``Real programmers use asm.'')
"
" ---Dan

if 0x7fffffff <= 0 || 0x7fffffff+1 >= 0
    " Vim uses plain C signed int's (long if <32 bits);
    " hence it's usually 32 bits everywhere.
    echoerr 'this RNG requires 32 bit arithmetic!'
    finish
endif

" Shifts are hard-coded in range 5-13; plus 32-shift, hence up to 27.
" >= 31 would be annoying.
let s:powerof2 = [
            \ 0x1, 0x2, 0x4, 0x8,
            \ 0x10, 0x20, 0x40, 0x80,
            \ 0x100, 0x200, 0x400, 0x800,
            \ 0x1000, 0x2000, 0x4000, 0x8000,
            \ 0x10000, 0x20000, 0x40000, 0x80000,
            \ 0x100000, 0x200000, 0x400000, 0x800000,
            \ 0x1000000, 0x2000000, 0x4000000, 0x8000000,
            \ ]

function! s:leftshift(x, offset)
    return a:x * s:powerof2[a:offset]
endfunction
function! s:rightshift(x, offset)
    if a:offset == 0
        return a:x
    endif
    if a:x < 0
        " Debian Squeeze ships a Vim without and/or/xor. Sorry guys.
        let x = and(a:x, 0x7fffffff)    " shift the sign bit
        let x = x / 2
        let x = or(x,    0x40000000)    " readd the sign bit (shifted)
        return s:rightshift(x, a:offset - 1)
    endif
    return a:x / s:powerof2[a:offset]
endfunction

function! s:ROTATE(x, b)
    return or(s:leftshift(a:x, a:b), s:rightshift(a:x, 32 - a:b))
endfunction

function! s:foobar(state, xy, nbits, idx, sum)
    "let x = ROTATE(x,5) |  x^=y | y=random_t[0] |  x+=y | y=sum | random_t[0] =x | y+=x
    let x = a:xy[0]
    let y = a:xy[1]
    let x = s:ROTATE(x, a:nbits)
    let x = xor(x, y)
    let y = a:state.t[a:idx]
    let x += y
    let y = a:sum
    let a:state.t[a:idx] = x
    let y += x
    let a:xy[0] = x
    let a:xy[1] = y
endfunction

function! s:random_fill(state)
    "register uint32 y, x = 0, sum = 0
    " No need to worry about signed/unsigned: all that matters is that
    " the operations performed on them result in the same bits of output.
    let y = 1234 | let x = 0 | let sum = 0
    for i in range(16)
        let a:state.t[i] = 0
    endfor
    for i in [0,4,8,12]
        let a:state.t[i] = a:state.in[i/4]
    endfor
    let s = a:state
    for rounds in range(3)
        let sum += 0x9e3779b9 | let y=x | let y+=sum
        let xy = [x,y]
        " loop unrolling ftw!
        call s:foobar(s, xy, 5,  0,  sum)
        call s:foobar(s, xy, 7,  1,  sum)
        call s:foobar(s, xy, 9,  2,  sum)
        call s:foobar(s, xy, 13, 3,  sum)
        call s:foobar(s, xy, 5,  4,  sum)
        call s:foobar(s, xy, 7,  5,  sum)
        call s:foobar(s, xy, 9,  6,  sum)
        call s:foobar(s, xy, 13, 7,  sum)
        call s:foobar(s, xy, 5,  8,  sum)
        call s:foobar(s, xy, 7,  9,  sum)
        call s:foobar(s, xy, 9,  10, sum)
        call s:foobar(s, xy, 13, 11, sum)
        call s:foobar(s, xy, 5,  12, sum)
        call s:foobar(s, xy, 7,  13, sum)
        call s:foobar(s, xy, 9,  14, sum)
        "ROTATE(x,9);  x^=y; y=random_t[14]; x+=y; y=sum; random_t[14]=x; y+=x;
        let x = xy[0] | let y = xy[1]
        "ROTATE(x,13); x^=y; y=random_t[15]; x+=y; random_t[15] = x;
        let x = s:ROTATE(x,13) | let x = xor(x, y) | let y=s.t[15] | let x+=y
        let s.t[15] = x
    endfor
    " if (!++random_in[0]) if (!++random_in[1]) if (!++random_in[2]) ++random_in[3]
    let s.in[0] += 1
    if !s.in[0]
        let s.in[1] += 1
        if !s.in[1]
            let s.in[2] += 1
            if !s.in[2]
                let s.in[3] += 1
            endif
        endif
    endif
    let a:state.pos = 15
    return a:state.t[15]
endfunction

" You can give a seed or two if you wish:
"   RANDOM_seed()
"   RANDOM_seed(          localtime())
"   RANDOM_seed(getpid(), localtime())
" XXX djb only uses random_in[2,3] because they jump a longer distance
"  -- one could also use random_in[0,1]
function! RANDOM_seed(...)
    let random_in = [0,0,0,0]
    if a:0 > 4
        throw '$# > 4'
    endif
    if a:0 == 0
        let random_in[2] = getpid()
        let random_in[3] = localtime()
    else    " one seed => random_in[3]
        for i in range(len(a:000))
            let random_in[3-i] = a:000[i]
        endfor
    endif
    let prng = {}
    let prng.in = random_in
    let prng.t = repeat([0], 16)
    let prng.pos = 0
    let s:prng = prng
endfunction

function! RANDOM()
    if s:prng.pos > 0
        let s:prng.pos -= 1
        return s:prng.t[s:prng.pos]
    endif
    return s:random_fill(s:prng)
endfunction

if len($DEBUG) > 0
    " There used to be a stupid bug in s:rightshift
    " Overflowing 2G is ok here.
    let expected = [
                \ 2418795960, 3003258757, 151880706, 3215773290,
                \ 513313070, 3657817576, 208155427, 3566403919,
                \ 1539252833, 318396758, 2608091252, 3668097793,
                \ 2254643236, 1130049323, 1880154880, 2419921727,
                \ 2754539177, 258988989, 2664258628, 462086491,
                \ 3366175608, 3441317232, 2596750669, 1208093774,
                \ 2763004728, 1748815996, 3549270765, 1323780817,
                \ 1122145413, 1637054897, 2757387850, 227111478,
                \ 3853466287, 364384882, 2116932039, 532721731,
                \ ]
    call RANDOM_seed(0,0)
    for i in range(len(expected))
        let got = RANDOM()
        if got == expected[i]
            continue
        endif
        echoerr printf("%d RANDOM.c says %d, .vim %d", i, expected[i], got)
    endfor
    unlet expected
    echomsg "tested ok"
else
    call RANDOM_seed()
endif
