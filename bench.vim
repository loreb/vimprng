
" If the generators produce the same sequence as a reference implementation
" there's no need to test them for randomness...
" TODO get vim to play nice with dieharder (just because).
echomsg "Measures are relative to fastest functions, such as:"
echomsg "Xkcd221() -- the fastest generator known to me"
echomsg "xkcd221() -- the above added to src/eval.c"

let s:seed = 0

function Xkcd221()
    return 4
endfunction

function Incf()
    let s:seed += 1
    return s:seed
endfunction

function s:new()
    let x = {}
    let x.seed = s:seed
    return x
endfunction
let s:x = s:new()   " vimscript fakes objects via hashtables - any overhead?
function OOPRNG()
    let s:x.seed += 1
    return s:x.seed
endfunction

" Simplest PRNG ever
function LCG()
    let s:seed = s:seed * 1664525 + 1013904223
    return s:seed
endfunction

if exists('*reltime')
    function Start()
        return reltime()
    endfunction
    function Clock(epoch)
        return reltimestr(reltime(a:epoch))
    endfunction
else
    function Start()
        return localtime()
    endfunction
    function Clock(epoch)
        return string(localtime() - a:epoch)
    endfunction
endif


let s:functions = [
            \ 'Xkcd221', 'LCG', 'OOPRNG', 'Incf'
            \ ]
let s:description = {}
let s:description['LCG']     = 'fast LCG for reference in benchmarks'
let s:description['OOPRNG']  = 'return obj.seed++'
let s:description['Incf']    = 'return seed++'
let s:description['xkcd221'] = 'Xkcd221 (in C)'
" FIXME some PRNGs have a 'state' parameter...
for f in ['lcg', 'xkcd221'] +
            \ [ 'Arc4random', 'Dev_urandom', 'Marsaglia', 'MT19337',
            \ 'P9lrand', 'RandIsaac', 'KISS' ]
    " On my machine xkcd221 <2x faster than Xkcd221,
    " while LCG is 3x slower than lcg -- you get the idea.
    if exists('*' . f)
        let s:functions += [ f ]
    endif
endfor
function PRNGs()
    return copy(s:functions)
endfunction
function! s:getdescription(fname)
    if has_key(s:description, a:fname)
        return s:description[a:fname]
    endif
    return a:fname
endfunction

let s:ncalls = 100 * 1000
" A nice thing about function pointers in vimscript is that they are actually
" *faster* than calling the function through its name!
function! Bench(funcname, ...)
    let n = s:ncalls
    if a:0 > 0
        let n = a:1
    endif
    if n <= 999
        throw 'EINVAL'
    endif
    let F = function(a:funcname)
    let t0 = Start()
    " XXX vim's range() uses memory (think range/xrange in python2);
    " XXX this makes loop unrolling noticeable when N is big enough.
    for i in range(n)
        call F()
    endfor
    let elapsed = Clock(t0)
    echomsg printf("%s      %d calls of %s (%s)",
                \ elapsed, n, a:funcname, s:getdescription(a:funcname))
    return elapsed
endfunction
function Doit(...)
    let cps = 56789.0   " YMMV of course!
    let n = s:ncalls
    if a:0 > 0
        let n = a:1
    endif
    echomsg "expect ~ " . string(n/cps) . " seconds..."
    for f in s:functions
        call Bench(f, n)
    endfor
endfunction

function! s:qwerty(x, y)
    " Dividing by zero is ok.
    return a:y / a:x " *100
endfunction
function VS(f1, f2, ...)
    let n = s:ncalls
    if a:0 > 0
        let n = a:1
    endif
    let f1 = a:f1
    let f2 = a:f2
    let t1 = str2float(Bench(f1, n))
    let t2 = str2float(Bench(f2, n))
    let p12 = s:qwerty(t1, t2)
    let p21 = s:qwerty(t2, t1)
    echomsg printf("%s() is %f times as fast as %s()", f1, p12, f2)
    echomsg printf("%s() is %f times as fast as %s()", f2, p21, f1)
    let w = '(none)'
    if p12 > p21 | let w = f1 | endif
    if p21 > p12 | let w = f2 | endif
    echomsg 'The winner is: ' . w
    return w
endfunction

" For non gamers, it's Everyone Vs Everyone.
" It doesn't return the winner or anything.
function EVE()
    for f1 in PRNGs()
        for f2 in PRNGs()
            if f1 < f2
                call VS(f1, f2)
            endif
        endfor
    endfor
endfunction


