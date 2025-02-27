# --
# Modified version of the work: Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com 
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::PostMaster::Filter::NewTicketReject;

use strict;
use warnings;

our @ObjectDependencies = (
    'Config',
    'Email',
    'Log',
    'Ticket',
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    $Self->{Debug} = $Param{Debug} || 0;

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(JobConfig GetParam)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    # get config options
    my %Config;
    my %Match;
    my %Set;
    if ( $Param{JobConfig} && ref $Param{JobConfig} eq 'HASH' ) {
        %Config = %{ $Param{JobConfig} };
        if ( $Config{Match} ) {
            %Match = %{ $Config{Match} };
        }
        if ( $Config{Set} ) {
            %Set = %{ $Config{Set} };
        }
    }

    # match 'Match => ???' stuff
    my $Matched    = '';
    my $MatchedNot = 0;
    for ( sort keys %Match ) {

        if ( $Param{GetParam}->{$_} && $Param{GetParam}->{$_} =~ /$Match{$_}/i ) {
            $Matched = $1 || '1';
            if ( $Self->{Debug} > 1 ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'debug',
                    Message  => "'$Param{GetParam}->{$_}' =~ /$Match{$_}/i matched!",
                );
            }
        }
        else {
            $MatchedNot = 1;
            if ( $Self->{Debug} > 1 ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'debug',
                    Message  => "'$Param{GetParam}->{$_}' =~ /$Match{$_}/i matched NOT!",
                );
            }
        }
    }
    if ( $Matched && !$MatchedNot ) {

        # get ticket object
        my $TicketObject = $Kernel::OM->Get('Ticket');

        # check if new ticket
        my $Tn = $TicketObject->GetTNByString( $Param{GetParam}->{Subject} );

        return 1 if $Tn && $TicketObject->TicketCheckNumber( Tn => $Tn );

        # set attributes if ticket is created
        for ( sort keys %Set ) {
            $Param{GetParam}->{$_} = $Set{$_};
            $Kernel::OM->Get('Log')->Log(
                Priority => 'notice',
                Message =>
                    "Set param '$_' to '$Set{$_}' (Message-ID: $Param{GetParam}->{'Message-ID'}) ",
            );
        }

        # get config object
        my $ConfigObject = $Kernel::OM->Get('Config');

        # send bounce mail
        my $Subject = $ConfigObject->Get(
            'PostMaster::PreFilterModule::NewTicketReject::Subject'
        );
        my $Body = $ConfigObject->Get(
            'PostMaster::PreFilterModule::NewTicketReject::Body'
        );
        my $Sender = $ConfigObject->Get(
            'PostMaster::PreFilterModule::NewTicketReject::Sender'
        ) || '';

        $Kernel::OM->Get('Email')->Send(
            From       => $Sender,
            To         => $Param{GetParam}->{From},
            Subject    => $Subject,
            Body       => $Body,
            Charset    => 'utf-8',
            MimeType   => 'text/plain',
            Loop       => 1,
            Attachment => [
                {
                    Filename    => 'email.txt',
                    Content     => $Param{GetParam}->{Body},
                    ContentType => 'application/octet-stream',
                }
            ],
        );

        $Kernel::OM->Get('Log')->Log(
            Priority => 'notice',
            Message  => "Send reject mail to '$Param{GetParam}->{From}'!",
        );
    }

    return 1;
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
