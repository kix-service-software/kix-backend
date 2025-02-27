# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::API::Operation::V1::GeneralCatalog::GeneralCatalogItemGet;

use strict;
use warnings;

use MIME::Base64;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::GeneralCatalog::GeneralCatalogItemGet - API GeneralCatalogItem Get Operation backend

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

=item ParameterDefinition()

define parameter preparation and check for this operation

    my $Result = $OperationObject->ParameterDefinition(
        Data => {
            ...
        },
    );

    $Result = {
        ...
    };

=cut

sub ParameterDefinition {
    my ( $Self, %Param ) = @_;

    return {
        'GeneralCatalogItemID' => {
            Type     => 'ARRAY',
            DataType => 'NUMERIC',
            Required => 1
        }
    }
}

=item Run()

perform GeneralCatalogItemGet Operation. This function is able to return
one or more ticket entries in one call.

    my $Result = $OperationObject->Run(
        Data => {
            GeneralCatalogItemID => 123       # comma separated in case of multiple or arrayref (depending on transport)
        },
    );

    $Result = {
        Success      => 1,                           # 0 or 1
        Code         => '',                          # In case of an error
        Message      => '',                          # In case of an error
        Data         => {
            GeneralCatalogItem => [
                {
                    ...
                },
                {
                    ...
                },
            ]
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    my @GeneralCatalogList;

    # start loop
    foreach my $GeneralCatalogItemID ( @{$Param{Data}->{GeneralCatalogItemID}} ) {

        # get the GeneralCatalogItem data
        my $ItemData = $Kernel::OM->Get('GeneralCatalog')->ItemGet(
            ItemID => $GeneralCatalogItemID,
            NoPreferences => $Param{Data}->{include}->{Preferences} ? 0 : 1
        );

        if ( !$ItemData ) {
            return $Self->_Error(
                Code => 'Object.NotFound',
            );
        }

        # add known preferences
        if ($Param{Data}->{include}->{Preferences}) {
            $ItemData->{Preferences} = [];

            # get knwon preferences
            my $PreferenceConfigs = $Kernel::OM->Get('Config')->Get('GeneralCatalogPreferences');
            if (IsHashRefWithData($PreferenceConfigs)) {
                for my $Pref ( values %{$PreferenceConfigs} ) {
                    if (
                        IsHashRefWithData($Pref) &&
                        $Pref->{Class} && $Pref->{Class} eq $ItemData->{Class} &&
                        $Pref->{PrefKey} && $ItemData->{ $Pref->{PrefKey} }
                    ) {
                        push(
                            @{$ItemData->{Preferences}},
                            {
                                Name  => $Pref->{PrefKey},
                                Value => $ItemData->{ $Pref->{PrefKey} }
                            }
                        );
                    }
                }
            }
        }

        # remove possible unecessary attributes ((unknown) preferences)
        for my $Attr ( keys %{$ItemData} ) {
            if ($Attr !~ m/^(ChangeBy|ChangeTime|Class|Comment|CreateBy|CreateTime|ItemID|Name|ValidID|Preferences)$/) {
                delete($ItemData->{$Attr});
            }
        }

        # add
        push(@GeneralCatalogList, $ItemData);
    }

    if ( scalar(@GeneralCatalogList) == 1 ) {
        return $Self->_Success(
            GeneralCatalogItem => $GeneralCatalogList[0],
        );
    }

    # return result
    return $Self->_Success(
        GeneralCatalogItem => \@GeneralCatalogList,
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
