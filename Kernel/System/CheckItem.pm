# --
# Modified version of the work: Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/ 
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::CheckItem;

use strict;
use warnings;

use Email::Valid;

our @ObjectDependencies = (
    'Config',
    'Log',
);

=head1 NAME

Kernel::System::CheckItem - check items

=head1 SYNOPSIS

All item check functions.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create an object. Do not use it directly, instead use:

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $CheckItemObject = $Kernel::OM->Get('CheckItem');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

=item CheckError()

get the error of check item back

    my $Error = $CheckItemObject->CheckError();

=cut

sub CheckError {
    my $Self = shift;

    return $Self->{Error};
}

=item CheckErrorType()

get the error's type of check item back

    my $ErrorType = $CheckItemObject->CheckErrorType();

=cut

sub CheckErrorType {
    my $Self = shift;

    return $Self->{ErrorType};
}

=item CheckEmail()

returns true if check was successful, if it's false, get the error message
from CheckError()

    my $Valid = $CheckItemObject->CheckEmail(
        Address => 'info@example.com',
    );

=cut

sub CheckEmail {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{Address} ) {
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => 'Need Address!'
            );
        }
        return;
    }

    # get config object
    my $ConfigObject = $Kernel::OM->Get('Config');

    # check if it's to do
    return 1 if !$ConfigObject->Get('CheckEmailAddresses');

    # check valid email addresses
    my $RegExp = $ConfigObject->Get('CheckEmailValidAddress');
    if ( $RegExp && $Param{Address} =~ /$RegExp/i ) {
        return 1;
    }
    my $Error = '';

    # email address syntax check
    if ( !Email::Valid->address( $Param{Address} ) ) {
        $Error = "Invalid syntax";
        $Self->{ErrorType} = 'InvalidSyntax';
    }

    # email address syntax check
    # period (".") may not be used to end the local part,
    # nor may two or more consecutive periods appear
    if ( $Param{Address} =~ /(\.\.)|(\.@)/ ) {
        $Error = "Invalid syntax";
        $Self->{ErrorType} = 'InvalidSyntax';
    }

    # mx check
    elsif (
        $ConfigObject->Get('CheckMXRecord')
        && eval { require Net::DNS }    ## no critic
        )
    {

        # get host
        my $Host = $Param{Address};
        $Host =~ s/^.*@(.*)$/$1/;
        $Host =~ s/\s+//g;
        $Host =~ s/(^\[)|(\]$)//g;

        # do dns query
        my $Resolver = Net::DNS::Resolver->new();
        if ($Resolver) {

            # it's no fun to have this hanging in the web interface
            $Resolver->tcp_timeout(3);
            $Resolver->udp_timeout(3);

            # check if we need to use a specific name server
            my $Nameserver = $ConfigObject->Get('CheckMXRecord::Nameserver');
            if ($Nameserver) {
                $Resolver->nameservers($Nameserver);
            }

            # A-record lookup to verify proper DNS setup
            my $Packet = $Resolver->send( $Host, 'A' );
            if ( !$Packet ) {
                $Self->{ErrorType} = 'InvalidDNS';
                $Error = "DNS problem: " . $Resolver->errorstring();
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => $Error,
                );
            }

            else {
                # RFC 5321: first check MX record and fallback to A record if present.
                # mx record lookup
                my @MXRecords = Net::DNS::mx( $Resolver, $Host );

                if ( !@MXRecords ) {

                    $Kernel::OM->Get('Log')->Log(
                        Priority => 'notice',
                        Message =>
                            "$Host has no mail exchanger (MX) defined, trying A resource record instead.",
                    );

                    # see if our previous A-record lookup returned a RR
                    if ( scalar $Packet->answer() eq 0 ) {

                        $Self->{ErrorType} = 'InvalidMX';
                        $Error = "$Host has no mail exchanger (MX) or A resource record defined.";

                        $Kernel::OM->Get('Log')->Log(
                            Priority => 'error',
                            Message  => $Error,
                        );
                    }
                }
            }
        }
    }
    elsif ( $ConfigObject->Get('CheckMXRecord') ) {

        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Can't load Net::DNS, no mx lookups possible",
        );
    }

    # check address
    if ( !$Error ) {

        # check special stuff
        my $RegExp = $ConfigObject->Get('CheckEmailInvalidAddress');
        if ( $RegExp && $Param{Address} =~ /$RegExp/i ) {
            $Self->{Error}     = "invalid $Param{Address} (config)!";
            $Self->{ErrorType} = 'InvalidConfig';
            return;
        }
        return 1;
    }
    else {

        # remember error
        $Self->{Error} = "invalid $Param{Address} ($Error)! ";
        return;
    }
}

=item StringClean()

clean a given string

    my $StringRef = $CheckItemObject->StringClean(
        StringRef         => \'String',
        TrimLeft          => 0,  # (optional) default 1
        TrimRight         => 0,  # (optional) default 1
        RemoveAllNewlines => 1,  # (optional) default 0
        RemoveAllTabs     => 1,  # (optional) default 0
        RemoveAllSpaces   => 1,  # (optional) default 0
    );

=cut

sub StringClean {
    my ( $Self, %Param ) = @_;

    if ( !$Param{StringRef} || ref $Param{StringRef} ne 'SCALAR' ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Need a scalar reference!'
        );
        return;
    }

    return $Param{StringRef} if !defined ${ $Param{StringRef} };
    return $Param{StringRef} if ${ $Param{StringRef} } eq '';

    # check for invalid utf8 characters and remove invalid strings
    if ( !utf8::valid( ${ $Param{StringRef} } ) ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Removed string containing invalid utf8: '${ $Param{StringRef} }'!",
        );
        ${ $Param{StringRef} } = '';
        return;
    }

    # set default values
    $Param{TrimLeft}  = defined $Param{TrimLeft}  ? $Param{TrimLeft}  : 1;
    $Param{TrimRight} = defined $Param{TrimRight} ? $Param{TrimRight} : 1;

    my %TrimAction = (
        RemoveAllNewlines => qr{ [\n\r\f] }xms,
        RemoveAllTabs     => qr{ \t       }xms,
        RemoveAllSpaces   => qr{ [ ]      }xms,
        TrimLeft          => qr{ \A \s+   }xms,
        TrimRight         => qr{ \s+ \z   }xms,
    );

    ACTION:
    for my $Action ( sort keys %TrimAction ) {
        next ACTION if !$Param{$Action};

        ${ $Param{StringRef} } =~ s{ $TrimAction{$Action} }{}xmsg;
    }

    return $Param{StringRef};
}

=item CreditCardClean()

clean a given string and remove credit card

    my ($StringRef, $Found) = $CheckItemObject->CreditCardClean(
        StringRef => \'String',
    );

=cut

sub CreditCardClean {
    my ( $Self, %Param ) = @_;

    if ( !$Param{StringRef} || ref $Param{StringRef} ne 'SCALAR' ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Need a scalar reference!'
        );
        return;
    }

    return ( $Param{StringRef}, 0 ) if ${ $Param{StringRef} } eq '';
    return ( $Param{StringRef}, 0 ) if !defined ${ $Param{StringRef} };

    # strip credit card numbers
    my $Count = 0;
    ${ $Param{StringRef} } =~ s{
        \b(\d{4})(\s|\.|\+|_|-|\\|/)(\d{4})(\s|\.|\+|_|-|\\|/|)(\d{4})(\s|\.|\+|_|-|\\|/)(\d{3,4})\b
    }
    {
        $Count++;
        "$1$2XXXX$4XXXX$6$7";
    }egx;

    return $Param{StringRef}, $Count;
}

1;





=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
