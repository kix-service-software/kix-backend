# --
# Modified version of the work: Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Placeholder::Queue;

use strict;
use warnings;

use Kernel::Language;

use Kernel::System::VariableCheck qw(:all);

use base qw(Kernel::System::Placeholder::Base);

our @ObjectDependencies = (
    'Log',
    'Queue',
    'TemplateGenerator'
);

=head1 NAME

Kernel::System::Placeholder::Queue

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
    if ( $Param{QueueID} && $Param{QueueID} =~ m/^\d+$/ ) {
        %Queue = $Kernel::OM->Get('Queue')->QueueGet(
            ID => $Param{QueueID}
        );
    } elsif ( $Param{Data}->{QueueID} && $Param{Data}->{QueueID} =~ m/^\d+$/ ) {
        %Queue = $Kernel::OM->Get('Queue')->QueueGet(
            ID => $Param{Data}->{QueueID}
        );
    } elsif ( IsHashRefWithData($Param{Ticket}) ) {
        if ( $Param{Ticket}->{QueueID} ) {
            %Queue = $Kernel::OM->Get('Queue')->QueueGet(
                ID => $Param{Ticket}->{QueueID}
            );
        } elsif ( $Param{Ticket}->{Queue} ) {
            %Queue = $Kernel::OM->Get('Queue')->QueueGet(
                Name => $Param{Ticket}->{Queue}
            );
        }
    }

    my $Tag = $Self->{Start} . 'KIX_QUEUE_';
    if ( IsHashRefWithData(\%Queue) ) {
        my %PreparedQueue = (
            ID           => $Queue{QueueID},
            Signature    => $Queue{Signature}
        );

        my $LanguageObject;
        if ($Param{Language}) {
            $LanguageObject = Kernel::Language->new(
                UserLanguage => $Param{Language}
            );
        }

        $PreparedQueue{FollowUpLock} = $Queue{FollowUpLock} ? 'Yes' : 'No';
        if ($LanguageObject) {
            $PreparedQueue{FollowUpLock} = $LanguageObject->Translate( $PreparedQueue{FollowUpLock} );
        }

        # handle placeholders in signature
        if (
            $PreparedQueue{Signature} &&
            !$Param{SignatureReplace} &&
            $Param{Text} =~ m/$Tag\Signature$Self->{End}/
        ) {
            $PreparedQueue{Signature} = $Kernel::OM->Get('TemplateGenerator')->ReplacePlaceHolder(
                %Param,
                Text => $PreparedQueue{Signature},

                # prevent replacement loop
                SignatureReplace => 1
            );
        } else {
            $PreparedQueue{Signature} = undef;
        }

        if ( $Queue{FollowUpID} ) {
            $PreparedQueue{FollowUp} = $Kernel::OM->Get('Queue')->GetFollowUpOption(
                QueueID => $Queue{QueueID}
            );
            if ($LanguageObject) {
                $PreparedQueue{FollowUp} = $LanguageObject->Translate( $PreparedQueue{FollowUp} );
            }
        }

        if ( $Queue{SystemAddressID} ) {
            my %Address = $Kernel::OM->Get('Queue')->GetSystemAddress(
                QueueID => $Queue{QueueID}
            );
            if (IsHashRefWithData(\%Address)) {
                if ($Address{RealName}) {
                    $PreparedQueue{SystemAddress} = '"' . $Address{RealName} . '" <' . $Address{Email} . '>';
                } else {
                    $PreparedQueue{SystemAddress} = $Address{Email};
                }
            }
        }

        my @QueueNameParts = split(/::/, $Queue{Name});
        $PreparedQueue{Fullname} = $Queue{Name};
        $PreparedQueue{Name}     = pop @QueueNameParts;

        if ( @QueueNameParts ) {
            my $ParentFullname = join('::', @QueueNameParts);
            $PreparedQueue{ParentID} = $Kernel::OM->Get('Queue')->QueueLookup(
                Queue  => $ParentFullname,
                Silent => 1
            );
            if ($PreparedQueue{ParentID}) {
                $PreparedQueue{ParentFullname} = $ParentFullname;
                $PreparedQueue{Parent} = pop @QueueNameParts;
            }
        }

        # replace it
        $Param{Text} = $Self->_HashGlobalReplace( $Param{Text}, $Tag, %Queue, %PreparedQueue );
    }

    # cleanup
    $Param{Text} =~ s/$Tag.+?$Self->{End}/$Param{ReplaceNotFound}/gi;

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
