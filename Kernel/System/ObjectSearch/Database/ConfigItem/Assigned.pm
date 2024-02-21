# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::ObjectSearch::Database::ConfigItem::Assigned;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::System::ObjectSearch::Database::CommonAttribute
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::System::ObjectSearch::Database::ConfigItem::Assigned - attribute module for database object search

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

sub GetSupportedAttributes {
    my ( $Self, %Param ) = @_;

    return {
        AssignedContact => {
            IsSearchable => 1,
            IsSortable   => 0,
            Operators    => ['EQ','IN'],
            ValueType    => 'NUMERIC'
        },
        AssignedOrganisation => {
            IsSearchable => 1,
            IsSortable   => 0,
            Operators    => ['EQ','IN'],
            ValueType    => 'NUMERIC'
        }
    };
}

sub Search {
    my ( $Self, %Param ) = @_;

    # check params
    return if ( !$Self->_CheckSearchParams( %Param ) );

    # isolate assigned object
    my $Assigned = $Param{Search}->{Field};
    $Assigned =~ s/^Assigned//;

    # no restriction by organisation, if restriction by contact is used
    # restriction is handled by AssignedContact
    if (
        $Assigned eq 'Organisation'
        && $Param{Flags}->{AssignedContact}
    ) {
        return {};
    }

    # prepare given values as array
    my @Values = ();
    if ( !IsArrayRef( $Param{Search}->{Value} ) ) {
        push( @Values,  $Param{Search}->{Value}  );
    }
    else {
        @Values = @{ $Param{Search}->{Value} };
    }

    # process values and gather assigned config item ids
    my @AssignedConfigItemIDs = ();
    for my $Value ( @Values ) {
        # get search parameter for assigned assets
        my $GetParams = $Self->_GetAssigendParams(
            %Param,
            Assigned => $Assigned,
            Value    => $Value
        );

        if ( IsHashRefWithData( $GetParams ) ) {
            # process parameter by class
            for my $ClassID ( keys( %{ $GetParams } ) ) {
                # skip classes without search params
                next if ( !IsHashRefWithData( $GetParams->{ $ClassID }->{SearchParams} ) );

                # isolate parameter
                my %SearchParams = %{ $GetParams->{ $ClassID }->{SearchParams} };
                my $IsWhat       = $GetParams->{ $ClassID }->{IsWhat};

                # init search definition. always filter by current class
                my %Search = (
                    AND => [
                        {
                            Field    => 'ClassID',
                            Operator => 'EQ',
                            Value    => $ClassID
                        }
                    ],
                    OR => []
                );

                # prepare search
                for my $Attr ( keys( %SearchParams ) ) {
                    # handle xml parameter
                    if (
                        ref( $IsWhat ) eq 'HASH'
                        && $IsWhat->{ $Attr }
                    ) {
                        push(
                            @{ $Search{OR} },
                            {
                                Field    => "CurrentVersion.Data.$Attr",
                                Operator => IsArrayRef( $SearchParams{ $Attr } ) ? 'IN' : 'EQ',
                                Value    => $SearchParams{ $Attr }
                            }
                        );
                    }
                    # handle other parameter
                    else {
                        push(
                            @{ $Search{AND} },
                            {
                                Field    => $Attr,
                                Operator => IsArrayRef( $SearchParams{ $Attr } ) ? 'IN' : 'EQ',
                                Value    => $SearchParams{ $Attr }
                            }
                        );
                    }
                }

                # search for assigned config items of this class
                my @ConfigItemIDs = $Kernel::OM->Get('ObjectSearch')->Search(
                    ObjectType => 'ConfigItem',
                    Result     => 'ARRAY',
                    UserID     => $Param{UserID},
                    UserType   => $Param{UserType},
                    Search     => \%Search,
                    Silent     => $Param{Silent}
                );

                # add found config items to filter value
                if ( scalar( @ConfigItemIDs ) ) {
                    push ( @AssignedConfigItemIDs, @ConfigItemIDs );
                }
            }
        }
    }

    # remove duplicated entries
    my @UniqueAssignedConfigItemIDs = $Kernel::OM->Get('Main')->GetUnique(@AssignedConfigItemIDs);

    # prepare condition with gatherd config item ids
    my $Condition = $Self->_GetCondition(
        Operator  => 'IN',
        Column    => 'ci.id',
        Value     => \@UniqueAssignedConfigItemIDs,
        ValueType => 'NUMERIC',
        Silent    => $Param{Silent}
    );
    return if ( !$Condition );

    # return search def
    return {
        Where => [ $Condition ]
    };
}

=begin Internal:

=cut

sub _GetAssigendParams {
    my ( $Self, %Param ) = @_;

    # get relevant mapping
    my $Mapping = $Self->_GetAssignedMapping( %Param );
    return if ( !$Mapping );

    # prepare lookup for classes
    my %ClassIDs = %{
        $Kernel::OM->Get('GeneralCatalog')->ItemList(
            Class => 'ITSM::ConfigItem::Class',
        )
    };
    my %Classes = reverse( %ClassIDs );

    # prepare object data
    my $ObjectData;
    if ( $Param{Assigned} eq 'Contact' ) {
        $ObjectData = $Self->_GetAssignedContact(
            ContactID              => $Param{Value},
            RelevantOrganisationID => $Param{Flags}->{AssignedOrganisation} || q{},
            Silent                 => $Param{Silent}
        );
    }
    elsif ( $Param{Assigned} eq 'Organisation' ) {
        $ObjectData = $Self->_GetAssignedOrganisation(
            OrganisationID => $Param{Value},
            Silent         => $Param{Silent}
        );
    }
    return if ( !IsHashRefWithData( $ObjectData ) );

    # process classes from mapping
    my %AssigendParams;
    CICLASS:
    for my $CIClass ( keys %{ $Mapping } ) {
        # skip unknown classes
        next CICLASS if ( !$Classes{ $CIClass } );
        # skip invalid mappings
        next CICLASS if ( !IsHashRefWithData( $Mapping->{ $CIClass } ) );

        # prepare search data
        my $SearchData = $Self->_GetAssignedSearchData(
            ClassMapping => $Mapping->{ $CIClass },
            Object       => $ObjectData
        );

        # ignore class if no search is given
        next CICLASS if ( !IsHashRefWithData( $SearchData ) );

        # get current definition of class
        my $XMLDefinition = $Kernel::OM->Get('ITSMConfigItem')->DefinitionGet(
            ClassID => $Classes{ $CIClass },
        );
        if ( !$XMLDefinition->{DefinitionID} ) {
            if ( !$Param{Silent} ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "No Definition definied for class $CIClass!",
                );
            }
            next CICLASS;
        }

        # prepare xml search params (What)
        my %SearchParam = ();
        $Self->_GetSearchDataForAssignedCIs(
            XMLDefinition => $XMLDefinition->{DefinitionRef},
            SearchParams  => \%SearchParam,
            SearchData    => $SearchData
        );

        # remember search params for class
        $AssigendParams{ $Classes{ $CIClass } } = \%SearchParam;
    }

    # return search params
    return \%AssigendParams;
}

sub _GetAssignedSearchData {
    my ($Self, %Param) = @_;

    # isolate parameter
    my %ClassMapping = %{ $Param{ClassMapping} };
    my %Object       = %{ $Param{Object} };

    # init result search data
    my %SearchData = ();

    # process attributes of class mapping
    for my $CISearchAttribute ( keys( %ClassMapping ) ) {
        # skip empty attribute keys
        next if ( !$CISearchAttribute );
        # skip empty attribute mappings
        next if ( !IsHashRefWithData( $ClassMapping{ $CISearchAttribute } ) );

        # prepare object search attributes
        my $ObjectSearchAttributes = $ClassMapping{ $CISearchAttribute }->{SearchAttributes};
        if (
            $ObjectSearchAttributes
            && !IsArrayRef($ObjectSearchAttributes)
        ) {
            $ObjectSearchAttributes = [ $ObjectSearchAttributes ];
        }

        # prepare static search attributes
        my $SearchStatics = $ClassMapping{ $CISearchAttribute }->{SearchStatic};
        if (
            $SearchStatics
            && !IsArrayRef( $SearchStatics )
        ) {
            $SearchStatics = [$SearchStatics];
        }

        # skip if nether object search nor static search is given
        next if (
            !IsArrayRefWithData( $ObjectSearchAttributes )
            && !IsArrayRefWithData( $SearchStatics )
        );

        # init search data for attribute
        $SearchData{ $CISearchAttribute } = [];

        # get attributes search data
        if (
            %Object
            && IsArrayRefWithData( $ObjectSearchAttributes )
        ) {
            $Self->_GetAssignedSearchDataObject(
                CISearchAttribute      => $CISearchAttribute,
                ObjectSearchAttributes => $ObjectSearchAttributes,
                SearchData             => \%SearchData,
                Object                 => \%Object
            );
        }

        # get static search data
        if ( IsArrayRefWithData( $SearchStatics ) ) {
            $Self->_GetAssignedSearchDataStatic(
                CISearchAttribute => $CISearchAttribute,
                SearchStatics     => $SearchStatics,
                SearchData        => \%SearchData,
            );
        }

        # delete attributes without search value
        if (!IsArrayRefWithData( $SearchData{ $CISearchAttribute } ) ) {
            delete( $SearchData{ $CISearchAttribute } );
        }
    }

    return \%SearchData;
}

sub _GetAssignedSearchDataStatic {
    my ($Self, %Param) = @_;

    # process static search entries
    for my $SearchStatic ( @{ $Param{SearchStatics} } ) {
        # skip undefined entries
        next if ( !defined( $SearchStatic ) );

        # add entry for attribute
        push ( @{ $Param{SearchData}->{ $Param{CISearchAttribute} } }, $SearchStatic );
    }

    return 1;
}

sub _GetAssignedSearchDataObject {
    my ($Self, %Param) = @_;

    # process object search entries
    for my $ObjectSearchAttribute ( @{ $Param{ObjectSearchAttributes} } ) {
        # init value
        my $Value = undef;

        # check if attribute contains a dot
        if ( $ObjectSearchAttribute =~ /.+\..+/ ) {
            my @AttributeStructure = split(/\./, $ObjectSearchAttribute);
            next if (
                scalar( @AttributeStructure ) != 2
                || !$AttributeStructure[0]
                || !$AttributeStructure[1]
                || !IsHashRefWithData( $Param{Object}->{ $AttributeStructure[0] } )
            );
            $Value = $Param{Object}->{ $AttributeStructure[0] }->{ $AttributeStructure[1] }
        } else {
            $Value = $Param{Object}->{ $ObjectSearchAttribute };
        }

        # skip undefined values
        next if ( !defined( $Value ) );

        # check if attribute is already set
        if ( IsArrayRefWithData( $Param{SearchData}->{ $Param{CISearchAttribute } } ) ) {
            # prepare lookup hash for existing data
            my %SearchData = map { $_ => 1 } @{ $Param{SearchData}->{ $Param{CISearchAttribute} } };

            # handle array value
            if ( IsArrayRef( $Value ) ) {
                # process value entries
                VALUE:
                for my $Entry ( @{ $Value } ) {
                    # skip already known entries
                    next VALUE if ( $SearchData{ $Entry } );

                    # add new entry
                    push (
                        @{ $Param{SearchData}->{ $Param{CISearchAttribute} } },
                        $Entry
                    );
                }
            }
            # handle unknow value
            elsif ( !$SearchData{ $Value } ) {
                # add new entry
                push (
                    @{ $Param{SearchData}->{ $Param{CISearchAttribute} } },
                    $Value
                );
            }
        }
        else {
            # add new entry for attribute
            push (
                @{ $Param{SearchData}->{ $Param{CISearchAttribute} } },
                IsArrayRef( $Value ) ? @{ $Value } : $Value
            );
        }
    }

    return 1;
}

sub _GetAssignedContact {
    my ($Self, %Param) = @_;

    # get contact data
    my %ContactData = $Kernel::OM->Get('Contact')->ContactGet(
        ID            => $Param{ContactID},
        DynamicFields => 1,
        Silent        => $Param{Silent}
    );
    if ( !%ContactData ) {
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Contact '$Param{ContactID}' not found."
            );
        }
        return;
    }

    # get user data if not already included
    if (
        !defined( $ContactData{User} )
        && $ContactData{AssignedUserID}
    ) {
        my %User = $Kernel::OM->Get('User')->GetUserData(
            UserID => $ContactData{AssignedUserID},
            Silent => $Param{Silent}
        );
        if ( !%User ) {
            if ( !$Param{Silent} ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Assigned user '$ContactData{AssignedUserID}' not found."
                );
            }
        }
        else {
            $ContactData{User} = \%User;
        }
    }

    # RelevantOrganisationID is given
    if ( $Param{RelevantOrganisationID} ) {
        # prepare lookup hash for provided ids
        my %RelevantOrganisationIDs;
        if ( IsArrayRef( $Param{RelevantOrganisationID} ) ) {
            %RelevantOrganisationIDs = map {$_ => 1} @{ $Param{RelevantOrganisationID} || {} };
        }
        else {
            $RelevantOrganisationIDs{ $Param{RelevantOrganisationID} } = 1;
        }

        # add matching organisations of config as RelevantOrganisationID
        if (
            %RelevantOrganisationIDs
            && IsArrayRefWithData( $ContactData{OrganisationIDs} )
        ) {
            # init RelevantOrganisationID in contact data
            $ContactData{RelevantOrganisationID} = [];

            # process organisation ids of contact
            for my $OrganisationID ( @{ $ContactData{OrganisationIDs} }) {
                # skip not matching ids 
                next if ( !$RelevantOrganisationIDs{ $OrganisationID } );

                # add matching ids to RelevantOrganisationID
                push(
                    @{ $ContactData{RelevantOrganisationID} },
                    $OrganisationID
                );
            }
        }
    }
    # fallback to PrimaryOrganisationID if no RelevantOrganisationID is given
    elsif ( $ContactData{PrimaryOrganisationID} ) {
        $ContactData{RelevantOrganisationID} = $ContactData{PrimaryOrganisationID};
    }

    return \%ContactData;
}

sub _GetAssignedOrganisation {
    my ($Self, %Param) = @_;

    # get organisation data
    my %OrganisationData = $Kernel::OM->Get('Organisation')->OrganisationGet(
        ID            => $Param{OrganisationID},
        DynamicFields => 1
    );
    if ( !%OrganisationData ) {
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Organisation '$Param{OrganisationID}' not found."
            );
        }
        return;
    }

    return \%OrganisationData;
}

sub _GetAssignedMapping {
    my ( $Self, %Param ) = @_;

    # check if mapping data is already prepared
    if ( !IsHashRefWithData( $Param{Flags}->{AssignedConfigItemsMapping} ) ) {
        # get mapping config
        my $MappingString = $Kernel::OM->Get('Config')->Get('AssignedConfigItemsMapping') || q{};
        if ( !$MappingString ) {
            if ( !$Param{Silent} ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Empty sysconfig option 'AssignedConfigItemsMapping'."
                );
            }

            return;
        }

        # decode mapping data
        my $MappingData = $Kernel::OM->Get('JSON')->Decode(
            Data   => $MappingString,
            Silent => $Param{Silent}
        );
        if ( !IsHashRefWithData( $MappingData ) ) {
            if ( !$Param{Silent} ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Invalid JSON for sysconfig option 'AssignedConfigItemsMapping'."
                );
            }

            return;
        }

        # save mapping in flags
        $Param{Flags}->{AssignedConfigItemsMapping} = $MappingData;
    }

    # get relevant mapping data
    my $Mapping = $Param{Flags}->{AssignedConfigItemsMapping}->{ $Param{Assigned} } || q{};

    # return mapping data
    return $Mapping;
}

sub _GetSearchDataForAssignedCIs {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    return if ( ref( $Param{XMLDefinition} ) ne 'ARRAY' );
    return if ( ref( $Param{SearchParams} ) ne 'HASH' );
    return if ( ref( $Param{SearchData} ) ne 'HASH' );

    # process items of xml definition
    for my $Item ( @{ $Param{XMLDefinition} } ) {
        # prepare current key
        my $Key = $Param{Prefix} ? $Param{Prefix} . q{::} . $Item->{Key} : $Item->{Key};

        # process sub entry
        if ( $Item->{Sub} ) {
            # start recursion, if "Sub" was found
            $Self->_GetSearchDataForAssignedCIs(
                XMLDefinition => $Item->{Sub},
                SearchParams  => $Param{SearchParams},
                SearchData    => $Param{SearchData},
                IsWhat        => $Param{IsWhat},
                Prefix        => $Key,
            );
        }

        # skip item if not relevant for search data
        next if ( !defined( $Param{SearchData}->{ $Key } ) );

        # add search parameter for key
        my $SearchKey = $Key;
        $SearchKey =~ s{::}{.}xmsg;
        $Param{SearchParams}->{IsWhat}->{ $SearchKey }       = 1;
        $Param{SearchParams}->{SearchParams}->{ $SearchKey } = $Param{SearchData}->{ $Key };
    }

    for my $Attribute (qw(DeploymentState DeplState DeplStateID DeplStateIDs IncidentState InciState InciStateID InciStateIDs Name Number)) {
        # skip attribute if not relevant for search data
        next if ( !defined( $Param{SearchData}->{ $Attribute } ) );

        if ( $Attribute eq 'DeploymentState' ) {
            $Param{SearchParams}->{SearchParams}->{DeplState} = $Param{SearchData}->{ $Attribute };
        }
        elsif ( $Attribute eq 'IncidentState' ) {
            $Param{SearchParams}->{SearchParams}->{InciState} = $Param{SearchData}->{ $Attribute };
        }
        else {
            $Param{SearchParams}->{SearchParams}->{ $Attribute } = $Param{SearchData}->{ $Attribute };
        }
    }

    return 1;
}

=end Internal:

=cut

1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-GPL3 for license information (GPL3). If you did not receive this file, see

<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
