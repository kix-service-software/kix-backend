# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Placeholder::User;

use strict;
use warnings;

use Kernel::Language;

use Kernel::System::VariableCheck qw(:all);

use base qw(Kernel::System::Placeholder::Base);

our @ObjectDependencies = qw(
    Config
    Contact
    HTMLUtils
    Log
    User
);

=head1 NAME

Kernel::System::Placeholder::User

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

    my $UserObject = $Kernel::OM->Get('User');

    # replace owner placeholders
    my $Tag  = $Self->{Start} . 'KIX_OWNER_';
    my $Tag2 = $Self->{Start} . 'KIX_TICKETOWNER_';

    # TODO: keep old placeholder syntax for backward compatibility
    my $OldTag = $Self->{Start} . 'KIX_TICKET_OWNER_';

    if ($Param{Text} =~ m/$Tag/ || $Param{Text} =~ m/$Tag2/ || $Param{Text} =~ m/$OldTag/) {
        if (IsHashRefWithData($Param{Ticket}) && $Param{Ticket}->{OwnerID}) {
            $Param{Text} = $Self->_ReplaceUserPlaceholder(
                %Param,
                Tags      => [ $Tag, $Tag2, $OldTag ],
                UseUserID => $Param{Ticket}->{OwnerID}
            );
        }

        # cleanup
        $Param{Text} =~ s/(?:$Tag|$Tag2|$OldTag).+?$Self->{End}/$Param{ReplaceNotFound}/gi;
    }

    # replace responsible placeholder
    $Tag  = $Self->{Start} . 'KIX_RESPONSIBLE_';
    $Tag2 = $Self->{Start} . 'KIX_TICKETRESPONSIBLE_';

    # TODO: keep old placeholder syntax for backward compatibility
    $OldTag = $Self->{Start} . 'KIX_TICKET_RESPONSIBLE_';

    if ($Param{Text} =~ m/$Tag/ || $Param{Text} =~ m/$Tag2/ || $Param{Text} =~ m/$OldTag/) {
        if (IsHashRefWithData($Param{Ticket}) && $Param{Ticket}->{ResponsibleID}) {
            $Param{Text} = $Self->_ReplaceUserPlaceholder(
                %Param,
                Tags      => [ $Tag, $Tag2, $OldTag ],
                UseUserID => $Param{Ticket}->{ResponsibleID}
            );
        }

        # cleanup
        $Param{Text} =~ s/(?:$Tag|$Tag2|$OldTag).+?$Self->{End}/$Param{ReplaceNotFound}/gi;
    }

    # replace current agent placeholders
    $Tag = $Self->{Start} . 'KIX_CURRENT_';

    if ($Param{Text} =~ m/$Tag/) {
        if ($Param{UserID}) {
            $Param{Text} = $Self->_ReplaceUserPlaceholder(
                %Param,
                Tags      => [ $Tag ],
                UseUserID => $Param{UserID}
            );
        }

        # cleanup
        $Param{Text} =~ s/$Tag.+?$Self->{End}/$Param{ReplaceNotFound}/gi;
    }

    return $Param{Text};
}

sub _ReplaceUserPlaceholder {
    my ( $Self, %Param ) = @_;

    my %User = $Kernel::OM->Get('User')->GetUserData(
        UserID => $Param{UseUserID},
    );

    my $Languages = $Kernel::OM->Get('Config')->Get('DefaultUsedLanguages');
    if (IsHashRefWithData($Languages) && $User{Preferences}->{UserLanguage}) {
        $User{UserLanguage} = $Languages->{$User{Preferences}->{UserLanguage}} || $User{Preferences}->{UserLanguage};
    }
    if ($User{Preferences}->{UserLastLoginTimestamp}) {
        $User{UserLastLogin} = $User{Preferences}->{UserLastLoginTimestamp};
    }
    # Preference attributes are moved to root as Preferences_SomePreference.
    # This allows preferences to be queried like with "<KIX_CURRENT_Preferences_SomePreference>"
    if ( IsHashRefWithData($User{Preferences}) ) {
        for my $Pref ( keys %{$User{Preferences}} ) {
            $User{"Preferences_$Pref"} = $User{Preferences}->{$Pref};
        }
        delete ($User{Preferences});
    }

    my %ContactOfUser = $Kernel::OM->Get('Contact')->ContactGet(
        UserID => $Param{UseUserID},
    );

    # FIXME: change/remove it (ID handling) with placeholder refactoring
    if (IsHashRefWithData(\%User)) {
        $User{ID} = $User{UserID};
    }
    if (IsHashRefWithData(\%ContactOfUser)) {
        $ContactOfUser{ContactID} = $ContactOfUser{ID};
        delete $ContactOfUser{ID};
    }

    # html quoting of content
    if ( $Param{RichText} ) {
        for my $Attribute ( keys %ContactOfUser ) {
            next if !$ContactOfUser{$Attribute};
            $ContactOfUser{$Attribute} = $Kernel::OM->Get('HTMLUtils')->ToHTML(
                String => $ContactOfUser{$Attribute},
            );
        }
        for my $Attribute ( keys %User ) {
            next if !$User{$Attribute};
            $User{$Attribute} = $Kernel::OM->Get('HTMLUtils')->ToHTML(
                String => $User{$Attribute},
            );
        }
    }

    return $Self->_HashGlobalReplace( $Param{Text}, join(q{|}, @{$Param{Tags}}), %ContactOfUser, %User );
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
