
" dietlibc/lib/rand48.c
" XXX It's important, different implementations give different results(!)
" XXX This is especially awful since POSIX specifies exactly how these
" XXX functions work...
function! s:right16(n)
    if a:n < 0
        return or(0x40000000, and(0x7fffffff, a:n)/2) / 0x8000
    endif
    return a:n / 0x10000
endfunction

" typedef unsigned short randbuf[3]
let s:rand48buf = [1,2,3]
let s:A_0       = 0xE66D
let s:A_1       = 0xDEEC
let s:A_2       = 0x5
let s:C         = 0xB
let s:a         = [ s:A_0, s:A_1, s:A_2 ]
let s:c         = s:C

function! s:calc_next(buf)
    let buf = a:buf
    let tmp = [1,2,3]
    let t = buf[0] * s:a[0] + s:c
    let tmp[0] = and(t, 0xffff)
    let tmp[1] = and(s:right16(t), 0xffff)
    let t = buf[1] * s:a[0] + buf[0] * s:a[1] + tmp[1]
    let tmp[1] = and(t, 0xffff)
    let tmp[2] = and(s:right16(t), 0xffff)
    let t = buf[2] * s:a[0] + buf[1] * s:a[1] + buf[0] * s:a[2] + tmp[2]
    let tmp[2] = and(t, 0xffff)
    let buf[0] = tmp[0]
    let buf[1] = tmp[1]
    let buf[2] = tmp[2]
endfunction

function! Drand48()
    return Erand48(s:rand48buf)
endfunction

function! Lrand48()
    return Nrand48(s:rand48buf)
endfunction

function! Mrand48()
    return Jrand48(s:rand48buf)
endfunction

" FIXME either check range (uint16) or prove it doesn't matter!
function! Srand48(seed)
    let s:rand48buf[1] = and(s:right16(a:seed), 0xffff)
    let s:rand48buf[2] = and(a:seed, 0xffff)
    let s:rand48buf[0] = 0x330e
    let s:a[0] = s:A_0
    let s:a[1] = s:A_1
    let s:a[2] = s:A_2
    let s:c = s:C
endfunction

function! Seed48(buf)
    if len(a:buf) != 3
        throw 'unsigned short buf[3]'
    endif
    let buf = a:buf
    let oldx = [1,2,3]
    for i in range(3)
        let oldx[i] = s:rand48buf[i]
        let s:rand48buf[i] = buf[i]
    endfor
    let s:a[0] = s:A_0
    let s:a[1] = s:A_1
    let s:a[2] = s:A_2
    let s:c = s:C
    return oldx
endfunction

function! Lcong48(param)
    if len(param) != 7
        throw 'unsigned short param[7]'
    endif
    for i in range(3)
        let s:rand48buf[i] = a:param[i]
        let s:a[i] = param[i + 3]
    endfor
    let s:c = param[6]
endfunction

function! Jrand48(buf)
    let buf = a:buf
    "ret = buf[2] << 16 | buf[1]
    let ret = or(buf[2] * 0x10000, buf[1])
    call s:calc_next(buf)
    return ret
endfunction

function! Nrand48(buf)
    return and(Jrand48(a:buf), 0x7FFFFFFF)
endfunction

function! Erand48(buf)
    let buf = a:buf
    let ret = ((buf[0] / 65536.0 + buf[1]) / 65536.0 + buf[2]) / 65536.0
    call s:calc_next(buf)
    return ret
endfunction

function! s:abserror(x, y)
    if a:x < a:y
        return s:abserror(a:y, a:x)
    endif
    if a:y < 0
        throw '< 0'
    endif
    return (a:x - a:y) / a:x
endfunction
function! s:SameDoublesAsC(fun, expected)
    " This function sucks, but it's good enough for my purposes.
    let F = function(a:fun)
    for i in range(len(a:expected))
        let x = F()
        if x == a:expected[i]
            continue
        endif
        if s:abserror(x, a:expected[i]) < 0.001
            continue
        endif
        throw printf("#%d: %s %f vs %f", i, a:fun, x, a:expected[i])
    endfor
endfunction
function! s:SameIntsAsC(fun, expected)
    let F = function(a:fun)
    for i in range(len(a:expected))
        let x = F()
        if x == a:expected[i]
            continue
        endif
        throw printf("#%d %s=%d, wanted %d", i, a:fun, x, a:expected[i])
    endfor
endfunction
if len($DEBUG) > 0
    " Test C conformance
    let origseed = Seed48([1,2,3])
    let myseed = [1234, 5678, 9012]
    let mrand48 = [ 590616110, 1003444100, 643887102, 1803712700, 2094363317,
                \ -320616573, 738821937, 1226386392, 2129450465, -1323928369,
                \ ]
    let lrand48 = [ 590616110, 1003444100, 643887102, 1803712700, 2094363317,
                \   1826867075, 738821937, 1226386392, 2129450465, 823555279,
                \ ]
    let drand48 = [ 0.137514, 0.233633, 0.149917, 0.419960, 0.487632,
                \   0.925351, 0.172020, 0.285540, 0.495801, 0.691749,
                \ ]
    call Seed48(myseed) | call s:SameDoublesAsC('Drand48', drand48)
    call Seed48(myseed) | call s:SameIntsAsC('Lrand48', lrand48)
    call Seed48(myseed) | call s:SameIntsAsC('Mrand48', mrand48)
    echomsg '[dlm]rand38(3) are equivalent to their C counterparts'
    " Restore default seed
    call Seed48(origseed)
    unlet origseed myseed mrand48 lrand48
endif
delfunction s:SameDoublesAsC
delfunction s:SameIntsAsC
delfunction s:abserror

