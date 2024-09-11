# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::CMDB::Common;

use strict;
use warnings;

use MIME::Base64();

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::CMDB::Common - Base class for all CMDB operations

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

=item PreRun()

some code to run before actual execution

    my $Success = $CommonObject->PreRun(
        ...
    );

    returns:

    $Success = {
        Success => 1,                     # if everything is OK
    }

    $Success = {
        Code    => 'Forbidden',           # if error
        Message => 'Error description',
    }

=cut

sub PreRun {
    my ( $Self, %Param ) = @_;

    # check if config items are accessible for current customer user
    if ($Param{Data}->{ConfigItemID}) {
        return $Self->_CheckCustomerAssignedObject(
            ObjectType             => 'ConfigItem',
            IDList                 => $Param{Data}->{ConfigItemID},
            RelevantOrganisationID => $Param{Data}->{RelevantOrganisationID}
        );
    }

    return $Self->_Success();
}

=begin Internal:

=item _CheckConfigItem()

checks if the given config item parameters are valid.

    my $ConfigItemCheck = $OperationObject->_CheckConfigItem(
        ConfigItem => $ConfigItem,                  # all config item parameters
    );

    returns:

    $ConfigItemCheck = {
        Success => 1,                               # if everything is OK
    }

    $ConfigItemCheck = {
        Code    => 'Function.Error',           # if error
        Message => 'Error description',
    }

=cut

sub _CheckConfigItem {
    my ( $Self, %Param ) = @_;

    my $ConfigItem = $Param{ConfigItem};

    my $ConfigObject     = $Kernel::OM->Get('Config');
    my $ConfigItemObject = $Kernel::OM->Get('ITSMConfigItem');

    # check, whether the feature to check for a unique name is enabled
    if (
        IsStringWithData( $ConfigItem->{Name} )
        && $ConfigObject->Get('UniqueCIName::EnableUniquenessCheck')
    ) {
        my @ConfigItemIDs = $Kernel::OM->Get('ObjectSearch')->Search(
            ObjectType => 'ConfigItem',
            Result     => 'ARRAY',
            Search     => {
                AND => [
                    {
                        Field    => 'Name',
                        Operator => 'EQ',
                        Type     => 'STRING',
                        Value    => $ConfigItem->{Name}
                    },
                    {
                        Field    => 'ClassID',
                        Operator => 'IN',
                        Type     => 'NUMERIC',
                        Value    => [ $ConfigItem->{ClassID} ]
                    }
                ]
            },
            UserID   => $Self->{Authorization}->{UserID},
            UserType => $Self->{Authorization}->{UserType}
        );

        my $NameDuplicates = $ConfigItemObject->UniqueNameCheck(
            ConfigItemID => $ConfigItemIDs[0],
            ClassID      => $ConfigItem->{ClassID},
            Name         => $ConfigItem->{Name},
        );

        # stop processing if the name is not unique
        if ( IsArrayRefWithData($NameDuplicates) ) {
            return $Self->_Error(
                Code    => "BadRequest",
                Message => "The name $ConfigItem->{Name} is already in use by the ConfigItemID(s): $ConfigItemIDs[0]"
            );
        }
    }

    if ( defined $ConfigItem->{Version} ) {

        if ( !IsHashRefWithData($ConfigItem->{Version}) ) {
            return $Self->_Error(
                Code    => 'BadRequest',
                Message => "Parameter Version is invalid!",
            );
        }

        # get last config item definition
        my $DefinitionData = $Kernel::OM->Get('ITSMConfigItem')->DefinitionGet(
            ClassID => $ConfigItem->{ClassID},
        );

        my $DataCheckResult = $Self->_CheckConfigItemVersion(
            Definition => $DefinitionData->{DefinitionRef},
            Version    => $ConfigItem->{Version},
        );

        if ( !$DataCheckResult->{Success} ) {
            return $DataCheckResult;
        }
    }

    if ( defined $ConfigItem->{Images} ) {

        if ( !IsArrayRefWithData($ConfigItem->{Images}) ) {
            return $Self->_Error(
                Code    => 'BadRequest',
                Message => "Parameter Images is invalid!",
            );
        }

        # check Images internal structure
        foreach my $ImageItem (@{$ConfigItem->{Images}}) {
            if ( !IsHashRefWithData($ImageItem) ) {
                return $Self->_Error(
                    Code    => 'BadRequest',
                    Message => "Parameter Images is invalid!",
                );
            }

            # check Image attribute values
            foreach my $Needed (qw(Filename Content)) {
                if ( !$ImageItem->{$Needed} ) {
                    return $Self->_Error(
                        Code    => 'BadRequest',
                        Message => "Parameter Images::$Needed is missing!",
                    );
                }
            }
        }
    }

    # if everything is OK then return Success
    return $Self->_Success();
}

=item _CheckConfigItemVersion()

checks if the given version parameters are valid.

    my $VersionCheck = $OperationObject->_CheckConfigItemVersion(
        Definition  => $Definition                          # relevant definition
        Version     => $ConfigItemVersion,                  # all Version parameters
    );

    returns:

    $VersionCheck = {
        Success => 1,                               # if everything is OK
    }

    $VersionCheck = {
        Code    => 'Function.Error',           # if error
        Message => 'Error description',
    }

=cut

sub _CheckConfigItemVersion {
    my ( $Self, %Param ) = @_;

    my $Definition = $Param{Definition};
    my $Version    = $Param{Version};

    if ( defined $Version->{Data} ) {

        my $DataCheckResult = $Self->_CheckData(
            Definition => $Definition,
            Data       => $Version->{Data},
        );
        if ( !$DataCheckResult->{Success} ) {
            return $DataCheckResult;
        }
    }

    # if everything is OK then return Success
    return $Self->_Success();
}

=item _CheckData()

checks if the given Data value are valid.

    my $DataCheck = $CommonObject->_CheckData(
        Definition => $DefinitionArrayRef,          # Config Item Definition ot just part of it
        Data       => $DataHashRef,
        Parent     => 'some parent',
    );

    returns:

    $DataCheck = {
        Success => 1,                               # if everything is OK
    }

    $DataCheck = {
        Code    => 'Function.Error',           # if error
        Message => 'Error description',
    }

=cut

sub _CheckData {
    my ( $Self, %Param ) = @_;

    my $Definition = $Param{Definition};
    my $Data       = $Param{Data} || {};
    my $Parent     = $Param{Parent} || '';

    my $CheckValueResult;
    for my $DefItem ( @{$Definition} ) {
        my $ItemKey = $DefItem->{Key};

        # check if at least one element should exist
        if (
            (
                defined $DefItem->{CountMin}
                && $DefItem->{CountMin} >= 1
                && defined $DefItem->{Input}->{Required}
                && $DefItem->{Input}->{Required}
            )
            && ( !defined $Data->{$ItemKey} || !$Data->{$ItemKey} )
            )
        {
            return $Self->_Error(
                Code    => "BadRequest",
                Message => "Parameter Version::Data::$Parent$ItemKey is missing!",
            );
        }

        # don't look at details if we don't have any value for this
        next if ( !IsHashRefWithData($Data) || !$Data->{$ItemKey} );

        # check structure and values
        if ( ref $Data->{$ItemKey} eq 'ARRAY' ) {
            for my $ArrayItem ( @{ $Data->{$ItemKey} } ) {
                if ( ref $ArrayItem eq 'HASH' && $DefItem->{Input}->{Type} ne 'Attachment' ) {        # attribute type Attachment needs some special handling
                    $CheckValueResult = $Self->_CheckValue(
                        Value   => $ArrayItem->{$ItemKey},
                        Input   => $DefItem->{Input},
                        ItemKey => $ItemKey,
                        Parent  => $Parent,
                    );
                    if ( !$CheckValueResult->{Success} ) {
                        return $CheckValueResult;
                    }
                }
                elsif ( ref $ArrayItem eq '' || $DefItem->{Input}->{Type} eq 'Attachment' ) {        # attribute type Attachment needs some special handling
                    $CheckValueResult = $Self->_CheckValue(
                        Value   => $ArrayItem,
                        Input   => $DefItem->{Input},
                        ItemKey => $ItemKey,
                        Parent  => $Parent,
                    );
                    if ( !$CheckValueResult->{Success} ) {
                        return $CheckValueResult;
                    }
                }
                else {
                    return $Self->_Error(
                        Code    => "BadRequest",
                        Message => "Parameter Version::Data::$Parent$ItemKey is invalid!",
                    );
                }
            }
        }
        elsif ( ref $Data->{$ItemKey} eq 'HASH' && $DefItem->{Input}->{Type} ne 'Attachment' ) {        # attribute type Attachment needs some special handling
            $CheckValueResult = $Self->_CheckValue(
                Value   => $Data->{$ItemKey}->{$ItemKey},
                Input   => $DefItem->{Input},
                ItemKey => $ItemKey,
                Parent  => $Parent,
            );
            if ( !$CheckValueResult->{Success} ) {
                return $CheckValueResult;
            }
        }
        else {

            # only perform checks if item really exits in the Data
            # CountMin checks was verified and passed before!, so it is safe to skip if needed
            if ( $Data->{$ItemKey} ) {
                $CheckValueResult = $Self->_CheckValue(
                    Value   => $Data->{$ItemKey},
                    Input   => $DefItem->{Input},
                    ItemKey => $ItemKey,
                    Parent  => $Parent,
                );
                if ( !$CheckValueResult->{Success} ) {
                    return $CheckValueResult;
                }
            }
        }

        # check if exists more elements than the ones they should
        if ( defined $DefItem->{CountMax} )
        {
            if (
                ref $Data->{$ItemKey} eq 'ARRAY'
                && scalar @{ $Data->{$ItemKey} } > $DefItem->{CountMax}
                )
            {
                return $Self->_Error(
                    Code    => "BadRequest",
                    Message => "Parameter Version::Data::$Parent$ItemKey count exceeds allowed maximum!",
                );
            }
        }

        # check if there is a sub and start recursion
        if ( defined $DefItem->{Sub} ) {

            if ( ref $Data->{$ItemKey} eq 'ARRAY' ) {
                my $Counter = 0;
                for my $ArrayItem ( @{ $Data->{$ItemKey} } ) {
                    # start recursion for each array item
                    my $DataCheck = $Self->_CheckData(
                        Definition => $DefItem->{Sub},
                        Data       => $ArrayItem,
                        Parent     => $Parent . $ItemKey . "[$Counter]::",
                    );
                    if ( !$DataCheck->{Success} ) {
                        return $DataCheck;
                    }
                    $Counter++;
                }
            }
            elsif ( ref $Data->{$ItemKey} eq 'HASH' ) {
                # start recursion
                my $DataCheck = $Self->_CheckData(
                    Definition => $DefItem->{Sub},
                    Data       => $Data->{$ItemKey},
                    Parent     => $Parent . $ItemKey . '::',
                );
                if ( !$DataCheck->{Success} ) {
                    return $DataCheck;
                }
            }
            else {
                # start recursion
                my $DataCheck = $Self->_CheckData(
                    Definition => $DefItem->{Sub},
                    Data       => {},
                    Parent     => $Parent . $ItemKey . '::',
                );
                if ( !$DataCheck->{Success} ) {
                    return $DataCheck;
                }
            }
        }
    }

    return $Self->_Success();
}

=item _CheckValue()

checks if the given value is valid.

    my $ValueCheck = $CommonObject->_CheckValue(
        Value   => $Value                        # $Value could be a string, a time stamp,
                                                 #   general catalog class name, or a integer
        Input   => $InputDefinitionHashRef,      # The definition of the element input extracted
                                                 #   from the Configuration Item definition for
                                                 #   for each value
        ItemKey => 'some key',                   # The name of the value as sent in the request
        Parent  => 'soem parent key->',          # The name of the parent followed by -> or empty
                                                 #   for root key items
    );

    returns:

    $ValueCheck = {
        Success => 1,                            # if everything is OK
    }

    $ValueCheck = {
        Code    => 'Function.Error',             # if error
        Message => 'Error description',
    }

=cut

sub _CheckValue {
    my ( $Self, %Param ) = @_;

    my $Parent  = $Param{Parent};
    my $ItemKey = $Param{ItemKey};

    if (
        defined $Param{Input}->{Required} && $Param{Input}->{Required} && !$Param{Value}
        )
    {
        return $Self->_Error(
            Code    => "BadRequest",
            Message => "Parameter Version::Data::$Parent$ItemKey value is required and missing!",
        );
    }

    # check if we have already created an instance of this type
    if ( !$Self->{AttributeTypeModules}->{$Param{Input}->{Type}} ) {
        # create module instance
        my $Module = 'ITSMConfigItem::XML::Type::'.$Param{Input}->{Type};
        my $Object;
        eval {
            $Object = $Kernel::OM->Get($Module);
        };

        if (!$Object || ref $Object ne $Kernel::OM->GetModuleFor($Module)) {
            return $Self->_Error(
                Code    => "InternalError",
                Message => "Invalid asset class definition! Unable to create instance of attribute type module for parameter Version::Data::$Parent$ItemKey!",
            );
        }
        $Self->{AttributeTypeModules}->{$Param{Input}->{Type}} = $Object;
    }

    # validate value if possible
    if ( $Self->{AttributeTypeModules}->{$Param{Input}->{Type}}->can('ValidateValue') ) {
        my $ValidateResult = $Self->{AttributeTypeModules}->{$Param{Input}->{Type}}->ValidateValue(%Param);

        if ( "$ValidateResult" ne "1" ) {
            return $Self->_Error(
                Code    => "BadRequest",
                Message => "Parameter Version::Data::$Parent$ItemKey has an invalid value ($ValidateResult)!",
            );
        }
    }

    return $Self->_Success();
}

=item ConvertDataToInternal()

Create a Data suitable for VersionAdd.

    my $NewData = $CommonObject->ConvertDataToInternal(
        ClassID      => $ClassID,
        ConfigItemID => $ConfigItemID,
        Definition   => $DefinitionHashRef,
        Data         => $DataHashRef,
        Child        => 1,                    # or 0, optional
    );

    returns:

    $NewData = $DataHashRef,                  # suitable for version add

=cut

sub ConvertDataToInternal {
    my ( $Self, %Param ) = @_;

    # isolate data
    my $Data = $Param{Data};

    # init variables
    my $NewData              = {};

    # init RestorePreviousValue on parent call
    if ( !$Param{Child} ) {
        $Param{RestorePreviousValue} = {};
    }

    ROOTKEY:
    for my $RootKey ( keys( %{ $Data } ) ) {

        # get attribute definition
        my %AttrDef = $Kernel::OM->Get('ITSMConfigItem')->GetAttributeDefByKey(
            Key           => $RootKey,
            XMLDefinition => $Param{Definition},
        );
        next ROOTKEY if ( !%AttrDef );

        # check if we have already created an instance of this type
        if ( !$Self->{AttributeTypeModules}->{ $AttrDef{Input}->{Type} } ) {
            # create module instance
            my $Module = 'ITSMConfigItem::XML::Type::' . $AttrDef{Input}->{Type};
            my $Object = $Kernel::OM->Get( $Module );

            # check that we got the expected object
            if ( ref( $Object ) ne $Kernel::OM->GetModuleFor( $Module )) {
                return $Self->_Error(
                    Code    => "Operation.InternalError",
                    Message => "Unable to create instance of attribute type module for parameter $RootKey!",
                );
            }
            $Self->{AttributeTypeModules}->{ $AttrDef{Input}->{Type} } = $Object;
        }

        # init new xml parts with undef item on index 0
        my @NewXMLParts = ( undef );

        # normalize data to array
        my @DataEntries;
        if ( ref( $Data->{ $RootKey } ) eq 'ARRAY' ) {
            @DataEntries = @{ $Data->{ $RootKey } };
        }
        else {
            @DataEntries = ( $Data->{ $RootKey } );
        }

        # process data entries
        for my $Entry ( @DataEntries ) {
            if ( ref( $Entry ) eq 'HASH' ) {

                # extract content from entry
                my $Content;
                # get content from own attribute key
                if ( defined( $Entry->{ $RootKey } ) ) {
                    $Content = delete( $Entry->{ $RootKey } );
                }
                # check if we have a special handling method to extract the content
                elsif ( $Self->{AttributeTypeModules}->{ $AttrDef{Input}->{Type} }->can('GetHashContentAttributes') ) {
                    my @HashContentAttributes = $Self->{AttributeTypeModules}->{ $AttrDef{Input}->{Type} }->GetHashContentAttributes();
                    for my $Attribute ( @HashContentAttributes ) {
                        $Content->{ $Attribute } = delete( $Entry->{ $Attribute } );
                    }
                }

                # check if we have a special handling method to prepare the value
                if ( $Self->{AttributeTypeModules}->{ $AttrDef{Input}->{Type} }->can('InternalValuePrepare') ) {
                    $Content = $Self->{AttributeTypeModules}->{ $AttrDef{Input}->{Type} }->InternalValuePrepare(
                        ClassID      => $Param{ClassID},
                        Definition   => \%AttrDef,
                        Value        => $Content,
                        UserID       => $Self->{Authorization}->{UserID},
                        UsageContext => $Self->{Authorization}->{UserType},
                    );

                    # check if value of previos version should be restored
                    if (
                        ref( $Content ) eq 'HASH'
                        && $Content->{RestorePreviousValue}
                    ) {
                        $Param{RestorePreviousValue}->{ $RootKey } = 1;

                        $Content = '';
                    }
                }

                # process sub data
                my $NewDataPart = $Self->ConvertDataToInternal(
                    ClassID              => $Param{ClassID},
                    ConfigItemID         => $Param{ConfigItemID},
                    RestorePreviousValue => $Param{RestorePreviousValue},
                    Definition           => $Param{Definition},
                    Data                 => $Entry,
                    Child                => 1,
                );

                # add content to new xml parts
                push(
                    @NewXMLParts,
                    {
                        %{ $NewDataPart },
                        Content => $Content,
                    }
                );
            }
            # handle content
            else {
                # check if we have a special handling method to prepare the value
                if ( $Self->{AttributeTypeModules}->{ $AttrDef{Input}->{Type} }->can('InternalValuePrepare') ) {
                    $Entry = $Self->{AttributeTypeModules}->{ $AttrDef{Input}->{Type} }->InternalValuePrepare(
                        ClassID      => $Param{ClassID},
                        Definition   => \%AttrDef,
                        Value        => $Entry,
                        UserID       => $Self->{Authorization}->{UserID},
                        UsageContext => $Self->{Authorization}->{UserType},
                    );

                    # check if value of previous version should be restored
                    if (
                        ref( $Entry ) eq 'HASH'
                        && $Entry->{RestorePreviousValue}
                    ) {
                        $Param{RestorePreviousValue}->{ $RootKey } = 1;

                        $Entry = '';
                    }
                }

                push @NewXMLParts, {
                    Content => $Entry
                };
            }

            # assamble the final value from the parts array
            $NewData->{ $RootKey } = \@NewXMLParts;
        }
    }

    # return only the part on recursion
    if ( $Param{Child} ) {
        return $NewData;
    }

    # check if previous version data has to be restored
    if ( IsHashRefWithData( $Param{RestorePreviousValue} ) ) {
        # get last version
        my $VersionData = $Kernel::OM->Get('ITSMConfigItem')->VersionGet(
            ConfigItemID => $Param{ConfigItemID},
            XMLDataGet   => 1,
        );

        # check if already a version exists
        if (
            IsHashRefWithData( $VersionData )
            && IsArrayRefWithData( $VersionData->{XMLData} )
        ) {
            $Self->_RestorePreviousValue(
                XMLDefinition        => $Param{Definition},
                XMLDataPrev          => $VersionData->{XMLData}->[1]->{Version}->[1],
                XMLData              => $NewData,
                RestorePreviousValue => $Param{RestorePreviousValue},
                Silent               => $Param{Silent}
            );
        }
    }

    # return the complete Data as needed for version add
    return [
        undef,
        {
            Version => [
                undef,
                $NewData
            ],
        },
    ];
}

=item ConvertDataToExternal()

Creates a readible Data.

    my $NewData = $CommonObject->ConvertDataToExternal(
        ClassID    => $ClassID,
        Definition => $DefinitionHashRef,
        Data       => $DataHashRef,
    );

    returns:

    $NewData = $DataHashRef,                  # suitable for display

=cut

sub ConvertDataToExternal {
    my ( $Self, %Param ) = @_;

    # isolate data
    my $Data = $Param{Data};

    # init new data hash
    my $NewData = {};

    ROOTHASH:
    for my $RootHash ( @{ $Data } ) {
        next ROOTHASH if ( !defined( $RootHash ) );

        # delete TagKey from data
        delete( $RootHash->{TagKey} );

        ROOTHASHKEY:
        for my $RootHashKey ( keys( %{ $RootHash } ) ) {
            # get attribute definition
            my %AttrDef = $Kernel::OM->Get('ITSMConfigItem')->GetAttributeDefByKey(
                Key           => $RootHashKey,
                XMLDefinition => $Param{Definition},
            );
            next ROOTHASHKEY if ( !%AttrDef );

            next ROOTHASHKEY if (
                !$AttrDef{CustomerVisible}
                && IsHashRefWithData( $Self->{Authorization} )
                && $Self->{Authorization}->{UserType} eq 'Customer'
            );

            # check if we have already created an instance of this type
            if ( !$Self->{AttributeTypeModules}->{ $AttrDef{Input}->{Type} } ) {
                # create module instance
                my $Module = 'ITSMConfigItem::XML::Type::' . $AttrDef{Input}->{Type};
                my $Object = $Kernel::OM->Get( $Module );

                # check that we got the expected object
                if ( ref( $Object ) ne $Kernel::OM->GetModuleFor( $Module )) {
                    return $Self->_Error(
                        Code    => "Operation.InternalError",
                        Message => "Unable to create instance of attribute type module for parameter $RootHashKey!",
                    );
                }
                $Self->{AttributeTypeModules}->{ $AttrDef{Input}->{Type} } = $Object;
            }

            # init counter
            my $Counter;
            if ( $AttrDef{CountMax} && $AttrDef{CountMax} > 1 ) {
                # we have multiple items, set defined value
                $Counter = 0;
            }

            # process data entries
            ARRAYITEM:
            for my $ArrayItem ( @{ $RootHash->{ $RootHashKey } } ) {
                next ARRAYITEM if ( !defined( $ArrayItem ) );

                # delete TagKey from entry
                delete $ArrayItem->{TagKey};

                # get content from entry
                my $Content = delete $ArrayItem->{Content} || '';

                # check if we have a special handling method to prepare the value
                if ( $Self->{AttributeTypeModules}->{ $AttrDef{Input}->{Type} }->can('ExternalValuePrepare') ) {
                    $Content = $Self->{AttributeTypeModules}->{ $AttrDef{Input}->{Type} }->ExternalValuePrepare(
                        ClassID      => $Param{ClassID},
                        Item         => \%AttrDef,
                        Value        => $Content,
                        UserID       => $Self->{Authorization}->{UserID},
                        UsageContext => $Self->{Authorization}->{UserType},
                    );
                }

                # check if we have a sub structure
                if ( $AttrDef{Sub} ) {
                    # start recursion
                    for my $ArrayItemKey ( keys( %{ $ArrayItem } ) ) {

                        my $NewDataPart = $Self->ConvertDataToExternal(
                            ClassID    => $Param{ClassID},
                            Definition => $Param{Definition},
                            Data       => [ undef, { $ArrayItemKey => $ArrayItem->{$ArrayItemKey} } ],
                            RootKey    => $RootHashKey,
                        );
                        for my $Key ( keys( %{ $NewDataPart } ) ) {
                            if ( defined( $Counter ) ) {
                                $NewData->{ $RootHashKey }->[ $Counter ]->{ $Key } = $NewDataPart->{ $Key };
                            }
                            else {
                                $NewData->{ $RootHashKey }->{ $Key } = $NewDataPart->{ $Key };
                            }
                        }
                    }

                    if ( defined( $Counter ) ) {
                        $NewData->{ $RootHashKey }->[ $Counter ]->{ $RootHashKey } = $Content;
                    }
                    else {
                        $NewData->{ $RootHashKey }->{ $RootHashKey } = $Content;
                    }
                }
                else {
                    if ( defined( $Counter ) ) {
                        $NewData->{ $RootHashKey }->[ $Counter ] = $Content;
                    }
                    else {
                        $NewData->{ $RootHashKey } = $Content;
                    }
                }

                if ( defined( $Counter ) ) {
                    $Counter += 1;
                }
            }
        }
    }

    return $NewData;
}

=item _CheckDefinition()

check the syntax of a new definition

    my $True = $ConfigItemObject->_CheckDefinition(
        Definition      => 'the definition code',
        CheckSubElement => 1,                 # (optional, default 0, to check sub elements recursively)
    );

=cut

sub _CheckDefinition {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{Definition} ) {
        return $Self->_Error(
            Code    => 'BadRequest',
            Message  => 'Need Definition!',
        );
    }

    if ( $Param{ClassID} ) {
        # get last definition
        my $LastDefinition = $Kernel::OM->Get('ITSMConfigItem')->DefinitionGet(
            ClassID => $Param{ClassID},
        );

        # stop add, if definition was not changed
        if ( $LastDefinition->{DefinitionID} && $LastDefinition->{Definition} eq $Param{Definition} ) {
            return $Self->_Error(
                Code    => 'Conflict',
                Message => "A new definition can't be created, because the definition has not been changed.",
            );
        }
    }

    # if check sub elements is enabled, we must not evaluate the expression
    # because this has been done in an earlier recursion step already
    my $Definition;
    if ( $Param{CheckSubElement} ) {
        $Definition = $Param{Definition};
    }
    else {
        $Definition = eval $Param{Definition};    ## no critic
        if ( !$Definition ) {
            return $Self->_Error(
                Code    => 'BadRequest',
                Message => "Syntax error in definition! ($@)",
            );
        }
    }

    # check if definition exists at all
    if ( !$Definition ) {
        return $Self->_Error(
            Code    => 'BadRequest',
            Message  => 'Invalid definition! You have a syntax error in the definition.',
        );
    }

    # definition must be an array
    if ( ref $Definition ne 'ARRAY' ) {
        return $Self->_Error(
            Code    => 'BadRequest',
            Message => 'Invalid definition! Definition is not an array reference.',
        );
    }

    # check each definition attribute
    for my $Attribute ( @{$Definition} ) {

        # each definition attribute must be a hash reference with data
        if ( !$Attribute || ref $Attribute ne 'HASH' || !%{$Attribute} ) {
            return $Self->_Error(
                Code    => 'BadRequest',
                Message => 'Invalid definition! At least one definition attribute is not a hash reference.',
            );
        }

        if ( IsHashRefWithData($Attribute->{Input}) && $Attribute->{Input}->{Type} ) {
            # create module instance
            my $Module = 'ITSMConfigItem::XML::Type::'.$Attribute->{Input}->{Type};
            my $Object;
            eval {
                $Object = $Kernel::OM->Get($Module);
            };
            if (!$Object || ref $Object ne $Kernel::OM->GetModuleFor($Module)) {
                return $Self->_Error(
                    Code    => "BadRequest",
                    Message => "Invalid definition! Type '$Attribute->{Input}->{Type}' of key '$Attribute->{Key}' is unknown!",
                );
            }
        }

        # check if the key contains no spaces
        if ( $Attribute->{Key} && $Attribute->{Key} =~ m{ \s }xms ) {
            return $Self->_Error(
                Code    => 'BadRequest',
                Message => "Invalid definition! Key '$Attribute->{Key}' must not contain whitespace!",
            );
        }

        # check if the key contains non-ascii characters
        if ( $Attribute->{Key} && $Attribute->{Key} =~ m{ ([^\x{00}-\x{7f}]) }xms ) {
            return $Self->_Error(
                Code    => 'BadRequest',
                Message => "Invalid definition! Key '$Attribute->{Key}' must not contain non ASCII characters '$1'!",
            );
        }

        # recursion check for Sub-Elements
        for my $Key ( sort keys %{$Attribute} ) {

            my $Value = $Attribute->{$Key};

            if ( $Key eq 'Sub' && ref $Value eq 'ARRAY' ) {

                # check the sub array
                my $DefinitionCheck = $Self->_CheckDefinition(
                    Definition      => $Value,
                    CheckSubElement => 1,
                );
                if ( !$DefinitionCheck->{Success} ) {
                    return $Self->_Error(
                        %{$DefinitionCheck},
                    );
                }
            }
        }
    }

    return $Self->_Success();
}

sub _RestorePreviousValue {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    return if ( !$Param{XMLDefinition} );
    return if ( !$Param{XMLData} );
    return if ( !$Param{XMLDataPrev} );
    return if ( ref( $Param{XMLDefinition} ) ne 'ARRAY' );    # the attributes of the config item class
    return if ( ref( $Param{XMLData} ) ne 'HASH' );           # hash with values that should be imported
    return if ( ref( $Param{XMLDataPrev} ) ne 'HASH' );       # hash with current values of the config item

    # isolate XMLData and XMLDataPrev
    my $XMLData     = $Param{XMLData};
    my $XMLDataPrev = $Param{XMLDataPrev};

    ITEM:
    for my $Item ( @{ $Param{XMLDefinition} } ) {
        for my $Counter ( 1 .. $Item->{CountMax} ) {
            # skip to next item if previous and current data is not defined
            next ITEM if (
                !exists( $XMLData->{ $Item->{Key} }->[ $Counter ] )
                && !exists( $XMLDataPrev->{ $Item->{Key} }->[ $Counter ] )
            );

            # start recursion, if "Sub" was found
            if ( $Item->{Sub} ) {
                $XMLData->{ $Item->{Key} }->[ $Counter ] ||= {};    # empty container, in case there is no current data

                my $Success = $Self->_RestorePreviousValue(
                    XMLDefinition        => $Item->{Sub},
                    XMLData              => $XMLData->{ $Item->{Key} }->[ $Counter ],
                    XMLDataPrev          => $XMLDataPrev->{ $Item->{Key} }->[ $Counter ],
                    RestorePreviousValue => $Param{RestorePreviousValue},
                    Silent               => $Param{Silent}
                );
                return if ( !$Success );

                # no current data and previous data should not be restored
                if (
                    (
                        !exists( $XMLDataPrev->{ $Item->{Key} }->[ $Counter ] )
                        || !$Param{RestorePreviousValue}->{ $Item->{Key} }
                    )
                    && (
                        !IsArrayRefWithData( $XMLData->{ $Item->{Key} } )
                        || !IsHashRefWithData( $XMLData->{ $Item->{Key} }->[ $Counter ] )
                    )
                ) {
                        # empty container added during sub-handling above - remove it
                        delete( $XMLData->{ $Item->{Key} }->[ $Counter ] );

                        next ITEM;
                }
            }

            # handle empty field
            if (
                !defined( $XMLData->{ $Item->{Key} }->[ $Counter ]->{Content} )
                || $XMLData->{ $Item->{Key} }->[ $Counter ]->{Content} eq ''
            ) {
                # check if existing old value should be restored
                if (
                    $Param{RestorePreviousValue}->{ $Item->{Key} }
                    && IsArrayRefWithData( $XMLDataPrev->{ $Item->{Key} } )
                    && IsHashRefWithData( $XMLDataPrev->{ $Item->{Key} }->[ $Counter ] )
                    && defined( $XMLDataPrev->{ $Item->{Key} }->[ $Counter ]->{Content} )
                ) {
                    $XMLData->{ $Item->{Key} }->[ $Counter ]->{Content} = $XMLDataPrev->{ $Item->{Key} }->[ $Counter ]->{Content};
                }
            }
        }
    }

    return 1;
}

1;

=end Internal:

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-GPL3 for license information (GPL3). If you did not receive this file, see

<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
