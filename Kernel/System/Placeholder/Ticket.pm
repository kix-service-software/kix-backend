# --
# Modified version of the work: Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Placeholder::Ticket;

use strict;
use warnings;

use Kernel::Language;

use Kernel::System::VariableCheck qw(:all);

use base qw(Kernel::System::Placeholder::Base);

our @ObjectDependencies = (
    'Config',
    'Log',
    'Queue'
);

=head1 NAME

Kernel::System::Placeholder::Ticket

=cut

=begin Internal:

=cut

sub _Replace {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(Text UserID)) {
        if ( !defined $Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    my %Queue;
    if ( $Param{QueueID} ) {
        %Queue = $Kernel::OM->Get('Queue')->QueueGet(
            ID => $Param{QueueID},
        );
    }

    if ( IsHashRefWithData(\%Queue) ) {
        $Param{Text} =~ s/$Self->{Start} KIX_TICKET_QUEUE $Self->{End}/$Queue{Name}/gixms;
    }

    my $Tag = $Self->{Start} . 'KIX_TICKET_';
    if ( IsHashRefWithData($Param{Ticket}) ) {
        $Param{Text} =~ s/$Self->{Start} KIX_TICKET_ID $Self->{End}/$Param{Ticket}->{TicketID}/gixms;
        $Param{Text} =~ s/$Self->{Start} KIX_TICKET_NUMBER $Self->{End}/$Param{Ticket}->{TicketNumber}/gixms;
        $Param{Text} =~ s/$Self->{Start} KIX_QUEUE $Self->{End}/$Param{Ticket}->{Queue}/gixms;

        # TODO: still necessary?
        # KIXBase-capeIT
        if ( $Param{Ticket}->{Service} && $Param{Text} ) {
            my $LevelSeparator        = $Kernel::OM->Get('Config')->Get('TemplateGenerator::LevelSeparator');
            my $ServiceLevelSeparator = '::';
            if ( $LevelSeparator && ref($LevelSeparator) eq 'HASH' && $LevelSeparator->{Service} ) {
                $ServiceLevelSeparator = $LevelSeparator->{Service};
            }
            my @Service = split( $ServiceLevelSeparator, $Param{Ticket}->{Service} );

            my $MatchPattern = $Self->{Start} . "KIX_TICKET_Service_Level_(.*?)" . $Self->{End};
            while ( $Param{Text} =~ /$MatchPattern/ ) {
                my $ReplacePattern = $Self->{Start} . "KIX_TICKET_Service_Level_" . $1 . $Self->{End};
                my $Level = ( $1 eq 'MAX' ) ? -1 : ($1) - 1;
                if ( $Service[$Level] ) {
                    $Param{Text} =~ s/$ReplacePattern/$Service[$Level]/gixms
                }
                else {
                    $Param{Text} =~ s/$ReplacePattern/-/gixms
                }

            }
        }

        # EO KIXBase-capeIT

        # replace it
        $Param{Text} = $Self->_HashGlobalReplace( $Param{Text}, $Tag, %{ $Param{Ticket} } );
    }

    # cleanup
    $Param{Text} =~ s/$Tag.+?$Self->{End}/-/gi;

    return $Param{Text};
}

1;

=end Internal:

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
