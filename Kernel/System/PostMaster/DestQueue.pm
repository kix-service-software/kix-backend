# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::PostMaster::DestQueue;

use strict;
use warnings;

our @ObjectDependencies = (
    'Config',
    'Log',
    'Queue',
    'SystemAddress',
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # get parser object
    $Self->{ParserObject} = $Param{ParserObject} || die "Got no ParserObject!";

    $Self->{Debug} = $Param{Debug} || 0;

    return $Self;
}

sub GetQueueID {
    my ( $Self, %Param ) = @_;

    # get email headers
    my %GetParam = %{ $Param{Params} };

    # check possible to, cc and resent-to emailaddresses
    my $Recipient = '';
    RECIPIENT:
    for my $Key (qw(Resent-To Envelope-To To Cc Delivered-To X-Original-To)) {

        next RECIPIENT if !$GetParam{$Key};

        if ($Recipient) {
            $Recipient .= ', ';
        }

        $Recipient .= $GetParam{$Key};
    }

    # get system address object
    my $SystemAddressObject = $Kernel::OM->Get('SystemAddress');

    # get addresses
    my @EmailAddresses = $Self->{ParserObject}->SplitAddressLine( Line => $Recipient );

    # check addresses
    my $QueueID;
    EMAIL:
    for my $Email (@EmailAddresses) {

        next EMAIL if !$Email;

        my $Address = $Self->{ParserObject}->GetEmailAddress( Email => $Email );

        next EMAIL if !$Address;

        $Address =~ s/("|')//g;

        # lookup queue id if recipiend address
        $QueueID = $SystemAddressObject->SystemAddressQueueID(
            Address => $Address,
        );

        # debug
        if ( $Self->{Debug} > 1 ) {
            if ($QueueID) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'debug',
                    Message =>
                        "Match email: $Email to QueueID $QueueID (MessageID:$GetParam{'Message-ID'})!",
                );
            }
            else {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'debug',
                    Message  => "Does not match email: $Email (MessageID:$GetParam{'Message-ID'})!",
                );
            }
        }

        last EMAIL if $QueueID;
    }

    return $QueueID if $QueueID;

    my $Queue = $Kernel::OM->Get('Config')->Get('PostmasterDefaultQueue');

    return $Kernel::OM->Get('Queue')->QueueLookup(
        Queue => $Queue,
    ) || 1;
}

sub GetTrustedQueueID {
    my ( $Self, %Param ) = @_;

    # get email headers
    my %GetParam = %{ $Param{Params} };

    return if !$GetParam{'X-KIX-Queue'};

    if ( $Self->{Debug} > 0 ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'debug',
            Message => "There exists a X-KIX-Queue header: $GetParam{'X-KIX-Queue'} (MessageID:$GetParam{'Message-ID'})!",
        );
    }

    # get dest queue
    return $Kernel::OM->Get('Queue')->QueueLookup(
        Queue  => $GetParam{'X-KIX-Queue'},
        Silent => 1,
    );
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
