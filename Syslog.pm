
package Tie::Syslog;

use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);

require Exporter;

@ISA = qw(Exporter);
# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.
@EXPORT = qw(
	
);
$VERSION = '1.01';

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
		my $i = 0;
		my @x;
		while ( @x = caller($i++) ) {
			return if ($x[3] =~ /\(eval\)/);  ## died from eval exception
		}
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

	## setup syslog
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
		$SIG{__WARN__} = $this->{'warn_sub'};
		$SIG{__DIE__}  = $this->{'die_sub'};
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

Tie::Syslog - Perl extension for tie'ing a filehandle to Syslog

=head1 SYNOPSIS

  use Tie::Syslog;

  ###
  ##  Pass three args:
  ##    facility.priority   ('local0.error')
  ##    identity            ('my_program')
  ##    log options         ('pid')
  ###
  tie *MYLOG, 'Tie::Syslog', 'local0.error', 'my_program', 'pid';

  print MYLOG "I made an error."; ## this will be syslogged
  printf MYLOG "Error %d", 42;    ## syslog as "Error 42"

  untie *MYLOG;


=head1 DESCRIPTION

This module allows you to tie a filehandle (output only) to syslog. This
becomes useful in general when you want to capture any activity that
happens on STDERR and see that it is syslogged for later perusal. This
module depends on the Sys::Syslog module to actually get info to syslog.

Tie your filehandle to syslog using a glob to the filehandle. When it is
tied to the 'Tie::Syslog' class, you may optionally pass three arguments
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
function has no way of knowing what the filhandle symbol is anyway.
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

  undef $x;
  untie *STDERR;


When used with STDERR, combined with the good habit of using the perl -w
switch, this module happens to be useful in catching unexpected errors in
any of your code, or team's code. Tie::Syslog is pretty brain-dead. However,
it can become quite flexible if you investigate your options with the
actual syslog daemon. Syslog has a variety of options available, including
notifying console, logging to other machines running syslog, or email
support in the event of "bad things". Consult your syslog documentation
to get /etc/syslog.conf setup by your sysadmin and use Tie::Syslog to get
information into those channels.


=head1 AUTHOR

Copyright (C) 1999 Broc Seib. All rights reserved. This program is free
software; you can redistribute it and/or modify it under the same terms as
Perl itself.

=head1 REVISION

$Id: Syslog.pm,v 1.1 1999/03/12 22:26:10 bseib Exp $

=head1 SEE ALSO

Read perldoc perltie for info on how to tie a filehandle.
Read perldoc Sys::Syslog.
Read man syslog to learn more about syslog.

=cut
