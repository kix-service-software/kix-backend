# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::HTMLToPDF::Object::Organisation;

use strict;
use warnings;

use base qw(
    Kernel::System::HTMLToPDF::Object::Common
);

our @ObjectDependencies = qw(
    Organisation
);

use Kernel::System::VariableCheck qw(:all);

sub GetParams {
    my ( $Self, %Param) = @_;

    return {
        IDKey => 'OrganisationID',
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

    for my $Needed ( qw(OrganisationID) ) {
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

    my $OrganisationObject = $Kernel::OM->Get('Organisation');

    my %Organisation;
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

    my $OrganisationID = $Param{OrganisationID};
    if (
        $Param{Filters}
        && $Param{Filters}->{Organisation}
        && IsHashRefWithData($Param{Filters}->{Organisation})
    ) {
        %Filters = %{$Param{Filters}->{Organisation}};
    }

    if ( !%Organisation ) {
        %Organisation = $OrganisationObject->OrganisationGet(
            ID     => $OrganisationID,
            UserID => $Param{UserID}
        );
    }
    else {
        %Organisation = %{$Param{Data}};
    }

    # Copies the object ID to the IDKey identifier so that the IDKey can be used everywhere
    $Organisation{OrganisationID} = $Organisation{ID};

    my $DynamicFields;
    if ( %Expands ) {
        for my $Expand ( keys %Expands ) {
            my $Function = $ExpendFunc{$Expand};

            next if !$Function;

            $Self->$Function(
                Expands  => $Expands{$Expand} || 0,
                ObjectID => $Organisation{ID} || $OrganisationID,
                UserID   => $Param{UserID},
                Data     => \%Organisation,
                Type     => 'Organisation',
            );

            if ( $Expand eq 'DynamicField' ) {
                $DynamicFields = $Organisation{Expands}->{DynamicFied};
            }
        }
    }

    if ( %Filters ) {
        my $Match = $Self->_Filter(
            Data   => {
                %Organisation,
                %{$DynamicFields}
            },
            Filter => \%Filters
        );

        return if !$Match;
    }

    return \%Organisation;
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
