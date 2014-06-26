" NSA's Speck cipher; http://eprint.iacr.org/2013/404

" It's kinda funny that this cipher is meant to be super fast,
" and it is very, __very__ fast; except that as you move far away
" from the metal (say, C->java->perl) it becomes slower than the competition.
" In vimscript it's almost 200x slower than xkcd221().


" ----------------- byte operations (from RC5) ---------------------------
let s:pow2 = [1]
while 1
        let n = s:pow2[len(s:pow2)-1]
        if n < 0
                break
        endif
        let s:pow2 += [n*2]
endwhile
let s:nbits     = len(s:pow2)    " aka 'n', as in Simon(2n,mn)
let s:nbytes    = s:nbits / 8
let s:MSB       = s:pow2[len(s:pow2)-1]
let s:NSB       = s:pow2[len(s:pow2)-2]

function! s:leftshift(x, k)
        return a:x * s:pow2[a:k]
endfunction
function! s:rightshift(x, k)
        if a:x < 0
                " The sign bit would be cleared anyway
                let x = a:x + s:MSB
                let x = x / 2
                let x = or(x, s:NSB)
                return s:rightshift(x, a:k - 1)
        endif
        return a:x / s:pow2[a:k]
endfunction

" The rotation amounts are fixed
function! s:ROTL(x, n)
        return s:leftshift(a:x, a:n) + s:rightshift(a:x, s:nbits - a:n)
endfunction
function! s:ROTR(x, n)
        return s:rightshift(a:x, a:n) + s:leftshift(a:x, s:nbits - a:n)
endfunction


" -------------------------- Speck encryption -----------------------------

" Key sizes for different word sizes.
" Refuse 16 bits because:
" - vim's integers are always >= 32 bits
" - 16 bits has (7,2) instead of (8,3) ==> hardcode them.
if s:nbits == 16
        throw "can't be 16 bits!"
elseif s:nbits == 24
        " can't happen - vim integers are >= 32 bits.
        let s:RoundsFromKeybits = { 72:22, 96:23 }
elseif s:nbits == 32
        let s:RoundsFromKeybits = { 96:26, 128:27 }
elseif s:nbits == 48
        let s:RoundsFromKeybits = { 96:28, 144:29 }
elseif s:nbits == 64
        let s:RoundsFromKeybits = { 128:32, 192:33, 256:34 }
else
        throw printf("do you have %d bits?", s:nbits)
endif
let s:ScheduleLengths = values(s:RoundsFromKeybits)

" #define R(x,y,k) (x=RCS(x,8), x+=y, x^=k, y=LCS(y,3), y^=x)
" R(ct[1], ct[0], k[i]);
" XXX did they switch 1<-->0 or what???
" by comparing the SPECK pseudocode with their reference code,
" it seems the refcode is wrong - they call the plaintext 'x,y',
" meaning x = ct[0] -- initialized with pt[0],
" and yet they got it backwards in the reference code:
" R(ct[1],ct[0],k[i]) should be R(ct[0], ct[1], k[i])!!!
function! SpeckEncrypt(pt, ct, keyschedule)
        if index(s:ScheduleLengths, len(a:keyschedule)) < 0
                throw "keyschedule?"
        endif
        " ct0,ct1 buys a ~10% speedup;
        " compacting the loop to just 2 lines yields a smaller speedup.
        let ct0 = a:pt[0]
        let ct1 = a:pt[1]
        let k = a:keyschedule
        for i in range(len(a:keyschedule))
                let ct0 = xor(s:ROTR(ct0, 8) + ct1, k[i])
                let ct1 = xor(s:ROTL(ct1, 3), ct0)
        endfor
        let a:ct[0] = ct0
        let a:ct[1] = ct1
endfunction

" takes an integer array
function! SpeckExpandKey(key)
        let T = s:RoundsFromKeybits[len(a:key) * s:nbits]
        let k = range(T)
        let m = len(a:key)
        let l = range(m)
        for i in range(m)
                " yep, l[m-1] is __not__ filled here.
                let l[i] = a:key[m-i-2]
        endfor
        let k[0] = a:key[m - 1]
        for i in range(T-1)     " yep, minus one
                let j = (i + m - 1) % m
                let l[j]     = xor(i, k[i] + s:ROTR(l[i%m],8))
                let k[i + 1] = xor(s:ROTL(k[i], 3), l[j])
        endfor
        return k
endfunction

" takes a byte array
function! SpeckExpandKeyBytes(key)
        for b in a:key
                if b < 0 || b > 0xff
                        throw "bytes!"
                endif
        endfor
        let kw = repeat([0], (len(a:key) + s:nbytes - 1) / s:nbytes)
        for i in range(len(a:key))
                let j = i / s:nbytes
                let kw[j] = kw[j] * 256
                let kw[j] += a:key[i]
        endfor
        return SpeckExpandKey(kw)
endfunction

" Pass in a big string, eg string(v:)
function! SpeckExpandString(str)
        let b = []
        for i in range(len(a:str))
                let b += [char2nr(a:str[i])]
        endfor
        let idx = 0
        let keybits = keys(s:RoundsFromKeybits)
        let maxkeylen = keybits[len(keybits)-1] / s:nbits
        while len(b) > maxkeylen * s:nbytes
                let val = remove(b, -1)
                let idx = idx + 1
                let b[idx%len(b)] = xor(b[idx%len(b)]*3, val) % 256
        endwhile
        return SpeckExpandKeyBytes(b)
endfunction

function! SpeckSetIV(iv)
        if len(a:iv) != 2
                throw "iv[2]"
        endif
        let s:ctr = copy(a:iv)
endfunction

function! SpeckSetKeySchedule(ks)
        let s:keyschedule = a:ks
        let s:got = 0
endfunction


" --------------------- rand(), srand() --------------------------------

let s:enc = [0,0]
call SpeckSetIV([getpid(), localtime()])
call SpeckSetKeySchedule(SpeckExpandString(string(v:)))
function! Speckuint()
        if s:got == 0
                let s:ctr[0] += 1
                if s:ctr[0] == 0
                        let s:ctr[1] += 1
                endif
                call SpeckEncrypt(s:ctr, s:enc, s:keyschedule)
                let s:got = 2
        endif
        let s:got -= 1
        return s:enc[s:got]
endfunction
function! Speckint()
        let x = Speckuint()
        if x < 0
                return 0 - (x+1)
        endif
        return x
endfunction


" --------------------- Speck test vectors --------------------------------
function! s:testvector(algo, key, plaintext, ciphertext)
        let keyschedule = SpeckExpandKey(a:key)
        let enc = [0,0]
        call SpeckEncrypt(a:plaintext, enc, keyschedule)
        if enc == a:ciphertext
                return
        endif
        let errmsg = printf("%s(%s): [%x %x] => want [%x %x] got [%x %x]",
                                \ a:algo,
                                \ string(a:key),
                                \ a:plaintext[0], a:plaintext[1],
                                \ a:ciphertext[0], a:ciphertext[1],
                                \ enc[0], enc[1])
        echoerr errmsg
        throw errmsg
endfunction
function! Speckselftest()
        echomsg "testing Speck..."
        if s:nbits == 24
                let alg = "Speck 48/72"
                let Key = [0x121110 ,0x0a0908 ,0x020100]
                let Plaintext = [0x20796c ,0x6c6172]
                let Ciphertext = [0xc049a5 ,0x385adc]
                call s:testvector(alg, Key, Plaintext, Ciphertext)
                let alg = "Speck 48/96"
                let Key = [0x1a1918 ,0x121110 ,0x0a0908 ,0x020100]
                let Plaintext = [0x6d2073 ,0x696874]
                let Ciphertext = [0x735e10 ,0xb6445d]
                call s:testvector(alg, Key, Plaintext, Ciphertext)
        elseif s:nbits == 32
                let alg = "Speck 64/96"
                let Key = [0x13121110 ,0x0b0a0908 ,0x03020100]
                let Plaintext = [0x74614620 ,0x736e6165]
                let Ciphertext = [0x9f7952ec ,0x4175946c]
                call s:testvector(alg, Key, Plaintext, Ciphertext)
                let alg = "Speck 64/128"
                let Key = [0x1b1a1918 ,0x13121110 ,0x0b0a0908 ,0x03020100]
                let Plaintext = [0x3b726574 ,0x7475432d]
                let Ciphertext = [0x8c6fa548 ,0x454e028b]
                call s:testvector(alg, Key, Plaintext, Ciphertext)
        elseif s:nbits == 48
                let alg = "Speck 96/96"
                let Key = [0x0d0c0b0a0908 ,0x050403020100]
                let Plaintext = [0x65776f68202c ,0x656761737520]
                let Ciphertext = [0x9e4d09ab7178 ,0x62bdde8f79aa]
                call s:testvector(alg, Key, Plaintext, Ciphertext)
                let alg = "Speck 96/144"
                let Key = [0x151413121110 ,0x0d0c0b0a0908 ,0x050403020100]
                let Plaintext = [0x656d6974206e ,0x69202c726576]
                let Ciphertext = [0x2bf31072228a ,0x7ae440252ee6]
                call s:testvector(alg, Key, Plaintext, Ciphertext)
        elseif s:nbits == 64
                let alg = "Speck 128/128"
                let Key = [0x0f0e0d0c0b0a0908 ,0x0706050403020100]
                let Plaintext = [0x6c61766975716520 ,0x7469206564616d20]
                let Ciphertext = [0x ,0xa65d985179783265 ,0x7860fedf5c570d18]
                call s:testvector(alg, Key, Plaintext, Ciphertext)
                let alg = "Speck 128/192"
                let Key = [0x1716151413121110 ,0x0f0e0d0c0b0a0908 ,0x0706050403020100]
                let Plaintext = [0x7261482066656968 ,0x43206f7420746e65]
                let Ciphertext = [0x1be4cf3a13135566 ,0xf9bc185de03c1886]
                call s:testvector(alg, Key, Plaintext, Ciphertext)
                let alg = "Speck 128/256"
                let Key = [0x1f1e1d1c1b1a1918 ,0x1716151413121110 ,0x0f0e0d0c0b0a0908 ,0x0706050403020100]
                let Plaintext = [0x65736f6874206e49 ,0x202e72656e6f6f70]
                let Ciphertext = [0x4109010405c0f53e ,0x4eeeb48d9c188f43]
                call s:testvector(alg, Key, Plaintext, Ciphertext)
        endif
        echomsg "ok!"
endfunction

if len($DEBUG) > 0
        call Speckselftest()
endif


