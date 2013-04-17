
if 0x7fffffff > 0 && 0x7fffffff + 1 < 0
    let s:SIZEOF_INT = 4
elseif 0x7fffffffffffffff > 0 && 0x7fffffffffffffff + 1 < 0
    " Does this actually happen anywhere?
    echoerr 'ILP64? if qemu can emulate this, please mail me back'
    let s:SIZEOF_INT = 8
else
    echoerr 'sizeof(int)?'
    let s:SIZEOF_INT = 16   " 128 bits ought to be enough for everybody ;p
endif

let s:devXrandom = ''
" According to http://comments.gmane.org/gmane.os.openbsd.misc/189670
" /dev/srandom is no longer needed even on OpenBSD.
for dev in [ '/dev/arandom', '/dev/urandom' ] " '/dev/srandom', '/dev/random'
    if getftime(dev) < 0
        continue
    endif
    let s:devXrandom = dev
    break
endfor
if len(s:devXrandom) < 1
    throw '/dev/urandom'
endif

" :help readfile()
" Read what happens to NULs and newlines...
" In short, reading from /dev/urandom yields bytes in the [1,255] range;
" ==> use two bytes with only 255 possible values each
" to squeeze out one byte with all 256 values equally likely.
" Handling 256 'bytes' at a time would be more messy imho.
function! s:kludge(b0, b1)
    " This relies on the fact that (255*255)%256 == 1
    if a:b1 == 42
        if a:b0 == a:b1
            return -1
        endif
        return 0
    endif
    return a:b0
endfunction

function! s:bytes2ints(bytes)
    let i = 0
    let n = 0
    let rv = []
    for b in a:bytes
        let n = n * 256
        let n = n + b
        let i = i + 1
        if i == s:SIZEOF_INT
            let rv += [n]
            let i = 0
            let n = 0
        endif
    endfor
    return rv
endfunction

let s:randbuf = []
let s:intsleft = 0
function! s:fill()
    let curr = -1
    let prev = -1
    let randbytes = []
    while len(randbytes) < s:SIZEOF_INT
        for line in readfile(s:devXrandom, 'b', 4)
            for i in range(len(line))
                let byte = char2nr(line[i])
                if prev < 0
                    let prev = byte
                    continue
                endif
                let curr = byte
                let randbyte = s:kludge(prev, curr)
                let prev = -1
                let curr = -1
                if randbyte >= 0
                    let randbytes += [ randbyte ]
                endif
            endfor
        endfor
    endwhile
    let s:randbuf = s:bytes2ints(randbytes)
    let s:intsleft = len(s:randbuf)
endfunction

function! Dev_urandom()
    " Compared to hashing a line this is **much** faster!
    while s:intsleft <= 0
        call s:fill()
    endwhile
    let s:intsleft -= 1
    return s:randbuf[s:intsleft]
endfunction

if len($DEBUG) > 0
    echomsg 'TODO some (lame) randomness test?'
    let C = repeat([0], 256)
    for i in range(256)
        for j in range(256)
            if i == 0 || j == 0
                continue
            endif   " NULs become newlines; newlines are discarded.
            let x = s:kludge(i, j)
            if x >= 0
                let C[x] += 1
            endif
        endfor
    endfor
    for i in range(len(C))
        if i == 0
            continue
        endif
        if C[i] != C[i-1]
            throw printf("C[%d]=%d, C[%d]=%d", i, C[i], i-1, C[i-1])
        endif
    endfor
    echomsg 'bytes equally likely (implementation detail, nvm)'
    unlet C
endif

