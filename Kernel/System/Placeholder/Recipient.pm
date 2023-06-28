# --
# Modified version of the work: Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com 
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Placeholder::Recipient;

use strict;
use warnings;

use Kernel::Language;

use Kernel::System::VariableCheck qw(:all);

use base qw(Kernel::System::Placeholder::Base);

our @ObjectDependencies = (
    'HTMLUtils',
    'Log',
    'User'
);

=head1 NAME

Kernel::System::Placeholder::Recipient

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

    my %Recipient = %{ $Param{Recipient} || {} };

    # get user object
    my $UserObject = $Kernel::OM->Get('User');

    if ( !%Recipient && $Param{RecipientID} ) {

        %Recipient = $UserObject->GetUserData(
            UserID        => $Param{RecipientID},
            NoOutOfOffice => 1,
        );
    }

    # get recipient data and replace it with <KIX_NOTIFICATION_RECIPIENT_...
    my $RecipientTag = $Self->{Start} . 'KIX_NOTIFICATIONRECIPIENT_';

    # TODO: keep old placeholder syntax for backward compatibility
    my $OldRecipientTag = $Self->{Start} . 'KIX_NOTIFICATION_RECIPIENT_';

    if (%Recipient) {

        # get contact of user if possible
        my %ContactOfUser;
        if ($Recipient{UserID} && $Recipient{Type} eq 'Agent') {
            %ContactOfUser = $Kernel::OM->Get('Contact')->ContactGet(
                UserID => $Recipient{UserID},
            );

            # FIXME: change/remove it (ID handling) with placeholder refactoring
            $Recipient{ID} = $Recipient{UserID};
            if (IsHashRefWithData(\%ContactOfUser)) {
                $ContactOfUser{ContactID} = $ContactOfUser{ID};
                delete $ContactOfUser{ID};

                # HTML quoting of content
                if ( $Param{RichText} ) {
                    for my $Attribute ( keys %ContactOfUser ) {
                        next if !$ContactOfUser{$Attribute};
                        $ContactOfUser{$Attribute} = $Kernel::OM->Get('HTMLUtils')->ToHTML(
                            String => $ContactOfUser{$Attribute},
                        );
                    }
                }
            }
        }

        if ( $Param{RichText} ) {
            ATTRIBUTE:
            for my $Attribute ( sort keys %Recipient ) {
                next ATTRIBUTE if !$Recipient{$Attribute};
                $Recipient{$Attribute} = $Kernel::OM->Get('HTMLUtils')->ToHTML(
                    String => $Recipient{$Attribute},
                );
            }
        }

        $Param{Text} = $Self->_HashGlobalReplace( $Param{Text}, "$RecipientTag|$OldRecipientTag", %ContactOfUser, %Recipient );
    }

    # cleanup
    $Param{Text} =~ s/(?:$RecipientTag|$OldRecipientTag).+?$Self->{End}/$Param{ReplaceNotFound}/gi;

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
