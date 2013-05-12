vimprng : pseudorandom number generators in vimscript
=====================================================

This is a collection of PRNGs translated into vimscript because...
well, it all started out of dissatisfaction with "random colorscheme" scripts:
I patched one of them to use `/dev/urandom`, then I thought that it
wouldn't work on windows, so I translated `rand()` from unix v7
and got hooked by the clumsiness of the language.

I've written most of these individually, usually while waiting for
$BoringComputerActivity to complete (fixing friend's computer, ...);
this means at least that there are some repetitions, such as comments
explaining vim's integers.

Most of the generators assume that `exists('*xor')`; as of
20130408, both mingw and Debian stable don't qualify.
> UPDATE: Debian wheezy got released last week.

Some generators assume an int is exactly 32 bits and `:throw` otherwise.

Most of the generators test themselves against the original C
implementation if `$DEBUG` is set.


Integers in vim
---------------

Quoting from vim/src/structs.h:

	#if SIZEOF_INT <= 3	/* use long if int is smaller than 32 bits */
	typedef long	varnumber_T;
	#else
	typedef int	varnumber_T;
	#endif

Iow: vim uses a signed integer that's at least 32 bits wide;
I have yet to find a machine where it's not **exactly** 32 bits.

