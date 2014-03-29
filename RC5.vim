" RC5 is a trademark of RSA Data Security, and it's patented.
" It's also beautiful in many ways, the only exception being
" the variable names used in the paper (read it!)
"
" RC5(r,w,b)
"       r #rounds
"       w #bits
"       b bytes in the key, [0-255]
" The paper suggests RC5-32/8/0 (ie: no key) in counter mode
" to generate random values where crypto is not needed...
"
" '''
" RC5 is well defined for any w > 0, although for simplicity
" it is proposed here that only the values 16,32 and 64 be "allowable"
" '''

" --------------------- byte operations --------------------------------
let s:pow2 = [1]
while 1
        let n = s:pow2[len(s:pow2)-1]
        if n < 0
                break
        endif
        let s:pow2 += [n*2]
endwhile
let s:wordbits = len(s:pow2)    " aka 'w'
let s:MSB      = s:pow2[len(s:pow2)-1]
let s:NSB      = s:pow2[len(s:pow2)-2]

" Rotations can have any value of K; shifts are bounded to [0,w)
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

function! s:RC5ROTL(x, n)
        let w = s:wordbits
        let n = and(a:n, w-1)
        if n == 0
                return a:x
        endif
        return s:leftshift(a:x,n) + s:rightshift(a:x,w-n)
endfunction
function! s:RC5ROTR(x, n)
        let w = s:wordbits
        let n = and(a:n, w-1)
        return s:leftshift(a:x,w-n) + s:rightshift(a:x,n)
endfunction
" TODO they say that data dependent rotations take constant time,
" TODO but salsafamily-20071225.pdf claims the opposite???
" http://citeseerx.ist.psu.edu/viewdoc/download?doi=10.1.1.1.7836&rep=rep1&type=pdf
" says it happens with eg 8-bit processors

" --------------------- block encryption --------------------------------
function! RC5encrypt(block, S, r)
        let A = a:block[0]
        let B = a:block[1]
        let S = a:S
        let r = a:r
        let A = A + S[0]
        let B = B + S[1]
        " i=1; i<=r
        for i in range(1,r)
                let A = s:RC5ROTL(xor(A,B), B) + S[2 * i]
                let B = s:RC5ROTL(xor(B,A), A) + S[2 * i + 1]
        endfor
        return [A,B]
endfunction

" constants based on e and the golden ratio
if s:wordbits == 16
        throw "can't happen"
elseif s:wordbits == 32
        let s:Pw = 0xb7e15163
        let s:Qw = 0x9e3779b9
elseif s:wordbits == 64
        let s:Pw = 0xb7e151628aed2a6b
        let s:Qw = 0x9e3779b97f4a7c15
else
        throw print("%d bits?", s:wordbits)
endif

function! RC5new(key, numrounds)
        if len(a:key) < 1
                return RC5new([0], a:numrounds)
        endif
        let w = s:wordbits
        let u = w/8
        let r = a:numrounds
        let K = a:key
        let b = len(K)
        let c = b / u
        if b % u
                let c += 1
        endif
        " bytes to words
        let L = repeat([0], c)
        let i = b-1
        while i >= 0
                if K[i] < 0 || K[i] > 0xff
                        throw "bytes"
                endif
                let L[i/u] = s:leftshift(L[i/u],8) + K[i]
                let i -= 1
        endwhile
        " initialize S
        let t = 2 * (r+1)
        let S = range(t)
        for i in range(t)
                if i == 0
                        let S[i] = s:Pw
                else
                        let S[i] = S[i-1] + s:Qw
                endif
        endfor
        " mix the key into S
        let i = 0
        let j = 0
        let A = 0
        let B = 0
        for times in range(3 * max([t,c]))
                let A = s:RC5ROTL(S[i]+A+B, 3)
                let S[i] = A
                let B = s:RC5ROTL(L[j]+A+B, A+B)
                let L[j] = B
                let i = (i + 1) % t
                let j = (j + 1) % c
        endfor
        return { "S":S, "r":r }
endfunction

" --------------------- rand(), srand() --------------------------------
" nominal choices (for encryption): 12 rounds for 32 bits, 16 for 64 bits
let s:ctr = [getpid(), localtime()]
function! RC5uint()
        if s:num == 0
                let s:ctr[0] += 1
                if s:ctr[0] == 0
                        let s:ctr[1] += 1
                endif
                let s:enc = RC5encrypt(s:ctr, s:x.S, s:x.r)
                let s:num = 2
        endif
        let s:num -= 1
        return s:enc[s:num]
endfunction
function! RC5int()
        let x = RC5uint()
        if x < 0
                return 0 - (x+1)
        endif
        return x
endfunction
function! RC5setcipher(x)       " result of RC5new()
        let s:x = a:x
        let s:num = 0
endfunction
call RC5setcipher(RC5new(range(255),8))
" TODO the key should be taken from a string, eg string(v:)
" TODO RC5setIV()?

" --------------------- RC5 test vectors --------------------------------
function! s:testvector(key, plaintext, ciphertext, rounds)
        let x = RC5new(a:key, a:rounds)
        let e = RC5encrypt(a:plaintext, x.S, x.r)
        if e == a:ciphertext
                return
        endif
        let errmsg = printf("rc5(%s): want [%x %x] got [%x %x]",
                                \ string(a:key),
                                \ a:ciphertext[0], a:ciphertext[1],
                                \ e[0], e[1])
        echoerr errmsg
        throw errmsg
endfunction
function! RC5selftest()
        " encrypt; encrypt the resulting text with a different key; repeat.
        if s:wordbits == 32
                let rounds = 12
                " ftp://ftp.rsasecurity.com/pub/rsalabs/rc5/rc5.tex
                let key = [0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]
                let plaintext = [0x00000000, 0x00000000]
                let ciphertext = [0xEEDBA521, 0x6D8F4B15]
                call s:testvector(key, plaintext, ciphertext, rounds)

                let key = [0x91, 0x5F, 0x46, 0x19, 0xBE, 0x41, 0xB2, 0x51, 0x63, 0x55, 0xA5, 0x01, 0x10, 0xA9, 0xCE, 0x91]
                let plaintext = [0xEEDBA521, 0x6D8F4B15]
                let ciphertext = [0xAC13C0F7, 0x52892B5B]
                call s:testvector(key, plaintext, ciphertext, rounds)

                let key = [0x78, 0x33, 0x48, 0xE7, 0x5A, 0xEB, 0x0F, 0x2F, 0xD7, 0xB1, 0x69, 0xBB, 0x8D, 0xC1, 0x67, 0x87]
                let plaintext = [0xAC13C0F7, 0x52892B5B]
                let ciphertext = [0xB7B3422F, 0x92FC6903]
                call s:testvector(key, plaintext, ciphertext, rounds)

                let key = [0xDC, 0x49, 0xDB, 0x13, 0x75, 0xA5, 0x58, 0x4F, 0x64, 0x85, 0xB4, 0x13, 0xB5, 0xF1, 0x2B, 0xAF]
                let plaintext = [0xB7B3422F, 0x92FC6903]
                let ciphertext = [0xB278C165, 0xCC97D184]
                call s:testvector(key, plaintext, ciphertext, rounds)

                let key = [0x52, 0x69, 0xF1, 0x49, 0xD4, 0x1B, 0xA0, 0x15, 0x24, 0x97, 0x57, 0x4D, 0x7F, 0x15, 0x31, 0x25]
                let plaintext = [0xB278C165, 0xCC97D184]
                let ciphertext = [0x15E444EB, 0x249831DA]
                call s:testvector(key, plaintext, ciphertext, rounds)
        else
                throw printf("TODO test vectors for %d bits", s:wordbits)
        endif
endfunction

if len($DEBUG) > 0
        echomsg "testing RC5..."
        call RC5selftest()
        echomsg "ok!"
endif


