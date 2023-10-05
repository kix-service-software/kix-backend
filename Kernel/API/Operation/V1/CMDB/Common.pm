# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com
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
        my $ConfigItemIDs = $ConfigItemObject->ConfigItemSearchExtended(
            Name           => $ConfigItem->{Name},
            ClassIDs       => [ $ConfigItem->{ClassID} ],
            UsingWildcards => 0,
        );

        my $NameDuplicates = $ConfigItemObject->UniqueNameCheck(
            ConfigItemID => $ConfigItemIDs->[0],
            ClassID      => $ConfigItem->{ClassID},
            Name         => $ConfigItem->{Name},
        );

        # stop processing if the name is not unique
        if ( IsArrayRefWithData($NameDuplicates) ) {
            return $Self->_Error(
                Code    => "BadRequest",
                Message => "The name $ConfigItem->{Name} is already in use by the ConfigItemID(s): $ConfigItemIDs->[0]"
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
        Definition => $DefinitionHashRef,
        Data       => $DataHashRef,
        Child      => 1,                    # or 0, optional
    );

    returns:

    $NewData = $DataHashRef,                  # suitable for version add

=cut

sub ConvertDataToInternal {
    my ( $Self, %Param ) = @_;

    my $Data  = $Param{Data};
    my $Child = $Param{Child};

    my $NewData = {};

    for my $RootKey ( sort keys %{$Data} ) {

        # get attribute definition
        my %AttrDef = $Kernel::OM->Get('ITSMConfigItem')->GetAttributeDefByKey(
            Key           => $RootKey,
            XMLDefinition => $Param{Definition},
        );

        if ( ref $Data->{$RootKey} eq 'ARRAY' ) {
            my @NewXMLParts;
            $NewXMLParts[0] = undef;

            for my $ArrayItem ( @{ $Data->{$RootKey} } ) {
                if ( ref $ArrayItem eq 'HASH' && $AttrDef{Input}->{Type} ne 'Attachment' ) {

                    # extract the root key from the hash and assign it to content key
                    my $Content = delete $ArrayItem->{$RootKey};

                    # start recursion
                    my $NewDataPart = $Self->ConvertDataToInternal(
                        Definition => $Param{Definition},
                        Data       => $ArrayItem,
                        Child      => 1,
                    );
                    push @NewXMLParts, {
                        Content => $Content,
                        %{$NewDataPart},
                    };
                }
                elsif ( ref $ArrayItem eq '' || $AttrDef{Input}->{Type} eq 'Attachment' ) {
                    my $Value = $ArrayItem;

                    # attribute type Attachment needs some special handling
                    if ($AttrDef{Input}->{Type} eq 'Attachment') {
                        # check if we have already created an instance of this type
                        if ( !$Self->{AttributeTypeModules}->{$AttrDef{Input}->{Type}} ) {
                            # create module instance
                            my $Module = 'ITSMConfigItem::XML::Type::'.$AttrDef{Input}->{Type};
                            my $Object = $Kernel::OM->Get($Module);

                            if (ref $Object ne $Kernel::OM->GetModuleFor($Module)) {
                                return $Self->_Error(
                                    Code    => "Operation.InternalError",
                                    Message => "Unable to create instance of attribute type module for parameter $RootKey!",
                                );
                            }
                            $Self->{AttributeTypeModules}->{$AttrDef{Input}->{Type}} = $Object;
                        }

                        # check if we have a special handling method to prepare the value
                        if ( $Self->{AttributeTypeModules}->{$AttrDef{Input}->{Type}}->can('InternalValuePrepare') ) {
                            $Value = $Self->{AttributeTypeModules}->{$AttrDef{Input}->{Type}}->InternalValuePrepare(
                                Value => $Value
                            );
                        }
                    }

                    push @NewXMLParts, {
                        Content => $Value,
                    };
                }
            }

            # assamble the final value from the parts array
            $NewData->{$RootKey} = \@NewXMLParts;
        }

        if ( ref $Data->{$RootKey} eq 'HASH' ) {

            my @NewXMLParts;
            $NewXMLParts[0] = undef;

            # attribute type Attachment needs some special handling
            if ($AttrDef{Input}->{Type} eq 'Attachment') {
                my $Value = $Data->{$RootKey};

                # check if we have already created an instance of this type
                if ( !$Self->{AttributeTypeModules}->{$AttrDef{Input}->{Type}} ) {
                    # create module instance
                    my $Module = 'ITSMConfigItem::XML::Type::'.$AttrDef{Input}->{Type};
                    my $Object = $Kernel::OM->Get($Module);

                    if (ref $Object ne $Kernel::OM->GetModuleFor($Module)) {
                        return $Self->_Error(
                            Code    => "Operation.InternalError",
                            Message => "Unable to create instance of attribute type module for parameter $RootKey!",
                        );
                    }
                    $Self->{AttributeTypeModules}->{$AttrDef{Input}->{Type}} = $Object;
                }

                # check if we have a special handling method to prepare the value
                if ( $Self->{AttributeTypeModules}->{$AttrDef{Input}->{Type}}->can('InternalValuePrepare') ) {
                    $Value = $Self->{AttributeTypeModules}->{$AttrDef{Input}->{Type}}->InternalValuePrepare(
                        Value => $Value
                    );
                }
                push @NewXMLParts, {
                    Content => $Value
                };
            } else {

                # extract the root key from the hash and assign it to content key
                my $Content = delete $Data->{$RootKey}->{$RootKey};

                # start recursion
                my $NewDataPart = $Self->ConvertDataToInternal(
                    Definition => $Param{Definition},
                    Data       => $Data->{$RootKey},
                    Child      => 1,
                );
                push @NewXMLParts, {
                    Content => $Content,
                    %{$NewDataPart},
                };
            }

            # assamble the final value from the parts array
            $NewData->{$RootKey} = \@NewXMLParts;
        }

        elsif ( ref $Data->{$RootKey} eq '' ) {

            $NewData->{$RootKey} = [
                undef,
                {
                    Content => $Data->{$RootKey},
                }
                ],
        }
    }

    # return only the part on recursion
    if ($Child) {
        return $NewData;
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
        Definition => $DefinitionHashRef,
        Data       => $DataHashRef,
    );

    returns:

    $NewData = $DataHashRef,                  # suitable for display

=cut

sub ConvertDataToExternal {
    my ( $Self, %Param ) = @_;

    my $Data = $Param{Data};

    my $NewData;
    my $Content;
    ROOTHASH:
    for my $RootHash ( @{$Data} ) {
        next ROOTHASH if !defined $RootHash;
        delete $RootHash->{TagKey};

        for my $RootHashKey ( sort keys %{$RootHash} ) {

            # get attribute definition
            my %AttrDef = $Kernel::OM->Get('ITSMConfigItem')->GetAttributeDefByKey(
                Key           => $RootHashKey,
                XMLDefinition => $Param{Definition},
            );

            my $AttributeName = $RootHashKey;

            # ignore attribute if user is logged in as Customer and attribute should not be visible
            next if IsHashRefWithData($Self->{Authorization}) && $Self->{Authorization}->{UserType} eq 'Customer' && !$AttrDef{CustomerVisible};

            if ( $AttrDef{CountMax} && $AttrDef{CountMax} > 1 ) {

                # we have multiple items
                my $Counter = 0;
                ARRAYITEM:
                for my $ArrayItem ( @{ $RootHash->{$RootHashKey} } ) {
                    next ARRAYITEM if !defined $ArrayItem;

                    delete $ArrayItem->{TagKey};

                    $Content = delete $ArrayItem->{Content} || '';

                    # look if we have a sub structure
                    if ( $AttrDef{Sub} ) {
                        $NewData->{$RootHashKey}->[$Counter]->{$RootHashKey} = $Content;

                        # start recursion
                        for my $ArrayItemKey ( sort keys %{$ArrayItem} ) {

                            my $NewDataPart = $Self->ConvertDataToExternal(
                                Definition => $Param{Definition},
                                Data       => [ undef, { $ArrayItemKey => $ArrayItem->{$ArrayItemKey} } ],
                                RootKey    => $RootHashKey,
                                ForDisplay => $Param{ForDisplay},
                            );
                            for my $Key ( sort keys %{$NewDataPart} ) {
                                $NewData->{$RootHashKey}->[$Counter]->{$Key} = $NewDataPart->{$Key};
                            }
                        }
                    }
                    else {
                        # get display values if ForDisplay=! is given or attribute type is Attachment
                        if ( $Param{ForDisplay} || $AttrDef{Input}->{Type} eq 'Attachment' ) {
                            # check if we have already created an instance of this type
                            if ( !$Self->{AttributeTypeModules}->{$AttrDef{Input}->{Type}} ) {
                                # create module instance
                                my $Module = 'ITSMConfigItem::XML::Type::'.$AttrDef{Input}->{Type};
                                my $Object = $Kernel::OM->Get($Module);

                                if (ref $Object ne $Kernel::OM->GetModuleFor($Module)) {
                                    return $Self->_Error(
                                        Code    => "Operation.InternalError",
                                        Message => "Unable to create instance of attribute type module for parameter $RootHashKey!",
                                    );
                                }
                                $Self->{AttributeTypeModules}->{$AttrDef{Input}->{Type}} = $Object;
                            }

                            # check if we have a special handling method to prepare the value
                            if ( $Self->{AttributeTypeModules}->{$AttrDef{Input}->{Type}}->can('ValueLookup') ) {
                                $Content = $Self->{AttributeTypeModules}->{$AttrDef{Input}->{Type}}->ValueLookup(
                                    Item  => \%AttrDef,
                                    Value => $Content
                                );
                            }
                        }

                        $NewData->{$RootHashKey}->[$Counter] = $Content;
                    }

                    $Counter++;
                }
            }
            else {
                # we've got a single item

                ARRAYITEM:
                for my $ArrayItem ( @{ $RootHash->{$RootHashKey} } ) {
                    next ARRAYITEM if !defined $ArrayItem;

                    delete $ArrayItem->{TagKey};

                    $Content = delete $ArrayItem->{Content} || '';

                    # get display values if ForDisplay=! is given or attribute type is Attachment
                    if ( $Param{ForDisplay} || ($AttrDef{Input} && $AttrDef{Input}->{Type} && $AttrDef{Input}->{Type} eq 'Attachment') ) {
                        # check if we have already created an instance of this type
                        if ( !$Self->{AttributeTypeModules}->{$AttrDef{Input}->{Type}} ) {
                            # create module instance
                            my $Module = 'ITSMConfigItem::XML::Type::'.$AttrDef{Input}->{Type};
                            my $Object = $Kernel::OM->Get($Module);

                            if (ref $Object ne $Kernel::OM->GetModuleFor($Module)) {
                                return $Self->_Error(
                                    Code    => "Operation.InternalError",
                                    Message => "Unable to create instance of attribute type module for parameter $RootHashKey!",
                                );
                            }
                            $Self->{AttributeTypeModules}->{$AttrDef{Input}->{Type}} = $Object;
                        }

                        # check if we have a special handling method to prepare the value
                        if ( $Self->{AttributeTypeModules}->{$AttrDef{Input}->{Type}}->can('ValueLookup') ) {
                            $Content = $Self->{AttributeTypeModules}->{$AttrDef{Input}->{Type}}->ValueLookup(
                                Item  => \%AttrDef,
                                Value => $Content
                            );
                        }
                    }

                    $NewData->{$RootHashKey} = $Content;

                    # look if we have a sub structure
                    if ( $AttrDef{Sub} ) {
                        # start recursion
                        for my $ArrayItemKey ( sort keys %{$ArrayItem} ) {

                            my $NewDataPart = $Self->ConvertDataToExternal(
                                Definition => $Param{Definition},
                                Data       => [ undef, { $ArrayItemKey => $ArrayItem->{$ArrayItemKey} } ],
                                RootKey    => $RootHashKey,
                                ForDisplay => $Param{ForDisplay},
                            );

                            if (ref $NewData->{$RootHashKey} ne 'HASH') {
                                # prepare hash for sub result
                                if ( $NewData->{$RootHashKey} ) {
                                    $NewData->{$RootHashKey} = {
                                        $RootHashKey => $NewData->{$RootHashKey}
                                    };
                                }
                                else {
                                    $NewData->{$RootHashKey} = {};
                                }
                            }

                            for my $Key ( sort keys %{$NewDataPart} ) {
                                $NewData->{$RootHashKey}->{$Key} = $NewDataPart->{$Key};
                            }
                        }
                    }
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
        return;
    }

    # definition must be an array
    if ( ref $Definition ne 'ARRAY' ) {
        return $Self->_Error(
            Code    => 'BadRequest',
            Message => 'Invalid definition! Definition is not an array reference.',
        );
        return;
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
