" George Marsaglia's favorite(*) PRNG in vimscript.
"
" Someday Debian Stable will finally ships a Vim in which exists('*and'),
" thus making Wheezy my favorite Debian release
" -- hey, it happened!
" Tnx wikipedia for showing me this gem.
"
" (*) http://www.ciphersbyritter.com/NEWS4/RANDC.HTM
" [A favorite stand-alone generator].

function! s:shift16right(n)
    if a:n < 0
        let n = a:n
        " Manually shift one bit => positive, then shift 15 bits.
        let n = and(0x7fffffff, n)
        let n = or( 0x40000000, n/2)
        return n / 0x8000
    endif
    return a:n / 0x10000
endfunction

function! s:intmax(n)
    " Vim uses N bits signed ints, N >= 32.
    " See vim/src/structs.h for details.
    return a:n>0 && a:n+1<0
endfunction

" This PRNG returns an uint32_t, ie a number in [0, 0xFFFFFFFF];
" vim typically uses int32_t, meaning this can return negative numbers.
if s:intmax(0x7fffffff)
    " 7x slower than Xkcd221()
    function! Marsaglia()
        let s:m_z = 36969 * and(s:m_z, 65535) + s:shift16right(s:m_z)
        let s:m_w = 18000 * and(s:m_w, 65535) + s:shift16right(s:m_w)
        return (s:m_z * 65536) + s:m_w  " 32-bit result
    endfunction
else
    let s:m_w = and(s:m_w, 0xFFFFFFFF)
    let s:m_z = and(s:m_z, 0xFFFFFFFF)
    function! Marsaglia()
        " These 2 lines can't overflow 32 bits
        let s:m_z = 36969 * and(s:m_z, 65535) + s:shift16right(s:m_z)
        let s:m_w = 18000 * and(s:m_w, 65535) + s:shift16right(s:m_w)
        " This line *will* overflow 32 bits
        return and(0xFFFFFFFF, (s:m_z * 65536) + s:m_w)     " 32-bit result
    endfunction
endif

function! MarsagliaSeed(w,z)
    let w = and(a:w, 0xFFFFFFFF)
    let z = and(a:z, 0xFFFFFFFF)
    if w == 0 || z == 0
        throw printf("(m_w=%d, m_z=%d) can't have any zeroes!", a:w, a:z)
    endif
    let s:m_w = w
    let s:m_z = z
endfunction

" Test vs C version
if len($DEBUG) > 0
    call MarsagliaSeed(3576326487, 1644975104) " /dev/urandom
    let expected = [
                \ 4076571226, 3763205391, 101373103, 1117688830, 869526986,
                \ 3150885829, 3854912735, 665006352, 1815267869, 735519881
                \ ]
    for i in range(len(expected))
        let got = Marsaglia()
        if got == expected[i]
            continue
        endif
        throw printf("%d: wanted %d, got %d", i, expected[i], got)
    endfor
    echomsg 'Marsaglia() tested ok'
    unlet expected got
endif

" Default seeding
" We could use many "random" values, such as:
"   size/mtime of $TMP, $TEMP, $TMPDIR, /etc/passwd, and so on;
"   on windows, $APPDATA, $WINDIR, and more.
"   v:windowid (zero w/o gui)
"   v:oldfiles (hashed once)
"   Vim command history
"   ...
" This crap is here *only* to remind myself of the possibilities.
function! s:hash(str)
    let h = 5381    " djb
    for i in range(len(a:str))
        let h = h * 33
        let h = xor(h, char2nr(a:str[i]))
    endfor
    return h
endfunction
let s:m_w = localtime() + 0x10000*getpid()
" On 64-bit systems, pid_max can be set to any value up to 2^22
" (PID_MAX_LIMIT, approximately 4 million).
let s:m_z = s:hash(hostname() . string(v:oldfiles) . getline("."))
if s:m_w == 0
    let s:m_w = 0x86BE1074  " from /dev/urandom
endif
if s:m_z == 0
    let s:m_z = 0x4376D02F  " from /dev/urandom
endif

