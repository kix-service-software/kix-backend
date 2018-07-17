# --
# Modified version of the work: Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::API::Operation::V1::CMDB::Common;

use strict;
use warnings;

use MIME::Base64();
use Mail::Address;

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

=item CheckCreatePermission ()

Tests if the user has the permission to create a CI for a specific class

    my $Result = $CommonObject->CheckCreatePermission(
        ConfigItem => $ConfigItemHashReference,
        UserID     => 123,
        UserType   => 'Agent',
    );

returns:
    $Result = 1                                 # if everything is OK

=cut

sub CheckCreatePermission {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(ConfigItem UserID UserType)) {
        if ( !$Param{$Needed} ) {
            return;
        }
    }

    # check create permissions
    my $Permission = $Kernel::OM->Get('Kernel::System::ITSMConfigItem')->Permission(
        Scope   => 'Class',
        ClassID => $Param{ConfigItem}->{ClassID},
        UserID  => $Param{UserID},
        Type    => 'rw',
    );

    return 1;
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

    # check ticket internally
    for my $Needed (qw(Name)) {
        if ( !$ConfigItem->{$Needed} ) {
            return $Self->_Error(
                Code    => 'BadRequest',
                Message => "Required parameter $Needed is missing!",
            );
        }
    }

    my $ConfigObject     = $Kernel::OM->Get('Kernel::Config');
    my $ConfigItemObject = $Kernel::OM->Get('Kernel::System::ITSMConfigItem');

    # check, whether the feature to check for a unique name is enabled
    if (
        IsStringWithData( $ConfigItem->{Name} )
        && $ConfigObject->Get('UniqueCIName::EnableUniquenessCheck')
    ) {
        my $ConfigItemIDs = $ConfigItemObject->ConfigItemSearchExtended(
            Name           => $ConfigItem->{Name},
            ClassIDs       => [ $ConfigItem->{ClassID ],
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
                Message => "Parameter ConfigItem::Version is invalid!",
            );            
        }

        # check version attribute values
        my $VersionCheck = $Self->_CheckConfigItemVersion( ConfigItemVersion => $VersionItem );

        if ( !$VersionCheck->{Success} ) {
            return $Self->_Error( 
                %{$VersionCheck} 
            );
        }
    }

    # if everything is OK then return Success
    return $Self->_Success();
}

=item _CheckConfigItemVersion()

checks if the given version parameters are valid.

    my $VersionCheck = $OperationObject->_CheckConfigItemVersion(
        ConfigItem        => $ConfigItem                          # all ConfigItem parameters
        ConfigItemVersion => $ConfigItemVersion,                  # all Version parameters
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

    my $ConfigItem        = $Param{ConfigItem};
    my $ConfigItemVersion = $Param{ConfigItemVersion};

    my $ConfigObject     = $Kernel::OM->Get('Kernel::Config');
    my $ConfigItemObject = $Kernel::OM->Get('Kernel::System::ITSMConfigItem');

    # get last config item defintion
    my $DefinitionData = $ConfigItemObject->DefinitionGet(
        ClassID => $ConfigItem->{ClassID},
    );

    my $XMLDataCheckResult = $Self->_CheckXMLData(
        Definition => $DefinitionData->{DefinitionRef},
        XMLData    => $ConfigItemVersion,
    );

    if ( !$XMLDataCheckResult->{Success} ) {
        return $XMLDataCheckResult;
    }

    # if everything is OK then return Success
    return $Self->_Success();
}

=item _CheckXMLData()

checks if the given XMLData value are valid.

    my $XMLDataCheck = $CommonObject->_CheckXMLData(
        Definition => $DefinitionArrayRef,          # Config Item Definition ot just part of it
        XMLData    => $XMLDataHashRef,
        Parent     => 'some parent',
    );

    returns:

    $XMLDataCheck = {
        Success => 1,                               # if everything is OK
    }

    $XMLDataCheck = {
        Code    => 'Function.Error',           # if error
        Message => 'Error description',
    }

=cut

sub _CheckXMLData {
    my ( $Self, %Param ) = @_;

    my $Definition = $Param{Definition};
    my $XMLData    = $Param{XMLData};
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
            && ( !defined $XMLData->{$ItemKey} || !$XMLData->{$ItemKey} )
            )
        {
            return $Self->_Error(
                Code    => "BadRequest",
                Message => "Parameter ConfigItem::Version::$Parent$ItemKey is missing!",
            };
        }

        if ( ref $XMLData->{$ItemKey} eq 'ARRAY' ) {
            for my $ArrayItem ( @{ $XMLData->{$ItemKey} } ) {
                if ( ref $ArrayItem eq 'HASH' ) {
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
                elsif ( ref $ArrayItem eq '' ) {
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
                        Message => "Parameter ConfigItem::Version::$Parent$ItemKey is invalid!",
                    };
                }
            }
        }
        elsif ( ref $XMLData->{$ItemKey} eq 'HASH' ) {
            $CheckValueResult = $Self->_CheckValue(
                Value   => $XMLData->{$ItemKey}->{$ItemKey},
                Input   => $DefItem->{Input},
                ItemKey => $ItemKey,
                Parent  => $Parent,
            );
            if ( !$CheckValueResult->{Success} ) {
                return $CheckValueResult;
            }
        }
        else {

            # only perform checks if item really exits in the XMLData
            # CountNin checks was verified and passed before!, so it is safe to skip if needed
            if ( $XMLData->{$ItemKey} ) {
                $CheckValueResult = $Self->_CheckValue(
                    Value   => $XMLData->{$ItemKey},
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
                ref $XMLData->{$ItemKey} eq 'ARRAY'
                && scalar @{ $XMLData->{$ItemKey} } > $DefItem->{CountMax}
                )
            {
                return $Self->_Error(
                    Code    => "BadRequest",
                    Message => "Parameter ConfigItem::Version::$Parent$ItemKey count exceeds allowed maximum!",
                };
            }
        }

        # check if there is a sub and start recursion
        if ( defined $DefItem->{Sub} ) {

            if ( ref $XMLData->{$ItemKey} eq 'ARRAY' ) {
                my $Counter = 0;
                for my $ArrayItem ( @{ $XMLData->{$ItemKey} } ) {

                    # start recursion for each array item
                    my $XMLDataCheck = $Self->CheckXMLData(
                        Definition => $DefItem->{Sub},
                        XMLData    => $ArrayItem,
                        Parent     => $Parent . $ItemKey . "[$Counter]::",
                    );
                    if ( !$XMLDataCheck->{Success} ) {
                        return $XMLDataCheck;
                    }
                    $Counter++;
                }
            }
            elsif ( ref $XMLData->{$ItemKey} eq 'HASH' ) {

                # start recursion
                my $XMLDataCheck = $Self->CheckXMLData(
                    Definition => $DefItem->{Sub},
                    XMLData    => $XMLData->{$ItemKey},
                    Parent     => $Parent . $ItemKey . '::',
                );
                if ( !$XMLDataCheck->{Success} ) {
                    return $XMLDataCheck;
                }
            }
            else {

                # start recusrsion
                my $XMLDataCheck = $Self->CheckXMLData(
                    Definition => $DefItem->{Sub},
                    XMLData    => {},
                    Parent     => $Parent . $ItemKey . '::',
                );
                if ( !$XMLDataCheck->{Success} ) {
                    return $XMLDataCheck;
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
            Message => "Parameter ConfigItem::Version::$Parent$ItemKey value is required and missing!",
        );
    }

# TODO!!!

    if ( $Param{Input}->{Type} eq 'Text' || $Param{Input}->{Type} eq 'TextArea' ) {

        # run Text validations
        if ( !$Self->ValidateInputText(%Param) ) {
            return {
                ErrorCode => "$Self->{OperationName}.InvalidParameter",
                ErrorMessage =>
                    "$Self->{OperationName}: ConfigItem->CIXMLData->$Parent$ItemKey parameter value"
                    . " excedes the maxium length!",
            };
        }
    }
    elsif ( $Param{Input}->{Type} eq 'Date' ) {

        # run Date validations
        if ( !$Self->ValidateInputDate(%Param) ) {
            return {
                ErrorCode => "$Self->{OperationName}.InvalidParameter",
                ErrorMessage =>
                    "$Self->{OperationName}: ConfigItem->CIXMLData->$Parent$ItemKey parameter value"
                    . " is not a valid Date format!",
            };
        }
    }
    elsif ( $Param{Input}->{Type} eq 'DateTime' ) {

        # run DateTime validations
        if ( !$Self->ValidateInputDateTime(%Param) ) {
            return {
                ErrorCode => "$Self->{OperationName}.InvalidParameter",
                ErrorMessage =>
                    "$Self->{OperationName}: ConfigItem->CIXMLData->$Parent$ItemKey parameter value"
                    . " is not a valid DateTime format!",
            };
        }
    }
    elsif ( $Param{Input}->{Type} eq 'Customer' ) {

        # run Customer validations
        if ( !$Self->ValidateInputCustomer(%Param) ) {
            return {
                ErrorCode => "$Self->{OperationName}.InvalidParameter",
                ErrorMessage =>
                    "$Self->{OperationName}: ConfigItem->CIXMLData->$Parent$ItemKey parameter value"
                    . " is not a valid customer!",
            };
        }
    }
    elsif ( $Param{Input}->{Type} eq 'CustomerCompany' ) {

        # run CustomerCompany validations
        if ( !$Self->ValidateInputCustomerCompany(%Param) ) {
            return {
                ErrorCode => "$Self->{OperationName}.InvalidParameter",
                ErrorMessage =>
                    "$Self->{OperationName}: ConfigItem->CIXMLData->$Parent$ItemKey parameter value"
                    . " is not a valid customer company!",
            };
        }
    }
    elsif ( $Param{Input}->{Type} eq 'Integer' ) {

        # run Integer validations
        if ( !$Self->ValidateInputInteger(%Param) ) {
            return {
                ErrorCode => "$Self->{OperationName}.InvalidParameter",
                ErrorMessage =>
                    "$Self->{OperationName}: ConfigItem->CIXMLData->$Parent$ItemKey parameter value"
                    . " is not a valid Integer or out of range!",
            };
        }
    }
    elsif ( $Param{Input}->{Type} eq 'GeneralCatalog' ) {

        # run General Catalog validations
        if ( !$Self->ValidateInputGeneralCatalog(%Param) ) {
            return {
                ErrorCode => "$Self->{OperationName}.InvalidParameter",
                ErrorMessage =>
                    "$Self->{OperationName}: ConfigItem->CIXMLData->$Parent$ItemKey parameter value"
                    . " is not a valid for General Catalog '$Param{Input}->{Class}'!",
            };
        }
    }
    else {

        # The type is dummy, do nothing
    }

    return {
        Success => 1,
    };
}

1;

=end Internal:




=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<http://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
COPYING for license information (AGPL). If you did not receive this file, see

<http://www.gnu.org/licenses/agpl.txt>.

=cut
