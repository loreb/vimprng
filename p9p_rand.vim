"
" $PLAN9/src/lib9/lrand.c
"
"	algorithm by
"	D. P. Mitchell & J. A. Reeds
"

" FIXME license?
" XXX Plan9 uses tabs

let	s:LEN	= 607
let	s:TAP	= 273
let	s:MASK	= 0x7fffffff
let	s:A	= 48271
let	s:M	= 2147483647
let	s:Q	= 44488
let	s:R	= 3399
let	s:NORM	= (1.0/(1.0+s:MASK))	" unused in the original code ;P

" 'ulong' on plan9 means 'uint32' - Vim has (signed) int32 at least
"static	ulong	rng_vec[LEN]
"static	ulong*	rng_tap = rng_vec
"static	ulong*	rng_feed = 0
"static	Lock	lk
let s:rng_vec  = range(s:LEN)
let s:rng_tap  = 0 " index into rng_vec
let s:rng_feed = 0 " index into rng_vec

"static void isrand(long seed)
function! s:isrand(argseed)
	let s:rng_tap = 0
	let s:rng_feed = s:LEN-s:TAP
	let seed = a:argseed % s:M
	if(seed < 0)
		let seed += s:M
	endif
	if(seed == 0)
		let seed = 89482311
	endif
	let x = seed
	"	Initialize by x[n+1] = 48271 * x[n] mod (2**31 - 1)
	"for(i = -20; i < LEN; i++) {
	for i in range(-20, s:LEN-1)
		let hi = x / s:Q
		let lo = x % s:Q
		let x = s:A*lo - s:R*hi
		if(x < 0)
			let x += s:M
		endif
		if(i >= 0)
			let s:rng_vec[i] = x
		endif
	endfor
endfunction

function s:lrand()
	let s:rng_tap -= 1
	if(s:rng_tap < 0)
		if(s:rng_feed == 0)
			call s:isrand(1)
			let s:rng_tap -= 1
		endif
		let s:rng_tap += s:LEN
	endif
	let s:rng_feed -= 1
	if(s:rng_feed < 0)
		let s:rng_feed += s:LEN
	endif
	if exists('*and')	" almost as fast as a constant
		let x = and((s:rng_vec[s:rng_feed] + s:rng_vec[s:rng_tap]), s:MASK)
	else
		" Tested on Deban/stable (squeeze) -- ok!
		let x = (s:rng_vec[s:rng_feed] + s:rng_vec[s:rng_tap])
		" MASK is 0x7fffffff
		if s:MASK != 0x7fffffff | throw '0x7fffffff' | endif
		while x > s:MASK
			let x -= s:MASK
			let x -= 1
		endwhile
		while x < 0
			let x += s:MASK
			let x += 1
		endwhile
	endif
	let s:rng_vec[s:rng_feed] = x

	return x
endfunction


"void
"p9srand(long seed)
"{
"	lock(&lk)
"	isrand(seed)
"	unlock(&lk)
"}
function! P9srand(seed)
	call s:isrand(a:seed)
endfunction
function P9lrand()
	return s:lrand()
endfunction

if len($DEBUG) > 0
	call P9srand(1)
	let want = [
				\ 1276109474, 1608359158, 1408080748,
				\ 1904696928, 507114484, 1044012054,
				\ 338575844, 535732357, 379449850
				\ ]
	let i = 0
	while i < len(want)
		let x = s:lrand()
		if x == want[i]
			let i += 1
			continue
		endif
		throw printf('p9lrand#%d: want %d, got %d', i, want[i], x)
	endwhile
	" test after >LEN iterations
	while i < 999
		call s:lrand()
		let i += 1
	endwhile
	let x = s:lrand()
	let nth = 1175397361
	if x != nth
		throw printf('after %d lrand(): want %d, got %d', i, nth, x)
	endif
	unlet x nth want
	echomsg 'P9lrand() tested equivalent to lrand(3)'
	call P9srand(1)
else
	call P9srand(localtime())
endif
