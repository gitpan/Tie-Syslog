###
##  $Id: Syslog.pm,v 1.6 2000/11/09 22:15:37 bseib Exp $
###
package Tie::Syslog;

use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);

$VERSION = '1.04';

use Sys::Syslog;

sub ident {
	my $app = $0;
	if ( $app =~ m#([^/]+)$# ) {
		return $1;
	}
	return $app;
}

sub ExtendedSTDERR {
	my $this = shift;

	return if (1 == $this->{'isSTDERR'});  ## already been here

	## trap these special cases because they're hardwired to stdout
	## and don't go thru the symbol *STDERR.
	$this->{'warn_sub'} = $SIG{__WARN__};
	$this->{'die_sub'}  = $SIG{__DIE__};
	$SIG{__WARN__} = sub { print STDERR @_; };
	$SIG{__DIE__} = sub {  ## still dies upon return
		return if $^S; ## see perldoc perlvar and perldoc -f die perlfunc
		print STDERR @_;
	};	

	## mark that this object is special to STDERR
	$this->{'isSTDERR'} = 1;
}

sub TIEHANDLE {
	my $class    = shift;
	my $this = {};
	my $facil_prior     = shift || 'local0.error';
	return undef unless ($facil_prior =~ /^((\w|\d)+)\.((\w|\d)+)$/);
	$this->{'facility'} = $1;
	$this->{'priority'} = $3;
	$this->{'identity'} = shift || ident();
	$this->{'log_opts'} = shift || 'pid';
	$this->{'isSTDERR'} = 0;

	## setup syslog setlogsock
	##
	## Many still have original Sys::Syslog which does not have
	## the setlogsock routine. There is no $VERSION constant to
	## test in Sys::Syslog, so we'll test the symbol table to see
	## if the routine exists. If not, skip this gracefully.
	if ( defined($Sys::Syslog::{'setlogsock'}) ) {
		my $sock = shift || 'inet';
		return undef unless ($sock =~ /^(unix|inet)$/);

		## boy this is messy... must be this way, else compile time error
		no strict 'refs';
		my $call = 'Sys::Syslog::setlogsock';
		&$call($sock);
		use strict 'refs';
	}

	## open a syslog connection
	openlog $this->{'identity'},$this->{'log_opts'},$this->{'facility'};

	return bless $this, $class;
}

sub PRINT {
	my $this = shift;
	syslog $this->{'priority'}, "%s", join('',@_);
}

sub PRINTF {
	my $this = shift;
	syslog $this->{'priority'}, @_;
}

sub DESTROY {
	my $this = shift;

	if ($this->{'isSTDERR'}) {
		## restore signal handlers
		{ local $^W = 0; ## hey, why can't I undef $SIG{__DIE__} w/out warns?
		$SIG{__WARN__} = $this->{'warn_sub'};
		$SIG{__DIE__}  = $this->{'die_sub'};
		}
	}

	## close syslog
	closelog;

	## destroy mem object
	undef $this;
}


# Autoload methods go after =cut, and are processed by the autosplit program.

1;
__END__
# Below is the stub of documentation for your module. You better edit it!

=head1 NAME

Tie::Syslog - Tie a filehandle to Syslog. If you Tie STDERR, then all STDERR errors are automatically caught, or you can debug by Carp'ing to STDERR, etc. (Good for CGI error logging.)

=head1 SYNOPSIS

  use Tie::Syslog;

  ###
  ##  Pass up to four args:
  ##    facility.priority   ('local0.error')
  ##    identity            ('my_program')
  ##    log options         ('pid')
  ##    setlogsock          ('inet'|'unix')
  ###
  tie *MYLOG, 'Tie::Syslog','local0.error','my_program','pid','inet';

  print MYLOG "I made an error."; ## this will be syslogged
  printf MYLOG "Error %d", 42;    ## syslog as "Error 42"

  untie *MYLOG;


=head1 DESCRIPTION

This module allows you to tie a filehandle (output only) to syslog. This
becomes useful in general when you want to capture any activity that
happens on STDERR and see that it is syslogged for later perusal. You
can also create an arbitrary filehandle, say LOG, and send stuff to syslog
by printing to this filehandle. This module depends on the Sys::Syslog
module to actually get info to syslog.

Tie your filehandle to syslog using a glob to the filehandle. When it is
tied to the 'Tie::Syslog' class, you may optionally pass four arguments
that determine the behavior of the output bound to syslog.

You first specify a facility and priority to direct your filehandle traffic
to the proper channels in syslog. I suggest reviewing a manpage for syslog
on your local system to identify what the facilities and priorities actually
are. Nonetheless, this first argument is specified as a string consisting
of the facility followed by a dot, followed by the priority. For example,
the default setting is 'local0.error'. If you do not specify a first arg,
this default is used.

The second argument is an identifier string. This is the string that shows
up in evey line of output that syslog writes. You may use this identifier
to help sort out syslog lines produced by different applications (with
different id's.) If you do not specify a value for this argument, it will
default to the name of the running program. (This is derived from the
special $0 variable, stripping off everything up to the final appearing
forward slash character.)

The third argument is a string of comma separated log options specific
to syslog. Current documentation supports 'pid,cons,ndelay,nowait'. Check
your local listings, as you may pass values that are only part of your
local system. I suggest checking your man pages for syslog, and perhaps
looking inside your site_perl/$archname/sys/syslog.ph for other such values.
If you do not pass this third argument, it defaults to the string 'pid',
which makes syslog put a [12345] pid value on each line of output.

The fourth argument is either the string 'inet' or 'unix'. This is
passed to the Sys::Syslog::setlogsock() call to specify the socket type
to be used when opening the connection to syslog. If this argument is
not specified, then the default used is 'inet'. Many perl installations
still have original Sys::Syslog which does not have the setlogsock()
routine. There is also no $VERSION constant to test in Sys::Syslog, so
we'll test the symbol table to see if the routine exists. If the routine
does not exist, then the fourth argument is silently ignored. I did not
want to require people to have "the latest" version of perl just to use
this module.


An aside on using 'STDERR':

The blessed object that is returned from tie also has one additional
member function. In the case that you tie the filehandle 'STDERR' (or
a dup'ed copy of STDERR) then you may want to capture information
going to the warn() and die() functions. You may call ExtendedSTDERR()
to setup the proper handler function to deal with the special signals
for __DIE__ and __WARN__. Because this module really has no knowledge
of what filehandle is being tied, I contemplated trying to make this
automatic for when the STDERR filehandle is used. But, alas, one may
have a different name for what is really STDERR, plus the TIEHANDLE
function has no way of knowing what the filehandle symbol is anyway.
I also decided to put the logic of how to handle the two signal cases
into this module, when perhaps they might be more suited to be at the
level of whoever is calling this module. Well, you don't have to call
the routine ExtendedSTDERR() if you don't like what it does. I felt
obligated to provide a proper solution to the signal handling since
a common use of this module would be to capture STDERR for syslogging.

  my $x = tie *STDERR, 'Tie::Syslog', 'local0.debug';
  $x->ExtendedSTDERR();            ## set __DIE__,__WARN__ handler

  print STDERR "I made an error."; ## this will be syslogged
  printf STDERR "Error %d", 42;    ## syslog as "Error 42"
  warn "Another error was made.";  ## this will also be syslogged
  eval {
      die "exception thrown";      ## this is *NOT* syslogged
  };
  die "Killing me softly?!";       ## syslogged, then script ends

  undef $x;                        ## be sure to do this, else warns!
  untie *STDERR;


When used with STDERR, combined with the good habit of using the perl C<-w>
switch, this module happens to be useful in catching unexpected errors in
any of your code, or team's code. Tie::Syslog is pretty brain-dead. However,
it can become quite flexible if you investigate your options with the
actual syslog daemon. Syslog has a variety of options available, including
notifying console, logging to other machines running syslog, or email
support in the event of Bad Things. Consult your syslog documentation
to get /etc/syslog.conf setup by your sysadmin and use Tie::Syslog to get
information into those channels.


=head1 BUGS

If you do not specify an identity (2nd arg) to tie() it defaults to
the name of the executable via special var $0. It is split by the
character '/', so non-unix systems will end up with a "full name"
for its identity, if left unspecified. I could use File::Spec for
non-unix paths -- but how many of you non-unix persons out there
have syslog and would like this? Tell me...

=head1 AUTHOR

Copyright (c) 2000 Broc Seib. All rights reserved. This program is free
software; you can redistribute it and/or modify it under the same terms as
Perl itself.

=head1 REVISION

$Id: Syslog.pm,v 1.6 2000/11/09 22:15:37 bseib Exp $

=head1 SEE ALSO

Read perldoc perltie for info on how to tie a filehandle.
Read perldoc Sys::Syslog.
Read man syslog to learn more about syslog.

=cut
