" http://web.archive.org/web/20080207125928/http://cypherpunks.venona.com/archive/1994/09/msg00304.html
" -- that's the anonymous post that revealed the RC4 algorithm to the world.
" He usually calls 'key' the rc4 struct, 'key_data_ptr' the key itself;
" the API is translated, so it's clumsy in vim.

"/* rc4.h */
"typedef struct rc4_key
"{
"     unsigned char state[256]
"     unsigned char x
"     unsigned char y
"} rc4_key

"/*rc4.c */
function! s:swap(A, i, j)
    let a = a:A
    let tmp    = a[a:i]
    let a[a:i] = a[a:j]
    let a[a:j] = tmp
endfunction

function! RC4_prepare_key(key_data_ptr)
    let k = []
    " string() isn't idempotent on strings -- it adds extra quotes(!)
    let longstring = "check it's a string"
    try
        let longstring = a:key_data_ptr
    catch
        let longstring = string(a:key_data_ptr)
    endtry
    for idx in range(len(longstring))
        let char = longstring[idx]
        let k += [char2nr(char)]
    endfor
    let key_data_len = len(k)
    let rs = {}
    let rs.state = range(256)
    let state = rs.state
    let rs.x = 0
    let rs.y = 0
    let index1 = 0
    let index2 = 0
    for counter in range(256)
        let index2 = (k[index1] + state[counter] + index2) % 256
        call s:swap(state, counter, index2)
        let index1 = (index1 + 1) % key_data_len
    endfor
    return rs
endfunction

" void rc4(unsigned char *buffer_ptr, int buffer_len, rc4_key *key)
" The rc4() function XORs the input with the keystream,
" but I don't want to depend upon vim's xor();
" hence I'll just expose the key stream.
function! RC4_keystream(buffer_ptr, buffer_len, rs)
    let x = a:rs.x
    let y = a:rs.y

    let state = a:rs.state
    for counter in range(a:buffer_len)
        let x = (x + 1) % 256
        let y = (state[x] + y) % 256
        call s:swap(state, x, y)
        let xorIndex = (state[x] + state[y]) % 256
        let a:buffer_ptr[counter] = state[xorIndex]
    endfor
    let a:rs.x = x
    let a:rs.y = y
    return a:buffer_ptr
endfunction

" Initialization much faster than I thought!
" about 0.3 seconds on my oldest machine (p3 coppermine, 800MHz).
" let s:rs = RC4_prepare_key([getpid(), localtime()])
" let s:rs = RC4_prepare_key([getpid(), reltime()])
let s:rs = RC4_prepare_key(string(localtime()) . string(getpid()) . string(v:))

" Names borrowed from golang;
" About 25/30x slower than xkcd221().
function! RC4_uint32()
    let b = [0,0,0,0]
    call RC4_keystream(b, 4, s:rs)
    return b[0]*0x1000000 + b[1]*0x10000 + b[2]*0x100 + b[3]
endfunction
function! RC4_int31()
    let b = [0,0,0,0]
    call RC4_keystream(b, 4, s:rs)
    let u = b[0]*0x1000000 + b[1]*0x10000 + b[2]*0x100 + b[3]
    if u < 0
        return 0 - (u+1)
    endif
    return u
endfunction

if len($DEBUG) > 0
    " https://en.wikipedia.org/wiki/RC4#Test_vectors
    let ks = {}
    let ks["Key"] = [0xEB, 0x9F, 0x77, 0x81, 0xB7, 0x34, 0xCA, 0x72, 0xA7, 0x19]
    let ks["Wiki"] = [0x60, 0x44, 0xDB, 0x6D, 0x41, 0xB7]
    let ks["Secret"] = [0x04, 0xD4, 0x6B, 0x05, 0x3C, 0xA8, 0x7B, 0x59 ]
    for k in keys(ks)
        let r = RC4_prepare_key(k)
        let x = ks[k]
        for i in range(len(x))
            let y = RC4_keystream([1], 1, r)
            if x[i] == y[0]
                continue
            endif
            throw printf("rc4(%s) @%d: want 0x%x, got 0x%x", k, i, x[i], y[0])
        endfor
    endfor
    unlet r x y i ks
    echomsg 'rc4 test vectors ok'
endif

