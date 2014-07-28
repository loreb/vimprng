" George Marsaglia's last, huge MWC
" http://mathforum.org/kb/message.jspa?messageID=7359611
" Aside from being his last RNG before he died,
" the original workd equally well in 32/64 bits,
" and it's nice in the way it avoids using a bigger integer type
" to compute the results (there's no uint128_t after all).
"
" The 'Q' array is so big that seeding takes time - for the lultz!
" Funny how I used to think SUPRKISS was too big to be usable...
if 0x7fffffff <= 0 || 0x7fffffff+1 >= 0
        throw '32 bits ftw!'
endif

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

" {{{ Vimscript lacks bit shifts; copypasta from SUPRKISS_usable.vim
" --- simplified because we only shift by known amounts.
" Btw, the left shift in the xorshift generators could be optimized
" to multiplications rather than function calls.
let s:powerof2 = [1]
while 1
        let x = s:powerof2[len(s:powerof2)-1]
        let y = x*2
        if y <= x
                break
        endif
        let s:powerof2 += [y]
endwhile

function! s:LS(n, offset)
        return a:n * s:powerof2[a:offset]
endfunction
" We only shift by 4 or by 17...
function! s:RS(n, offset)
        if a:n >= 0
                return a:n / s:powerof2[a:offset]
        endif
        let u1 = a:n
        let u1 = and(0x7fffffff, u1) / 2
        let u1 =  or(0x40000000, u1)
        return s:RS(u1, a:offset - 1)
endfunction
" }}}

let s:Q = range(4194304)
let s:carry = 0
let s:j = 4194303
let s:cng = localtime()
let s:xs = getpid()


" x<<28 => 0x10000000
function! B32MWC()
        let s:j = and(s:j+1, 4194303)
        let x = s:Q[s:j]
        let t = (x * 0x10000000) + s:carry
        let s:carry = s:RS(x,4) - s:uint32lt(t, x)
        let rv = t - x
        let s:Q[s:j] = rv
        return rv
endfunction

"#define CNG ( cng=69069*cng+13579 )
"#define XS ( xs^=(xs<<13), xs^=(xs>>17), xs^=(xs<<5) )
"#define KISS ( b32MWC()+CNG+XS )
function! B32KISS()
        let s:cng = s:cng * 69069 + 13579
        let s:xs = xor(s:xs, s:LS(s:xs, 13))
        let s:xs = xor(s:xs, s:RS(s:xs, 17))
        let s:xs = xor(s:xs, s:LS(s:xs, 5))
        return B32MWC() + s:xs + s:cng
endfunction

" LCG is the fastest RNG in vimscript (1.5x xkcd221!);
" adding an (optional!!!) xorshift makes B32srand() >3x slower
" -- not the xorshift itself, testing IF there is an extra argument!
" ==> I had to manually bring the IF outside of the loop...
" (fyi, the extra argument leads to ~7x slowdown)
function! B32srand(cng, ...)
        let s:j = 4194303
        let s:cng = a:cng
        let s:xs = 362436069
        let s:carry = 0
        if a:0 == 0
                for i in range(len(s:Q))
                        let s:Q[i] = s:cng
                        let s:cng = s:cng * 69069 + 13579
                endfor
        elseif a:0 == 1
                let s:xs = a:1
                if s:xs == 0
                        throw "xorshift(0) == 0"
                endif
                for i in range(len(s:Q))
                        let s:cng = s:cng * 69069 + 13579
                        let s:xs = xor(s:xs, s:LS(s:xs, 13))
                        let s:xs = xor(s:xs, s:RS(s:xs, 17))
                        let s:xs = xor(s:xs, s:LS(s:xs, 5))
                        let s:Q[i] = s:xs + s:cng
                endfor
        else
                throw "(cng[,xs])"
        endif
endfunction

function! s:all(array, value)
        for x in a:array
                if x != a:value
                        return 0
                endif
        endfor
        return 1
endfunction
function! B32setQcarry(Q, carry)
        if a:carry < 0 || a:carry >= 0x10000000
                throw "need carry in [0,0x10000000)"
        elseif a:carry == 0 && s:all(a:Q, 0)
                throw "MWC(0; 0,...,0)"
        elseif a:carry == 0x10000000-1 && s:all(a:Q, -1)
                throw "MWC(a-1; b-1,...,b-1)"
        endif
        if len(a:Q) > len(s:Q)
                throw 'Q'
        endif
        for i in range(len(a:Q))
                let s:Q[i] = a:Q[i]
        endfor
        let s:carry = a:carry
endfunction


if len($DEBUG) > 0
        echomsg "testing..."
        " Marsaglia's test will take forever, so use a shorter version.
        let chunksize = 1000
        let chunks = chunksize
        let results = [2769813733, 3545999299]
        if $DEBUG ==? "Marsaglia"
                echomsg "this will take *forever*"
        else
                echomsg "short test..."
                " 1/1000 of Marsaglia's test does 0.238 rounds;
                " chosen because it takes ~ as long as seeding.
                let chunks = 1
                let results = [676384285, 3099071164]
        endif
        let s:cng = 123456789
        let s:xs = 362436069
        " /* First seed Q[] with CNG+XS: */
        for i in range(4194304)
                let s:cng = s:cng * 69069 + 13579
                let s:xs = xor(s:xs, s:LS(s:xs, 13))
                let s:xs = xor(s:xs, s:RS(s:xs, 17))
                let s:xs = xor(s:xs, s:LS(s:xs, 5))
                let s:Q[i] = s:xs + s:cng
                let s:Q[i] = s:cng + s:xs
        endfor
        echomsg "seeded..."
        " /* Then generate 10^9 b32MWC()s */ (only a fraction of them!)
        for chunk in range(chunks)
                for i in range(1000000000 / chunksize)
                        let x = B32MWC()
                endfor
        endfor
        let want = results[0]
        if x != want
                throw printf("10^9 b32MWCs(): want %d, got %d", want, x)
        endif
        echomsg "B32MWC() ok"
        " /* followed by 10^9 KISSes: */
        for chunk in range(chunks)
                for i in range(1000000000 / chunksize)
                        let x = B32KISS()
                endfor
        endfor
        let want = results[1]
        if x != want
                throw printf("10^9 KISSes(): want %d, got %d", want, x)
        endif
        echomsg "B32KISS() ok"
endif

