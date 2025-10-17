# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

use strict;
use warnings;
use utf8;

use vars (qw($Self));

# This unit test checks whether the fix for KIX2018-14824 is still available.

# get helper object
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

# get objectsearch object
my $ObjectSearch = $Kernel::OM->Get('ObjectSearch');

# begin transaction on database
$Helper->BeginWork();

# load translations for given language
my @Translations = $Kernel::OM->Get('Translation')->TranslationList();
my %TranslationsDE;
for my $Translation ( @Translations ) {
    $TranslationsDE{ $Translation->{Pattern} } = $Translation->{Languages}->{'de'};
}

# prepare class mapping
my $ClassRef = $Kernel::OM->Get('GeneralCatalog')->ItemGet(
    Class         => 'ITSM::ConfigItem::Class',
    Name          => 'Computer',
    NoPreferences => 1
);

# prepare depl state mapping
my @DeplStates;
for my $Key ( qw(Production Pilot Planned Retired) ) {
    my $ItemDataRef = $Kernel::OM->Get('GeneralCatalog')->ItemGet(
        Class         => 'ITSM::ConfigItem::DeploymentState',
        Name          => $Key,
        NoPreferences => 1
    );

    push(
        @DeplStates,
        {
            ItemID => $ItemDataRef->{ItemID},
            Name   => $ItemDataRef->{Name}
        }
    );

    $Self->True(
        $ItemDataRef->{ItemID},
        "DeplState $Key has a id"
    );
    $Self->Is(
        $ItemDataRef->{Name},
        $Key,
        "DeplState $Key has expected name"
    );
}

my @InciStates;
for my $Key ( qw(Operational Warning Incident) ) {
    my $ItemDataRef = $Kernel::OM->Get('GeneralCatalog')->ItemGet(
        Class         => 'ITSM::Core::IncidentState',
        Name          => $Key,
        NoPreferences => 1
    );

    push(
        @InciStates,
        {
            ItemID => $ItemDataRef->{ItemID},
            Name   => $ItemDataRef->{Name}
        }
    );

    $Self->True(
        $ItemDataRef->{ItemID},
        "InciState $Key has a id"
    );
    $Self->Is(
        $ItemDataRef->{Name},
        $Key,
        "InciState $Key has expected name"
    );
}

## prepare test assets ##
my @ConfigItemIDs;
for my $Index ( 0...3 ) {

    my $ConfigItemID = $Kernel::OM->Get('ITSMConfigItem')->ConfigItemAdd(
        ClassID => $ClassRef->{ItemID},
        UserID  => 1,
    );
    $Self->True(
        $ConfigItemID,
        'Created #' . ($Index+1) . ' asset'
    );

    push ( @ConfigItemIDs, $ConfigItemID );

    my $VersionID = $Kernel::OM->Get('ITSMConfigItem')->VersionAdd(
        ConfigItemID => $ConfigItemID,
        Name         => $Helper->GetRandomID(),
        DefinitionID => 1,
        DeplStateID  => $DeplStates[$Index]->{ItemID},
        InciStateID  => $InciStates[$Index]->{ItemID} || $InciStates[$Index-1]->{ItemID},
        UserID       => 1,
    );

    $Self->True(
        $VersionID,
        'Created version for #' . ($Index+1) . ' asset'
    );
}

# discard config item object to process events
$Kernel::OM->ObjectsDiscard(
    Objects => ['ITSMConfigItem'],
);

# test Search
my @IntegrationSearchTests = (
    {
        Name     => 'Search: Class EQ Computer AND DeplState IN [Production, Pilot, Planned]',
        Search   => {
            'AND' => [
                {
                    Field    => 'Class',
                    Operator => 'EQ',
                    Value    => 'Computer'
                },
                {
                    Field    => 'DeplState',
                    Operator => 'IN',
                    Value    => [$DeplStates[0]->{Name},$DeplStates[1]->{Name},$DeplStates[2]->{Name}]
                }
            ]
        },
        Expected => [
            $ConfigItemIDs[0],
            $ConfigItemIDs[1],
            $ConfigItemIDs[2]
        ]
    },
    {
        Name     => 'Search: Class EQ Computer AND DeplState IN [Retired]',
        Search   => {
            'AND' => [
                {
                    Field    => 'Class',
                    Operator => 'EQ',
                    Value    => 'Computer'
                },
                {
                    Field    => 'DeplState',
                    Operator => 'IN',
                    Value    => [$DeplStates[3]->{Name}]
                }
            ]
        },
        Expected => [$ConfigItemIDs[3]]
    },
    {
        Name     => 'Search: Class EQ Computer AND InciState IN [Operational, Warning]',
        Search   => {
            'AND' => [
                {
                    Field    => 'Class',
                    Operator => 'EQ',
                    Value    => 'Computer'
                },
                {
                    Field    => 'InciState',
                    Operator => 'IN',
                    Value    => [$InciStates[0]->{Name},$InciStates[1]->{Name}]
                }
            ]
        },
        Expected => [
            $ConfigItemIDs[0],
            $ConfigItemIDs[1]
        ]
    },
    {
        Name     => 'Search: Class EQ Computer AND InciState IN [Incident]',
        Search   => {
            'AND' => [
                {
                    Field    => 'Class',
                    Operator => 'EQ',
                    Value    => 'Computer'
                },
                {
                    Field    => 'InciState',
                    Operator => 'IN',
                    Value    => [$InciStates[2]->{Name}]
                }
            ]
        },
        Expected => [
            $ConfigItemIDs[2],
            $ConfigItemIDs[3]
        ]
    }
);
for my $Test ( @IntegrationSearchTests ) {
    my @Result = $ObjectSearch->Search(
        ObjectType => 'ConfigItem',
        Result     => 'ARRAY',
        Search     => $Test->{Search},
        UserType   => 'Agent',
        UserID     => 1,
    );
    $Self->IsDeeply(
        \@Result,
        $Test->{Expected},
        $Test->{Name}
    );
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
