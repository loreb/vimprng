
" https://github.com/mono/mono/blob/master/mcs/class/corlib/System/Random.cs
" This is Mono's System.Random; I find it marginally interesting because
" knowing java's PRNG I thought this would be equally crappy,
" and so I was pleasantly surprised.
" Plus it has a few features that work well with vimscript:
" - it doesn't use any weird operations (xor())...
" - all arithmetic is int32;
" - it's fast (in vimscript).

"
" System.Random.cs
"
" Authors:
"   Bob Smith (bob@thestuff.net)
"   Ben Maurer (bmaurer@users.sourceforge.net)
"
" (C) 2001 Bob Smith.  http:"www.thestuff.net
" (C) 2003 Ben Maurer
"

"
" Copyright (C) 2004 Novell, Inc (http:"www.novell.com)
"
" Permission is hereby granted, free of charge, to any person obtaining
" a copy of this software and associated documentation files (the
" "Software"), to deal in the Software without restriction, including
" without limitation the rights to use, copy, modify, merge, publish,
" distribute, sublicense, and/or sell copies of the Software, and to
" permit persons to whom the Software is furnished to do so, subject to
" the following conditions:
" 
" The above copyright notice and this permission notice shall be
" included in all copies or substantial portions of the Software.
" 
" THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
" EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
" MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
" NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
" LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
" OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
" WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
"

if 0x7fffffff <= 0 || 0x7fffffff+1 >= 0
    throw '32 bits'
endif
let s:MBIG = 0x7fffffff
let s:MSEED = 161803398

"int32_t s:inext, s:inextp
let s:inext = 0
let s:inextp = 0
let s:SeedArray = range(56)

let s:INT32_MIN = -0x7fffffff - 1
function! MonoSrand(Seed)
    " Numerical Recipes in C online @ http:"www.library.cornell.edu/nr/bookcpdf/c7-1.pdf

    " Math.Abs throws on INT32_MIN, so we need to work around that case.
    " Fixes: 605797
    if a:Seed == s:INT32_MIN
        let mj = s:MSEED - abs(s:INT32_MIN + 1)
    else
        let mj = s:MSEED - abs(a:Seed)
    endif

    let s:SeedArray[55] = mj
    let mk = 1
    for i in range(1, 55-1) "  [1, 55] is special (Knuth); range() is weird.
        let ii = (21 * i) % 55
        let s:SeedArray[ii] = mk
        let mk = mj - mk
        if (mk < 0)
            let mk += s:MBIG
        endif
        let mj = s:SeedArray[ii]
    endfor
    for k in range(1, 5-1)
        " for (i = 1; i < 56; i++) {
        for i in range(1, 55)
            let s:SeedArray[i] -= s:SeedArray[1 + (i + 30) % 55]
            if  s:SeedArray[i] < 0
                let s:SeedArray[i] += s:MBIG
            endif
        endfor
    endfor
    let s:inext = 0
    let s:inextp = 31
endfunction

" protected virtual double Sample ()
function! s:Sample()
    let s:inext += 1
    if s:inext  >= 56
        let s:inext  = 1
    endif
    let s:inextp += 1
    if s:inextp >= 56
        let s:inextp = 1
    endif

    let retVal = s:SeedArray[s:inext] - s:SeedArray[s:inextp]

    if retVal < 0
        let retVal += s:MBIG
    endif

    let s:SeedArray[s:inext] = retVal

    return retVal * (1.0 / s:MBIG)
endfunction

function! MonoRand()
    return float2nr(s:Sample() * 0x7fffffff)
endfunction

call MonoSrand(localtime() + getpid() * 6561)
if len($DEBUG) > 0
    call MonoSrand(314159)  " knuth's 123456
    let wanted = [
                \ 1220052072,
                \ 776956238,
                \ 826285397,
                \ 1622308232,
                \ 1214823801,
                \ 177668324,
                \ 126940243,
                \ 1247974683,
                \ 1210433860,
                \ 188777646,
                \ 705407648,
                \ 1278001777,
                \ 1386869882,
                \ 606992255,
                \ 983667398,
                \ 2030673156,
                \ 16570373,
                \ 1292258545,
                \ 1284320844,
                \ 1305275209,
                \ 629507699,
                \ 654474390,
                \ 1299946547,
                \ 857275255,
                \ 433679092,
                \ 852730979,
                \ 1791481703,
                \ 638928959,
                \ 191372743,
                \ 1316926772,
                \ 697476682,
                \ ]
    for i in range(len(wanted))
        let x = wanted[i]
        let y = MonoRand()
        if x == y
            continue
        endif
        throw printf("#%d want %d, got %d", i, x, y)
    endfor
    echomsg 'System.Random.cs tested ok'
    unlet wanted x y
endif



