# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/ 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::CMDB::ClassGet;

use strict;
use warnings;

use MIME::Base64;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::CMDB::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::CMDB::ClassGet - API ClassGet Operation backend

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
        'ClassID' => {
            Type     => 'ARRAY',
            DataType => 'NUMERIC',
            Required => 1
        },
        }
}

=item Run()

perform ClassGet Operation.

    my $Result = $OperationObject->Run(
        ClassID  => 1                                              # required
    );

    $Result = {
        Success      => 1,                                # 0 or 1
        Code         => '',                               # In case of an error
        Message      => '',                               # In case of an error
        Data         => {
            ConfigItemClass => [
                {
                    ...
                },
            ]
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    my @ClassList;
    foreach my $ClassID ( @{ $Param{Data}->{ClassID} } ) {

        my $ItemData = $Kernel::OM->Get('GeneralCatalog')->ItemGet(
            ItemID => $ClassID,
        );

        if ( !IsHashRefWithData($ItemData) || $ItemData->{Class} ne 'ITSM::ConfigItem::Class' ) {
            return $Self->_Error(
                Code => 'Object.NotFound',
            );
        }

        my %Class = %{$ItemData};

        # prepare data
        $Class{ID} = $ClassID;
        foreach my $Key (qw(ItemID Class Permission)) {
            delete $Class{$Key};
        }

        # include CurrentDefinition if requested
        if ( $Param{Data}->{include}->{CurrentDefinition} ) {

            $Class{CurrentDefinition} = undef;

            my $Definition = $Kernel::OM->Get('ITSMConfigItem')->DefinitionGet(
                ClassID => $ClassID,
            );

            if ( IsHashRefWithData($Definition) ) {
                # get already prepared data of current definition from ClassDefinitionSearch operation
                my $Result = $Self->ExecOperation(
                    OperationType => 'V1::CMDB::ClassDefinitionGet',
                    Data          => {
                        ClassID      => $ClassID,
                        DefinitionID => $Definition->{DefinitionID},
                    }
                );

                if ( IsHashRefWithData($Result) && $Result->{Success} ) {
                    $Class{CurrentDefinition} = IsHashRefWithData( $Result->{Data}->{ConfigItemClassDefinition} ) ? $Result->{Data}->{ConfigItemClassDefinition} : undef;
                }
            }
        }

        # include ConfigItemStats if requested
        if ( $Param{Data}->{include}->{ConfigItemStats} ) {

            my %Stats;
            $Stats{PreProductiveCount} = $Kernel::OM->Get('ITSMConfigItem')->ConfigItemCounterGet(
                ClassID => $ClassID,
                Counter => 'DeploymentState::Functionality::preproductive'
            );
            $Stats{ProductiveCount} = $Kernel::OM->Get('ITSMConfigItem')->ConfigItemCounterGet(
                ClassID => $ClassID,
                Counter => 'DeploymentState::Functionality::productive'
            );

            $Class{ConfigItemStats} = \%Stats;

            # inform API caching about a new dependency
            $Self->AddCacheDependency( Type => 'ITSMConfigurationManagement' );
        }

        push( @ClassList, \%Class );
    }

    # inform API caching about a new dependency
    $Self->AddCacheDependency( Type => 'GeneralCatalog' );

    if ( scalar(@ClassList) == 0 ) {
        return $Self->_Error(
            Code => 'Object.NotFound',
        );
    }
    elsif ( scalar(@ClassList) == 1 ) {
        return $Self->_Success(
            ConfigItemClass => $ClassList[0],
        );
    }

    return $Self->_Success(
        ConfigItemClass => \@ClassList,
    );
}

1;


=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-GPL3 for license information (GPL3). If you did not receive this file, see

<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
