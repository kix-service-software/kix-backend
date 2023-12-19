# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::ObjectSearch::Database::FAQArticle::Assigned;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::System::ObjectSearch::Database::CommonAttribute
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::System::ObjectSearch::Database::FAQArticle::Assigned - attribute module for database object search

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
            Operators    => ['EQ'],
            ValueType    => 'NUMERIC'
        }
    };
}

sub Search {
    my ( $Self, %Param ) = @_;

    # check params
    return if ( !$Self->_CheckSearchParams( %Param ) );

    my $Assigned = $Param{Search}->{Field};
    $Assigned =~ s/Assigned//sm;

    my $SearchParams = $Self->_GetAssigendParams(
        %Param,
        Assigned => $Assigned
    );

    my @Values;
    if ( IsHashRefWithData($SearchParams) ) {
        for my $Attribute ( sort keys %{$SearchParams} ) {
            next if !$SearchParams->{$Attribute};

            my %Search;
            if ( $Attribute eq 'CustomerVisible' ) {
                for my $Value ( @{$SearchParams->{$Attribute}} ){
                    push(
                        @{$Search{OR}},
                        {
                            Field    => $Attribute,
                            Operator => 'EQ',
                            Value    => $Value
                        }
                    );
                }
            }
            else {
                push(
                    @{$Search{AND}},
                    {
                        Field    => $Attribute,
                        Operator => IsArrayRef($SearchParams->{$Attribute}) ? 'IN' : 'EQ',
                        Value    => $SearchParams->{$Attribute}
                    }
                )
            }

            my @IDs = $Kernel::OM->Get('ObjectSearch')->Search(
                ObjectType => 'FAQArticle',
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

    my $Condition = $Self->_GetCondition(
        Operator  => 'IN',
        Column    => 'f.id',
        Value     => \@Values
    );

    return if ( !$Condition );

    return {
        Where => [ $Condition ]
    };
}

sub _GetAssigendParams {
    my ( $Self, %Param ) = @_;

    my %Result;

    my $Mapping = $Self->_GetAssignedMapping(%Param);

    return %Result if !$Mapping;

    my $Value = IsArrayRef($Param{Search}->{Value}) ? $Param{Search}->{Value}->[0] : $Param{Search}->{Value};

    my %ObjectData;
    if ( $Param{Assigned} eq 'Contact' ) {
        %ObjectData = $Self->_GetAssignedContact(
            ContactID              => $Value,
            RelevantOrganisationID => $Param{Flags}->{AssignedOrganisation} || q{}
        );
    }

    return if !%ObjectData;


    # prepare search data
    %Result = $Self->_GetAssignedSearchData(
        Mapping => $Mapping,
        Object  => \%ObjectData
    );

    return \%Result;
}

sub _GetAssignedSearchData {
    my ($Self, %Param) = @_;

    my $Mapping = $Param{Mapping};
    my %Object  = %{$Param{Object}};
    my %SearchData;

    for my $SearchAttribute ( keys %{ $Mapping } ) {
        next if (!$SearchAttribute);
        next if ( !IsHashRefWithData( $Mapping->{$SearchAttribute} ) );

        my $ObjectSearchAttributes = $Mapping->{$SearchAttribute}->{SearchAttributes};
        if ($ObjectSearchAttributes && !IsArrayRefWithData($ObjectSearchAttributes)) {
            $ObjectSearchAttributes = [$ObjectSearchAttributes];
        }
        my $SearchStatics = $Mapping->{$SearchAttribute}->{SearchStatic};
        if ($SearchStatics && !IsArrayRefWithData($SearchStatics)) {
            $SearchStatics = [$SearchStatics];
        }

        next if ( !IsArrayRefWithData($ObjectSearchAttributes) && !IsArrayRefWithData($SearchStatics) );

        $SearchAttribute =~ s/^\s+//g;
        $SearchAttribute =~ s/\s+$//g;

        next if !$SearchAttribute;

        $SearchData{$SearchAttribute} = [];

        # get attributes search data
        if (
            %Object
            && IsArrayRefWithData($ObjectSearchAttributes)
        ) {
            $Self->_GetAssignedSearchDataObject(
                SearchAttribute        => $SearchAttribute,
                ObjectSearchAttributes => $ObjectSearchAttributes,
                SearchData             => \%SearchData,
                Object                 => \%Object
            );
        }

        # get static search data
        if (IsArrayRefWithData($SearchStatics)) {
            $Self->_GetAssignedSearchDataStatic(
                SearchAttribute => $SearchAttribute,
                SearchStatics   => $SearchStatics,
                SearchData      => \%SearchData,
            );
        }

        if (!scalar(@{ $SearchData{$SearchAttribute} })) {
            delete $SearchData{$SearchAttribute};
        }
    }

    return %SearchData;
}

sub _GetAssignedSearchDataStatic {
    my ($Self, %Param) = @_;

    for my $SearchStatic ( @{$Param{SearchStatics}} ) {
        next if ( !defined $SearchStatic );
        push ( @{ $Param{SearchData}->{$Param{SearchAttribute}} }, $SearchStatic );
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

        if ( IsArrayRefWithData($Param{SearchData}->{$Param{SearchAttribute}}) ) {
            my %SearchData = map { $_ => 1 } @{ $Param{SearchData}->{$Param{SearchAttribute}} };
            if ( IsArrayRef($Value) ) {
                VALUE:
                for my $Val ( @{$Value} ) {
                    next VALUE if ($SearchData{$Val});
                    push (
                        @{ $Param{SearchData}->{$Param{SearchAttribute}} },
                        $Val
                    );
                }
            }
            elsif ( !$SearchData{$Value} ) {
                push (
                    @{ $Param{SearchData}->{$Param{SearchAttribute}} },
                    $Value
                );
            }
        }
        else {
            push (
                @{ $Param{SearchData}->{$Param{SearchAttribute}} },
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

sub _GetAssignedMapping {
    my ( $Self, %Param ) = @_;

    my $Mapping;
    if ( !$Param{Flags}->{AssignedConfigItemsMapping} ) {
        my $MappingString = $Kernel::OM->Get('Config')->Get('AssignedObjectsMapping') || q{};

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
                    Message  => "Invalid JSON for sysconfig option 'AssignedObjectsMapping'."
                );
            }
        }

        $Param{Flags}->{AssignedObjectsMapping} = $MappingData;
        $Mapping = $MappingData->{$Param{Assigned}}->{FAQArticle} if ( $MappingData->{$Param{Assigned}}->{FAQArticle} );
    }
    else {
        $Mapping = $Param{Flags}->{AssignedObjectsMapping}->{$Param{Assigned}}->{FAQArticle} || q{};
    }

    return $Mapping;
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
