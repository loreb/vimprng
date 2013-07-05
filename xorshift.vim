" Marsaglia's xorshift PRNG (http://www.jstatsoft.org/v08/i14/paper)
"
" This is just the basic version (one integer seed, 3 xorshift operations)
" ==> zero isn't a valid seed, and it's never returned.
"
" Criticism at http://www.iro.umontreal.ca/~lecuyer/myftp/papers/xorshift.pdf
" Xorgen at http://maths-people.anu.edu.au/~brent/random.html

let s:triplets32 = '
\ | 1, 3,10| 1, 5,16| 1, 5,19| 1, 9,29| 1,11, 6| 1,11,16| 1,19, 3| 1,21,20| 1,27,27|
\ | 2, 5,15| 2, 5,21| 2, 7, 7| 2, 7, 9| 2, 7,25| 2, 9,15| 2,15,17| 2,15,25| 2,21, 9|
\ | 3, 1,14| 3, 3,26| 3, 3,28| 3, 3,29| 3, 5,20| 3, 5,22| 3, 5,25| 3, 7,29| 3,13, 7|
\ | 3,23,25| 3,25,24| 3,27,11| 4, 3,17| 4, 3,27| 4, 5,15| 5, 3,21| 5, 7,22| 5, 9,7 |
\ | 5, 9,28| 5, 9,31| 5,13, 6| 5,15,17| 5,17,13| 5,21,12| 5,27, 8| 5,27,21| 5,27,25|
\ | 5,27,28| 6, 1,11| 6, 3,17| 6,17, 9| 6,21, 7| 6,21,13| 7, 1, 9| 7, 1,18| 7, 1,25|
\ | 7,13,25| 7,17,21| 7,25,12| 7,25,20| 8, 7,23| 8,9,23 | 9, 5,14 | 9, 5,25| 9,11,19|
\ | 9,21,16|10, 9,21|10, 9,25|11, 7,12|11, 7,16|11,17,13|11,21,13|12, 9,23|13, 3,17|
\ |13, 3,27|13, 5,19|13,17,15|14, 1,15|14,13,15|15, 1,29|17,15,20|17,15,23|17,15,26|'
" L'Ecuyer noticed that <9,5,1> is a typo; replaced with <9,5,14>

let s:triplets64 = '
\ | 1, 1,54| 1, 1,55| 1, 3,45| 1, 7, 9| 1, 7,44| 1, 7,46| 1, 9,50| 1,11,35| 1,11,50|
\ | 1,13,45| 1,15, 4| 1,15,63| 1,19, 6| 1,19,16| 1,23,14| 1,23,29| 1,29,34| 1,35, 5|
\ | 1,35,11| 1,35,34| 1,45,37| 1,51,13| 1,53, 3| 1,59,14| 2,13,23| 2,31,51| 2,31,53|
\ | 2,43,27| 2,47,49| 3, 1,11| 3, 5,21| 3,13,59| 3,21,31| 3,25,20| 3,25,31| 3,25,56|
\ | 3,29,40| 3,29,47| 3,29,49| 3,35,14| 3,37,17| 3,43, 4| 3,43, 6| 3,43,11| 3,51,16|
\ | 3,53, 7| 3,61,17| 3,61,26| 4, 7,19| 4, 9,13| 4,15,51| 4,15,53| 4,29,45| 4,29,49|
\ | 4,31,33| 4,35,15| 4,35,21| 4,37,11| 4,37,21| 4,41,19| 4,41,45| 4,43,21| 4,43,31|
\ | 4,53, 7| 5, 9,23| 5,11,54| 5,15,27| 5,17,11| 5,23,36| 5,33,29| 5,41,20| 5,45,16|
\ | 5,47,23| 5,53,20| 5,59,33| 5,59,35| 5,59,63| 6, 1,17| 6, 3,49| 6,17,47| 6,23,27|
\ | 6,27, 7| 6,43,21| 6,49,29| 6,55,17| 7, 5,41| 7, 5,47| 7, 5,55| 7, 7,20| 7, 9,38|
\ | 7,11,10| 7,11,35| 7,13,58| 7,19,17| 7,19,54| 7,23, 8| 7,25,58| 7,27,59| 7,33, 8|
\ | 7,41,40| 7,43,28| 7,51,24| 7,57,12| 8, 5,59| 8, 9,25| 8,13,25| 8,13,61| 8,15,21|
\ | 8,25,59| 8,29,19| 8,31,17| 8,37,21| 8,51,21| 9, 1,27| 9, 5,36| 9, 5,43| 9, 7,18|
\ | 9,19,18| 9,21,11| 9,21,20| 9,21,40| 9,23,57| 9,27,10| 9,29,12| 9,29,37| 9,37,31|
\ | 9,41,45|10, 7,33|10,27,59|10,53,13|11, 5,32|11, 5,34|11, 5,43|11, 5,45|11, 9,14|
\ |11, 9,34|11,13,40|11,15,37|11,23,42|11,23,56|11,25,48|11,27,26|11,29,14|11,31,18|
\ |11,53,23|12, 1,31|12, 3,13|12, 3,49|12, 7,13|12,11,47|12,25,27|12,39,49|12,43,19|
\ |13, 3,40|13, 3,53|13, 7,17|13, 9,15|13, 9,50|13,13,19|13,17,43|13,19,28|13,19,47|
\ |13,21,18|13,21,49|13,29,35|13,35,30|13,35,38|13,47,23|13,51,21|14,13,17|14,15,19|
\ |14,23,33|14,31,45|14,47,15|15, 1,19|15, 5,37|15,13,28|15,13,52|15,17,27|15,19,63|
\ |15,21,46|15,23,23|15,45,17|15,47,16|15,49,26|16, 5,17|16, 7,39|16,11,19|16,11,27|
\ |16,13,55|16,21,35|16,25,43|16,27,53|16,47,17|17,15,58|17,23,29|17,23,51|17,23,52|
\ |17,27,22|17,45,22|17,47,28|17,47,29|17,47,54|18, 1,25|18, 3,43|18,19,19|18,25,21|
\ |18,41,23|19, 7,36|19, 7,55|19,13,37|19,15,46|19,21,52|19,25,20|19,41,21|19,43,27|
\ |20, 1,31|20, 5,29|21, 1,27|21, 9,29|21,13,52|21,15,28|21,15,29|21,17,24|21,17,30|
\ |21,17,48|21,21,32|21,21,34|21,21,37|21,21,38|21,21,40|21,21,41|21,21,43|21,41,23|
\ |22, 3,39|23, 9,38|23, 9,48|23, 9,57|23,13,38|23,13,58|23,13,61|23,17,25|23,17,54|
\ |23,17,56|23,17,62|23,41,34|23,41,51|24, 9,35|24,11,29|24,25,25|24,31,35|25, 7,46|
\ |25, 7,49|25, 9,39|25,11,57|25,13,29|25,13,39|25,13,62|25,15,47|25,21,44|25,27,27|
\ |25,27,53|25,33,36|25,39,54|28, 9,55|28,11,53|29,27,37|31, 1,51|31,25,37|31,27,35|
\ |33,31,43|33,31,55|43,21,46|49,15,61|55, 9,56|'

function! s:str2triplets(s)
    let nows = substitute(a:s, " ", "", 'g')
    let t = split(nows, "|")
    let rv = []
    for i in t
        if len(i) < 1
            continue
        endif
        let s3 = split(i, ',')
        if len(s3) != 3
            throw printf('triplet(%s)', i)
        endif
        let triplet = []
        for j in range(3)
            let triplet += [str2nr(s3[j])]
        endfor
        if triplet[0] >= triplet[2]
            throw 'need a < c in ' . i
        endif
        let rv += [triplet]
    endfor
    return rv
endfunction

" paranoia: check that triplets are parsed correctly
if len(s:str2triplets(s:triplets32)) != 81
    throw '81'
endif
if len(s:str2triplets(s:triplets64)) != 275
    throw '275'
endif

" copypasta from smallprng.vim
" -- I want this scripts to be self contained.
let s:INT_MAX = -1      " will be overwritten
let s:NSB = 0x40000000  " Next Significant Bit ;p

" {{{ Vimscript lacks bit shifts...
let s:powerof2 = [1]
while 1 > 0
    let x = 2 * s:powerof2[len(s:powerof2)-1]
    if x <= 0
        break
    endif
    let s:powerof2 += [x]
endwhile
function! s:rightshift(x, nbits)
    if a:nbits == 0
        return a:x
    endif
    if a:x < 0
        " The sign bit would be cleared anyway
        let x = a:x + s:INT_MAX + 1
        let x = x / 2   " Argh! I missed this line!
        let x = or(x, s:NSB)
        return s:rightshift(x, a:nbits - 1)
    endif
    return a:x / s:powerof2[a:nbits]
endfunction
function! s:leftshift(x, nbits)
    return a:x * s:powerof2[a:nbits]
endfunction
" }}}

let s:INT32_MAX = 0x7fffffff
let s:INT64_MAX = 0x7fffffffffffffff

if s:INT32_MAX > 0 && s:INT32_MAX+1 < 0
    let s:INT_MAX = s:INT32_MAX
    let s:triplets = s:triplets32
    let s:testtriplet = [5, 17, 13]
    let s:testseed = 2463534242
    let s:testresults = [
                \ 723471715, 2497366906, 2064144800, 2008045182,
                \ 3532304609, 374114282, 1350636274, 691148861,
                \ 746858951 ]
elseif s:INT64_MAX > 0 && s:INT64_MAX+1 < 0
    let $DEBUG = 'y'    " untested => force testing
    let s:INT_MAX = s:INT64_MAX
    let s:triplets = s:triplets64
    let s:testseed = 88172645463325252
    let s:testtriplet = [17, 7, 13]
    let s:testresults = [
                \ 8748534153485358512, 3040900993826735515,
                \ 3453997556048239312, 16431732851926010853,
                \ 8204724074003728306, 17801246309558322749,
                \ 7041795614029497201, 16736801589742238903,
                \ 16679961579883806606 ]
else
    throw 'how many bits?'
endif

let s:NSB = s:INT_MAX / 2 + 1
if and(s:NSB, s:NSB-1)
    throw printf("assertfail: NSB has more than a bit set (%x)", s:NSB)
endif


" y ^= (y<<a); u ^= (y>>b); y ^= (y<<c)
" is transalated into 'LaRbRc', that is
" [ 1, 'a', -1, 'b', 1, 'c' ]
"
" Notice that the proper solution would be to dynamically create a function
" for each of these combinations, but it's not possible because eval()
" is useless.
let s:lines = '
            \ LaRbLc | LcRbLa |
            \ RaLbRc | RcLbRa |
            \ LaLcRb | LcLaRb |
            \ RaRcLb | RcRaLb |'
function! s:lines2ops(s)
    let nows = substitute(a:s, " ", "", 'g')
    let ops = []
    for df in split(nows, "|")
        if len(df) != len('LaRbRc')
            if len(df) == 0
                continue
            endif
            throw df
        endif
        let x = []
        for i in range(3)
            let dir = df[i*2]
            if dir == 'L'
                let x += [1]
            elseif dir == 'R'
                let x += [-1]
            else
                throw dir
            endif
            let field = df[i*2 + 1] " a,b,c
            let x += [ field ]
        endfor
        let ops += [x]
    endfor
    return ops
endfunction
if len(s:lines2ops(s:lines)) != 8
    throw '8'
endif

let s:XS = {}

function! Xorshift()
    let x = s:XS
    let y = x.y
    let op = x.op
    for i in [0,2,4]
        let field = op[i+1]
        if op[i] > 0
            let shifted = s:leftshift(y, x[field])
        else
            let shifted = s:rightshift(y, x[field])
        endif
        let y = xor(y, shifted)
    endfor
    let x.y = y
    return y
endfunction

" A 3-xorshift generator is defined by:
" 1. seed (nonzero)
" 2. values of (a,b,c); a < c
" 3. choice of xorshift operations (see the paper).
" FIXME the api for (2,3) is __ugly__

function! Xorshift_seed(val)
    if a:val == 0
        throw 'xorshift(0)'
    endif
    let s:XS.y = a:val
endfunction

function! Xorshift_01234567(n)
    let modus_operandi = s:lines2ops(s:lines)
    let s:XS.op = modus_operandi[a:n]
endfunction

function! Xorshift_abc(a, b, c)
    if a:a >= a:c
        return s:Xorshift_abc(a:c, a:b, a:a)
    endif
    return Xorshift_triplet([a:a, a:b, a:c])
endfunction

function! Xorshift_triplet(t)
    let allowed = s:str2triplets(s:triplets)
    for i in allowed
        if a:t == i
            let s:XS.a = a:t[0]
            let s:XS.b = a:t[1]
            let s:XS.c = a:t[2]
            return
        endif
    endfor
    throw printf("unknown triplet %s", string(a:t))
endfunction

function! Xorshift_triplets()
    return s:str2triplets(s:triplets)
endfunction


call Xorshift_seed(localtime())
call Xorshift_01234567(getpid() % 8)
call Xorshift_triplet(Xorshift_triplets()[getpid()%len(Xorshift_triplets())])

if len($DEBUG) > 0
    call Xorshift_triplet(s:testtriplet)
    call Xorshift_seed(s:testseed)
    call Xorshift_01234567(1)
    echomsg string(s:XS)
    for i in range(len(s:testresults))
        let x = Xorshift()
        if x == s:testresults[i]
            continue
        endif
        throw printf('#%i: want %d got %d', i, s:testresults[i], x)
    endfor
    echomsg 'xorshift() ok'
endif
unlet s:testtriplet
unlet s:testseed
unlet s:testresults


