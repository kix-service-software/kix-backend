# --
# Copyright (C) 2006-2021 c.a.p.e. IT GmbH, https://www.cape-it.de
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

            # get already prepared data of current definition from ClassDefinitionSearch operation
            my $Result = $Self->ExecOperation(
                OperationType => 'V1::CMDB::ClassDefinitionSearch',
                Data          => {
                    ClassID => $ClassID,
                    sort    => 'ConfigItemClassDefinition.-Version:numeric',
                    limit   => 1,
                }
            );

            if ( IsHashRefWithData($Result) && $Result->{Success} ) {
                $Class{CurrentDefinition} = IsArrayRefWithData( $Result->{Data}->{ConfigItemClassDefinition} ) ? $Result->{Data}->{ConfigItemClassDefinition}->[0] : undef;
            }
        }

        # include ConfigItemStats if requested
        if ( $Param{Data}->{include}->{ConfigItemStats} ) {

            my $Response = $Self->_GetConfigItemStats(ClassID => $ClassID);

            if ( !IsHashRefWithData($Response) || !$Response->{Success} ) {
                return $Response;
            }
            $Class{ConfigItemStats} = $Response->{Stats};

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

sub _GetConfigItemStats {
    my ( $Self, %Param ) = @_;

    my %Stats;
    # search pre-/productive CIs - use API modules to consider permissions
    # get relevant deployment states
    my $Response = $Self->ExecOperation(
        OperationType => 'V1::GeneralCatalog::GeneralCatalogItemSearch',
        IgnoreInclude => 1, # ignore "hereditary" includes (ConfigItemStats) to use own include
        Data          => {
            include => 'Preferences',
            filter => {
                GeneralCatalogItem => {
                    AND => [
                        {
                            Field    => 'Class',
                            Operator => 'EQ',
                            Value    => 'ITSM::ConfigItem::DeploymentState'
                        },
                        {
                            Field    => 'Preferences.Name',
                            Operator => 'EQ',
                            Value    => 'Functionality'
                        },
                        {
                            Field    => 'Preferences.Value',
                            Operator => 'IN',
                            Value    => [ 'preproductive', 'productive' ]
                        }
                    ]
                }
            }
        }
    );

    if ( !IsHashRefWithData($Response) || !$Response->{Success} ) {
        return $Response;
    }

    my @PreProductiveDeplStateIDs;
    my @ProductiveDeplStateIDs;
    foreach my $Item ( @{ $Response->{Data}->{GeneralCatalogItem} } ) {
        if ( IsArrayRefWithData($Item->{Preferences}) ) {
            for my $Pref ( @{ $Item->{Preferences} } ) {
                if (
                    IsHashRefWithData($Pref) &&
                    $Pref->{Name} && $Pref->{Name} eq 'Functionality' &&
                    $Pref->{Value}
                ) {
                    if ( $Pref->{Value} eq 'preproductive' ) {
                        push( @PreProductiveDeplStateIDs, $Item->{ItemID} );
                        last;
                    } elsif ( $Pref->{Value} eq 'productive' ) {
                        push( @ProductiveDeplStateIDs, $Item->{ItemID} );
                        last;
                    }
                }
            }
        }
    }

    # search pre-/productive CIs
    if (IsArrayRefWithData(\@PreProductiveDeplStateIDs)) {
        my $PreProductiveResponse = $Self->ExecOperation(
            OperationType => 'V1::CMDB::ConfigItemSearch',
            Data          => {
                search => {
                    ConfigItem => {
                        AND => [
                            {
                                Field    => 'ClassIDs',
                                Operator => 'IN',
                                Value    => [$Param{ClassID}]
                            },
                            {
                                Field    => 'DeplStateIDs',
                                Operator => 'IN',
                                Value    => \@PreProductiveDeplStateIDs
                            }
                        ]
                    }
                }
            }
        );
        if ( !IsHashRefWithData($PreProductiveResponse) || !$PreProductiveResponse->{Success} ) {
            return $PreProductiveResponse;
        }
        $Stats{PreProductiveCount} = @{ $PreProductiveResponse->{Data}->{ConfigItem} };
    } else {
        $Stats{PreProductiveCount} = 0;
    }

    if (IsArrayRefWithData(\@ProductiveDeplStateIDs)) {
        my $ProductiveResponse = $Self->ExecOperation(
            OperationType => 'V1::CMDB::ConfigItemSearch',
            Data          => {
                search => {
                    ConfigItem => {
                        AND => [
                            {
                                Field    => 'ClassIDs',
                                Operator => 'IN',
                                Value    => [$Param{ClassID}]
                            },
                            {
                                Field    => 'DeplStateIDs',
                                Operator => 'IN',
                                Value    => \@ProductiveDeplStateIDs
                            }
                        ]
                    }
                }
            }
        );
        if ( !IsHashRefWithData($ProductiveResponse) || !$ProductiveResponse->{Success} ) {
            return $ProductiveResponse;
        }
        $Stats{ProductiveCount} = @{ $ProductiveResponse->{Data}->{ConfigItem} };
    } else {
        $Stats{ProductiveCount} = 0;
    }

    return {
        Success => 1,
        Stats =>\%Stats
    }
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
