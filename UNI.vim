" Marsaglia's UNIversal random generator
" Mostly because I was downloading & burning the latest knoppix...

" It generates 24 bits integers/doubles in [0,1)
" It doesn't need any bitwise operator, and it has no problem with 32/64 bits.
" FORTRAN is unreadable!!!
" I tried reimplementing it in C
" ==> taking 3 bytes per number passes the first 666 seconds of dieharder
" ==> it is ~6x slower than [c]mwc
" ... which is funny, because in vim it's actually much faster instead.
" Even better -- it's one of the fastest PRNGs.

let s:u = repeat([0.0], 97)
let s:IP = 1234
let s:JP = 5678

let s:CD = 7654321.0  / 16777216
let s:CM = 16777213.0 / 16777216
lockvar s:CD | lockvar s:CM
let s:C = 362436.0 / 16777216

function! s:within_1_178(n)
    if a:n < 1
        throw string(n) . ' < 1'
    endif
    if a:n > 178
        throw string(n) . ' > 178'
    endif
endfunction

" This is the original initialization routine:
" I,J,K are in [1,178] excluding (1,1,1)
" L is in [0,168]
function! s:RSTART(I, J, K, L)
    if a:L < 0 || a:L > 168
        throw string(a:L) . " must be in [0,168]"
    endif
    call s:within_1_178(a:I)
    call s:within_1_178(a:J)
    call s:within_1_178(a:K)
    if a:I == 1 && a:J == 1 && a:K == 1
        throw 'i=j=k=1'
    endif
    let I = a:I
    let J = a:J
    let K = a:K
    let L = a:L
    for ii in range(97)
        let s = 0.0
        let t = 0.5
        for jj in range(24)
            let m = (((I * J) % 179) * K) % 179
            let I = J
            let J = K
            let K = m
            let L = (53 * L + 1) % 169
            if (L * m % 64) >= 32
                let s = s + t
            endif
            let t = 0.5 * t
        endfor
        let s:u[ii] = s
    endfor
    let s:C = 362436.0 / 16777216.0
    let s:IP = 97
    let s:JP = 33
endfunction

function! RSTART(i,j,k,l)
    " For the masochist in me
    call s:RSTART(a:i, a:j, a:k, a:l)
endfunction

function! UNI()
    " This returns a double in [0,1)
    let uni = s:u[s:IP-1] - s:u[s:JP-1]     " fortran indexes from 1, not 0
    if uni < 0
        let uni = uni + 1.0
    endif
    let s:u[s:IP-1] = uni
    let s:IP = s:IP - 1
    if s:IP == 0
        let s:IP = 97
    endif
    let s:JP = s:JP - 1
    if s:JP == 0
        let s:JP = 97
    endif
    let s:C = s:C - s:CD
    if s:C < 0
        let s:C += s:CM
    endif
    let uni = uni - s:C
    if uni < 0
        let uni = uni + 1
    endif
    return uni
endfunction

function! UNIRand()
    " Return a number in [0, 0xffffff]
    return float2nr(UNI() * 0x1000000)
endfunction

function UNISrand(seed)
    if a:seed < 0
        call UNISeed2(0 - (a:seed + 1), -1)
    else
        call UNISeed2(a:seed, a:seed / 1234)
    endif
endfunction

function! s:ijk(x)
    if a:x < 0
        return s:ijk(0 - (a:x + 1))
    endif
    if a:x == 0
        return 42
    endif
    return 1 + (a:x % 178)
endfunction
function! UNISeed2(x, y)
    " Convenience: provide only two seeds and check
    let I = a:x
    let J = a:x / 0x10000 + 0x10000 * (a:x % 0x10000)
    let K = a:y
    let L = a:y / 0x10000 + 0x10000 * (a:y % 0x10000)
    let I = s:ijk(I)
    let J = s:ijk(J)
    let K = s:ijk(K)
    if I == 1 && J == 1 && K == 1
        echoerr 'I=J=K=1...'
        let J = 42
    endif
    let L = L % 168
    while L < 0
        let L += 168
    endwhile
    call s:RSTART(I, J, K, L)
endfunction

call UNISeed2(localtime(), getpid())
if len($DEBUG) > 0
    echomsg 'testing the UNIversal generator...'
    let table4 = [
                \ [6, 3, 11, 3, 0, 4, 0],
                \ [13, 8, 15, 11, 11, 14, 0],
                \ [6, 15, 0, 2, 3, 11, 0],
                \ [5, 14, 2, 14, 4, 8, 0],
                \ [7, 15, 7, 10, 12, 2, 0],
                \ ]
    call s:RSTART(12,34,56,78)
    for ii in range(20005)
        let x = UNI()
        if ii > 20000
            let tab = table4[ii - 20000]
            for i in range(7)
                " print 21.(MOD(INT(X*16.**I),16).I=1.7)
                " let line .= printf("%d \t", float2nr(x*pow(16, i+1)) % 16)
                let res = float2nr(x*pow(16, i+1)) % 16
                if res != tab[i]
                    throw printf('uni@%d: %d != %d', ii, res, tab[i])
                endif
            endfor
            unlet tab
        endif
    endfor
    unlet ii table4
    echomsg 'UNI ok'
endif

