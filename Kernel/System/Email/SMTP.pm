# --
# Modified version of the work: Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/ 
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Email::SMTP;

use strict;
use warnings;

use Net::SMTP;

use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = (
    'Config',
    'DB',
    'Encode',
    'Log',
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {%Param};
    bless( $Self, $Type );

    # debug
    $Self->{Debug} = $Param{Debug} || 0;
    if ( $Self->{Debug} > 2 ) {

        # shown on STDERR
        $Self->{SMTPDebug} = 1;
    }

    return $Self;
}

sub Check {
    my ( $Self, %Param ) = @_;

    # get config object
    my $ConfigObject = $Kernel::OM->Get('Config');

    # get config data
    my $FQDN = $ConfigObject->Get('FQDN');
    if (IsHashRefWithData($FQDN)) {
        $FQDN = $FQDN->{Backend}
    }
    $Self->{FQDN}      = $FQDN;
    $Self->{MailHost}  = $ConfigObject->Get('SendmailModule::Host')
        || die "No SendmailModule::Host found in Kernel/Config.pm";
    $Self->{SMTPPort}  = $ConfigObject->Get('SendmailModule::Port');
    $Self->{User}      = $ConfigObject->Get('SendmailModule::AuthUser');
    $Self->{Password}  = $ConfigObject->Get('SendmailModule::AuthPassword');
    $Self->{SSLVerify} = $ConfigObject->Get('SendmailModule::SSLVerify');

    # try it 3 times to connect with the SMTP server
    # (M$ Exchange Server 2007 have sometimes problems on port 25)
    my $SMTP;
    TRY:
    for my $Try ( 1 .. 3 ) {

        # connect to mail server
        $SMTP = $Self->_Connect(
            MailHost  => $Self->{MailHost},
            FQDN      => $Self->{FQDN},
            SMTPPort  => $Self->{SMTPPort},
            SMTPDebug => $Self->{SMTPDebug},
            SSLVerify => $Self->{SSLVerify},
        );

        last TRY if $SMTP;

        # sleep 0,3 seconds;
        select( undef, undef, undef, 0.3 );    ## no critic
    }

    # return if no connect was possible
    if ( !$SMTP ) {
        return (
            Successful => 0,
            Message    => "Can't connect to $Self->{MailHost}: $!!",
        );
    }

    # use smtp auth if configured
    if ( $Self->{User} && $Self->{Password} ) {
        if ( !$SMTP->auth( $Self->{User}, $Self->{Password} ) ) {
            my $Error = $SMTP->code() . $SMTP->message();
            $SMTP->quit();
            return (
                Successful => 0,
                Message =>
                    "SMTP authentication failed: $Error!"
            );
        }
    }

    return (
        Successful => 1,
        SMTP       => $SMTP,
    );
}

sub Send {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(Header Body ToArray)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!",
            );
            return;
        }
    }
    if ( !$Param{From} ) {
        $Param{From} = '';
    }

    # check mail configuration - is there a working smtp host?
    my %Result = $Self->Check();
    if ( !$Result{Successful} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => $Result{Message},
        );
        return;
    }

    # set/get SMTP handle
    my $SMTP = $Result{SMTP};

    # set from, return it from was not accepted
    if ( !$SMTP->mail( $Param{From} ) ) {
        my $Error = $SMTP->code() . $SMTP->message();
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message =>
                "Can't use from '$Param{From}': $Error!",
        );
        $SMTP->quit();
        return;
    }

    # get recipients
    my $ToString = '';
    for my $To ( @{ $Param{ToArray} } ) {
        $ToString .= $To . ',';
        if ( !$SMTP->to($To) ) {
            my $Error = $SMTP->code() . $SMTP->message();
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Can't send to '$To': $Error!",
            );
            $SMTP->quit();
            return;
        }
    }

    # get encode object
    my $EncodeObject = $Kernel::OM->Get('Encode');

    # encode utf8 header strings (of course, there should only be 7 bit in there!)
    $EncodeObject->EncodeOutput( $Param{Header} );

    # encode utf8 body strings
    $EncodeObject->EncodeOutput( $Param{Body} );

    # send data
    if ( !$SMTP->data( ${ $Param{Header} }, "\n", ${ $Param{Body} } ) ) {
        my $Error = $SMTP->code() . $SMTP->message();
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Can't send message: $Error!"
        );
        $SMTP->quit();
        return;
    }
    $SMTP->quit();

    # debug
    if ( $Self->{Debug} > 2 ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'notice',
            Message  => "Sent email to '$ToString' from '$Param{From}'.",
        );
    }
    return 1;
}

sub _Connect {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(MailHost FQDN)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!",
            );
            return;
        }
    }

    # Remove a possible port from the FQDN value
    my $FQDN = $Param{FQDN};
    $FQDN =~ s{:\d+}{}smx;

    # set up connection connection
    my $SMTP = Net::SMTP->new(
        $Param{MailHost},
        Hello   => $FQDN,
        Port    => $Param{SMTPPort} || 25,
        Timeout => 30,
        Debug   => $Param{SMTPDebug},
    );
    return $SMTP;
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
