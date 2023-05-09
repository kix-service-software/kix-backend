# --
# Copyright (C) 2006-2023 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::HTMLToPDF::Object::Contact;

use strict;
use warnings;

use base qw(
    Kernel::System::HTMLToPDF::Object::Common
);

our @ObjectDependencies = qw(
    Contact
);

use Kernel::System::VariableCheck qw(:all);

sub GetParams {
    my ( $Self, %Param) = @_;

    return {
        IDKey => 'ContactID',
    };
}

sub GetPossibleExpands {
    my ( $Self, %Param) = @_;

    return [
        'DynamicField'
    ];
}

sub CheckParams {
    my ( $Self, %Param) = @_;

    for my $Needed ( qw(ContactID) ) {
        if ( !$Param{$Needed} ) {
            return {
                error => "No given $Needed!"
            }
        }
    }

    return 1;
}

sub DataGet {
    my ($Self, %Param) = @_;

    my $ContactObject = $Kernel::OM->Get('Contact');

    my %Contact;
    my %Expands;
    my %Filters;

    if ( IsArrayRefWithData($Param{Expands}) ) {
        %Expands = map { $_ => 1 } @{$Param{Expands}};
    }
    elsif( $Param{Expands} ) {
        %Expands = map { $_ => 1 } split( /[,]/sm, $Param{Expands});
    }

    my %ExpendFunc = (
        DynamicField => '_GetDynamicFields',
    );

    my $ContactID = $Param{ContactID};
    if (
        $Param{Filters}
        && $Param{Filters}->{Contact}
        && IsHashRefWithData($Param{Filters}->{Contact})
    ) {
        %Filters = %{$Param{Filters}->{Contact}};
    }

    if ( !%Contact ) {
        %Contact = $ContactObject->ContactGet(
            ID => $ContactID,
        );
    }
    else {
        %Contact = %{$Param{Data}};
    }

    my $DynamicFields;
    if ( %Expands ) {
        for my $Expand ( keys %Expands ) {
            my $Function = $ExpendFunc{$Expand};

            next if !$Function;

            $Self->$Function(
                Expands  => $Expands{$Expand} || 0,
                ObjectID => $Contact{ID} || $ContactID,
                UserID   => $Param{UserID},
                Type     => 'Contact',
                Data     => \%Contact,
            );

            if ( $Expand eq 'DynamicField' ) {
                $DynamicFields = $Contact{Expands}->{DynamicFied};
            }
        }
    }

    if ( %Filters ) {
        my $Match = $Self->_Filter(
            Data   => {
                %Contact,
                %{$DynamicFields}
            },
            Filter => \%Filters
        );

        return if !$Match;
    }

    return \%Contact;
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