
" George Marsaglia's SUPERKISS, from
" http://compgroups.net/comp.lang.c/superkiss-for-32-and-64-bit-rngs-in-both-c-and-fo/325306 {{{

" (His C code contains a stupid typo -- SUPRKISS64 is repeated twice).
" (Therefore I'm translating the "whiter" version of SUPRKISS32).

" -----------------------------------------------------------
" And here are equivalent Fortran versions, which, absent
" C's inline features, seem to need ~10% more run time.
"
" -----------------------------------------------------------
" module suprkiss64_M   ! period 5*2^1320480*(2^64-1)
" integer,parameter :: I8=selected_int_kind(18)
" integer(kind=I8) :: Q(20632),carry=36243678541_I8, &
"  xcng=12367890123456_I8,xs=521288629546311_I8,indx=20633_I8
" contains
" function KISS64() result(x)
" integer(kind=I8) :: x
"    if(indx <= 20632)then; x=Q(indx); indx=indx+1
"      else; x=refill(); endif
"  xcng=xcng*6906969069_I8+123
"  xs=ieor(xs,ishft(xs,13))
"  xs=ieor(xs,ishft(xs,-17))
"  xs=ieor(xs,ishft(xs,43))
"  x=x+xcng+xs
" return; end function KISS64
"
" function refill() result(s)
"    integer(kind=I8) :: i,s,z,h
"    do i=1,20632
"       h=iand(carry,1_I8)
"       z = ishft(ishft(Q(i),41),-1)+ &
"           ishft(ishft(Q(i),39),-1)+ &
"           ishft(carry,-1)
"       carry=ishft(Q(i),-23)+ishft(Q(i),-25)+ishft(z,-63)
"       Q(i)=not(ishft(z,1)+h)
"    end do
"    indx=2; s=Q(1)
"    return; end function refill
"
" end module suprkiss64_M
"
" program testKISS64
" use suprkiss64_M
" integer(kind=I8) :: i,x
"   do i=1,20632      !fill Q with Congruential+Xorshift
"      xcng=xcng*6906969069_I8+123
"      xs=ieor(xs,ishft(xs,13))
"      xs=ieor(xs,ishft(xs,-17))
"      xs=ieor(xs,ishft(xs,43))
"      Q(i)=xcng+xs
"   end do
" do i=1,1000000000_I8; x=KISS64(); end do
" write(*,10) x
" 10 format(' Does x =  4013566000157423768 ?',/,6x,'x = ',I20)
" end program testKISS64
" -------------------------------------------------------------
"
"  module suprkiss32_M  ! period 5*2^1320481*(2^32-1)
"  integer,parameter :: I4=selected_int_kind(9)
"  integer(kind=I4) :: Q(41265),carry=362_I4, &
"     xcng=1236789_I4,xs=521288629_I4,indx=41266_I4
"  contains
"  function KISS32() result(x)
"  integer(kind=I4):: x
"     if(indx <= 41265)then;x=Q(indx); indx=indx+1
"       else; x=refill(); endif
"   xcng=xcng*69069_I4+123
"   xs=ieor(xs,ishft(xs,13))
"   xs=ieor(xs,ishft(xs,-17));
"   xs=ieor(xs,ishft(xs,5))
"   x=x+xcng+xs
"  return; end function KISS32
"
"  function refill() result(s)
"     integer(kind=I4) :: i,s,z,h
"     do i = 1,41265
"        h = iand(carry,1_I4)
"        z = ishft(ishft(Q(i),9),-1)+ &
"            ishft(ishft(Q(i),7),-1)+ &
"            ishft(carry,-1)
"        carry=ishft(Q(i),-23)+ishft(Q(i),-25)+ishft(z,-31)
"        Q(i)=not(ishft(z,1)+h)
"     end do
"     indx=2;   s=Q(1)
"     return; end function refill
"
"  end module suprkiss32_M
"
"  program testKISS32
"  use suprkiss32_M
"  integer(kind=I4) :: i,x
"  do i=1,41265   !fill Q with Congruential+Xorshift
"     xcng=xcng*69069_I4+123
"     xs=ieor(xs,ishft(xs,13))
"     xs=ieor(xs,ishft(xs,-17))
"     xs=ieor(xs,ishft(xs,5))
"     Q(i)=xcng+xs
"  end do
"  do i=1,1000000000_I4;  x=KISS32();  end do
"  write(*,10) x
"  10 format(' Does x = 1809478889 ?',/,6x,'x =',I11)
"  end program testKISS32
"
" ---------------------------------------------------------------
" }}}

let s:powerof2 = [1]
while 1
    let x = s:powerof2[len(s:powerof2)-1]
    let y = x*2
    if y <= x
        break
    endif
    let s:powerof2 += [y]
endwhile

function! s:LS(n, offset)
    return a:n * s:powerof2[a:offset]
endfunction

" XXX tnx http://www.vim.org/scripts/script.php?script_id=2806 (md5.vim)
function! s:bitwise_not(a)
  return -a:a - 1
endfunction

function! s:bits()
    return 1 + len(s:powerof2)
endfunction

if s:bits() == 32
    let s:Q = repeat([0], 41265)
    let s:carry = 362
    let s:xcng = 1236789
    let s:xs = 521288629
    let s:indx = 41265

    function! s:RS(n, offset)
        if a:offset >= len(s:powerof2)
            " n>>31 means 'is MSB set?'
            return a:n < 0? 1: 0
            "return s:RS(s:RS(a:n, 1), a:offset - 1)
        endif
        if a:n >= 0
            return a:n / s:powerof2[a:offset]
        endif
        if a:offset == 0 | return a:n | endif
        let u1 = a:n
        let u1 = and(0x7fffffff, u1) / 2
        let u1 =  or(0x40000000, u1)
        return s:RS(u1, a:offset - 1)
    endfunction

    function! s:CNG()
        let s:xcng = 69069 * s:xcng + 123
        return s:xcng
    endfunction
    " #define XS      ( xs ^= xs << 13, xs ^= xs >> 17, xs ^= xs << 5 )
    function! s:XS()
        let s:xs = xor(s:xs, s:LS(s:xs, 13))
        let s:xs = xor(s:xs, s:RS(s:xs, 17))
        let s:xs = xor(s:xs, s:LS(s:xs, 5))
        return s:xs
    endfunction
    function! s:SUPR()
        if s:indx < 41265
            let rv = s:Q[s:indx]
            let s:indx += 1
            return rv
        endif
        return s:refill()
    endfunction
    function! KISS()
        return s:SUPR() + s:CNG() + s:XS()
    endfunction

    function! s:refill()
        for i in range(41265)
            let h = and(s:carry, 1)
            "z = ((Q[i] << 9) >> 1) + ((Q[i] << 7) >> 1) + (carry >> 1);
            let z = s:RS(s:LS(s:Q[i], 9), 1) + s:RS(s:LS(s:Q[i], 7), 1)
                        \ + s:RS(s:carry, 1)
            let s:carry = s:RS(s:Q[i], 23) + s:RS(s:Q[i], 25) + s:RS(z, 31)
            " Q[i] = ~((z << 1) + h);
            let s:Q[i] = s:bitwise_not(s:LS(z, 1) + h)
        endfor
        let s:indx = 1
        return s:Q[0]
    endfunction
    let s:milliardth = 1809478889
    let s:millionth  = 2251051864
    let s:first = [
                \ 731790251,  2496544477, 4260112702, 446560973,
                \ 1364216893, 3953018364, 1511295292, 1676480129
                \ ]
elseif s:bits() == 64
    throw 'todo 64 bits'
else
    throw printf('does your computer have %d bits?', s:bits())
endif

" https://en.wikipedia.org/wiki/1,000,000,000 says "billion" is supposed
" to mean 10^9 unambiguously -- I'm paranoid
if len($DEBUG) > 0
    echomsg 'testing SUPRKISS'
    echomsg 'filling Q...'
    for i in range(len(s:Q))
        let s:Q[i] = s:CNG() + s:XS()
    endfor
    echomsg 'wait for refill()...'
    " Prof Marsaglia's test is to print the 10^9th number.
    " That takes a while in vimscript => check the first 10 numbers or so.
    for i in range(len(s:first))
        let x = KISS()
        if x != s:first[i]
            throw printf('really buggy: wanted %d, got %d', s:first[i], x)
        endif
    endfor
    echomsg 'YAFIYGI -- this takes <20s in C, literally **days** in vim'
    let t0 = localtime()
    " Vim's range takes memory...
    for i in range(1000)
        for j in range(1000)
            for k in range(i==0 && j==0? 1000-len(s:first): 1000)
                let x = KISS()
            endfor
        endfor
        echomsg printf('#%d<1000 => %d secs total', i, localtime()-t0)
        if x != s:millionth
            throw printf("after 1e6: want %d, got %d", s:millionth, x)
        endif
    endfor
    echomsg printf("Does x = %d?\n     x = %d.\n", s:milliardth, x);
    if x != s:milliardth
        throw 'SUPRBUG!'
    endif
endif
unlet s:milliardth
unlet s:millionth
unlet s:first

" This is especially beautiful in how it avoids using "bigger" integers
" to compute the carry, and in how it shows vim's slugginess on the 1st call
" to refill() -- it takes a few seconds!
echoerr 'TODO provide srand()'
