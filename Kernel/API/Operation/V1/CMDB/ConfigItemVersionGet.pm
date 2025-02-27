# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::API::Operation::V1::CMDB::ConfigItemVersionGet;

use strict;
use warnings;

use MIME::Base64;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::CMDB::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::CMDB::ConfigItemVersionGet - API ConfigItemVersionGet Operation backend

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
        'ConfigItemID' => {
            DataType => 'NUMERIC',
            Required => 1
        },
        'VersionID' => {
            Type     => 'ARRAY',
            DataType => 'NUMERIC',
            Required => 1
        },
    }
}

=item Run()

perform ConfigItemVersionGet Operation.

    my $Result = $OperationObject->Run(
        ConfigItemID => 1,                                # required
        VersionID    => 1                                 # required
    );

    $Result = {
        Success      => 1,                                # 0 or 1
        Code         => '',                               # In case of an error
        Message      => '',                               # In case of an error
        Data         => {
            ConfigItemVersion => [
                {
                    ...
                },
            ]
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # check if ConfigItem exists
    my $ConfigItem = $Kernel::OM->Get('ITSMConfigItem')->ConfigItemGet(
        ConfigItemID => $Param{Data}->{ConfigItemID},
    );

    if (!IsHashRefWithData($ConfigItem)) {
        return $Self->_Error(
            Code => 'ParentObject.NotFound',
        );
    }

    my @VersionList;

    # get all versions of ConfigItem (it's cheaper than getting selected version by single requests)
    my $Versions = $Kernel::OM->Get('ITSMConfigItem')->VersionZoomList(
        ConfigItemID => $Param{Data}->{ConfigItemID},
    );

    if (IsArrayRefWithData($Versions)) {
        my %VersionListMap = map { $_->{VersionID} => $_ } @{$Versions};

        foreach my $VersionID ( @{$Param{Data}->{VersionID}} ) {

            my $Version = $VersionListMap{$VersionID};

            if (!IsHashRefWithData($Version)) {
                return $Self->_Error(
                    Code => 'Object.NotFound',
                );
            }

            # include Definition if requested
            if ( $Param{Data}->{include}->{Definition} ) {
                my $VersionData = $Kernel::OM->Get('ITSMConfigItem')->VersionGet(
                    VersionID  => $VersionID,
                );

                # get already prepared Definition data from ClassDefinitionGet operation
                my $Result = $Self->ExecOperation(
                    OperationType => 'V1::CMDB::ClassDefinitionGet',
                    Data          => {
                        ClassID      => $ConfigItem->{ClassID},
                        DefinitionID => $VersionData->{DefinitionID},
                    }
                );
                if ( IsHashRefWithData($Result) && $Result->{Success} ) {
                    $Version->{Definition} = $Result->{Data}->{ConfigItemClassDefinition};
                }
            }

            # include XMLData if requested
            if ( $Param{Data}->{include}->{Data} ) {
                my $VersionData = $Kernel::OM->Get('ITSMConfigItem')->VersionGet(
                    VersionID  => $VersionID,
                    XMLDataGet => 1,
                );

                $Version->{Data} = $Self->ConvertDataToExternal(
                    ClassID    => $ConfigItem->{ClassID},
                    Definition => $VersionData->{XMLDefinition},
                    Data       => $VersionData->{XMLData}->[1]->{Version},
                );
            }

            # include XMLData if requested
            if ( $Param{Data}->{include}->{PreparedData} ) {
                my $VersionData = $Kernel::OM->Get('ITSMConfigItem')->VersionGet(
                    VersionID  => $VersionID,
                    XMLDataGet => 1,
                );

                my $Data = $Version->{Data};
                if ( !IsHashRefWithData($Data) ) {
                    $Data = $Self->ConvertDataToExternal(
                        ClassID    => $ConfigItem->{ClassID},
                        Definition => $VersionData->{XMLDefinition},
                        Data       => $VersionData->{XMLData}->[1]->{Version},
                    );
                }

                $Version->{PreparedData} = $Self->_PrepareData(
                    Definition => $VersionData->{XMLDefinition},
                    Data       => $Data,
                );
            }


            # add ConfigItemID to version hash
            $Version->{ConfigItemID} = $Param{Data}->{ConfigItemID};

            # add last version identifier
            $Version->{IsLastVersion} = ($ConfigItem->{LastVersionID} == $VersionID) ? 1 : 0;

            push(@VersionList, $Version);
        }

        if ( scalar(@VersionList) == 0 ) {
            return $Self->_Error(
                Code => 'Object.NotFound',
            );
        }
        elsif ( scalar(@VersionList) == 1 ) {
            return $Self->_Success(
                ConfigItemVersion => $VersionList[0],
            );
        }
    }

    return $Self->_Success(
        ConfigItemVersion => \@VersionList,
    );
}

sub _PrepareData {
    my ( $Self, %Param ) = @_;

    my $Definition = $Param{Definition};
    my $Data       = $Param{Data};

    # create sorted structure with data
    my @Result = ();
    for my $DefItem ( @{ $Definition } ) {
        my $ItemKey = $DefItem->{Key};

        # don't look at details if we don't have any value for this
        next if ( !defined( $Data->{ $ItemKey } ) );

        # ignore attribute if user is logged in as Customer and attribute should not be visible
        next if (
            IsHashRefWithData( $Self->{Authorization} )
            && $Self->{Authorization}->{UserType} eq 'Customer'
            && !$DefItem->{CustomerVisible}
        );

        if ( ref( $Data->{ $ItemKey } ) eq 'ARRAY' ) {
            for my $ArrayItem ( @{ $Data->{ $ItemKey } } ) {
                my $ResultItem = {
                    Key   => $ItemKey,
                    Label => $DefItem->{Name},
                    Type  => $DefItem->{Input}->{Type}
                };

                if ( ref( $ArrayItem ) eq 'HASH' ) {
                    # get content from own attribute key
                    if ( defined( $ArrayItem->{ $ItemKey } ) ) {
                        $ResultItem->{Value} = delete( $ArrayItem->{ $ItemKey } );
                    }
                    # check if we have a special handling method to extract the content
                    elsif ( $Self->{AttributeTypeModules}->{ $DefItem->{Input}->{Type} }->can('GetHashContentAttributes') ) {
                        my @HashContentAttributes = $Self->{AttributeTypeModules}->{ $DefItem->{Input}->{Type} }->GetHashContentAttributes();
                        for my $Attribute ( @HashContentAttributes ) {
                            $ResultItem->{Value}->{ $Attribute } = delete( $ArrayItem->{ $Attribute } );
                        }
                    }
                    $ResultItem->{DisplayValue} = $Self->_GetDisplayValue(
                        Item  => $DefItem,
                        Value => $ResultItem->{Value},
                    );
                    if ( defined( $DefItem->{Sub} ) ) {
                        # start recursion for each array item
                        my $PreparedResult = $Self->_PrepareData(
                            Definition => $DefItem->{Sub},
                            Data       => $ArrayItem,
                        );
                        if ( IsArrayRefWithData( $PreparedResult ) ) {
                            $ResultItem->{Sub} = $PreparedResult;
                        }
                    }
                }
                elsif ( ref $ArrayItem eq '' ) {
                    $ResultItem->{Value}        = $ArrayItem;
                    $ResultItem->{DisplayValue} = $Self->_GetDisplayValue(
                        Item  => $DefItem,
                        Value => $ArrayItem,
                    );

                    if ( defined( $DefItem->{Sub} ) ) {
                        # start recursion for each array item
                        my $PreparedResult = $Self->_PrepareData(
                            Definition => $DefItem->{Sub},
                            Data       => $ArrayItem,
                        );
                        if ( IsArrayRefWithData( $PreparedResult ) ) {
                            $ResultItem->{Sub} = $PreparedResult;
                        }
                    }
                }
                else {
                    # error
                    return;
                }

                push( @Result, $ResultItem );
            }
        }
        elsif ( ref( $Data->{ $ItemKey } ) eq 'HASH' ) {
            my $ResultItem = {
                Key   => $ItemKey,
                Label => $DefItem->{Name},
                Type  => $DefItem->{Input}->{Type}
            };
            if ( exists( $Data->{ $ItemKey }->{ $ItemKey } ) ) {
                $ResultItem->{Value}        = $Data->{ $ItemKey }->{ $ItemKey };
                $ResultItem->{DisplayValue} = $Self->_GetDisplayValue(
                    Item  => $DefItem,
                    Value => $Data->{ $ItemKey }->{ $ItemKey },
                );
            }
            if ( defined( $DefItem->{Sub} ) ) {
                # start recursion for each array item
                my $PreparedResult = $Self->_PrepareData(
                    Definition => $DefItem->{Sub},
                    Data       => $Data->{ $ItemKey },
                );
                if ( IsArrayRefWithData( $PreparedResult ) ) {
                    $ResultItem->{Sub} = $PreparedResult;
                }
            }
            push( @Result, $ResultItem );
        }
        else {
            my $ResultItem = {
                Key   => $ItemKey,
                Label => $DefItem->{Name},
                Value => $Data->{ $ItemKey },
                Type  => $DefItem->{Input}->{Type},
            };
            $ResultItem->{DisplayValue} = $Self->_GetDisplayValue(
                Item  => $DefItem,
                Value => $Data->{ $ItemKey },
            );

            if ( defined $DefItem->{Sub} ) {
                # start recursion for each array item
                my $PreparedResult = $Self->_PrepareData(
                    Definition => $DefItem->{Sub},
                    Data       => $Data->{ItemKey},
                );
                if ( IsArrayRefWithData( $PreparedResult ) ) {
                    $ResultItem->{Sub} = $PreparedResult;
                }
            }
            push( @Result, $ResultItem );
        }
    }

    return \@Result;
}

sub _GetDisplayValue {
    my ($Self, %Param) = @_;

    my $Result;

    # check if we have already created an instance of this type
    if ( !$Self->{AttributeTypeModules}->{ $Param{Item}->{Input}->{Type} } ) {
        # create module instance
        my $Module = 'ITSMConfigItem::XML::Type::' . $Param{Item}->{Input}->{Type};
        my $Object = $Kernel::OM->Get( $Module );

        if ( ref( $Object ) ne $Kernel::OM->GetModuleFor( $Module )) {
            return;
        }
        $Self->{AttributeTypeModules}->{ $Param{Item}->{Input}->{Type} } = $Object;
    }

    # check if we have a special handling method to prepare the value
    if ( $Self->{AttributeTypeModules}->{ $Param{Item}->{Input}->{Type} }->can('ValueLookup') ) {
        $Result = $Self->{AttributeTypeModules}->{ $Param{Item}->{Input}->{Type} }->ValueLookup(
            Item  => $Param{Item},
            Value => $Param{Value},
        );
    }

    return $Result;
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
