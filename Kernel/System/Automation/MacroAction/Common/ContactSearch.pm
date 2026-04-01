# --
# Copyright (C) 2006-2026 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --
# --
# Copyright (C) 2006-2026 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Automation::MacroAction::Common::ContactSearch;

use strict;
use warnings;
use utf8;

use Kernel::System::VariableCheck qw(:all);

use base qw(Kernel::System::Automation::MacroAction::Common);

our @ObjectDependencies = (
    "Contact",
    "Log",
    "ObjectSearch",
);

=head1 NAME

Kernel::System::Automation::MacroAction::Common::ContactSearch - A module to search for a contact

=head1 SYNOPSIS

All ContactSearch functions.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item Describe()

Describe this macro action module.

=cut

sub Describe {
    my ( $Self, %Param ) = @_;

    $Self->Description(Kernel::Language::Translatable('Search for ContactID or UserID.'));
    $Self->AddOption(
        Name        => 'Pattern',
        Label       => Kernel::Language::Translatable('Pattern'),
        Description => Kernel::Language::Translatable('Search pattern which is checked against the value of the selected attribute. Placeholders <KIX_TICKET_...>, <KIX_CONTACT_...> and <KIX...> are supported.'),
        Required    => 1,
        Placeholder => {
            Richtext  => 0,
            Translate => 1,
        },
    );
    $Self->AddOption(
        Name        => 'Attribute',
        Label       => Kernel::Language::Translatable('Attribute'),
        Description => Kernel::Language::Translatable('Determines in which attribute to search. "Firstname", "Lastname" and contact dynamic fields "DynamicField_xyz" are allowed.'),
        Required    => 1,
    );
    $Self->AddOption(
        Name        => 'OnlyValid',
        Label       => Kernel::Language::Translatable('Valid'),
        Description => Kernel::Language::Translatable('(Optional) Determines whether only valid contacts should be searched for. With "0" all contacts are taken into account and with "1" only valid ones.'),
        Required    => 0,
    );

    $Self->AddResult(
        Name        => 'ResultContactID',
        Description => Kernel::Language::Translatable('The ID of the found contact.'),
    );
    $Self->AddResult(
        Name        => 'ResultUserID',
        Description => Kernel::Language::Translatable('The assigned user ID of the found contact.'),
    );

    return;
}

=item Run()

Run this module. Returns 1 if everything is ok.

Example:
    my $Success = $Object->Run(
        TicketID => 123,
        Config   => {
            Attribute       => 'Lastname',
            Pattern         => 'Mustermann',
            OnlyValid       => 1,
        },
        UserID   => 123
    );

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # check incoming parameters
    return if !$Self->_CheckParams(%Param);

    my $Attribute = $Param{Config}->{Attribute};
    my $Pattern   = $Param{Config}->{Pattern};

    if (
        $Pattern eq q{}
        || $Pattern eq q{-}
    ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "The given search pattern is empty or not valid!"
        );
        return;
    };

    my %Search = (
        AND => []
    );
    if (
        $Attribute =~ /^(?:First|Last)name$/smx
        || $Attribute =~ /^DynamicField_/smx
    ) {
        push(
            @{ $Search{AND} },
            {
                Field    => $Attribute,
                Operator => 'LIKE',
                Value    => $Pattern,
            }
        );
    }
    else {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "The given attribute '$Attribute' is not allowed!"
        );
        return;
    }
    if ( $Param{Config}->{OnlyValid} ) {
        push(
            @{ $Search{AND} },
            {
                Field    => 'ValidID',
                Operator => 'EQ',
                Value    => 1,
            }
        );
    }

    my @ContactIDs = $Kernel::OM->Get('ObjectSearch')->Search(
        ObjectType => 'Contact',
        Result     => 'ARRAY',
        Search     => \%Search,
        UserID     => $Param{UserID},
    );
    return if ( !IsArrayRefWithData( \@ContactIDs ) );

    my $ResultContactID;
    my $ResultUserID;
    for my $ContactID (@ContactIDs) {
        my %Contact = $Kernel::OM->Get('Contact')->ContactGet(
            ID => $ContactID,
        );
        next if ( !%Contact );

        if ( $Attribute =~ /^(?:First|Last)name$/smx ) {
            next if ( !$Contact{ $Attribute } );
        }

        $ResultContactID = $ContactID;

        if ( $Contact{AssignedUserID} ) {
            $ResultUserID = $Contact{AssignedUserID};
        }

        last;
    }

    if ( $ResultContactID ) {
        $Self->SetResult(
            Name   => 'ResultContactID',
            Value  => $ResultContactID,
            UserID => $Param{UserID}
        );
    }
    if ( $ResultUserID ) {
        $Self->SetResult(
            Name   => 'ResultUserID',
            Value  => $ResultUserID,
            UserID => $Param{UserID}
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