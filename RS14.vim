" Spritz - a spongy RC4-like stream cipher and hash function
" http://people.csail.mit.edu/rivest/pubs/RS14.pdf

" Spritz is defined for any N>2; in the paper, N is a parameter,
" while here N = 256 is hardcoded.
"
" The API and parameters are named like in the paper, prefixed "RS14"
" -- Exceptions: InitializeState(), Output(), Q->ctx
"
" Functions like Crush() etc are kept private.
"
" Spritz (used as a hash) is known to be very slow;
" -- try rewriting it in C and compare with sha256!
"
" "TLDR" stands for "if you didn't read the paper, and don't mean to"


" The (optional) arguments are keys, separated by absorbStop()
function! RS14New(...)
        let x = {}
        let x.i = 0
        let x.j = 0
        let x.k = 0
        let x.z = 0
        let x.a = 0
        let x.w = 1
        let x.S = range(256)
        let absorbStop = 0      " absorbStop() after 1st argument.
        for k in a:000
                if absorbStop
                        call RS14absorbStop(x)
                endif
                let absorbStop = 1
                call RS14absorb(k, x)
        endfor
        return x
endfunction


function! RS14absorb(I, ...)
        if a:0 == 0
                return RS14absorb(a:I, s:spritz)
        endif
        " string/byte array?
        " Kudos to junegunn/vim-plug/plug.vim,
        " first for letting me know about type(),
        " and second for showing that if you try really really hard (I didn't)
        " you can actually write pleasant vimscript!
        if type(a:I) == type("s")
                let a = []
                let i = 0
                while i < len(a:I)
                        let a += [char2nr(a:I[i])]
                        let i += 1
                endwhile
                return RS14absorb(a, a:1)
        endif
        if type(a:I) != type([])
                throw printf("absorb(%s)", string(a:I))
        endif
        for b in a:I
                " char2nr() returns unsigned char;
                " char2nr('€') is 8364, len('€')==3 even with utf-16?
                " I should investigate, but utf-16 must die anyway...
                if b < 0 || b > 0xFF
                        throw printf("byte %d?", b)
                endif
                call s:absorbByte(b, a:1)
        endfor
endfunction


function! s:absorbByte(b, ctx)
        call s:absorbNibble(a:b%16, a:ctx)
        call s:absorbNibble(a:b/16, a:ctx)
endfunction

function! s:swap(A, i, j)
        let tmp      = a:A[a:i]
        let a:A[a:i] = a:A[a:j]
        let a:A[a:j] = tmp
endfunction

function! s:absorbNibble(x, ctx)
        if a:ctx.a == 128
                call s:shuffle(a:ctx)
        endif
        call s:swap(a:ctx.S, a:ctx.a, 128+a:x)
        let a:ctx.a += 1
endfunction

" TLDR: use this as a delimiter between eg key and iv.
function! RS14absorbStop(...)
        if a:0 == 0
                return RS14absorbStop(s:spritz)
        endif
        let ctx = a:1
        if ctx.a == 128
                call s:shuffle(ctx)
        endif
        let ctx.a += 1
endfunction

function! s:shuffle(ctx)
        call s:whip(2*256, a:ctx)
        call s:crush(a:ctx)
        call s:whip(2*256, a:ctx)
        call s:crush(a:ctx)
        call s:whip(2*256, a:ctx)
        let a:ctx.a = 0
endfunction

function! s:whip(r, ctx)
        for v in range(a:r)
                call s:update(a:ctx)
        endfor
        " w = w + 1 until gcd(N,w) == 1
        let a:ctx.w = (a:ctx.w + 2) % 256
endfunction

function! s:crush(ctx)
        let S = a:ctx.S
        for v in range(128)
                if S[v] > S[256 - 1 - v]
                        call s:swap(S, v, 256 - 1 - v)
                endif
        endfor
endfunction


function! s:drip(ctx)
        if a:ctx.a > 0
                call s:shuffle(a:ctx)
        endif
        call s:update(a:ctx)
        let S = a:ctx.S
        " The following line was giving me wrong results:
        " let a:ctx.z = S[(a:ctx.j + S[( + S[(a:ctx.z + a:ctx.k)%256]) % 256]) % 256]
        " ... in a way it's funny, because I wrote this like in the paper,
        " ie with globals, and then introduced "a:ctx" via :s,
        " so I guess we can blame normal mode for this bug ^^
        let a:ctx.z = S[(a:ctx.j + S[(a:ctx.i + S[(a:ctx.z + a:ctx.k)%256]) % 256]) % 256]
        return a:ctx.z
endfunction

" TLDR: return an array of bytes from the keystream.
function! RS14squeeze(r, ...)
        if a:0 == 0
                return RS14squeeze(a:r, s:spritz)
        endif
        let ctx = a:1
        if ctx.a > 0
                call s:shuffle(ctx)
        endif
        let P = range(a:r)
        for v in P
                let P[v] = s:drip(ctx)
        endfor
        return P
endfunction

" TLDR: return a byte of keystream.
function! RS14drip(...)
        return s:drip(a:0 == 0 ? s:spritz : a:1)
endfunction

function! s:update(ctx)
        let ctx = a:ctx
        let ctx.i = (ctx.i + ctx.w) % 256
        let ctx.j = (ctx.k + ctx.S[(ctx.j + ctx.S[ctx.i]) % 256]) % 256
        let ctx.k = (ctx.i + ctx.k + ctx.S[ctx.j]) % 256
        call s:swap(ctx.S, ctx.i, ctx.j)
endfunction

" Same as RS14packhashbytes, but operating on bits for convenience.
function! RS14packhashbits(bits)
        if a:bits%8
                throw "seriously..."
        endif
        return RS14packhashbytes(a:bits / 8)
endfunction

" Convert #bytes into the binary format expected by the Spritz hash function.
function! RS14packhashbytes(r)
        if a:r < 1
                throw printf("%s bytes?", string(r))
        endif
        let bytes = []
        let r = a:r
        while r > 0
                let bytes = [r%256] + bytes
                let r = r / 256
        endwhile
        while bytes[0] == 0
                call remove(bytes, 0)
        endwhile
        return bytes
endfunction

" Mostly to test absorbStop(); remember 'r' is in bytes, not bits.
function! RS14hash(M, r)
        let ctx = RS14New()
        call RS14absorb(a:M, ctx)
        call RS14absorbStop(ctx)
        let bytes = RS14packhashbytes(a:r)
        call RS14absorb(bytes, ctx)
        return RS14squeeze(a:r, ctx)
endfunction


function! s:testcipher(key, vec)
        let ctx = RS14New(a:key)
        let got = RS14squeeze(len(a:vec), ctx)
        if got == a:vec
                return
        endif
        throw printf("RS14(%s): %s got %s", string(a:key), string(a:vec), string(got))
endfunction

function! s:testhash(M, r, H)
        let h = RS14hash(a:M, a:r)
        " The test vectors in the paper are SHORTENED...
        for i in range(len(a:H))
                if a:H[i] == h[i]
                        continue
                endif
                throw printf("RS14hash(%s, r=%d): %s, got %s", string(a:M), a:r,
                                        \ string(a:H), string(h))
        endfor
endfunction


" Test vectors.
function! RS14selftest()
        " Basic Spritz output - ie, stream cipher:
        call s:testcipher("ABC", [0x77, 0x9a, 0x8e, 0x01, 0xf9, 0xe9, 0xcb, 0xc0])
        call s:testcipher("spam", [0xf0, 0x60, 0x9a, 0x1d, 0xf1, 0x43, 0xce, 0xbf])
        call s:testcipher("arcfour", [0x1a, 0xfa, 0x8b, 0x5e, 0xe3, 0x37, 0xdb, 0xc7])
        " Spritz hash function (256 bits):
        let r = 256/8
        call s:testhash("ABC",r,[0x02, 0x8f, 0xa2, 0xb4, 0x8b, 0x93, 0x4a, 0x18,])
        call s:testhash("spam",r,[0xac, 0xbb, 0xa0, 0x81, 0x3f, 0x30, 0x0d, 0x3a])
        call s:testhash("arcfour",r,[0xff, 0x8c, 0xf2, 0x68, 0x09, 0x4c, 0x87, 0xb9,])
endfunction

if len($DEBUG) > 0
        call RS14selftest()
        echo 'selftest ok'
endif


" Convenience; 35/40 times slower than Xkcd221().
function! RS14i32()
        return s:drip(s:spritz)*0x1000000 + s:drip(s:spritz)*0x10000
                                \ + s:drip(s:spritz)*0x100 + s:drip(s:spritz)
endfunction

function! RS14i31()
        return s:drip(s:spritz)*0x800000 + s:drip(s:spritz)*0x8000
                                \ + s:drip(s:spritz)*0x80 + s:drip(s:spritz)/2
endfunction


" Seed the global generator.
let s:spritz = RS14New(hostname(), string(getpid()))
call RS14absorbStop()
try
        call RS14absorb(string(reltimestr(reltime())))
catch /.*E117/
        call RS14absorb(string(localtime()))
endtry
call RS14absorbStop()
" call RS14absorb(string(v:)) -- this takes SECONDS! ditto values(v:)
" call RS14absorb(string(g:)) -- often almost as long as v:
" call RS14absorb(string(b:)) -- this may take ~1s...


