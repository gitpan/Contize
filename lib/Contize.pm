
package Contize;
use strict;
use Carp;

our $VERSION = '0.1';

our $AUTOLOAD;

=head1 NAME

    Contize - Help an object be a continuation thingie (suspendable)

=head1 SYNOPSIS

Help an object be suspendable, like a continuation.

=head1 INTRODUCTION

Contize helps an object to be suspendable. The object must be aware of this,
and when it is ready to be halted calls $self->suspend(@results), replacing the
normal return statement.

=head1 METHODS

=over 4

=item $thingie = new Contize($thingie)

Takes a $thingie object and continuizes it... we replace it with ourselves and
intercept all method calls.

=cut

# We take over the following elements of the hash:
#   _child := our child object we've overtaken
#   _cache := count for how we are doing catch-up wise
#   _nocache := a list of methods not to cache
#   _callstack := the current call stack (array)
#   _callstack_count := the current count of the top callstack item

sub new {
  my $class = shift;
  my $child = shift;
  # For now we assume our child uses a hash as it's data. Lets take it's
  # existing data and make it ours
  my $self = { %{$child} };
  bless $self, $class;
  # Now we must save our child so we can actually call it's methods later
  $self->{_child} = $child;
  # Clear out the callstack and the count for a new trace
  undef $self->{_callstack};
  undef $self->{_callstack_count};
  return $self;
}


=item $thingie->nocache('methodname1', 'methodname2', ...)

Turn off caching for the given methods

=cut

sub nocache {
  my ($self, @methods) = @_;
  push @{$self->{_nocache}}, @methods;
}


=item $thingie->somemethod(@params) ... aka AUTOLOAD

AUTOLOAD actually does the work. We intercept method invocations and usually
cache the results. Difficult to explain...

=cut

sub AUTOLOAD {
  my ($self, @args) = @_;
  my $name = $AUTOLOAD;
  my $val;
  # Chop off the 'Contize::' namespace
  $name =~ s/.*://;
  # Figure out the method's full name
  my $method = (ref $self->{_child}) . "::$name";
  if($self->{_child}->can($method)) {
    # Keep track of this invocation through our internal stacks
    push @{$self->{_callstack}}, $name;
    my $callstack = "@{$self->{_callstack}}";
    my $count = ++$self->{_callstack_count}{$callstack};
    push @{$self->{_callstack}}, $count;


    # Check to see if we should cache the result
    if(grep {$_ eq $name} @{$self->{_nocache}}) {
      # We should NOT cache the result.
      $val = $self->$method(@args);
    } else {
      $callstack = "@{$self->{_callstack}}";
      if(exists $self->{_cache}{$callstack}) {
        # We've already chached this call, lets just return it
        $val = $self->{_cache}{$callstack};
      } else {
        # We've never done this before, lets run it...
        $val = $self->$method(@args);
        # Cache all method calls (direct AND inherited)
        $self->{_cache}{$callstack} = $val;
      }
    }
    pop @{$self->{_callstack}}; # The num
    pop @{$self->{_callstack}}; # and the name
    return $val;
  } else {
    if($name ne 'DESTROY') {
      carp "Method '$method' not implemented.";
    }
  }
}


=item $thingie->suspend($retval)

This replaces the return function in a subroutine and suspends the object. When
the object is resumed it will give $retval to the caller.

=cut

sub suspend {
  my $self = shift;
  my $retval = shift;
  my $callstack = "@{$self->{_callstack}}";
  $self->{_cache}{$callstack} = $retval;
  exit;
}


=item $thingie->reset()

Reset the thingie so that it will be re-run. This clears the callstack and the
callstack_count so that it will begin returning cached results.

=cut

sub resume {
  my $self = shift;
  undef $self->{_callstack};
  undef $self->{_callstack_count};
}


=item DESTROY

Upon destruction we undef our child, thus calling the child's own DESTROY, if
such a thing exists. I'm pretty sure this is the proper way to do things, but
it might break if their DESTROY does more complicated activities.

=cut

sub DESTROY {
  my $self = shift;
  undef $self->{_child};
}
  

=back

=head1 SEE ALSO

Coro::Cont

=head1 AUTHOR

Brock Wilcox <awwaiid@thelackthereof.org>

=head1 COPYRIGHT

Copyright (c) 2004 Brock Wilcox <awwaiid@thelackthereof.org>. All rights
reserved.  This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;

