# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::ITSMConfigItem::XML::Type::CIClassReference;

use strict;
use warnings;

our @ObjectDependencies = qw(
    Config
    GeneralCatalog
    ITSMConfigItem
    Log
    ObjectSearch
);

=head1 NAME

Kernel::System::ITSMConfigItem::XML::Type::CIClassReference - xml backend module

=head1 SYNOPSIS

All xml functions of CIClassReference objects

=over 4

=cut

=item new()

create an object

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $BackendObject = $Kernel::OM->Get('ITSMConfigItem::XML::Type::CIClassReference');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

=item ValueLookup()

get the xml data of a version

    my $Value = $BackendObject->ValueLookup(
        Value => 11, # (optional)
    );

=cut

sub ValueLookup {
    my ( $Self, %Param ) = @_;

    # return empty string, when false value (undef, 0, empty string) is given
    return q{} if ( !$Param{Value} );

    # return given value, if given value is not a number
    return $Param{Value} if ( $Param{Value} =~ /\D/ );

    # get current version of given config item
    my $CIVersionDataRef = $Kernel::OM->Get('ITSMConfigItem')->VersionGet(
        ConfigItemID => $Param{Value},
        XMLDataGet   => 0,
        Silent       => 1,
    );

    # init result variable with given value
    my $CIName = $Param{Value};

    # set result with name and number if available in data
    if (
        ref( $CIVersionDataRef ) eq 'HASH'
        && $CIVersionDataRef->{Name}
    ) {
        $CIName = $CIVersionDataRef->{Name}
            . " ("
            . $CIVersionDataRef->{Number}
            . ")";
    }

    return $CIName;
}

=item ExportSearchValuePrepare()

prepare search value for export

    my $ArrayRef = $BackendObject->ExportSearchValuePrepare(
        Value => 11, # (optional)
    );

=cut

sub ExportSearchValuePrepare {
    my ( $Self, %Param ) = @_;

    return if !defined $Param{Value};
    return $Param{Value};
}

=item ExportValuePrepare()

prepare value for export

    my $Value = $BackendObject->ExportValuePrepare(
        Value => 11, # (optional)
    );

=cut

sub ExportValuePrepare {
    my ( $Self, %Param ) = @_;

    # return undefined value if given value is undefined
    return if !defined $Param{Value};

    # return empty string if given value is false (empty string, or 0)
    return q{} if !$Param{Value};

    # return empty string, if given value is not a number
    return q{} if ( $Param{Value} =~ /\D/ );

    my $SearchAttr = $Param{Item}->{Input}->{ReferencedCIClassReferenceAttributeKey} || q{};

    # check if special attribut should be used for export
    if ($SearchAttr) {
        # get current version data including xml data
        my $VersionData = $Kernel::OM->Get('ITSMConfigItem')->VersionGet(
            ConfigItemID => $Param{Value},
            XMLDataGet   => 1,
            Silent       => 1,
        );

        if ( ref( $VersionData ) eq 'HASH' ) {
            # return name of referenced asset if ReferencedCIClassReferenceAttributeKey is 'Name'
            return $VersionData->{Name} if ( $SearchAttr eq 'Name' );

            # get current definition of the asset class
            my $XMLDefinition = $Kernel::OM->Get('ITSMConfigItem')->DefinitionGet(
                ClassID => $VersionData->{ClassID},
            );

            # get export value from xml data with current definition
            my $ArrRef = $Kernel::OM->Get('ITSMConfigItem')->GetAttributeValuesByKey(
                KeyName       => $SearchAttr,
                XMLData       => $VersionData->{XMLData}->[1]->{Version}->[1],
                XMLDefinition => $XMLDefinition->{DefinitionRef},
            );

            # return first value if set
            if (
                ref( $ArrRef ) eq 'ARRAY'
                && $ArrRef->[0]
            ) {
                return $ArrRef->[0];
            }
        }
    }

    # lookup CI number for given CI ID
    my $ConfigItemNumber = $Kernel::OM->Get('ITSMConfigItem')->ConfigItemLookup(
        ConfigItemID => $Param{Value},
    );

    return $ConfigItemNumber || q{};
}

=item ImportSearchValuePrepare()

prepare search value for import

    my $ArrayRef = $BackendObject->ImportSearchValuePrepare(
        Value => 11, # (optional)
    );

=cut

sub ImportSearchValuePrepare {
    my ( $Self, %Param ) = @_;

    # return undefined value if given value is undefined
    return if !defined $Param{Value};

    # return empty string if given value is false (empty string, or 0)
    return q{} if !$Param{Value};

    my $SearchAttr    = $Param{Item}->{Input}->{ReferencedCIClassReferenceAttributeKey} || q{};
    my $SearchClasses = $Param{Item}->{Input}->{ReferencedCIClassName} || q{};

    # make CI-Number out of given value
    if (
        $SearchAttr
        && $SearchClasses
    ) {
        # get array of relevant class names
        my @CIClassNames;
        if ( ref( $SearchClasses ) eq 'ARRAY' ) {
            @CIClassNames = @{ $SearchClasses };
        }
        else {
            @CIClassNames = ( $SearchClasses );
        }

        # process classes
        CLASS:
        for my $ClassName ( @CIClassNames ) {
            next CLASS if ( !$ClassName );

            # get class id
            my $ItemDataRef = $Kernel::OM->Get('GeneralCatalog')->ItemGet(
                Class  => 'ITSM::ConfigItem::Class',
                Name   => $ClassName,
                Silent => 1,
            );
            if (
                ref($ItemDataRef) ne 'HASH'
                || !$ItemDataRef->{ItemID}
            ) {
                next CLASS;
            }
            my $ClassID = $ItemDataRef->{ItemID};

            # search for name if ReferencedCIClassReferenceAttributeKey is 'Name'
            if ( $SearchAttr eq 'Name' ) {
                my @ConfigItemIDs = $Kernel::OM->Get('ObjectSearch')->Search(
                    ObjectType => 'ConfigItem',
                    Result     => 'ARRAY',
                    Search     => {
                        AND => [
                            {
                                Field    => 'Name',
                                Operator => 'EQ',
                                Type     => 'STRING',
                                Value    => $Param{Value}
                            },
                            {
                                Field    => 'ClassID',
                                Operator => 'IN',
                                Type     => 'NUMERIC',
                                Value    => [$ClassID]
                            }
                        ]
                    },
                    Sort => [
                        {
                            Field     => 'Number',
                            Direction => 'ASCENDING'
                        }
                    ],
                    Limit      => 1,
                    UserID     => 1,
                    UsertType  => 'Agent'
                );

                # return config item id if found
                if (
                    @ConfigItemIDs
                    && $ConfigItemIDs[0]
                ) {
                    return $ConfigItemIDs[0];
                }
            }
            # search for xml attribute
            else {
                # get current definition of the asset class
                my $XMLDefinition = $Kernel::OM->Get('ITSMConfigItem')->DefinitionGet(
                    ClassID => $ClassID,
                );

                # prepare search params
                my %SearchData   = (
                    $SearchAttr => $Param{Value},
                );
                my @SearchParams;
                $Self->_XMLSearchDataPrepare(
                    XMLDefinition => $XMLDefinition->{DefinitionRef},
                    What          => \@SearchParams,
                    SearchData    => \%SearchData,
                    Prefix        => q{},
                );

                # only search if parameter is prepared
                if ( @SearchParams ) {

                    # add class to search in
                    push (
                        @SearchParams,
                        {
                            Field    => 'ClassID',
                            Operator => 'IN',
                            Type     => 'NUMERIC',
                            Value    => [$ClassID]
                        }
                    );

                    # search the config items
                    my @ConfigItemIDs = $Kernel::OM->Get('ObjectSearch')->Search(
                        ObjectType => 'ConfigItem',
                        Result     => 'ARRAY',
                        Search     => {
                            AND => \@SearchParams
                        },
                        Sort => [
                            {
                                Field     => 'Number',
                                Direction => 'ASCENDING'
                            }
                        ],
                        Limit      => 1,
                        UserID     => 1,
                        UsertType  => 'Agent'
                    );

                    # return config item id if found
                    if (
                        @ConfigItemIDs
                        && $ConfigItemIDs[0]
                    ) {
                        return $ConfigItemIDs[0];
                    }
                }
            }
        }
    }

    # if given value begins with asset hook, lookup as asset number
    my $Hook = $Kernel::OM->Get('Config')->Get('ITSMConfigItem::Hook');
    if (
        $Hook
        && $Param{Value} =~ m/^$Hook(.+)$/
    ) {
        my $ConfigItemNumber = $1;

        my $ConfigItemID = $Kernel::OM->Get('ITSMConfigItem')->ConfigItemLookup(
            ConfigItemNumber => $ConfigItemNumber,
        );

        return $ConfigItemID if ( $ConfigItemID );
    }

    # check if given value is asset number
    my $ConfigItemID = $Kernel::OM->Get('ITSMConfigItem')->ConfigItemLookup(
        ConfigItemNumber => $Param{Value},
    );
    return $ConfigItemID if $ConfigItemID;

    # if given value is an number, check if it is an ID
    if ( $Param{Value} !~ /\D/ ) {
        my $ConfigItemNumber = $Kernel::OM->Get('ITSMConfigItem')->ConfigItemLookup(
            ConfigItemID => $Param{Value},
        );
        return $Param{Value} if ( $ConfigItemNumber );
    }

    # check if given value is name of an asset in relevant classes
    if (
        $SearchClasses
        && (
            !$SearchAttr
            || $SearchAttr ne 'Name'
        )
    ) {

        # get array of relevant class names
        my @CIClassNames;
        if ( ref( $SearchClasses ) eq 'ARRAY' ) {
            @CIClassNames = @{ $SearchClasses };
        }
        else {
            @CIClassNames = ( $SearchClasses );
        }

        # prepare class ids for search
        my @SearchClassIDs;
        CLASS:
        for my $ClassName ( @CIClassNames ) {
            next CLASS if ( !$ClassName );

            # get class id
            my $ItemDataRef = $Kernel::OM->Get('GeneralCatalog')->ItemGet(
                Class  => 'ITSM::ConfigItem::Class',
                Name   => $ClassName,
                Silent => 1,
            );
            if (
                ref( $ItemDataRef ) ne 'HASH'
                || !$ItemDataRef->{ItemID}
            ) {
                next CLASS;
            }
            my $ClassID = $ItemDataRef->{ItemID};

            my @ConfigItemIDs = $Kernel::OM->Get('ObjectSearch')->Search(
                ObjectType => 'ConfigItem',
                Result     => 'ARRAY',
                Search     => {
                    AND => [
                        {
                            Field    => 'Name',
                            Operator => 'EQ',
                            Type     => 'STRING',
                            Value    => $Param{Value}
                        },
                        {
                            Field    => 'ClassID',
                            Operator => 'IN',
                            Type     => 'NUMERIC',
                            Value    => [$ClassID]
                        }
                    ]
                },
                Sort => [
                    {
                        Field     => 'Number',
                        Direction => 'ASCENDING'
                    }
                ],
                Limit      => 1,
                UserID     => 1,
                UsertType  => 'Agent'
            );

            # return config item id if found
            if (
                @ConfigItemIDs
                && $ConfigItemIDs[0]
            ) {
                return $ConfigItemIDs[0];
            }
        }
    }

    return;
}

=item ImportValuePrepare()

prepare value for import

    my $Value = $BackendObject->ImportValuePrepare(
        Value => 11, # (optional)
    );

=cut

sub ImportValuePrepare {
    my ( $Self, %Param ) = @_;

    # return undefined value if given value is undefined
    return if !defined $Param{Value};

    # return empty string if given value is false (empty string, or 0)
    return q{} if !$Param{Value};

    my $SearchAttr    = $Param{Item}->{Input}->{ReferencedCIClassReferenceAttributeKey} || q{};
    my $SearchClasses = $Param{Item}->{Input}->{ReferencedCIClassName} || q{};

    # make CI-Number out of given value
    if (
        $SearchAttr
        && $SearchClasses
    ) {
        # get array of relevant class names
        my @CIClassNames;
        if ( ref( $SearchClasses ) eq 'ARRAY' ) {
            @CIClassNames = @{ $SearchClasses };
        }
        else {
            @CIClassNames = ( $SearchClasses );
        }

        # process classes
        CLASS:
        for my $ClassName ( @CIClassNames ) {
            next CLASS if ( !$ClassName );

            # get class id
            my $ItemDataRef = $Kernel::OM->Get('GeneralCatalog')->ItemGet(
                Class  => 'ITSM::ConfigItem::Class',
                Name   => $ClassName,
                Silent => 1,
            );
            if (
                ref($ItemDataRef) ne 'HASH'
                || !$ItemDataRef->{ItemID}
            ) {
                next CLASS;
            }
            my $ClassID = $ItemDataRef->{ItemID};

            # search for name if ReferencedCIClassReferenceAttributeKey is 'Name'
            if ( $SearchAttr eq 'Name' ) {
                my @ConfigItemIDs = $Kernel::OM->Get('ObjectSearch')->Search(
                    ObjectType => 'ConfigItem',
                    Result     => 'ARRAY',
                    Search     => {
                        AND => [
                            {
                                Field    => 'Name',
                                Operator => 'EQ',
                                Type     => 'STRING',
                                Value    => $Param{Value}
                            },
                            {
                                Field    => 'ClassID',
                                Operator => 'IN',
                                Type     => 'NUMERIC',
                                Value    => [$ClassID]
                            }
                        ]
                    },
                    Sort => [
                        {
                            Field     => 'Number',
                            Direction => 'ASCENDING'
                        }
                    ],
                    Limit      => 1,
                    UserID     => 1,
                    UsertType  => 'Agent'
                );

                # return config item id if found
                if (
                    @ConfigItemIDs
                    && $ConfigItemIDs[0]
                ) {
                    return $ConfigItemIDs[0];
                }
            }
            # search for xml attribute
            else {
                # get current definition of the asset class
                my $XMLDefinition = $Kernel::OM->Get('ITSMConfigItem')->DefinitionGet(
                    ClassID => $ClassID,
                );

                # prepare search params
                my %SearchData   = (
                    $SearchAttr => $Param{Value},
                );
                my @SearchParams;
                $Self->_XMLSearchDataPrepare(
                    XMLDefinition => $XMLDefinition->{DefinitionRef},
                    What          => \@SearchParams,
                    SearchData    => \%SearchData,
                    Prefix        => q{},
                );

                # only search if parameter is prepared
                if ( @SearchParams ) {
                    # add class to search in
                    push (
                        @SearchParams,
                        {
                            Field    => 'ClassID',
                            Operator => 'IN',
                            Type     => 'NUMERIC',
                            Value    => [$ClassID]
                        }
                    );
                    # search the config items
                    my @ConfigItemIDs = $Kernel::OM->Get('ObjectSearch')->Search(
                        ObjectType => 'ConfigItem',
                        Result     => 'ARRAY',
                        Search     => {
                            AND => \@SearchParams
                        },
                        Sort => [
                            {
                                Field     => 'Number',
                                Direction => 'ASCENDING'
                            }
                        ],
                        Limit      => 1,
                        UserID     => 1,
                        UsertType  => 'Agent'
                    );

                    # return config item id if found
                    if (
                        @ConfigItemIDs
                        && $ConfigItemIDs[0]
                    ) {
                        return $ConfigItemIDs[0];
                    }
                }
            }
        }
    }

    # if given value begins with asset hook, lookup as asset number
    my $Hook = $Kernel::OM->Get('Config')->Get('ITSMConfigItem::Hook');
    if (
        $Hook
        && $Param{Value} =~ m/^$Hook(.+)$/
    ) {
        my $ConfigItemNumber = $1;

        my $ConfigItemID = $Kernel::OM->Get('ITSMConfigItem')->ConfigItemLookup(
            ConfigItemNumber => $ConfigItemNumber,
        );

        return $ConfigItemID if ( $ConfigItemID );
    }

    # check if given value is asset number
    my $ConfigItemID = $Kernel::OM->Get('ITSMConfigItem')->ConfigItemLookup(
        ConfigItemNumber => $Param{Value},
    );
    return $ConfigItemID if $ConfigItemID;

    # if given value is an number, check if it is an ID
    if ( $Param{Value} !~ /\D/ ) {
        my $ConfigItemNumber = $Kernel::OM->Get('ITSMConfigItem')->ConfigItemLookup(
            ConfigItemID => $Param{Value},
        );
        return $Param{Value} if ( $ConfigItemNumber );
    }

    # check if given value is name of an asset in relevant classes
    if (
        $SearchClasses
        && (
            !$SearchAttr
            || $SearchAttr ne 'Name'
        )
    ) {
        # get array of relevant class names
        my @CIClassNames;
        if ( ref( $SearchClasses ) eq 'ARRAY' ) {
            @CIClassNames = @{ $SearchClasses };
        }
        else {
            @CIClassNames = ( $SearchClasses );
        }

        # prepare class ids for search
        my @SearchClassIDs;
        CLASS:
        for my $ClassName ( @CIClassNames ) {
            next CLASS if ( !$ClassName );

            # get class id
            my $ItemDataRef = $Kernel::OM->Get('GeneralCatalog')->ItemGet(
                Class  => 'ITSM::ConfigItem::Class',
                Name   => $ClassName,
                Silent => 1,
            );
            if (
                ref( $ItemDataRef ) ne 'HASH'
                || !$ItemDataRef->{ItemID}
            ) {
                next CLASS;
            }
            my $ClassID = $ItemDataRef->{ItemID};

            my @ConfigItemIDs = $Kernel::OM->Get('ObjectSearch')->Search(
                ObjectType => 'ConfigItem',
                Result     => 'ARRAY',
                Search     => {
                    AND => [
                        {
                            Field    => 'Name',
                            Operator => 'EQ',
                            Type     => 'STRING',
                            Value    => $Param{Value}
                        },
                        {
                            Field    => 'ClassID',
                            Operator => 'IN',
                            Type     => 'NUMERIC',
                            Value    => [$ClassID]
                        }
                    ]
                },
                Sort => [
                    {
                        Field     => 'Number',
                        Direction => 'ASCENDING'
                    }
                ],
                Limit      => 1,
                UserID     => 1,
                UsertType  => 'Agent'
            );

            # return config item id if found
            if (
                @ConfigItemIDs
                && $ConfigItemIDs[0]
            ) {
                return $ConfigItemIDs[0];
            }
        }
    }

    return;
}

sub _XMLSearchDataPrepare {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    return if (
        ref( $Param{XMLDefinition} ) ne 'ARRAY'
        || ref( $Param{What} ) ne 'ARRAY'
        || ref( $Param{SearchData} ) ne 'HASH'
        || !defined( $Param{Prefix} )
    );

    # process definition
    ITEM:
    for my $Item ( @{ $Param{XMLDefinition} } ) {
        # combine prefix with current key
        my $CombinedKey;
        if ( $Param{Prefix} ) {
            $CombinedKey = $Param{Prefix} . q{::} . $Item->{Key};
        }
        else {
            $CombinedKey = $Item->{Key};
        }

        # check for relevant search value
        if ( $Param{SearchData}->{ $Item->{Key} } ) {
            # prepare search key
            my $SearchKey = $CombinedKey;
            $SearchKey = 'CurrentVersion.Data.' . $SearchKey;
            $SearchKey =~ s/::/./gsm;

            # push search hash to What parameter
            push (
                @{ $Param{What} },
                {
                    Field    => $SearchKey,
                    Operator => 'EQ',
                    Type     => 'STRING',
                    Value    => $Param{SearchData}->{$Item->{Key}}
                }
            );
        }
        next ITEM if( !$Item->{Sub} );

        # start recursion, if "Sub" was found
        $Self->_XMLSearchDataPrepare(
            XMLDefinition => $Item->{Sub},
            What          => $Param{What},
            SearchData    => $Param{SearchData},
            Prefix        => $CombinedKey,
        );
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
