" Marsaglia's UNIversal random generator extended to double precision
" G. Marsaglia, W.W. Tsang / Statistics & Probability Letters 66 (2004) 183 – 187
" "The 64-bit universal RNG"
" Basically it's a double-precision LFG combined with a weyl generator.
let s:U = repeat([0.0], 98)
let s:r = 9007199254740881.0 / 9007199254740992.0
let s:d = 362436069876.0 / 9007199254740992.0

" return a number in [0,1)
function! UNI64()
        let U = s:U
        let x = U[s:i] - U[s:j]
        if x < 0.0
                let x += 1.0
        endif
        let U[s:i] = x
        " if(--i==0) i=97; -- TODO wtf? did he do 1-based indexing?
        let s:i -= 1
        if s:i == 0
                let s:i = 97
        endif
        let s:j -= 1
        if s:j == 0
                let s:j = 97
        endif
        let s:c = s:c - s:d
        if s:c < 0.0
                let s:c += s:r
        endif
        let x -= s:c
        if x < 0.0
                return x + 1.0
        endif
        return x
endfunction

" "A two-seed function for filling the static array U[98] one bit at a time"
" Multiplicative RNG => throw if zero; buggy as in the original.
function! UNI64_fillU(seed1, seed2)
        let x = a:seed1
        let y = a:seed2

        "for (i=1; i<98; i++){
        for i in range(1,97)
                let s = 0.0
                let t = 0.5

                "for (j=1; j<54; j++){
                for j in range(1, 53)
                        let x = (6969*x) % 65543
                        " "y = (8888 * x)" -- yep, x, not y, or the tests are
                        " botched. IMVHO it's a typo, seed2 becomes useless!
                        let y = (8888*x) % 65579
                        if and(32, xor(x,y)) > 0
                                let s += t
                        endif
                        let t = 0.5 * t
                endfor
                let s:U[i] = s
                if x == 0
                        throw "x"
                endif
                if y == 0
                        throw "y"
                endif
        endfor
        let s:c = 0.0
        let s:i = 97
        let s:j = 33
endfunction

let x = getpid()
let y = localtime()
while 1
        try
                call UNI64_fillU(x, y)
                break
        catch
                let x += char2nr('x')
                let y += char2nr('y')
        endtry
endwhile
if len($DEBUG) > 0
        for i in range(1234)
                let x = UNI64()
                if x < 0 || x >= 1.0
                        throw string(x)
                endif
        endfor
        call UNI64_fillU(123456789,987654321)
        "for(i=1;i<=10000000;i++)
        "for i in range(10000000) => Q: how much RAM does it take?
        for j in range(1000)
                redraw
                echo printf("%d/%d...", j, 1000)
                for i in range(10000000/1000)
                        let x = UNI64()
                endfor
        endfor
        let correct_output = [
                                \ 4973478098168054.0,
                                \ 7093627369399858.0,
                                \ 6724709031495432.0,
                                \ 3308798729116051.0,
                                \ 7384281049802113.0,
                                \ ]
        for i in range(5)
                let x = UNI64() * 9007199254740992.0
                if x == correct_output[i]
                        continue
                endif
                throw printf("[%d] got %f, want %f - difference %f",
                                        \ i, x, correct_output[i],
                                        \ abs(x - correct_output[i]))
        endfor
        echomsg "UNI64 ok"
else
endif

" Sloppy - don't care, float2nr() sucks anyway.
function! UNI64_int()
        return float2nr(UNI64() * 2147483648.0)
endfunction


