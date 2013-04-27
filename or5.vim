
" http://www.woodmann.com/forum/archive/index.php/t-3100.html
" A small random **bit** generator by Adi SHamir (the 'A' in "RSA").
" Every iteration of "x+=(x*x) | 5" gives a random MSB.
" I must find the time to study cryptography.

let s:sentinel = 1
let s:NBITS   = 1
let s:HIBIT   = 1
while 1
    let x = s:sentinel * 2 + 1
    let s:sentinel = x
    let s:NBITS += 1
    let s:HIBIT += s:HIBIT
    if x < 0
        break
    endif
endwhile
unlet s:sentinel

let s:x = 1

function! s:bit()
    let s:x += or(s:x * s:x, 5)
    return 0 != and(s:HIBIT, s:x)
endfunction

" 40x/50x slower than Xkcd221()
function! OR5rand()
    let n = 0
    for i in range(s:NBITS)
        let n += n
        let n += s:bit()
    endfor
    return n
endfunction

function! OR5srand(seed)
    let s:x = a:seed
endfunction

if len($DEBUG) > 0
    let wanted = []
    let s:x = 123456
    if s:NBITS == 32
        let wanted = [
                    \ 0x9a22b52f, 0xe3bcca7d, 0xed534f4f, 0xbf4c792a,
                    \ 0x95c82782, 0xcd053747, 0xacf7e457, 0xbd3f37a7,
                    \ ]
    elseif s:NBITS == 64
        let wanted = [
                    \ 0x9a22b52fe3bcca7d, 0xed534f4fbf4c792a,
                    \ 0x95c82782cd053747, 0xacf7e457bd3f37a7,
                    \ 0xddc06cf84fe26661, 0xb52e6b211f61c5c7,
                    \ 0x18db5510be35de80, 0x2616382b6d41b917,
                    \ 0xae9982ad8debf957, 0x9cbee884354b9565,
                    \ ]
    else
        echoerr printf('%d bits?', s:NBITS)
    endif
    for i in range(len(wanted))
        let got = OR5rand()
        if got == wanted[i]
            continue
        endif
        throw printf('#%d(%d bits): wanted %d, got %d',
                    \ i, s:NBITS, wanted[i], got)
    endfor
    echomsg 'x+=(x*x) | 5; => ok'
    unlet wanted
endif
let s:x = localtime() + getpid()*321


