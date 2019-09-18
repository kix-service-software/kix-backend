# --
# Copyright (C) 2006-2019 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::CMDB::ClassGet;

use strict;
use warnings;

use MIME::Base64;

use Kernel::System::VariableCheck qw(IsArrayRefWithData IsHashRefWithData IsStringWithData);

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

=item new()

usually, you want to create an instance of this
by using Kernel::API::Operation::V1->new();

=cut

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};
    bless( $Self, $Type );

    # check needed objects
    for my $Needed (qw(DebuggerObject WebserviceID)) {
        if ( !$Param{$Needed} ) {
            return {
                Success      => 0,
                ErrorMessage => "Got no $Needed!",
            };
        }

        $Self->{$Needed} = $Param{$Needed};
    }

    return $Self;
}

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

        my $ItemData = $Kernel::OM->Get('Kernel::System::GeneralCatalog')->ItemGet(
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
                    sort    => 'ConfigItemClassDefinition.-DefinitionID:numeric',
                    limit   => 1,
                }
            );

            if ( IsHashRefWithData($Result) && $Result->{Success} ) {
                $Class{CurrentDefinition} = IsArrayRefWithData( $Result->{Data}->{ConfigItemClassDefinition} ) ? $Result->{Data}->{ConfigItemClassDefinition}->[0] : undef;
            }
        }

        # include ConfigItemStats if requested
        if ( $Param{Data}->{include}->{ConfigItemStats} ) {

            # execute CI searches
            my %ConfigItemStats;

            # search pre-productive CIs
            my $Response = $Self->ExecOperation(
                OperationType => 'V1::GeneralCatalog::GeneralCatalogItemSearch',
                Data          => {
                    search => {
                        GeneralCatalogItem => {
                            AND => [
                                {
                                    Field    => 'Class',
                                    Operator => 'EQ',
                                    Value    => 'ITSM::ConfigItem::DeploymentState'
                                },
                                {
                                    Field    => 'Functionality',
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
                if ( $Item->{Functionality} && $Item->{Functionality} eq 'preproductive' ) {
                    push( @PreProductiveDeplStateIDs, $Item->{ItemID} );
                }
                elsif ( $Item->{Functionality} && $Item->{Functionality} eq 'productive' ) {
                    push( @ProductiveDeplStateIDs, $Item->{ItemID} );
                }
            }

            my $PreProductiveList = $Kernel::OM->Get('Kernel::System::ITSMConfigItem')->ConfigItemSearch(
                ClassIDs     => [$ClassID],
                DeplStateIDs => \@PreProductiveDeplStateIDs,
                UserID       => $Self->{Authorization}->{UserID},
            );
            $ConfigItemStats{PreProductiveCount} = @{$PreProductiveList};

            my $ProductiveList = $Kernel::OM->Get('Kernel::System::ITSMConfigItem')->ConfigItemSearch(
                ClassIDs     => [$ClassID],
                DeplStateIDs => \@ProductiveDeplStateIDs,
                UserID       => $Self->{Authorization}->{UserID},
            );
            $ConfigItemStats{ProductiveCount} = @{$ProductiveList};

            $Class{ConfigItemStats} = \%ConfigItemStats;

            # inform API caching about a new dependency
            $Self->AddCacheDependency( Type => 'ITSMConfigurationManagement' );
        }

        push( @ClassList, \%Class );
    }

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
