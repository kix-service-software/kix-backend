# --
# Modified version of the work: Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::API::Operation::V1::CMDB::ConfigItemVersionGet;

use strict;
use warnings;

use MIME::Base64;

use Kernel::System::VariableCheck qw(IsArrayRefWithData IsHashRefWithData IsStringWithData);

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

    my @VersionList;        

    # check if ConfigItem exists
    my $ConfigItem = $Kernel::OM->Get('Kernel::System::ITSMConfigItem')->ConfigItemGet(
        ConfigItemID => $Param{Data}->{ConfigItemID},
    );

    if (!IsHashRefWithData($ConfigItem)) {
        return $Self->_Error(
            Code => 'ParentObject.NotFound',
        );
    }

    # get all versions of ConfigItem (it's cheaper than getting selected version by single requests)
    my $Versions = $Kernel::OM->Get('Kernel::System::ITSMConfigItem')->VersionZoomList(
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
                # get already prepared Definition data from ClassDefinitionGet operation
                my $Result = $Self->ExecOperation(
                    OperationType => 'V1::CMDB::ClassDefinitionGet',
                    Data          => {
                        ClassID      => $ConfigItem->{ClassID},
                        DefinitionID => $Version->{DefinitionID},
                    }
                );
                if ( IsHashRefWithData($Result) && $Result->{Success} ) {
                    $Version->{Definition} = $Result->{Data}->{ConfigItemClassDefinition};
                }
            }

            # include XMLData if requested
            if ( $Param{Data}->{include}->{Data} ) {
                my $VersionData = $Kernel::OM->Get('Kernel::System::ITSMConfigItem')->VersionGet(
                    VersionID  => $VersionID,
                    XMLDataGet => 1,
                );

                $Version->{Data} = $Self->ConvertDataToExternal(
                    Definition => $VersionData->{XMLDefinition},
                    Data       => $VersionData->{XMLData}->[1]->{Version}
                );
            }

            # include XMLData if requested
            if ( $Param{Data}->{include}->{PreparedData} ) {
                my $VersionData = $Kernel::OM->Get('Kernel::System::ITSMConfigItem')->VersionGet(
                    VersionID  => $VersionID,
                    XMLDataGet => 1,
                );

                $Version->{PreparedData} = $Self->_PrepareData(
                    Definition => $VersionData->{XMLDefinition},
                    Data       => $Version->{Data},
                );
            }


            # add ConfigItemID to version hash
            $Version->{ConfigItemID} = $Param{Data}->{ConfigItemID};

            push(@VersionList, $Version);
        }

        if ( scalar(@VersionList) == 0 ) {
            return $Self->_Error(
                Code => 'Object.NotFound'
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
    for my $DefItem ( @{$Definition} ) {
        my $ItemKey = $DefItem->{Key};

        # don't look at details if we don't have any value for this
        next if !$Data->{$ItemKey};

        if ( ref $Data->{$ItemKey} eq 'ARRAY' ) {
            for my $ArrayItem ( @{ $Data->{$ItemKey} } ) {
                my $ResultItem = {
                    Key   => $ItemKey,
                    Label => $DefItem->{Name},
                    Type  => $DefItem->{Input}->{Type}
                };

                if ( ref $ArrayItem eq 'HASH' && $DefItem->{Input}->{Type} ne 'Attachment' ) {        # attribute type Attachment needs some special handling
                    $ResultItem->{Value} = $ArrayItem->{$ItemKey},
                    $ResultItem->{DisplayValue} = $Self->_GetDisplayValue(
                        Item  => $DefItem,
                        Value => $ArrayItem->{$ItemKey},
                    );
                    if ( defined $DefItem->{Sub} ) {
                        # start recursion for each array item
                        my $PreparedResult = $Self->_PrepareData(
                            Definition => $DefItem->{Sub},
                            Data       => $ArrayItem,
                        );
                        if ( IsArrayRefWithData($PreparedResult) ) {
                            $ResultItem->{Sub} = $PreparedResult;
                        }
                    }
                }
                elsif ( ref $ArrayItem eq '' || $DefItem->{Input}->{Type} eq 'Attachment' ) {        # attribute type Attachment needs some special handling
                    $ResultItem->{Value} = $ArrayItem;
                    if ( $DefItem->{Input}->{Type} ne 'Attachment' ) {
                        $ResultItem->{DisplayValue} = $Self->_GetDisplayValue(
                            Item  => $DefItem,
                            Value => $ArrayItem,
                        );
                    }
                    if ( defined $DefItem->{Sub} ) {
                        # start recursion for each array item
                        my $PreparedResult = $Self->_PrepareData(
                            Definition => $DefItem->{Sub},
                            Data       => $ArrayItem,
                        );
                        if ( IsArrayRefWithData($PreparedResult) ) {
                            $ResultItem->{Sub} = $PreparedResult;
                        }
                    }
                }
                else {
                    # error
                    return;
                }

                push(@Result, $ResultItem);
            }
        }
        elsif ( ref $Data->{$ItemKey} eq 'HASH' && $DefItem->{Input}->{Type} ne 'Attachment' ) {        # attribute type Attachment needs some special handling
            my $ResultItem = {
                Key   => $ItemKey,
                Label => $DefItem->{Name},
                Type  => $DefItem->{Input}->{Type}
            };
            if (exists $Data->{$ItemKey}->{$ItemKey}) {
                $ResultItem->{Value} = $Data->{$ItemKey}->{$ItemKey};
                $ResultItem->{DisplayValue} = $Self->_GetDisplayValue(
                    Item  => $DefItem,
                    Value => $Data->{$ItemKey}->{$ItemKey},
                );
            }
            if ( defined $DefItem->{Sub} ) {
                # start recursion for each array item
                my $PreparedResult = $Self->_PrepareData(
                    Definition => $DefItem->{Sub},
                    Data       => $Data->{$ItemKey},
                );
                if ( IsArrayRefWithData($PreparedResult) ) {
                    $ResultItem->{Sub} = $PreparedResult;
                }
            }
            push(@Result, $ResultItem);
        }
        else {
            my $ResultItem = {
                Key   => $ItemKey,
                Label => $DefItem->{Name},
                Value => $Data->{$ItemKey},
                Type  => $DefItem->{Input}->{Type}
            };
            if ( $DefItem->{Input}->{Type} ne 'Attachment' ) {
                $ResultItem->{DisplayValue} = $Self->_GetDisplayValue(
                    Item  => $DefItem,
                    Value => $Data->{$ItemKey},
                );
            }
            if ( defined $DefItem->{Sub} ) {
                # start recursion for each array item
                my $PreparedResult = $Self->_PrepareData(
                    Definition => $DefItem->{Sub},
                    Data       => $Data->{ItemKey},
                );
                if ( IsArrayRefWithData($PreparedResult) ) {
                    $ResultItem->{Sub} = $PreparedResult;
                }
            }
            push(@Result, $ResultItem);
        }
    }

    return \@Result;
}

sub _GetDisplayValue {
    my ($Self, %Param) = @_;
    my $Result;

    # check if we have already created an instance of this type
    if ( !$Self->{AttributeTypeModules}->{$Param{Item}->{Input}->{Type}} ) {
        # create module instance
        my $Module = 'Kernel::System::ITSMConfigItem::XML::Type::'.$Param{Item}->{Input}->{Type};
        my $Object = $Kernel::OM->Get($Module);

        if (ref $Object ne $Module) {
            return;
        }
        $Self->{AttributeTypeModules}->{$Param{Item}->{Input}->{Type}} = $Object;
    }

    # check if we have a special handling method to prepare the value
    if ( $Self->{AttributeTypeModules}->{$Param{Item}->{Input}->{Type}}->can('ValueLookup') ) {
        $Result = $Self->{AttributeTypeModules}->{$Param{Item}->{Input}->{Type}}->ValueLookup(
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
(L<http://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
COPYING for license information (AGPL). If you did not receive this file, see

<http://www.gnu.org/licenses/agpl.txt>.

=cut
