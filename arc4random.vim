" http://www.openbsd.org/cgi-bin/cvsweb/~checkout~/src/lib/libc/crypt/arc4random.c?rev=1.23
" /*	$OpenBSD: arc4random.c,v 1.23 2012/06/24 18:25:12 matthew Exp $	*/

" UPDATE: OpenBSD replaces RC4 with ChaCha20
" http://marc.info/?l=openbsd-cvs&m=138065251627052&w=2
" -- nice since chacha/salsa are beautiful and were on my todo list XD

" /*
"  * Copyright (c) 1996, David Mazieres <dm@uun.org>
"  * Copyright (c) 2008, Damien Miller <djm@openbsd.org>
"  *
"  * Permission to use, copy, modify, and distribute this software for any
"  * purpose with or without fee is hereby granted, provided that the above
"  * copyright notice and this permission notice appear in all copies.
"  *
"  * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
"  * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
"  * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
"  * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
"  * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
"  * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
"  * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
"  */

" /*
"  * Arc4 random number generator for OpenBSD.
"  *
"  * This code is derived from section 17.1 of Applied Cryptography,
"  * second edition, which describes a stream cipher allegedly
"  * compatible with RSA Labs "RC4" cipher (the actual description of
"  * which is a trade secret).  The same algorithm is used as a stream
"  * cipher called "arcfour" in Tatu Ylonen's ssh package.
"  *
"  * RC4 is a registered trademark of RSA Laboratories.
"  */

if 0x7fffffff<=0 || 0x7fffffff+1>=0
    " The arc4random() function works with bytes, it generates uint32
    " one byte t a time.
    " If you ever find a system where vim's integers are >32bits,
    " you'll need to:
    " - adjust Arc4random_uniform;
    " - adjust Arc4random;
    " - run with $DEBUG set to make sure everything works (it should).
    throw 'arc4random needs uint32_t'
endif
" struct arc4_stream {
" 	u_int8_t i;
" 	u_int8_t j;
" 	u_int8_t s[256];
" };

" static int rs_initialized = 0;
let s:rs = {}
" pid? nope, we don't fork in vim
let s:arc4_count = 0

"static inline u_int8_t arc4_getbyte(void);
function! s:arc4_getbyte()
    throw 'prototype'
endfunction

" This is arc4_init()
let s:rs.s = range(256)
let s:rs.i = 0
let s:rs.j = 0

function! s:getrandomdevice()
    for dev in ["/dev/arandom", "/dev/urandom", "/dev/random"]
        if getftime(dev) < 0
            continue
        endif
        return dev
    endfor
    throw '/dev/urandom?'
endfunction
let s:randomdevice = s:getrandomdevice()

" This is copypasta from devurandom.vim {{{
" REPETITA IVVANT: see how readfile() treats NULs and newlines.
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

let s:buf = {}
let s:buf.bytes = []
let s:buf.left  = 0
function! s:fill()
    let curr = -1
    let prev = -1
    let randbytes = []
    while len(randbytes) < 1
        for line in readfile(s:randomdevice, 'b', 4)
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
    let s:buf.bytes = randbytes
    let s:buf.left  = len(randbytes)
endfunction
" }}}
function! s:urandom_byte()
    if s:buf.left < 1
        call s:fill()
    endif
    let s:buf.left -= 1
    return s:buf.bytes[s:buf.left]
endfunction

" Small integers, not characters!
function! s:devurandom(numbytes)
    let rv = []
    while len(rv) < a:numbytes
        let rv += [ s:urandom_byte() ]
    endwhile
endfunction
let s:powerof2 = [ 1 ]
while 1
    let x = s:powerof2[len(s:powerof2)-1] * 2
    if x <= 0
        break
    endif
    let s:powerof2 += [x]
endwhile
function! s:LS(x, n)
    return a:x * s:powerof2[a:n]
endfunction

function! s:arc4_addrandom(dat, datlen)
    let rs = s:rs
    " u_int8_t si;

    let rs.i -= 1
    for n in range(256)
        let rs.i = (rs.i + 1)%256 " uint8_t
        let si = rs.s[rs.i]
        let rs.j = (rs.j + si + a:dat[n % a:datlen]) % 256
        let rs.s[rs.i] = rs.s[rs.j]
        let rs.s[rs.j] = si
    endfor
    let rs.j = rs.i
endfunction

function! s:arc4_stir()
    " u_char rnd[128];
    let rnd = s:devurandom(128)
    call s:arc4_addrandom(rnd, len(rnd))

    " /*
    "  * Discard early keystream, as per recommendations in:
    "  * http://www.wisdom.weizmann.ac.il/~itsik/RC4/Papers/Rc4_ksa.ps
    "  */
    for i in range(256)
        call s:arc4_getbyte()
    endfor
    let s:arc4_count = 1600000
endfunction

function! s:arc4_stir_if_needed()
    if s:arc4_count <= 0 " || !rs_initialized || arc4_stir_pid != pid)
        call s:arc4_stir()
    endif
endfunction

delfunction s:arc4_getbyte
function! s:arc4_getbyte()
    " u_int8_t si, sj;
    let rs = s:rs

    let rs.i = (rs.i + 1)%256
    let si = rs.s[rs.i]
    let rs.j = (rs.j + si)%256
    let sj = rs.s[rs.j]
    let rs.s[rs.i] = sj
    let rs.s[rs.j] = si
    return rs.s[(si + sj) % 256] " why is there '& 0xff' in the original code?
endfunction

" 32 bits -- I've had to use windows
function! s:arc4_getword()
    let val = s:LS(s:arc4_getbyte(), 24)
    let val += s:LS(s:arc4_getbyte(), 16)
    let val += s:LS(s:arc4_getbyte(), 8)
    let val += s:arc4_getbyte()
    return val
endfunction

function! Arc4random_stir()
    " OpenBSD needs this to lock properly
    call s:arc4_stir()
endfunction

function! Arc4random_addrandom(dat, datlen)
    "if (!rs_initialized)
    "	arc4_stir();
    call s:arc4_addrandom(a:dat, a:datlen)
endfunction

function! Arc4random()
    let s:arc4_count -= 4
    call s:arc4_stir_if_needed()
    let val = s:arc4_getword()
    return val
endfunction

function! Arc4random_buf(_buf, n)
    let buf = a:_buf
    let n = a:n
    call arc4_stir_if_needed()
    while n > 0
        let n -= 1
        let s:arc4_count -= 1
        if s:arc4_count <= 0
            call s:arc4_stir()
        endif
        let buf[n] = s:arc4_getbyte()
    endwhile
endfunction

" /*
"  * Calculate a uniformly distributed random number less than upper_bound
"  * avoiding "modulo bias".
"  *
"  * Uniformity is achieved by generating new random numbers until the one
"  * returned is outside the range [0, 2**32 % upper_bound).  This
"  * guarantees the selected random number will be inside
"  * [2**32 % upper_bound, 2**32) which maps back to [0, upper_bound)
"  * after reduction modulo upper_bound.
"  */
function! Arc4random_uniform(upper_bound)
    " http://www.openbsd.org/cgi-bin/cvsweb/src/lib/libc/crypt/arc4random.c.diff?r1=1.22;r2=1.23
    " The patch above is really beautiful imho;
    " let's adapt it to vim's int32!
    if a:upper_bound < 2
        if a:upper_bound < 0
            throw printf("arc4random_uniform(%d)", a:upper_bound)
        endif
        return 0
    endif

    "/* 2**32 % x == (2**32 - x) % x */
    let min = (0x7fffffff - a:upper_bound + 1) % a:upper_bound

    "/*
    " * This could theoretically loop forever but each retry has
    " * p > 0.5 (worst case, usually far better) of selecting a
    " * number inside the range we need, so it should rarely need
    " * to re-roll.
    " */
    let r = 0
    while 1
        let r = Arc4random()
        if r >= min
            break
        endif
    endwhile

    return r % a:upper_bound
endfunction

if len($DEBUG) > 0
    " Make sure it produces the same results as the original {{{
    " OpenBSD's test code does 1M iterations and prints #cycles (rdtsc()),
    " but I need to check that this is a faithful translation...
    let s:DebugRandomBytes = [
                \ 0x9c, 0x8c, 0xd8, 0xbb, 0x4f, 0x5f, 0x4f, 0x06,
                \ 0xf5, 0xe5, 0xaf, 0x9d, 0x0f, 0x3f, 0x97, 0xe6,
                \ 0xcb, 0x24, 0xcb, 0x90, 0x0d, 0xf3, 0x81, 0x10,
                \ 0x45, 0x43, 0x4f, 0xb1, 0xa2, 0x0f, 0x31, 0xcc,
                \ 0x2f, 0x90, 0x78, 0x8f, 0xa9, 0x9d, 0x8e, 0x87,
                \ 0x3e, 0x61, 0xa6, 0xd1, 0xfe, 0xcf, 0x07, 0x2d,
                \ 0x27, 0xca, 0x52, 0x48, 0xc2, 0xad, 0xf0, 0x91,
                \ 0xa4, 0x5a, 0x0c, 0x69, 0x55, 0x3f, 0xcd, 0xea,
                \ 0x57, 0x14, 0x13, 0x7b, 0xec, 0xdd, 0x22, 0x3e,
                \ 0xa8, 0xbf, 0x53, 0x83, 0xfd, 0x46, 0x50, 0x59,
                \ 0xea, 0x15, 0x2d, 0xde, 0xb3, 0x48, 0xa6, 0x43,
                \ 0xc8, 0xd7, 0x7d, 0x59, 0x5d, 0xba, 0xb9, 0x26,
                \ 0x39, 0x8b, 0x23, 0x39, 0x55, 0xb1, 0x46, 0x9f,
                \ 0xf6, 0xf8, 0x13, 0xe7, 0x8d, 0xc9, 0x5e, 0x8d,
                \ 0xfa, 0xbe, 0x97, 0x34, 0xec, 0x78, 0xb2, 0xdb,
                \ 0x2e, 0x97, 0x19, 0x26, 0x11, 0xef, 0x28, 0xde,
                \ ]
    let s:DebugExpected = [
                \ 0xc181cde7, 0xd9bc4ec9, 0xf29f31de, 0xbe9d38f0,
                \ 0x1f2b2403, 0xbc9da8cd, 0x82ee7bd6, 0xebcc448a,
                \ 0xb2f4d078, 0x9d61ead0, 0xfa089b1c, 0xcdc5e870,
                \ 0x783ed21f, 0xb602890f, 0x47cb6fce, 0x5adedbcd,
                \ 0x9674feb7, 0x6e3868c9, 0x81bfd445, 0xbb51943c,
                \ 0x9a8839e8, 0xe5613e31, 0x3a940dda, 0xd3b4df63,
                \ 0x3a0f68f7, 0x1897ecc5, 0x4feeae17, 0xb8d0e986,
                \ 0x51486e6d, 0x609f4e9a, 0x31566c52, 0x96862d5a,
                \ 0x78f6286a, 0x159deee7, 0xf887a047, 0x3eb2ec23,
                \ 0x996c5ec4, 0xe71a2277, 0x22d8d378, 0x4dc694ca,
                \ 0x5b45a8a6, 0x5d9f5b5e, 0xe6c89ba2, 0xd3d6ddd0,
                \ 0x61e971f6, 0x476bacd1, 0x93674f75, 0x6311fa97,
                \ 0x10bd41d6, 0x2db98787, 0x067b4bc1, 0xe10ecb24,
                \ 0xd8ef5907, 0x4dfcff6d, 0xf40a76df, 0xdf044c5d,
                \ 0xf2369855, 0xdb5ac6be, 0xd874708b, 0xc6e01b7e,
                \ 0x6ffa2490, 0x9ae2a075, 0xefc69192, 0x35089ba1,
                \ 0x471ce45c, 0xa354815a, 0x8cc08c56, 0x2e0641f4,
                \ 0x7070ca0d, 0x8c58f7ac, 0xb336c2d9, 0x8d72940a,
                \ 0x9a98faff, 0xfb7a2312, 0x151f6aca, 0x3f3bd5bd,
                \ 0xad3f38c9, 0x7ee3e177, 0x23bd71ba, 0xdd2cae9c,
                \ 0x914c6799, 0x438895aa, 0xf649a6bd, 0x89f49f1d,
                \ 0x0fc2dd40, 0xe9178003, 0xa670313e, 0x868d0902,
                \ 0x32988f4a, 0xe9f20fc1, 0x4e824d71, 0x1277f46b,
                \ 0x3f7f686a, 0x486ce4fb, 0x79212785, 0x710116dc,
                \ 0x7bee323f, 0xcd99906a, 0x7b74d1ff, 0x8a58ea14,
                \ 0x49f96c39, 0x4a0a1be5, 0x18edd277, 0xc6a4d6b5,
                \ 0x0131ddfb, 0xe6c8ded4, 0x13187321, 0x770830f6,
                \ 0x2e643d8d, 0x2bd5e137, 0x4bdc0767, 0xc57be48a,
                \ 0x66410539, 0x87675d93, 0x045f59e0, 0x16da5656,
                \ 0xeb517888, 0xf8534ae5, 0xaf2b8833, 0x57109f96,
                \ 0x5488f56d, 0x56005bf1, 0x588b0b15, 0x7f22fbe7,
                \ 0x3e467adb, 0x869b0b75, 0x8da0ad9b, 0xd7610957,
                \ 0x461b2660, 0xd4d84b87, 0xbcd88035, 0x6ea7c273,
                \ 0x635ca7bc, 0xcb5f04c6, 0x469e3c34, 0x3e0e4e70,
                \ 0x2505ded0, 0x8f8c1a08, 0xd4085b6e, 0x1e69621f,
                \ 0xc6680d56, 0x1c448a3b, 0xcc738e15, 0x700b061e,
                \ 0x835536fa, 0x0234aab8, 0x73d4c36b, 0xb0257c3b,
                \ 0x564a3a6c, 0xb6ed6c85, 0xbe442012, 0xd99a5c38,
                \ 0xff7e323e, 0xa0490820, 0x64851f68, 0xcca148b8,
                \ 0x583d9e2d, 0x09827eaa, 0xc768344c, 0x5d48fc8b,
                \ 0x61c39e75, 0xb4dadce0, 0x1630d105, 0xa4d48a1f,
                \ 0x59f7beac, 0x1edeecae, 0x46ca1036, 0x4312e7d7,
                \ 0xa3f0935f, 0xdc1fed5c, 0x6f343653, 0xd808faa1,
                \ 0xecc63948, 0x9ecb6c19, 0xc2d70b78, 0xdfe3ce71,
                \ 0xc58d0d81, 0xb84995af, 0x6dc0b848, 0x89ec135a,
                \ 0xef677b9d, 0x8c4d3a5c, 0x624b3214, 0xd25df3b5,
                \ 0x5a4bac29, 0xe14e122c, 0x6a72f040, 0x34de0356,
                \ 0xa7f6c9aa, 0x6b9c73bc, 0xc916d9c6, 0x52ba773e,
                \ 0x6151057a, 0x716893d6, 0x1ad89f49, 0xd3e80ddf,
                \ 0x921ddd48, 0xf87dbf47, 0xffab0c51, 0x904c7dcb,
                \ 0x373a7736, 0xa686624a, 0x2114464f, 0x63325042,
                \ 0xd05a508f, 0xb5566407, 0xe5ce9d32, 0x06fb65a8,
                \ 0xac8a49e0, 0x0ea529f0, 0x4474577f, 0xc6a1f85f,
                \ 0xe1d2efe1, 0xf674e2c6, 0xe81addc3, 0x8d1266b9,
                \ 0xbb13768d, 0x43a859ef, 0xbbdb1738, 0xba32bb63,
                \ 0x01ce43e2, 0x4f4d00e7, 0x690f8f02, 0x95b19744,
                \ 0xfd537820, 0xea58081b, 0x3661908c, 0x50d2a27a,
                \ 0xe4767a0c, 0x4b3b9567, 0xfacab0db, 0x411ab7f3,
                \ 0x63cac997, 0xe3eeaf55, 0x5218cf06, 0x970c8a0e,
                \ 0xcc9e49e8, 0x297bd5b1, 0x9cbff152, 0x2fef1aa7,
                \ 0x5134fadb, 0x356520f6, 0x557a6bd8, 0x9c916680,
                \ 0x2bd6e5d3, 0x13897752, 0x3c1b650d, 0x5d7d32ff,
                \ 0xb866e0a0, 0xb2c830ec, 0x404cdb98, 0xa4b2e8ed,
                \ 0x254190a4, 0x64a75557, 0x9dd5e576, 0x686b9011,
                \ 0x60b67c6d, 0x5b3097da, 0xe134f2ff, 0xbe0abd24,
                \ 0x6a099e88, 0xfe656eac, 0xcd595f4d, 0xfbe04421,
                \ 0xf3169ec6, 0xdc49efd9, 0xe14f6c72, 0xa87751ba,
                \ 0xb9c21f71, 0xb786677b, 0x380238aa, 0xbb1ed440,
                \ 0x77170b4f, 0xff98f22f, 0xd7d2bdc2, 0xf088edec,
                \ 0x880f68ff, 0xbca5d337, 0x1c2f00bf, 0x0271b708,
                \ 0xa7756331, 0xa60a2400, 0x3462eb6c, 0xf2d3c6e0,
                \ 0xce02a6bb, 0xb0183bb1, 0x7b38189b, 0xaaf42b85,
                \ 0x26fa23f4, 0x675eda79, 0xf492be0a, 0xa1571151,
                \ 0x170346dc, 0x0db63eff, 0x5105d6d9, 0x01d9bac2,
                \ 0x2655ae6f, 0x1df11212, 0x67cadd5d, 0xa197eb08,
                \ 0x8de6d372, 0x11c88f4f, 0x0f4a1f18, 0xa3c0a88e,
                \ 0xfdb2071d, 0xc51bdf0b, 0x4218e78e, 0xebedc171,
                \ 0xc80c953c, 0x89decadf, 0x2d602448, 0xeb9e455b,
                \ 0xf2723058, 0x525a56d9, 0x4d6908e0, 0x58117ddf,
                \ 0x93159fe5, 0xcb70d5fe, 0xb0313805, 0x50c1eeaa,
                \ 0x4a7a5cfc, 0xfaa9ea3a, 0xa540bb76, 0x1ff6f70d,
                \ 0x91d009c8, 0x65bae274, 0x2ca12b4c, 0x05c542dd,
                \ 0xf1c90dbb, 0x8664d228, 0x089708e0, 0x0e42ae4b,
                \ 0x947de2f0, 0xc6dc208b, 0x1b2e3636, 0xb9394092,
                \ 0x97ac0076, 0xbe342127, 0x717d56dd, 0x949b0aa9,
                \ 0xdd101917, 0x38113434, 0x8c5b60b8, 0x6ba6f147,
                \ 0x93a9f457, 0x329f6c41, 0x92eea429, 0x853c78e3,
                \ 0x5b5892a5, 0xf8a00dc8, 0x69a00d5a, 0x7640f3d0,
                \ 0x1e33edd6, 0x36c1239b, 0x167e1735, 0xc8a6fc65,
                \ 0x5bb5c1af, 0xf0fea228, 0x70760528, 0x065e80b9,
                \ 0x9e920094, 0x51f3bfb5, 0x60bd1895, 0x6f965d88,
                \ 0xa5c1b13f, 0x6a5245be, 0x4f726db7, 0x56991d0a,
                \ 0xdc5ae005, 0x9c9004d7, 0x1b8e7a65, 0x898fc25b,
                \ 0xa0159e7c, 0xef0c3daa, 0x1ce3d4bc, 0x63f14e60,
                \ 0x60a74a12, 0x27169f3d, 0x21d94aef, 0xec690955,
                \ 0x7dab9e37, 0x29202449, 0xbf7c752d, 0x074f59a5,
                \ 0x895c01cf, 0x234893e2, 0xe9568460, 0xfbfe537f,
                \ 0xe88ce537, 0x2b1aa26e, 0x0a14205f, 0xdb73f75f,
                \ 0xc7107102, 0x5003c79d, 0xdc5a06b2, 0x0d39ed23,
                \ ]
    if len(s:DebugRandomBytes) != 128
        throw  's:DebugRandomBytes'
    endif
    " FIXME copypasta!
    call s:arc4_addrandom(s:DebugRandomBytes, len(s:DebugRandomBytes))
    for i in range(256)
        call s:arc4_getbyte()
    endfor
    let s:arc4_count = 1600000
    for i in range(len(s:DebugExpected))
        let want = s:DebugExpected[i]
        let got = Arc4random()
        if want == got
            continue
        endif
        throw printf('arc4random#%d: want %d, got %d', i, want, got)
    endfor
    unlet got
    unlet want
    unlet s:DebugExpected
    unlet s:DebugRandomBytes
    " }}}
    echomsg 'Compatibility with arc4random(3)... ok'
endif

call s:arc4_stir()  " Init, possibly destroying debug-only values.

