" http://burtleburtle.net/bob/rand/smallprng.html
" A small noncryptographic PRNGa by Bob Jenkins;
" public domain.

let s:INT_MAX = -1      " will be overwritten
let s:NSB = 0x40000000  " Next Significant Bit ;p

" {{{ Vimscript lacks bit shifts...
let s:powerof2 = [1]
while 1 > 0
    let x = 2 * s:powerof2[len(s:powerof2)-1]
    if x <= 0
        break
    endif
    let s:powerof2 += [x]
endwhile
function! s:rightshift(x, nbits)
    if a:nbits == 0
        return a:x
    endif
    if a:x < 0
        " The sign bit would be cleared anyway
        let x = a:x + s:INT_MAX + 1
        let x = x / 2   " Argh! I missed this line!
        let x = or(x, s:NSB)
        return s:rightshift(x, a:nbits - 1)
    endif
    return a:x / s:powerof2[a:nbits]
endfunction
function! s:leftshift(x, nbits)
    return a:x * s:powerof2[a:nbits]
endfunction
" }}}

let s:INT32_MAX = 0x7fffffff
let s:INT64_MAX = 0x7fffffffffffffff
let s:testseed = 12345


" 'The fastest small unbiased noncryptographic PRNG that I could find'
if s:INT32_MAX > 0 && s:INT32_MAX+1 < 0
    let s:INT_MAX = s:INT32_MAX
    let s:expected = [
                \ 639134590, 358813179, 1271789997, 2905678157, 513685281,
                \ 3054902804, 2845333787, 2508307947, 3451467843
                \ ]
    "typedef struct ranctx { u4 a; u4 b; u4 c; u4 d; } ranctx

    "#define rot(x,k) (((x)<<(k))|((x)>>(32-(k))))
    function! s:rot(x, k)
        let a = s:leftshift(a:x, a:k)
        let b = s:rightshift(a:x, 32 - a:k)
        return or(a, b)
    endfunction
    function Ranval(x)
        " 10k in ~2 seconds!
        " $ grep Hz /proc/cpuinfo
        " cpu MHz		: 1800.000
        let x = a:x
        let e = x.a - s:rot(x.b, 27)
        let x.a = xor(x.b, s:rot(x.c, 17))
        let x.b = x.c + x.d
        let x.c = x.d + e
        let x.d = e + x.a
        return x.d
    endfunction

    function! s:raninit(x, seed)
        let x = a:x
        let x.a = 0xf1ea5eed
        let x.b = a:seed | let x.c = a:seed | let x.d = a:seed
        for i in range(20)
            call Ranval(x)
        endfor
    endfunction


elseif s:INT64_MAX > 0 && s:INT64_MAX+1 < 0 " 64 bits
    let s:INT_MAX = s:INT64_MAX
    let s:expected = [
                \ 8366559432958802373,
                \ 12716083930207378436,
                \ 15593292340433450964,
                \ 3153763237479697831,
                \ 3315216031252466201,
                \ 327484848147684404,
                \ 9606697960016685836,
                \ 11188217450915011923,
                \ 5113990650165285849
                \ ]
    " '''
    " I don't think that there's an 8-byte rotate instruction on any 64-bit
    " platform. And you only need 2 terms to get to 128 bits of internal state
    " if you have 64-bit terms. Quite likely 64-bit deserves a whole different
    " approach, not just different constants.
    " '''
    if len($NDEBUG) == 0 | echomsg "vim's integers are 64 bits" | endif
    echoerr "XXX untested"
    "typedef struct ranctx { u8 a; u8 b; u8 c; u8 d; } ranctx

    " #define rot(x,k) (((x)<<(k))|((x)>>(64-(k))))
    function! s:rot(x, k)
        let a = s:leftshift(a:x, a:k)
        let b = s:rightshift(a:x, 64 - a:k)
        return or(a, b)
    endfunction
    function! Ranval(x)
        " 64 bits, untested
        let x = a:x
        let e = x.a - s:rot(x.b, 7)
        let x.a = xor(x.b, s:rot(x.c, 13))
        let x.b = x.c + s:rot(x.d, 37)
        let x.c = x.d + e
        let x.d = e + x.a
        return x.d
    endfunction

    function! s:raninit(x, seed)    " sounds familiar?
        let x = a:x
        let x.a = 0xf1ea5eed
        let x.b = a:seed | let x.c = a:seed | let x.d = a:seed
        for i in range(20)
            call Ranval(x)
        endfor
    endfunction

else
    throw "Neither 32 bits nor 64?"
endif


let s:NSB = s:INT_MAX / 2 + 1
if and(s:NSB, s:NSB-1)
    throw printf("assertfail: NSB has more than a bit set (%x)", s:NSB)
endif
lockvar s:INT_MAX   " paranoia(1)
lockvar s:NSB       " paranoia(2)

" seed with raninit(), or there are cycles of length 1!
" XXX one of them is obvious XD
function Raninit(seed)
    let x = {}
    let x.a = 0 | let x.b = 0 | let x.c = 0 | let x.d = 0
    call s:raninit(x, a:seed)
    return x
endfunction

if len($DEBUG) > 0
    " Check it produces the same results as the C version
    let prng = Raninit(s:testseed)
    for i in range(len(s:expected))
        let x = Ranval(prng)
        if s:expected[i] == x
            continue
        endif
        throw printf("sample[%d]: wanted %d, got %d", i, s:expected[i], x)
    endfor
    echomsg "smallprng test ok"
    unlet i prng
endif
unlet s:testseed s:expected
