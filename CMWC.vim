" 32 bit MWC/CMWC
" http://www.jmasm.com/journal/2003_vol2_no1.pdf
" http://interstat.statjournals.net/YEAR/2005/articles/0510005.pdf
" (xorshift on TODO list)

" This only exists because after trying to replicate myself Prof Marsaglia's
" efforts to write a 32(64) bits [C]MWC without resorting to 64(128) bit
" unsigned integers I wanted to see how ugly it could be to fake uint64_t
" using vim's int32 to generate a random uint32.
" If you **have** 64 bits, you definitely shouldn't be using this.
if 0x7fffffff <= 0 || 0x7fffffff+1 >= 0
    throw '32 bits ftw!'
endif

" Uint64 crappy simulation {{{

function! s:u64_fromint(n)
    " Array of four 16-bit digits, abuse overflow, yada yada.
    let rv = [0,0,0,0]
    let rv[2] = s:hi16(a:n)
    let rv[3] = s:lo16(a:n)
    return rv
endfunction

function! s:hi16(n)
    if a:n >= 0
        return a:n / 0x10000
    endif
    let x = s:hi16(a:n + 0x80000000)
    if x < 0x8000
        return x + 0x8000
    endif
    return x
endfunction
function! s:lo16(n)
    if a:n >= 0
        return a:n % 0x10000
    endif
    return s:lo16(a:n + 0x80000000)
endfunction

function! s:u64_fixup(u)
    let carry = 0
    for i in [3,2,1,0]
        let a:u[i] += carry
        if a:u[i] >= 0 && a:u[i] <= 0xffff
            let carry = 0
            continue
        endif
        let carry = s:hi16(a:u[i])
        let a:u[i] = s:lo16(a:u[i])
    endfor
    return carry    " just because
endfunction

function! s:u64_mul(u, n)
    let hi = s:hi16(a:n)
    if hi
        let aux = s:u64_mul(copy(a:u), s:lo16(a:n))
        call s:u64_mul(a:u, hi)
        " shift 16 bits
        for i in [0,1,2]
            let a:u[i] = a:u[i+1]
        endfor
        let a:u[3] = 0
        for i in [0,1,2,3]
            let a:u[i] += aux[i]
        endfor
        call s:u64_fixup(a:u)
        return a:u
    else
        for i in [0,1,2,3]
            let a:u[i] = a:u[i] * a:n
        endfor
        call s:u64_fixup(a:u)
        return a:u
    endif
endfunction

function! s:u64_add(u, n)
    let a:u[2] += s:hi16(a:n)
    let a:u[3] += s:lo16(a:n)
    call s:u64_fixup(a:u)
    return a:u
endfunction

function! s:u64_low32(u)
    return 0x10000 * a:u[2] + a:u[3]
endfunction

function! s:u64_high32(u)
    return 0x10000 * a:u[0] + a:u[1]
endfunction
" }}}

" ... and some (old) code to test it {{{
function! s:testu64(a, b, sum_hi, mul_hi)
    let a = a:a | let b = a:b
    for n in [a,b]
        let x = s:u64_fromint(n)
        if s:u64_high32(x) != 0
            throw 'hi'
        endif
        if s:u64_low32(x) != n
            throw printf("lo(u64(0x%x)) => 0x%x", n, s:u64_low32(n))
        endif
    endfor
    let u64 = s:u64_fromint(a)
    let a64 = s:u64_add(copy(u64), b)
    let m64 = s:u64_mul(copy(u64), b)
    if s:u64_low32(a64) != a+b
        throw printf("u32(u64+a) => 0x%x (%s), should be 0x%x",
                    \ s:u64_low32(a64), string(a64), a+b)
    endif
    if s:u64_low32(m64) != a*b
        throw printf("u32(u64*a) => 0x%x (%s), should be 0x%x",
                    \ s:u64_low32(m64), string(m64), a*b)
    endif
    if s:u64_high32(a64) != a:sum_hi
        throw 'add'
    endif
    if s:u64_high32(m64) != a:mul_hi
        throw printf("low32(u64*a) => 0x%x (%s), should be 0x%x",
                    \ s:u64_high32(m64), string(m64), a:mul_hi)
    endif
endfunction
call s:testu64(1, 2, 0, 0)
call s:testu64(0x80000, 0x80000, 0, 0x40)
" The rest if from /dev/urandom
call s:testu64(0x639dba3c, 0x2413e16b, 0x00000000, 0x0e09ea9c)
call s:testu64(0xfe2d90b1, 0x93e6abf0, 0x00000001, 0x92d931bc)
call s:testu64(0xe883906b, 0xbca1e4ef, 0x00000001, 0xab53a8ba)
call s:testu64(0x631f8870, 0x18b5d14e, 0x00000000, 0x09915b20)
call s:testu64(0xc2314562, 0xd4d15dfc, 0x00000001, 0xa16f9ef9)
call s:testu64(0x39932383, 0xe6a59c43, 0x00000001, 0x33df70e2)
call s:testu64(0x55c1215a, 0x4a6c6630, 0x00000000, 0x18ee2359)
call s:testu64(0xdacb44bd, 0xc3a0958f, 0x00000001, 0xa7321439)
call s:testu64(0x270c0446, 0xc37b22e8, 0x00000000, 0x1dd0ef5a)
call s:testu64(0x3924b444, 0x5f0440b4, 0x00000000, 0x153591e9)
call s:testu64(0xe67f0fd8, 0xafc4ff3f, 0x00000001, 0x9e423aee)
call s:testu64(0x38449e4b, 0xb271fb5c, 0x00000000, 0x2738c399)
call s:testu64(0xbe9d03a7, 0x50ac3a16, 0x00000001, 0x3c114de2)
delfunction s:testu64
" }}}

" The defaults are those in the paper's examples.
let s:cmwc = {
            \ "r" : 4096,
            \ "a" : 18782,
            \ "b" : 0xffffffff,
            \ "c" : 123,
            \ "m" : 0xfffffffe,
            \ "cmwc" : 1,
            \ "i" : 0,
            \ }
let s:cmwc.Q = repeat([0], s:cmwc.r)

" lag; 2^k is merely a convenient choice to increment i
let s:mwc = {
            \ "r" : 1038,
            \ "a" : 611373678,
            \ "b" : 0xffffffff+1,
            \ "c" : 123,
            \ "cmwc" : 0,
            \ "i" : 0,
            \ }
let s:mwc.Q = repeat([0], s:mwc.r)

" https://en.wikipedia.org/wiki/Multiply-with-carry#Complementary-multiply-with-carry_generators {{{
let s:PHI = 0x9e3779b9
if exists('*xor')
    function! s:XMWC_seed(Q, x)
        let a:Q[0] = a:x
        let a:Q[1] = a:x + s:PHI
        let a:Q[2] = a:x + s:PHI + s:PHI

        for i in range(3, len(a:Q)-1)   " range() is bogus
            let a:Q[i] = xor(xor(xor(a:Q[i - 3], a:Q[i - 2]), s:PHI), i)
        endfor
    endfunction
else
    function! s:XMWC_seed(Q, x)
        let a:Q[0] = 1
        let a:Q[1] = a:x
        for i in range(len(a:Q))
            if i > 1
                let a:Q[i] = a:Q[i-1] + a:Q[i-2] + i
            endif
        endfor
    endfunction
endif
" }}}
function! CMWC_seed(x)
    call s:XMWC_seed(s:cmwc.Q, a:x)
endfunction
function! MWC_seed(x)
    call s:XMWC_seed(s:mwc.Q, a:x)
endfunction

function! s:seedarray(x, a, c)
    let a = a:a
    let q = repeat([0], a:x.r)
    for i in range(len(a))
        if i < len(q)
            let q[i] = a[i]
        else
            let q[i % len(q)] += a[i]
        endif
    endfor
    let c = a:c
    if c >= a:x.a
        throw printf('need carry < a (a=%d, c=%d)', a:x.a, c)
    endif
    if ! a:x.cmwc   " MWC: bad seeds?
        " c, Q[...] all zeroes?
        if a:x.c == 0
            let ok = 0
            for val in a:x.Q
                if val != 0
                    let ok = 1
                    break
                endif
            endfor
            if !ok | throw 'MWC(c=0; x1..n = 0)' | endif
        endif
        "   c = a-1, x1..n = b-1
        if a:x.c == a:x.a-1
            let ok = 0
            for val in a:x.Q
                if val != a:x.b - 1
                    let ok = 1
                    break
                endif
            endfor
            if !ok | throw 'MWC(a-1; b-1, ..., b-1)' | endif
        endif
    endif
    let a:x.Q = q
    let a:x.c = c
endfunction
function! CMWC_array(a, ...)
    call s:seedarray(s:cmwc, a:a, a:0 == 1? a:1 : s:cmwc.c)
endfunction

function! MWC_array(a, ...)
    call s:seedarray(s:mwc, a:a, a:0 == 1? a:1 : s:mwc.c)
endfunction

" "Magic values" because, well, as long as finding them requires
" months of CPU time, they might as well be magic.
" XXX TODO FIXME is there a list of **all** known good values anywhere?
let s:magicvalues = []
" The examples in the paper
let s:magicvalues += [
            \ [4096, 18782],
            \ [1038, 611373678],
            \ ]
" http://computer-programming-forum.com/47-c-language/2a86b422191d5bb1.htm
let s:magicvalues += [
            \ [512, 123554632 ],
            \ [256, 8001634 ],
            \ [128, 8007626   ],
            \ [64, 647535442 ],
            \ [32, 547416522 ],
            \ [16, 487198574 ],
            \ [8, 716514398 ],
            \ [4096, 200047750],
            \ ]
" '''Here are a few good choices for r and a'''
let s:magicvalues += [
            \ [2048, 1030770],
            \ [2048, 1047570],
            \ [1024, 5555698],
            \ [1024, 987769338],
            \ [512, 123462658],
            \ [512, 123484214],
            \ [256, 987662290],
            \ [256, 987665442],
            \ [128, 987688302],
            \ [128, 987689614],
            \ [64, 987651206],
            \ [64, 987657110],
            \ [32, 987655670],
            \ [32, 987655878],
            \ [16, 987651178],
            \ [16, 987651182],
            \ [8, 987651386],
            \ [8, 987651670],
            \ [4, 987654366],
            \ [4, 987654978],
            \ ]
function! s:setparams(x, r, a)
    let magic = 0
    for ar in s:magicvalues
        if ar == [a:r, a:a]
            let magic = 1
            break
        endif
    endfor
    if !magic
        echomsg printf("magic(%s); more magic(a=%d, r=%d)?", string(s:magicvalues), a:a, a:r)
        if a:r > 0xffff || a:r < 0
            throw "methinks you swithced a<-->r"
        endif
    endif
    let x = a:x
    let x.r = a:r
    let x.a = a:a
    if len($DEBUG) > 0 && len(x.Q) != x.r
        echomsg printf('Q: %d => %d', len(x.Q), x.r)
    endif
    while len(x.Q) < x.r
        let x.Q += [42]
    endwhile
    while len(x.Q) > x.r
        call remove(x.Q, len(x.Q) - 1)
    endwhile
    " '''Numerous safeprimes of the form a*b^r - 1, b = 2^32 will
    " be given in a separate article. The largest such is 3686175744b^1359 - 1
    " so every possible sequence of 1058 successive 32-bit integers
    " can be produced by the MWC RNG based on that prime.'''
    " -- where is that 'separate article'? ACM?
    "
    " TODO http://mathforum.org/kb/message.jspa?messageID=445277
endfunction

" These are ~50x/100x slower than Xkcd221(), with no significant difference;
" it's ~50x when a fits in a uint16, ~100x if it needs 32 bits
" -- hence with the default config MWC() is 2x slower than CMWC()...
function! CMWC_params(r, a)
    call s:setparams(s:cmwc, a:r, a:a)
endfunction
function! MWC_params(r, a)
    call s:setparams(s:mwc, a:r, a:a)
endfunction

function! s:uint32lt(x, y)
    " MSB set: vim=>negative, uint=>bigger; 0xffffffff becomes -1...
    if a:x >= 0
        if a:y >= 0
            return a:x < a:y
        endif
        return 1
    else
        if a:y < 0
            return a:x < a:y
        endif
        return 0
    endif
endfunction

function! s:XMWC(x)
    let x = a:x
    let Q = x.Q
    " XXX it's actually 'i--' in the paper's MWC;
    " XXX this means you can't just copy/paste the C code!
    let i = (x.i + 1) % len(Q)
    let x.i = i
    " t = a * Q[i] + c
    " split in hi/lo 32 bits
    let t_low  = x.a * Q[i] + x.c
    let t = s:u64_add(s:u64_mul(s:u64_fromint(Q[i]), x.a), x.c)
    let t_high = s:u64_high32(t)
    let x.c = t_high    "(t >> 32)
    if x.cmwc
        let y = t_low + x.c
        if s:uint32lt(y, x.c)
            let y   += 1
            let x.c += 1
        endif
        let Q[i] = x.m - y
    else
        let Q[i] = t_low
    endif
    return Q[i]
endfunction

function! CMWC()
    return s:XMWC(s:cmwc)
endfunction

function! MWC()
    return s:XMWC(s:mwc)
endfunction

" Doesn't depend on xor().
function! s:dbg_makeseed(n)
    let rv = range(a:n)
    let rv[0] = 1
    for i in range(a:n)
        if i > 0
            let rv[i] = rv[i-1] * 69069 + 123
        endif
    endfor
    return rv
endfunction

function! s:test(funcname, results)
    let n = max(keys(a:results))
    let F = function(a:funcname)
    for j in range(n)
        let got = F()
        let i = j+1
        if ! has_key(a:results, i)
            continue
        endif
        let wanted = a:results[i]
        if wanted == got
            continue
        endif
        throw printf('%s#%d: wanted %d, got %d', a:funcname, i, wanted, got)
    endfor
    echomsg printf("%s tested ok (%d calls)", a:funcname, n)
endfunction

if len($DEBUG) > 0
    " index : result -- index starts from 1 (/bin/cat -n...)
    let mwc = {
                \ 1     : 1034629995,
                \ 10    : 1219037173,
                \ 100   : 2552337351,
                \ 1000  : 1175100210,
                \ 10000 : 1162635615,
                \ }
    let cmwc = {
                \ 1     : 2995403027,
                \ 10    : 838516043,
                \ 100   : 3932822103,
                \ 1000  : 3137837417,
                \ 10000 : 1577604300,
                \ }
    echo 'testing...'
    call CMWC_params(4096, 18782)
    call CMWC_array(s:dbg_makeseed(4096), 123)
    call s:test("CMWC", cmwc)
    call MWC_params(1038, 611373678)
    call MWC_array(s:dbg_makeseed(1038), 123)
    call s:test("MWC", mwc)
    echomsg 'ok'
endif

" Here's the C code to generate the test results {{{
" /* Marsaglia's mwc/cmwc */
" #include <stdint.h>
" #include <stdio.h>
" #include <string.h>
"
" static void asrand(uint32_t a[], unsigned n)
" {
"     unsigned i;
"     a[0] = 1;
"     for(i = 1; i < n; i++)
"         a[i] = a[i-1] * 69069 + 123;
" }
" static uint32_t cmwc_Q[4096];
" static uint32_t mwc_Q[1038];
" static uint32_t c = 123;
"
" static uint32_t CMWC(void)
" {
"     uint64_t t, a = 18782;
"     static unsigned i = 0; /* 4095 */
"     uint32_t x, m = 0xfffffffe;
"     i = (i+1)&4095;
"     t = a * cmwc_Q[i] + c;
"     c = (t>>32);
"     x = t+c;
"     if(x < c) {
"         ++x;
"         ++c;
"     }
"     return cmwc_Q[i] = m - x;
" }
" static uint32_t MWC(void)
" {
"     static unsigned i = 0;  /* 1037 */
"     uint64_t t, a = 611373678LL;
"     i = (i+1) % 1038;
"     t = mwc_Q[i] * a + c;
"     c = (t>>32);
"     return mwc_Q[i] = t; /* the original is a bit different */
" }
"
" int main(int argc, char *argv[])
" {
"     if(argc != 1) {
"         if(argc != 2)
"             return 100;
"         if(strcmp(argv[1], "-c") != 0)
"             return 100;
"         asrand(cmwc_Q, 4096);
"         while(!ferror(stdout))
"             printf("%lu cmwc\n", (unsigned long)CMWC());
"     } else {
"         asrand(mwc_Q, 1038);
"         while(!ferror(stdout))
"             printf("%lu mwc\n", (unsigned long)MWC());
"     }
"     return 0;
" }
" }}}

