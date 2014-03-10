" if +cryptv there's sha256(); using it as a PRNG (one call per number)
" is only 7x slower than Xkcd221! (5x using all the bytes)

let s:CTR = [0, 1, v:version, getpid(), localtime()]

function! s:numbits()
        let n = 1
        let i = 1
        while n > 0
                let i = i + 1
                let n = n + n
        endwhile
        return i
endfunction
" how many bytes from the hash?
let s:numbytes = s:numbits() / 8 * 2

func SHA256()
        let hex = "0x" . sha256(string(s:CTR))
        for i in range(len(s:CTR))
                let s:CTR[i] += 1
                if s:CTR[i] != 0
                        break
                endif
        endfor
        " This is how you handle those hex digits in vimscript;
        " let rv = 0 + "0x" . hash[...] -- won't work.
        " We could avoid slicing, but it's clearer like this.
        let rv = 0 + hex[ : 2 + s:numbytes]
        return rv
endfunction
func SHA256i()
        let n = SHA256()
        if n < 0
                return 0 - (n+1)
        else
                return n
        endif
endfunction

