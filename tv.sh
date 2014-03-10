#! /bin/sh
# Q&D script to convert draft-strombergson-chacha-test-vectors-00.txt
# into some vimscript that does the testing.
# I'm keeping it in case some other cipher uses the same format.
if [ -t 0 ] ; then
        echo>&2 "Usage: $0 < draft-strombergson-chacha-test-vectors-00.txt"
        exit 100
fi
awk '
BEGIN { print "\" generated automagically" }
function closearray() {
        printf("\\ ]\n")
}
function dumpF(field0, escape) {
        printf("%s", escape)
        for(i = field0; i <= NF; i++) {
                printf(" %s", $i)
        }
        printf("\n")
}
#{ printf("$1(%s)\n", $1) }
function testprev() {
        closearray()
        print "call s:testvector(key, iv, numrounds, keystream)"
}
$1 == "Key:" {
        if(notfirst) {
                testprev()
        }
        notfirst = 1
        printf("let key = [\n")
        dumpF(2, "\\ ")
        next
}
$1 == "IV:" {
        closearray()
        printf("let iv = [\n");
        dumpF(2, "\\ ")
        next
}
$1 == "Rounds:" {
        closearray()
        print "let numrounds = " $2
        next
}
$1 == "Keystream" {
        #Keystream block 1:
        #Keystream block 2:
        if($3 == "1:") {
                printf("let keystream = [\n");
        }
        # stupid vimscript comments...
        #printf(" \" %s\n", $0)
        next
}
{
        # if it looks like hex data, print it; otherwise it is for humans.
        if(match($1, "0x.*") > 0) {
                # This bug took me hours to debug.
                # I. Am. An. Idiot.
                # I should have **never** spent the time looking at chacha.vim!
                #dumpF(0, "\\ ")
                dumpF(1, "\\ ")
        }
}
END {
        testprev()
        print "unlet key iv keystream numrounds"
}
' | sed 's/0x\(..\)/0x\1,/g'

