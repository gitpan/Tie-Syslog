# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

######################### We start with some black magic to print on failure.

# Change 1..1 below to 1..last_test_to_print .
# (It may become useful if the test is moved to ./t subdirectory.)

BEGIN { $| = 1; print "1..2\n"; }
END {print "not ok 1\n" unless $loaded;}
use Tie::Syslog;
$loaded = 1;
print "ok 1\n";

######################### End of black magic.

# Insert your test code below (better if it prints "ok 13"
# (correspondingly "not ok 13") depending on the success of chunk 13
# of the test code):

$^W=1;  ## warnings on.

tie *MYLOG, 'Tie::Syslog', 'local6.debug';
print MYLOG "Hello World";
untie *MYLOG;


my $x = tie *STDERR, 'Tie::Syslog', 'local6.debug';

$x->ExtendedSTDERR();

#print STDERR "this is a test\n";
#die "this is killing me.\n";
#printf STDERR "Error %d", 42;
#warn "this is another test\n";
#eval {
#   die "this is inside an eval and will be ignored";
#};

undef $x;
untie *STDERR;

print "ok 2\n";

print "  Things seem OK, But I *really* can't test your local syslog setup.\n";
print "  Please read the documentation for this module.\n";

