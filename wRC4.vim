" RC4 from wikipedia

function! s:swap(array, i, j)
    let x = a:array[a:i]
    let a:array[a:i] = a:array[a:j]
    let a:array[a:j] = x
endfunction

" This function needs an array of uint8, not a string/number.
function! RC4_KSA(key)
    let S = range(256)
    let j = 0
    for i in range(255)
        let j = (j + S[i] + a:key[i % len(a:key)]) % 256
        call s:swap(S, i, j)
    endfor
    return { "S":S, "i":0, "j":0 }
endfunction

function! RC4_PRGA(rs, length)
    let keystream = range(a:length)
    let i = a:rs.i
    let j = a:rs.j
    let S = a:rs.S
    for k in keystream
        let i = (i + 1) % 256
        let j = (j + S[i]) % 256
        call s:swap(S, i, j)
        let keystream[k] = S[(S[i] + S[j]) % 256]
    endfor
    let a:rs.i = i
    let a:rs.j = j
    return keystream
endfunction

" In vimscript you can't treat strings as an array of bytes;
" "AAA"[0] is not 0x41, it's atoi("A"), ie zero.
function! RC4_string2bytes(str)
    let b = []
    for i in range(len(a:str))
        let b += [char2nr(a:str[i])]
    endfor
    return b
endfunction

" PRNG
let s:stream = RC4_KSA(RC4_string2bytes(printf("%d+%d+%s",
            \ localtime(), getpid(), string(values(v:)))))
function! RC4_u32()
    let b = RC4_PRGA(s:stream, 4)
    return b[0]*0x1000000 + b[1]*0x10000 + b[2]*0x100 + b[3]
endfunction

function! RC4_i31()
    let b = RC4_PRGA(s:stream, 4)
    return (b[0]%128) * 0x1000000 + b[1]*0x10000 + b[2]*0x100 + b[3]
endfunction


if len($DEBUG) > 0
    " https://en.wikipedia.org/wiki/RC4#Test_vectors
    let ks = {}
    let ks["Key"] = [0xEB, 0x9F, 0x77, 0x81, 0xB7, 0x34, 0xCA, 0x72, 0xA7, 0x19]
    let ks["Wiki"] = [0x60, 0x44, 0xDB, 0x6D, 0x41, 0xB7]
    let ks["Secret"] = [0x04, 0xD4, 0x6B, 0x05, 0x3C, 0xA8, 0x7B, 0x59 ]
    for k in keys(ks)
        let r = RC4_KSA(RC4_string2bytes(k))
        let x = ks[k]
        for i in range(len(x))
            let y = RC4_PRGA(r, 1)
            if x[i] == y[0]
                continue
            endif
            throw printf("rc4(%s) @%d: want 0x%x, got 0x%x", k, i, x[i], y[0])
        endfor
    endfor
    unlet r x y i ks
    echomsg 'rc4 test vectors ok'
endif

