" RC6 is a trademark of RSA Data Security, and it's patented.
" It's largely based on RC5, so most comments stil apply.
" The two ciphers, and the description of how RC6 was born out of RC6,
" are an insanely interesting read, only surpassed by djb's description
" of salsa20's rationale (imho), which among other things points out that
" there are machines on which multiplications and data-dependent rotations
" are difficult to get right in constant time.
"
" An amusing difference between the papers is that djb writes in a very terse
" style - you'll likely miss some important point if you don't read very
" carefuly, while RC6 is written to be read easily; yet, RC[56] uses
" one-letter, non mnemonic variable names (L, c, ...), while djb has variables
" called "input", "output", ...
"
" The code startes as copypasta from RC5.vim


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

function! s:RC6ROTL(x, n)
        let w = s:wordbits
        let n = and(a:n, w-1)
        if n == 0
                return a:x
        endif
        return s:leftshift(a:x,n) + s:rightshift(a:x,w-n)
endfunction
function! s:RC6ROTR(x, n)
        let w = s:wordbits
        let n = and(a:n, w-1)
        return s:leftshift(a:x,w-n) + s:rightshift(a:x,n)
endfunction


" --------------------- block encryption --------------------------------
function! RC6encrypt(block, S, r)
        let A = a:block[0]
        let B = a:block[1]
        let C = a:block[2]
        let D = a:block[3]
        let S = a:S
        let r = a:r
        let B = B + S[0]
        let D = D + S[1]
        for i in range(1, a:r)
                let t = s:RC6ROTL(B * (2*B+1), s:log2w)
                let u = s:RC6ROTL(D * (2*D+1), s:log2w)
                let A = s:RC6ROTL(xor(A,t), u) + S[2*i]
                let C = s:RC6ROTL(xor(C,u), t) + S[2*i+1]
                " (A,B,C,D) = (B,C,D,A) - loop unrolling!
                let t = A
                let A = B
                let B = C
                let C = D
                let D = t
        endfor
        let A = A + S[2*r + 2]
        let C = C + S[2*r + 3]
        return [A,B,C,D]
endfunction

" constants based on e and the golden ratio
if s:wordbits == 16
        throw "can't happen"
elseif s:wordbits == 32
        let s:Pw = 0xb7e15163
        let s:Qw = 0x9e3779b9
        let s:log2w = 5
elseif s:wordbits == 64
        let s:Pw = 0xb7e151628aed2a6b
        let s:Qw = 0x9e3779b97f4a7c15
        let s:log2w = 6
else
        throw print("%d bits?", s:wordbits)
endif

if s:leftshift(1, s:log2w) != s:wordbits
        throw "log2(w) botched"
endif

" A separate function because it's reused for the test vectors
function! s:bytes2words(b)
        let K = a:b
        let u = s:wordbits/8
        let c = len(K) / u
        if len(K) % u
                let c += 1
        endif
        let L = repeat([0], c)
        let i = len(a:b)-1
        while i >= 0
                if K[i] < 0 || K[i] > 0xff
                        throw "bytes"
                endif
                let L[i/u] = s:leftshift(L[i/u],8) + K[i]
                let i -= 1
        endwhile
        return L
endfunction

function! RC6new(key, numrounds)
        if len(a:key) < 1
                return RC6new([0], a:numrounds)
        endif
        if len(a:key) > 255
                throw "keylen <= 255"
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
        let L = s:bytes2words(K)
        " initialize S
        let S = range(2*r+4)
        let S[0] = s:Pw
        for i in range(1, 2*r+3)
                let S[i] = S[i-1] + s:Qw
        endfor
        " mix the key into S
        let A = 0
        let B = 0
        let i = 0
        let j = 0
        let v = 3 * max([c, 2*r+4])
        for s in range(1, v)
                let A = s:RC6ROTL(S[i]+A+B, 3)
                let S[i] = A
                let B = s:RC6ROTL(L[j]+A+B, A+B)
                let L[j] = B
                let i = (i + 1) % (2*r+4)
                let j = (j + 1) % c
        endfor
        return { "S":S, "r":r }
endfunction


" --------------------- rand(), srand() --------------------------------
" nominal choices (for encryption): 12 rounds for 32 bits, 16 for 64 bits
let s:ctr = [0, v:version, getpid(), localtime()]
function! RC6uint()
        if s:num == 0
                for i in range(4)
                        let s:ctr[i] += 1
                        if s:ctr[i] == 0
                                continue
                        endif
                        break
                endfor
                let s:enc = RC6encrypt(s:ctr, s:x.S, s:x.r)
                let s:num = 4
        endif
        let s:num -= 1
        return s:enc[s:num]
endfunction
function! RC6int()
        let x = RC6uint()
        if x < 0
                return 0 - (x+1)
        endif
        return x
endfunction
function! RC6setcipher(x)       " result of RC6new()
        let s:x = a:x
        let s:num = 0
endfunction
call RC6setcipher(RC6new(range(255),8))
" TODO the key should be taken from a string, eg sha256(string(v:))
" TODO RC6setIV()?

" --------------------- RC6 test vectors --------------------------------
function! s:testvector(key, plainbytes, cipherbytes, rounds)
        let cipheruints = s:bytes2words(a:cipherbytes)
        let plainuints  = s:bytes2words(a:plainbytes)
        let x = RC6new(a:key, a:rounds)
        let e = RC6encrypt(plainuints, x.S, x.r)
        if e == cipheruints
                return
        endif
        let errmsg = printf("rc5(%s) %s: want [%x %x %x %x] got [%x %x %x %x]",
                                \ string(a:key), string(a:plainbytes),
                                \ cipheruints[0], cipheruints[1],
                                \ cipheruints[2], cipheruints[3],
                                \ e[0], e[1], e[2], e[3])
        echoerr errmsg
        throw errmsg
endfunction
function! RC6selftest()
        if s:wordbits == 32
                " RC5 expresses the results as uint32; this is in bytes,
                " so we need to convert back and forth...
                let rounds = 20
                let plaintext = [0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]
                let key = [0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]
                let ciphertext = [0x8f, 0xc3, 0xa5, 0x36, 0x56, 0xb1, 0xf7, 0x78, 0xc1, 0x29, 0xdf, 0x4e, 0x98, 0x48, 0xa4, 0x1e]
                call s:testvector(key, plaintext, ciphertext, rounds)

                let plaintext = [0x02, 0x13, 0x24, 0x35, 0x46, 0x57, 0x68, 0x79, 0x8a, 0x9b, 0xac, 0xbd, 0xce, 0xdf, 0xe0, 0xf1]
                let key = [0x01, 0x23, 0x45, 0x67, 0x89, 0xab, 0xcd, 0xef, 0x01, 0x12, 0x23, 0x34, 0x45, 0x56, 0x67, 0x78]
                let ciphertext = [0x52, 0x4e, 0x19, 0x2f, 0x47, 0x15, 0xc6, 0x23, 0x1f, 0x51, 0xf6, 0x36, 0x7e, 0xa4, 0x3f, 0x18]
                call s:testvector(key, plaintext, ciphertext, rounds)

                let plaintext = [0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]
                let key = [0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]
                let ciphertext = [0x6c, 0xd6, 0x1b, 0xcb, 0x19, 0x0b, 0x30, 0x38, 0x4e, 0x8a, 0x3f, 0x16, 0x86, 0x90, 0xae, 0x82]
                call s:testvector(key, plaintext, ciphertext, rounds)

                let plaintext = [0x02, 0x13, 0x24, 0x35, 0x46, 0x57, 0x68, 0x79, 0x8a, 0x9b, 0xac, 0xbd, 0xce, 0xdf, 0xe0, 0xf1]
                let key = [0x01, 0x23, 0x45, 0x67, 0x89, 0xab, 0xcd, 0xef, 0x01, 0x12, 0x23, 0x34, 0x45, 0x56, 0x67, 0x78, 0x89, 0x9a, 0xab, 0xbc, 0xcd, 0xde, 0xef, 0xf0]
                let ciphertext = [0x68, 0x83, 0x29, 0xd0, 0x19, 0xe5, 0x05, 0x04, 0x1e, 0x52, 0xe9, 0x2a, 0xf9, 0x52, 0x91, 0xd4]
                call s:testvector(key, plaintext, ciphertext, rounds)

                let plaintext = [0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]
                let key = [0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                                        \ 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]
                let ciphertext = [0x8f, 0x5f, 0xbd, 0x05, 0x10, 0xd1, 0x5f, 0xa8, 0x93, 0xfa, 0x3f, 0xda, 0x6e, 0x85, 0x7e, 0xc2]
                call s:testvector(key, plaintext, ciphertext, rounds)

                let plaintext = [0x02, 0x13, 0x24, 0x35, 0x46, 0x57, 0x68, 0x79, 0x8a, 0x9b, 0xac, 0xbd, 0xce, 0xdf, 0xe0, 0xf1]
                let key = [0x01, 0x23, 0x45, 0x67, 0x89, 0xab, 0xcd, 0xef,
                                        \ 0x01, 0x12, 0x23, 0x34, 0x45, 0x56,
                                        \ 0x67, 0x78, 0x89, 0x9a, 0xab, 0xbc,
                                        \ 0xcd, 0xde, 0xef, 0xf0, 0x10, 0x32,
                                        \ 0x54, 0x76, 0x98, 0xba, 0xdc, 0xfe]
                let ciphertext = [0xc8, 0x24, 0x18, 0x16, 0xf0, 0xd7, 0xe4, 0x89, 0x20, 0xad, 0x16, 0xa1, 0x67, 0x4e, 0x5d, 0x48]
                call s:testvector(key, plaintext, ciphertext, rounds)
        else
                throw printf("TODO test vectors for %d bits", s:wordbits)
        endif
endfunction

if len($DEBUG) > 0
        echomsg "testing RC6..."
        call RC6selftest()
        echomsg "ok!"
endif


