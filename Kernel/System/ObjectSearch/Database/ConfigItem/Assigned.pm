# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com
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
    Kernel::System::ObjectSearch::Database::Common
);

our @ObjectDependencies = qw(
    Log
);

=head1 NAME

Kernel::System::ObjectSearch::Database::ConfigItem::XMLData - attribute module for database object search

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

=item GetSupportedAttributes()

defines the list of attributes this module is supporting

    my $AttributeList = $Object->GetSupportedAttributes();

    $Result = {
        Property => {
            IsSortable     => 0|1,
            IsSearchable => 0|1,
            Operators     => []
        },
    };

=cut

sub GetSupportedAttributes {
    my ( $Self, %Param ) = @_;

    $Self->{Supported} = {
        AssignedContact => {
            IsSearchable => 1,
            IsSortable   => 0,
            Operators    => ['EQ'],
            ValueType    => 'Contact.ID'
        },
        AssignedOrganisation => {
            IsSearchable => 1,
            IsSortable   => 0,
            Operators    => ['EQ'],
            ValueType    => 'Organisation.ID'
        }
    };

    return $Self->{Supported};
}


=item Search()

run this module and return the SQL extensions

    my $Result = $Object->Search(
        Search => {}
    );

    $Result = {
        Where   => [ ],
    };

=cut

sub Search {
    my ( $Self, %Param ) = @_;
    my @SQLWhere;

    # check params
    if ( !$Param{Search} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Need Search!",
        );
        return;
    }

    my $Assigned = $Param{Search}->{Field};
    $Assigned =~ s/Assigned//sm;

    if (
        $Assigned eq 'Organisation'
        && $Param{Flags}->{AssignedContact}
    ) {
        return {};
    }

    my $GetParams = $Self->_GetAssigendParams(
        %Param,
        Assigned => $Assigned
    );

    my @Values;
    if ( IsHashRefWithData($GetParams) ) {
        for my $ClassID ( sort keys %{$GetParams} ) {
            next if !$GetParams->{$ClassID}->{SearchParams};

            my $SearchParams = $GetParams->{$ClassID}->{SearchParams};
            my $IsWhat       = $GetParams->{$ClassID}->{IsWhat};
            my %Search;

            push(
                @{$Search{AND}},
                {
                    Field    => 'ClassID',
                    Operator => 'EQ',
                    Value    => $ClassID
                }
            );

            for my $Attr ( keys %{$SearchParams} ) {
                if ( $IsWhat->{$Attr} ) {
                    push(
                        @{$Search{OR}},
                        {
                            Field    => "CurrentVersion.Data.$Attr",
                            Operator => 'EQ',
                            Type     => 'STRING',
                            Value    => $SearchParams->{$Attr}
                        }
                    );
                }
                else {
                    push(
                        @{$Search{AND}},
                        {
                            Field    => $Attr,
                            Operator => IsArrayRef($SearchParams->{$Attr}) ? 'IN' : 'EQ',
                            Type     => 'STRING',
                            Value    => $SearchParams->{$Attr}
                        }
                    );
                }
            }
            my @IDs = $Kernel::OM->Get('ObjectSearch')->Search(
                ObjectType => 'ConfigItem',
                Result     => 'ARRAY',
                UserID     => $Param{UserID},
                UserType   => $Param{UserType},
                Search     => \%Search
            );

            if ( scalar(@IDs) ) {
                push ( @Values, @IDs );
            }
        }
    }

    my @Where = $Self->GetOperation(
        Operator  => 'IN',
        Column    => 'ci.id',
        Value     => \@Values,
        Supported => ['IN']
    );

    return if !@Where;

    push( @SQLWhere, @Where );

    return {
        Where => \@SQLWhere,
    };
}

sub _GetAssigendParams {
    my ( $Self, %Param ) = @_;

    my %Result;

    my $Mapping = $Self->_GetAssignedMapping(%Param);

    return %Result if !$Mapping;

    my %ClassIDs = %{$Kernel::OM->Get('GeneralCatalog')->ItemList(
        Class => 'ITSM::ConfigItem::Class',
    )};
    my %Classes = reverse %ClassIDs;

    my $Value = IsArrayRef($Param{Search}->{Value}) ? $Param{Search}->{Value}->[0] : $Param{Search}->{Value};

    my %ObjectData;
    if ( $Param{Assigned} eq 'Contact' ) {
        %ObjectData = $Self->_GetAssignedContact(
            ContactID              => $Value,
            RelevantOrganisationID => $Param{Flags}->{AssignedOrganisation} || q{}
        );
    }
    elsif ( $Param{Assigned} eq 'Organisation' ) {
        %ObjectData = $Self->_GetAssignedOrganisation(
            OrganisationID => $Value
        );
    }

    return if !%ObjectData;

    CICLASS:
    for my $CIClass ( keys %{ $Mapping } ) {
        next CICLASS if !$Classes{$CIClass};
        next CICLASS if ( !IsHashRefWithData( $Mapping->{$CIClass} ) );

        my %SearchParam;

        # get CI-class definition...
        my $XMLDefinition = $Kernel::OM->Get('ITSMConfigItem')->DefinitionGet(
            ClassID => $Classes{$CIClass},
        );

        if ( !$XMLDefinition->{DefinitionID} ) {
            if (
                !defined $Param{Silent}
                || !$Param{Silent}
            ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "No Definition definied for class $CIClass!",
                );
            }
            next CICLASS;
        }

        # prepare search data
        my %SearchData = $Self->_GetAssignedSearchData(
            CIClass => $CIClass,
            Mapping => $Mapping,
            Object  => \%ObjectData
        );

        # ignore class if not search is given/usable
        next if (!scalar(keys %SearchData));

        # prepare xml search params (What)
        $Self->_GetXMLSearchDataForAssignedCIs(
            XMLDefinition => $XMLDefinition->{DefinitionRef},
            SearchParams  => \%SearchParam,
            SearchData    => \%SearchData
        );

        $Result{$Classes{$CIClass}} = \%SearchParam;
    }

    return \%Result;
}

sub _GetAssignedSearchData {
    my ($Self, %Param) = @_;

    my $CIClass = $Param{CIClass};
    my $Mapping = $Param{Mapping};
    my %Object  = %{$Param{Object}};
    my %SearchData;

    for my $CISearchAttribute ( keys %{ $Mapping->{$CIClass} } ) {
        next if (!$CISearchAttribute);
        next if ( !IsHashRefWithData( $Mapping->{$CIClass}->{$CISearchAttribute} ) );

        my $ObjectSearchAttributes = $Mapping->{$CIClass}->{$CISearchAttribute}->{SearchAttributes};
        if ($ObjectSearchAttributes && !IsArrayRefWithData($ObjectSearchAttributes)) {
            $ObjectSearchAttributes = [$ObjectSearchAttributes];
        }
        my $SearchStatics = $Mapping->{$CIClass}->{$CISearchAttribute}->{SearchStatic};
        if ($SearchStatics && !IsArrayRefWithData($SearchStatics)) {
            $SearchStatics = [$SearchStatics];
        }

        next if ( !IsArrayRefWithData($ObjectSearchAttributes) && !IsArrayRefWithData($SearchStatics) );

        $CISearchAttribute =~ s/^\s+//g;
        $CISearchAttribute =~ s/\s+$//g;

        next if !$CISearchAttribute;

        $SearchData{$CISearchAttribute} = [];

        # get attributes search data
        if (
            %Object
            && IsArrayRefWithData($ObjectSearchAttributes)
        ) {
            $Self->_GetAssignedSearchDataObject(
                CISearchAttribute      => $CISearchAttribute,
                ObjectSearchAttributes => $ObjectSearchAttributes,
                SearchData             => \%SearchData,
                Object                 => \%Object
            );
        }

        # get static search data
        if (IsArrayRefWithData($SearchStatics)) {
            $Self->_GetAssignedSearchDataStatic(
                CISearchAttribute => $CISearchAttribute,
                SearchStatics     => $SearchStatics,
                SearchData        => \%SearchData,
            );
        }

        if (!scalar(@{ $SearchData{$CISearchAttribute} })) {
            delete $SearchData{$CISearchAttribute};
        }
    }

    return %SearchData;
}

sub _GetAssignedSearchDataStatic {
    my ($Self, %Param) = @_;

    for my $SearchStatic ( @{$Param{SearchStatics}} ) {
        next if ( !defined $SearchStatic );
        push ( @{ $Param{SearchData}->{$Param{CISearchAttribute}} }, $SearchStatic );
    }

    return 1;
}

sub _GetAssignedSearchDataObject {
    my ($Self, %Param) = @_;

    for my $ObjectSearchAttribute ( @{$Param{ObjectSearchAttributes}} ) {
        my $Value;
        if ( $ObjectSearchAttribute =~ /.+[.].+/sm ) {
            my @AttributStructure = split(/[.]/sm, $ObjectSearchAttribute);
            next if (
                !$AttributStructure[0]
                || !$AttributStructure[1]
                || !IsHashRefWithData( $Param{Object}->{$AttributStructure[0]} )
            );
            $Value = $Param{Object}->{$AttributStructure[0]}->{$AttributStructure[1]}
        } else {
            $Value = $Param{Object}->{$ObjectSearchAttribute};
        }

        next if ( !defined $Value );

        if ( IsArrayRefWithData($Param{SearchData}->{$Param{CISearchAttribute}}) ) {
            my %SearchData = map { $_ => 1 } @{ $Param{SearchData}->{$Param{CISearchAttribute}} };
            if ( IsArrayRef($Value) ) {
                VALUE:
                for my $Val ( @{$Value} ) {
                    next VALUE if ($SearchData{$Val});
                    push (
                        @{ $Param{SearchData}->{$Param{CISearchAttribute}} },
                        $Val
                    );
                }
            }
            elsif ( !$SearchData{$Value} ) {
                push (
                    @{ $Param{SearchData}->{$Param{CISearchAttribute}} },
                    $Value
                );
            }
        }
        else {
            push (
                @{ $Param{SearchData}->{$Param{CISearchAttribute}} },
                IsArrayRefWithData($Value) ? @{$Value} : $Value
            );
        }
    }

    return 1;
}

sub _GetAssignedContact {
    my ($Self, %Param) = @_;

    # get contact and user data
    my %ContactData = $Kernel::OM->Get('Contact')->ContactGet(
        ID            => $Param{ContactID},
        DynamicFields => 1,
        Silent        => 1
    );

    if ( !%ContactData ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Contact '$Param{ContactID}' not found."
        );
        return;
    }

    if (
        !$ContactData{User}
        && $ContactData{AssignedUserID}
    ) {
        my %User = $Kernel::OM->Get('User')->GetUserData(
            UserID => $ContactData{AssignedUserID},
        );
        $ContactData{User} = IsHashRefWithData(\%User) ? \%User : undef;
    }

    my %RelevantOrganisationIDs;
    if ( $Param{RelevantOrganisationID} ) {
        if ( IsArrayRefWithData($Param{RelevantOrganisationID}) ) {
            %RelevantOrganisationIDs = map {$_ => 1} @{$Param{RelevantOrganisationID} || {}};
        }
        else {
            $RelevantOrganisationIDs{$Param{RelevantOrganisationID}} = 1;
        }
    }

    if (
        %RelevantOrganisationIDs
        && IsArrayRefWithData($ContactData{OrgisationIDs})
    ) {
        for my $OrgID ( @{$ContactData{OrgisationIDs}}) {
            next if !$RelevantOrganisationIDs{$OrgID};
            push(
                @{$ContactData{RelevantOrganisationID}},
                $OrgID
            );
        }
    }

    if (
        !$ContactData{RelevantOrganisationID}
        && $ContactData{PrimaryOrganisationID}
    ) {
        $ContactData{RelevantOrganisationID} = $ContactData{PrimaryOrganisationID};
    }

    return %ContactData;
}
sub _GetAssignedOrganisation {
    my ($Self, %Param) = @_;

    # get organisation and user data
    my %OrganisationData = $Kernel::OM->Get('Organisation')->OrganisationGet(
        ID            => $Param{OrganisationID},
        DynamicFields => 1
    );

    if ( !%OrganisationData ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Organisation '$Param{OrganisationID}' not found."
        );
        return;
    }

    return %OrganisationData;
}

sub _GetAssignedMapping {
    my ( $Self, %Param ) = @_;

    my $Mapping;
    if ( !$Param{Flags}->{AssignedConfigItemsMapping} ) {
        my $MappingString = $Kernel::OM->Get('Config')->Get('AssignedConfigItemsMapping') || q{};

        my $MappingData = $Kernel::OM->Get('JSON')->Decode(
            Data   => $MappingString,
            Silent => $Param{Silent} || 0
        );

        if ( !IsHashRefWithData($MappingData) ) {
            if (
                !defined $Param{Silent}
                || !$Param{Silent}
            ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Invalid JSON for sysconfig option 'AssignedConfigItemsMapping'."
                );
            }
        }

        $Param{Flags}->{AssignedConfigItemsMapping} = $MappingData;
        $Mapping = $MappingData->{$Param{Assigned}} if ( $MappingData->{$Param{Assigned}} );
    }
    else {
        $Mapping = $Param{Flags}->{AssignedConfigItemsMapping}->{$Param{Assigned}} || q{};
    }

    return $Mapping;
}

sub _GetXMLSearchDataForAssignedCIs {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    return if !$Param{XMLDefinition} || ref $Param{XMLDefinition} ne 'ARRAY';
    return if !$Param{SearchParams}  || ref $Param{SearchParams}   ne 'HASH';
    return if !$Param{SearchData}    || ref $Param{SearchData}    ne 'HASH';

    for my $Item ( @{ $Param{XMLDefinition} } ) {
        my $Key = $Param{Prefix} ? $Param{Prefix} . q{::} . $Item->{Key} : $Item->{Key};

        if ( $Item->{Sub} ) {
            # start recursion, if "Sub" was found
            $Self->_GetXMLSearchDataForAssignedCIs(
                XMLDefinition => $Item->{Sub},
                SearchParams  => $Param{SearchParams},
                SearchData    => $Param{SearchData},
                IsWhat        => $Param{IsWhat},
                Prefix        => $Key,
            );
        }

        next if !defined $Param{SearchData}->{$Key};

        # prepare value
        my $Values = [];
        if ( IsArrayRefWithData($Param{SearchData}->{$Key}) ) {

            for my $SingleValue ( @{$Param{SearchData}->{$Key}} ) {
                my $ValuePart = $Kernel::OM->Get('ITSMConfigItem')->XMLExportSearchValuePrepare(
                    Item  => $Item,
                    Value => $SingleValue,
                );

                if (defined $ValuePart && $ValuePart ne q{}) {
                    if ( IsArrayRefWithData($ValuePart) ) {
                        push( @{$Values}, @{$ValuePart} );
                    } else {
                        push( @{$Values}, $ValuePart);
                    }
                }
            }
        }

        # create search key
        my $SearchKey = $Key;
        $SearchKey =~ s{::}{.}xmsg;
        $Param{SearchParams}->{ IsWhat }->{ $SearchKey }       = 1;
        $Param{SearchParams}->{ SearchParams }->{ $SearchKey } = $Values;

    }
    return 1;
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
