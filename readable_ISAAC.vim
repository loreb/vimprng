" http://www.burtleburtle.net/bob/c/readable.c
" ----------------------------------------------------------------------------
" readable.c: My random number generator, ISAAC.
" (c) Bob Jenkins, March 1996, Public Domain
" You may use this code in any way you wish, and it is free.  No warrantee.
" * May 2008 -- made it not depend on standard.h
" ----------------------------------------------------------------------------

" /* a ub4 is an unsigned 4-byte quantity */
" typedef uint32_t ub4
if 0x7fffffff <= 0 || 0x7fffffff+1 >= 0
    throw '32 bits -- TODO 64 bits?'
endif

" Shift 32 bit numbers left/right {{{
let s:pow2 = [
            \ 0x1, 0x2, 0x4, 0x8,
            \ 0x10, 0x20, 0x40, 0x80,
            \ 0x100, 0x200, 0x400, 0x800,
            \ 0x1000, 0x2000, 0x4000, 0x8000,
            \ 0x10000, 0x20000, 0x40000, 0x80000,
            \ 0x100000, 0x200000, 0x400000, 0x800000,
            \ 0x1000000, 0x2000000, 0x4000000, 0x8000000,
            \ 0x10000000, 0x20000000, 0x40000000
            \ ]
function! s:rightshift(x, n)
    if a:n == 0
        return a:x
    endif
    if a:x < 0
        " shift 1 manually ==> make positive
        let y = or(0x40000000, and(a:x, 0x7fffffff) / 2)
        return s:rightshift(y, a:n-1)
    endif
    return a:x / s:pow2[a:n]
endfunction

function! s:leftshift(x, n)
    return a:x * s:pow2[a:n]
endfunction
" }}}

" /* external results */
" ub4 randrsl[256], randcnt
let s:randrsl = repeat([0], 256) | let s:randcnt = 0

" /* internal state */
let s:mm = repeat([0], 256)
let s:aa = 0 | let s:bb = 0 | let s:cc = 0

function! s:isaac()
    " register ub4 i, x, y

    let s:cc += 1       " /* cc just gets incremented once per 256 results */
    let s:bb += s:cc    " /* then combined with bb */

    for i in range(256)
        let x = s:mm[i]
        let i4 = i%4
        if i4 == 0
            let s:aa = xor(s:aa, s:leftshift(s:aa, 13))
        elseif i4 == 1
            let s:aa = xor(s:aa, s:rightshift(s:aa, 6))
        elseif i4 == 2
            let s:aa = xor(s:aa, s:leftshift(s:aa, 2))
        else
            let s:aa = xor(s:aa, s:rightshift(s:aa, 16))
        endif
        let s:aa = s:mm[(i + 128) % 256] + s:aa
        let y =  s:mm[s:rightshift(x, 2) % 256] + s:aa + s:bb | let s:mm[i] = y
        let s:bb = s:mm[s:rightshift(y, 10) % 256] + x | let s:randrsl[i] = s:bb

        " /* Note that bits 2..9 are chosen from x but 10..17 are chosen
        "    from y.  The only important thing here is that 2..9 and 10..17
        "    don't overlap.  2..9 and 10..17 were then chosen for speed in
        "    the optimized version (rand.c) */
        " /* See http://burtleburtle.net/bob/rand/isaac.html
        "    for further explanations and analysis. */
    endfor
endfunction


" /* if (flag!=0), then use the contents of randrsl[] to initialize mm[]. */
" Vim: structs are faked with hashtables + syntactic sugar (sounds familiar);
" Vim: microbenchmark says structs are ~10% slower than variable name lookup.
" #define mix(a,b,c,d,e,f,g,h) \
function! s:mix(x)
    let x = a:x
    let x.a = xor(x.a, s:leftshift(x.b,11))  | let x.d+=x.a | let x.b+=x.c
    let x.b = xor(x.b, s:rightshift(x.c,2))  | let x.e+=x.b | let x.c+=x.d
    let x.c = xor(x.c, s:leftshift(x.d,8))   | let x.f+=x.c | let x.d+=x.e
    let x.d = xor(x.d, s:rightshift(x.e,16)) | let x.g+=x.d | let x.e+=x.f
    let x.e = xor(x.e, s:leftshift(x.f,10))  | let x.h+=x.e | let x.f+=x.g
    let x.f = xor(x.f, s:rightshift(x.g,4))  | let x.a+=x.f | let x.g+=x.h
    let x.g = xor(x.g, s:leftshift(x.h,8))   | let x.b+=x.g | let x.h+=x.a
    let x.h = xor(x.h, s:rightshift(x.a,9))  | let x.c+=x.h | let x.a+=x.b
endfunction

function! s:randinit(flag)  " int flag -- in vim, 'y' evaluates to zero.
    " ub4 a, b, c, d, e, f, g, h
    let s:aa = 0 | let s:bb = 0 | let s:cc = 0
    " a = b = c = d = e = f = g = h = 0x9e3779b9; /* the golden ratio */
    let x = {}  " see s:mix()
    for field in  [ 'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h' ]
        let x[field] = 0x9e3779b9   " /* the golden ratio */
    endfor

    for i in range(4)   " /* scramble it */
        " mix(a, b, c, d, e, f, g, h)
        call s:mix(x)
    endfor

    " Vim's range() is such a mess...
    let i = 0
    while i < 256
    " for (i = 0; i < 256; i += 8) {      /* fill in mm[] with messy stuff */
        if a:flag   "               /* use all the information in the seed */
            let x.a += s:randrsl[i]
            let x.b += s:randrsl[i + 1]
            let x.c += s:randrsl[i + 2]
            let x.d += s:randrsl[i + 3]
            let x.e += s:randrsl[i + 4]
            let x.f += s:randrsl[i + 5]
            let x.g += s:randrsl[i + 6]
            let x.h += s:randrsl[i + 7]
        endif
        call s:mix(x)
        let s:mm[i] = x.a
        let s:mm[i + 1] = x.b
        let s:mm[i + 2] = x.c
        let s:mm[i + 3] = x.d
        let s:mm[i + 4] = x.e
        let s:mm[i + 5] = x.f
        let s:mm[i + 6] = x.g
        let s:mm[i + 7] = x.h
        let i += 8
    endwhile

    if a:flag " /* do a second pass to make all of the seed affect all of mm */
        let i = 0
        while i < 256
            let x.a += s:mm[i]
            let x.b += s:mm[i + 1]
            let x.c += s:mm[i + 2]
            let x.d += s:mm[i + 3]
            let x.e += s:mm[i + 4]
            let x.f += s:mm[i + 5]
            let x.g += s:mm[i + 6]
            let x.h += s:mm[i + 7]
            call s:mix(x) " (a, b, c, d, e, f, g, h)
            let s:mm[i] = x.a
            let s:mm[i + 1] = x.b
            let s:mm[i + 2] = x.c
            let s:mm[i + 3] = x.d
            let s:mm[i + 4] = x.e
            let s:mm[i + 5] = x.f
            let s:mm[i + 6] = x.g
            let s:mm[i + 7] = x.h
            let i += 8
        endwhile
    endif

    call s:isaac()              " /* fill in the first set of results */
    let s:randcnt = 256         " /* prepare to use the first set of results */
endfunction

" Pass an array with 256 ints, or no argument for default seed.
function! Randinit(...)
    if a:0 > 1
        throw 'Randinit(seed[256])'
    endif
    if a:0 == 0
        call s:randinit(0)
    else
        let a = a:1
        if len(a) != 256
            throw printf("seed[%d]", len(a))
        endif
        for i in range(len(a))
            let s:randrsl[i] = a[i]
        endfor
        call s:randinit(1)
    endif
endfunction

" $ grep Hz /proc/cpuinfo
" cpu MHz		: 1800.000
" 10k calls in just above 2 seconds.
function! RandIsaac()
    " The original API is to expose randrsl and randcnt;
    " I prefer returning single integers.
    if s:randcnt == 0
        call s:isaac()
        let s:randcnt = 256
    endif
    let s:randcnt -= 1
    return s:randrsl[s:randcnt]
endfunction

if len($DEBUG) > 0
    " This must output the same string as readable.c -- ok.
    let s:aa = 0 | let s:bb = 0 | let s:cc = 0
    for i in range(256)
        let s:mm[i] = 0
        let s:randrsl[i] = 0
    endfor
    call s:randinit(1)
    for i in range(2)
        call s:isaac()
        let h = ''
        for j in range(256)
            " let h .= printf("%.8lx", s:randrsl[j])
            let h .= printf("%.8x", s:randrsl[j])
            if and(j, 7) == 7
                echomsg h
                let h = ''
            endif
        endfor
        if len(h) > 0
            throw 'bug!'
        endif
    endfor
else
    " Seed!
    call s:randinit(0)
endif

