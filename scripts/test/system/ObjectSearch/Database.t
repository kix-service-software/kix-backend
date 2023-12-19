# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

use strict;
use warnings;
use utf8;

use vars (qw($Self));

# get helper object
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

# discard current object search object
$Kernel::OM->ObjectsDiscard(
    Objects => ['ObjectSearch'],
);

# make sure config 'ObjectSearch::Backend' is set to Module 'ObjectSearch::Database'
$Kernel::OM->Get('Config')->Set(
    Key   => 'ObjectSearch::Backend',
    Value => {
        Module => 'ObjectSearch::Database',
    }
);

# get objectsearch object
my $ObjectSearch = $Kernel::OM->Get('ObjectSearch');

# check for correct backend module
my $BackendModule = $Kernel::OM->GetModuleFor('ObjectSearch::Database') || 'Kernel::System::ObjectSearch::Database';
$Self->Is(
    ref( $ObjectSearch->{Backend} ),
    $BackendModule,
    'Backend has correct module ref'
);

# get registered object types for backend database
my $RegisteredObjectTypes = $Kernel::OM->Get('Config')->Get('ObjectSearch::Database::ObjectType') || {};

# check NormalizedObjectType
for my $ObjectType ( sort( keys( %{ $RegisteredObjectTypes } ) ) ) {
    my $ObjectTypeNormalResult = $ObjectSearch->{Backend}->NormalizedObjectType(
        ObjectType => $ObjectType
    );
    $Self->Is(
        $ObjectTypeNormalResult,
        $ObjectType,
        'NormalizedObjectType provides expected string given correct name "' . $ObjectType . '"'
    );

    my $ObjectTypeLowerResult = $ObjectSearch->{Backend}->NormalizedObjectType(
        ObjectType => lc( $ObjectType )
    );
    $Self->Is(
        $ObjectTypeLowerResult,
        $ObjectType,
        'NormalizedObjectType provides expected string given lower case name "' . lc( $ObjectType ) . '"'
    );

    my $ObjectTypeUpperResult = $ObjectSearch->{Backend}->NormalizedObjectType(
        ObjectType => uc( $ObjectType )
    );
    $Self->Is(
        $ObjectTypeUpperResult,
        $ObjectType,
        'NormalizedObjectType provides expected string given upper case name "' . uc( $ObjectType ) . '"'
    );

    my $RandomCaseObjectType = $Helper->GetRandomCaseString(
        String => $ObjectType
    );
    my $ObjectTypeRandomResult = $ObjectSearch->{Backend}->NormalizedObjectType(
        ObjectType => $RandomCaseObjectType
    );
    $Self->Is(
        $ObjectTypeRandomResult,
        $ObjectType,
        'NormalizedObjectType provides expected string given random case name "' . $RandomCaseObjectType . '"'
    );
}

my $RandomObjectType = $Helper->GetRandomID();
my $ObjectTypeUnknownResult = $ObjectSearch->{Backend}->NormalizedObjectType(
    ObjectType => $RandomObjectType
);
$Self->Is(
    $ObjectTypeUnknownResult,
    undef,
    'NormalizedObjectType provides undef given random string "' . $RandomObjectType . '"'
);

# begin transaction on database
$Helper->BeginWork();

# process registered object types for backend database
for my $ObjectType ( sort( keys( %{ $RegisteredObjectTypes } ) ) ) {
    my $SupportedAttributes = $ObjectSearch->GetSupportedAttributes(
        ObjectType => $ObjectType
    );
    $Self->Is(
        defined( $SupportedAttributes ),
        '1',
        'ObjectSearch > GetSupportedAttributes: ObjectType ' . $ObjectType . ' (defined)'
    );
    $Self->Is(
        ref( $SupportedAttributes ),
        'ARRAY',
        'ObjectSearch > GetSupportedAttributes: ObjectType ' . $ObjectType . ' (ref)'
    );

    for my $Entry ( @{ $SupportedAttributes } ) {
        $Self->True(
            (
                ref( $Entry ) eq 'HASH'
                && defined( $Entry->{ObjectType} )
                && ref( $Entry->{ObjectType} ) eq ''
                && $Entry->{ObjectType} eq $ObjectType
                && defined( $Entry->{Property} )
                && ref( $Entry->{Property} ) eq ''
                && $Entry->{Property}
                && defined( $Entry->{IsSearchable} )
                && ref( $Entry->{IsSearchable} ) eq ''
                && defined( $Entry->{IsSortable} )
                && ref( $Entry->{IsSortable} ) eq ''
                && defined( $Entry->{Operators} )
                && ref( $Entry->{Operators} ) eq 'ARRAY'
                && defined( $Entry->{ValueType} )
                && ref( $Entry->{ValueType} ) eq ''
            ),
            'ObjectSearch > GetSupportedAttributes: ObjectType ' . $ObjectType . ' / Property ' . ($Entry->{Property} || '') . ' (expected structure)'
        );

        if ( $Entry->{IsSearchable} ) {
            $Self->True(
                scalar( @{ $Entry->{Operators} } ),
                'ObjectSearch > GetSupportedAttributes: ObjectType ' . $ObjectType . ' / Property ' . ($Entry->{Property} || '') . ' IsSearchable and has Operators'
            );

            for my $Operator ( @{ $Entry->{Operators} } ) {
                my $SearchValue;
                if ( $Entry->{ValueType} eq 'NUMERIC' ) {
                    $SearchValue = 1;
                }
                elsif ( $Entry->{ValueType} eq 'DATE' ) {
                    $SearchValue = '1990-01-01';
                }
                elsif ( $Entry->{ValueType} eq 'DATETIME' ) {
                    $SearchValue = '1990-01-01 00:00:00';
                }
                else {
                    $SearchValue = 'Test';
                }

                my $Result = $ObjectSearch->Search(
                    ObjectType => $ObjectType,
                    UserID     => 1,
                    Search     => {
                        AND => [
                            {
                                Field    => $Entry->{Property},
                                Operator => $Operator,
                                Value    => $Operator =~ m/^[!]?IN$/ ? [ $SearchValue ] : $SearchValue
                            }
                        ]
                    }
                );
                $Self->Is(
                    defined( $Result ),
                    '1',
                    'ObjectSearch > Search: ObjectType ' . $ObjectType . ' / Property ' . ($Entry->{Property} || '') . ' IsSearchable / Operator ' . $Operator
                );

                if ( $Operator =~ m/^[!]?IN$/ ) {

                    $Result = $ObjectSearch->Search(
                        ObjectType => $ObjectType,
                        UserID     => 1,
                        Search     => {
                            AND => [
                                {
                                    Field    => $Entry->{Property},
                                    Operator => $Operator,
                                    Value    => []
                                }
                            ]
                        }
                    );
                    $Self->Is(
                        defined( $Result ),
                        '1',
                        'ObjectSearch > Search: ObjectType ' . $ObjectType . ' / Property ' . ($Entry->{Property} || '') . ' IsSearchable / Operator ' . $Operator . ' / empty value array'
                    );
                }
            }
        }

        if ( $Entry->{IsSortable} ) {
            my $Result = $ObjectSearch->Search(
                ObjectType => $ObjectType,
                UserID     => 1,
                Sort       => [
                    {
                        Field => $Entry->{Property},
                    }
                ]
            );
            $Self->Is(
                defined( $Result ),
                '1',
                'ObjectSearch > Search: ObjectType ' . $ObjectType . ' / Property ' . ($Entry->{Property} || '') . ' IsSortable'
            );
        }
    }
}

# rollback transaction on database
$Helper->Rollback();

1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
