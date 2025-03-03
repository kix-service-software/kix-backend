# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

use strict;
use warnings;
use utf8;

use vars (qw($Self));

# get helper object
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

# begin transaction on database
$Helper->BeginWork();

# create organisation
my $OrgaID  = _CreateOrganisation(
    NumberPrefix => 1,
    Pattern      => [
        'main.*.com',
        '*.org',
        'test.net'
    ]
);

my $OrgaID2 = _CreateOrganisation(
    NumberPrefix => 2,
    Pattern      => [
        '*.example.com',
        '*.de',
        '*.org'
    ]
);

my @Contacts;
for ( 0..6  ) {
    push ( @Contacts, $Helper->GetRandomID());
}

my @Tests = (
    {
        Number => '#01 ',
        Name   => 'Create Contact: without organisation',
        Type   => 'Create',
        Config => {
            'Contact::EventModulePost###800-AutoAssignOrganisation' => {
                Module         => 'Kernel::System::Contact::Event::AutoAssignOrganisation',
                Event          => '(ContactAdd|ContactUpdate)',
                MappingMethods => [
                    {
                        Active => 0,
                        Method => 'MailDomain'
                    },
                    {
                        Active              => 0,
                        Method              => 'DefaultOrganisation',
                        DefaultOrganisation => ''
                    },
                    {
                        Active => 0,
                        Method => 'PersonalOrganisation'
                    }
                ]
            }
        },
        Setting => {
            Contact => $Contacts[0]
        },
        Result => {
            PrimaryOrganisationID => undef
        }
    },
    {
        Number => '#02 ',
        Name   => 'Update Contact: enable method "MailDomain" (no organisation is set)',
        Type   => 'Update',
        Setting => {
            Contact => $Contacts[0],
            Email   => 'text@example.com'
        },
        Config => {
            'Contact::EventModulePost###800-AutoAssignOrganisation' => {
                Module         => 'Kernel::System::Contact::Event::AutoAssignOrganisation',
                Event          => '(ContactAdd|ContactUpdate)',
                MappingMethods => [
                    {
                        Active => 1,
                        Method => 'MailDomain'
                    },
                    {
                        Active              => 0,
                        Method              => 'DefaultOrganisation',
                        DefaultOrganisation => ''
                    },
                    {
                        Active => 0,
                        Method => 'PersonalOrganisation'
                    }
                ]
            }
        },
        Result => {
            PrimaryOrganisationID => undef
        },
        Silent => 1
    },
    {
        Number => '#03 ',
        Name   => 'Update Contact: enable method "MailDomain" (organisation is set)',
        Type   => 'Update',
        Config => {
            'Contact::EventModulePost###800-AutoAssignOrganisation' => {
                Module         => 'Kernel::System::Contact::Event::AutoAssignOrganisation',
                Event          => '(ContactAdd|ContactUpdate)',
                MappingMethods => [
                    {
                        Active => 1,
                        Method => 'MailDomain'
                    },
                    {
                        Active              => 0,
                        Method              => 'DefaultOrganisation',
                        DefaultOrganisation => ''
                    },
                    {
                        Active => 0,
                        Method => 'PersonalOrganisation'
                    }
                ]
            }
        },
        Setting => {
            Contact => $Contacts[0],
            Email => 'text@test.example.com'
        },
        Result => {
            PrimaryOrganisationID => $OrgaID2->{ID},
        }
    },
    {
        Number => '#04 ',
        Name   => 'Create Contact: enable method "MailDomain" (multiple organisations are set)',
        Type   => 'Create',
        Config => {
            'Contact::EventModulePost###800-AutoAssignOrganisation' => {
                Module         => 'Kernel::System::Contact::Event::AutoAssignOrganisation',
                Event          => '(ContactAdd|ContactUpdate)',
                MappingMethods => [
                    {
                        Active => 1,
                        Method => 'MailDomain'
                    },
                    {
                        Active              => 0,
                        Method              => 'DefaultOrganisation',
                        DefaultOrganisation => ''
                    },
                    {
                        Active => 0,
                        Method => 'PersonalOrganisation'
                    }
                ]
            }
        },
        Setting => {
            Contact => $Contacts[5],
            Email => 'text@example.org'
        },
        Result => {
            PrimaryOrganisationID => $OrgaID->{ID},
            OrganisationIDs       => [
                $OrgaID->{ID},
                $OrgaID2->{ID}
            ]
        }
    },
    {
        Number => '#05 ',
        Name   => 'Create Contact: enable method "MailDomain" and "Personal" (organisation is set)',
        Type   => 'Create',
        Config => {
            'Contact::EventModulePost###800-AutoAssignOrganisation' => {
                Module         => 'Kernel::System::Contact::Event::AutoAssignOrganisation',
                Event          => '(ContactAdd|ContactUpdate)',
                MappingMethods => [
                    {
                        Active => 1,
                        Method => 'MailDomain'
                    },
                    {
                        Active              => 0,
                        Method              => 'DefaultOrganisation',
                        DefaultOrganisation => ''
                    },
                    {
                        Active => 1,
                        Method => 'PersonalOrganisation'
                    }
                ]
            }
        },
        Setting => {
            Contact => $Contacts[1],
            Email => 'text@example.com'
        },
        Result => {
            PrimaryOrganisationID => 'text@example.com',
        }
    },
    {
        Number => '#06 ',
        Name   => 'Create Contact: disable method "MailDomain" enable method "Default" (no defined default) and "Personal" (organisation is set)',
        Type   => 'Create',
        Config => {
            'Contact::EventModulePost###800-AutoAssignOrganisation' => {
                Module         => 'Kernel::System::Contact::Event::AutoAssignOrganisation',
                Event          => '(ContactAdd|ContactUpdate)',
                MappingMethods => [
                    {
                        Active => 0,
                        Method => 'MailDomain'
                    },
                    {
                        Active              => 1,
                        Method              => 'DefaultOrganisation',
                        DefaultOrganisation => undef
                    },
                    {
                        Active => 1,
                        Method => 'PersonalOrganisation'
                    }
                ]
            }
        },
        Setting => {
            Contact => $Contacts[2],
            Email => 'text2@example.com'
        },
        Result => {
            PrimaryOrganisationID => 'text2@example.com',
        },
        Silent => 1
    },
    {
        Number => '#07 ',
        Name   => 'Create Contact: disable method "Personal","MailDomain" and enable method "Default" and no defined default (no organisation is set)',
        Type   => 'Create',
        Config => {
            'Contact::EventModulePost###800-AutoAssignOrganisation' => {
                Module         => 'Kernel::System::Contact::Event::AutoAssignOrganisation',
                Event          => '(ContactAdd|ContactUpdate)',
                MappingMethods => [
                    {
                        Active => 0,
                        Method => 'MailDomain'
                    },
                    {
                        Active              => 1,
                        Method              => 'DefaultOrganisation',
                        DefaultOrganisation => undef
                    },
                    {
                        Active => 0,
                        Method => 'PersonalOrganisation'
                    }
                ]
            }
        },
        Setting => {
            Contact => $Contacts[3],
            Email => 'text2@test.example.com'
        },
        Result => {
            PrimaryOrganisationID => undef,
        },
        Silent => 1
    },
    {
        Number => '#08 ',
        Name   => 'Update Contact: set default organisation as ID (not exists) for method "Default" (no organisation is set)',
        Type   => 'Update',
        Config => {
            'Contact::EventModulePost###800-AutoAssignOrganisation' => {
                Module         => 'Kernel::System::Contact::Event::AutoAssignOrganisation',
                Event          => '(ContactAdd|ContactUpdate)',
                MappingMethods => [
                    {
                        Active => 0,
                        Method => 'MailDomain'
                    },
                    {
                        Active              => 1,
                        Method              => 'DefaultOrganisation',
                        DefaultOrganisation => $OrgaID->{ID} + 100
                    },
                    {
                        Active => 0,
                        Method => 'PersonalOrganisation'
                    }
                ]
            }
        },
        Setting => {
            Contact => $Contacts[3],
            Comment => 'unit.test'
        },
        Result => {
            PrimaryOrganisationID => undef,
        },
        Silent => 1
    },
    {
        Number => '#09 ',
        Name   => 'Update Contact: set default organisation as Number (not exists) for method "Default" (no organisation is set)',
        Type   => 'Update',
        Config => {
            'Contact::EventModulePost###800-AutoAssignOrganisation' => {
                Module         => 'Kernel::System::Contact::Event::AutoAssignOrganisation',
                Event          => '(ContactAdd|ContactUpdate)',
                MappingMethods => [
                    {
                        Active => 0,
                        Method => 'MailDomain'
                    },
                    {
                        Active              => 1,
                        Method              => 'DefaultOrganisation',
                        DefaultOrganisation => 'UT0815'
                    },
                    {
                        Active => 0,
                        Method => 'PersonalOrganisation'
                    }
                ]
            }
        },
        Setting => {
            Contact => $Contacts[3],
            Comment => 'unit.test2'
        },
        Result => {
            PrimaryOrganisationID => undef,
        },
        Silent => 1
    },
    {
        Number => '#10 ',
        Name   => 'Update Contact: set default organisation as Name (not exists) for method "Default" (no organisation is set)',
        Type   => 'Update',
        Config => {
            'Contact::EventModulePost###800-AutoAssignOrganisation' => {
                Module         => 'Kernel::System::Contact::Event::AutoAssignOrganisation',
                Event          => '(ContactAdd|ContactUpdate)',
                MappingMethods => [
                    {
                        Active => 0,
                        Method => 'MailDomain'
                    },
                    {
                        Active              => 1,
                        Method              => 'DefaultOrganisation',
                        DefaultOrganisation => 'Unit Test GmbH'
                    },
                    {
                        Active => 0,
                        Method => 'PersonalOrganisation'
                    }
                ]
            }
        },
        Setting => {
            Contact => $Contacts[3],
            Comment => 'unit.test3'
        },
        Result => {
            PrimaryOrganisationID => undef,
        },
        Silent => 1
    },
    {
        Number => '#11 ',
        Name   => 'Update Contact: set default organisation as ID (exists) for method "Default" (organisation is set)',
        Type   => 'Update',
        Config => {
            'Contact::EventModulePost###800-AutoAssignOrganisation' => {
                Module         => 'Kernel::System::Contact::Event::AutoAssignOrganisation',
                Event          => '(ContactAdd|ContactUpdate)',
                MappingMethods => [
                    {
                        Active => 0,
                        Method => 'MailDomain'
                    },
                    {
                        Active              => 1,
                        Method              => 'DefaultOrganisation',
                        DefaultOrganisation => $OrgaID->{ID}
                    },
                    {
                        Active => 0,
                        Method => 'PersonalOrganisation'
                    }
                ]
            }
        },
        Setting => {
            Contact => $Contacts[3],
            Comment => 'unit.test4'
        },
        Result => {
            PrimaryOrganisationID => $OrgaID->{ID},
        }
    },
    {
        Number => '#12 ',
        Name   => 'Create Contact: set default organisation as Name (exists) for method "Default" (organisation is set)',
        Type   => 'Create',
        Config => {
            'Contact::EventModulePost###800-AutoAssignOrganisation' => {
                Module         => 'Kernel::System::Contact::Event::AutoAssignOrganisation',
                Event          => '(ContactAdd|ContactUpdate)',
                MappingMethods => [
                    {
                        Active => 0,
                        Method => 'MailDomain'
                    },
                    {
                        Active              => 1,
                        Method              => 'DefaultOrganisation',
                        DefaultOrganisation => $OrgaID2->{Name}
                    },
                    {
                        Active => 0,
                        Method => 'PersonalOrganisation'
                    }
                ]
            }
        },
        Setting => {
            Contact => $Contacts[4],
            Email => 'text4@test.example.com'
        },
        Result => {
            PrimaryOrganisationID => $OrgaID2->{ID},
        }
    },
);

for my $Test ( @Tests ) {

    $Kernel::OM->ObjectsDiscard(
        Objects => [
            'Contact',
            'User'
        ]
    );

    my $Setting = $Test->{Setting} || {};
    my $ContactID;

    if ( !IsHashRefWithData($Setting) ) {
        $Self->Is(
            0,
            $Test->{Number} . ' - No given settings'
        );
        next;
    }

    if ( IsHashRefWithData($Test->{Config}) ) {
        for my $Key ( keys %{$Test->{Config}} ) {
            my $Success = $Kernel::OM->Get('Config')->Set(
                Key   => $Key,
                Value => $Test->{Config}->{$Key},
            );

            $Self->True(
                $Success,
                $Test->{Number} . " - Set config $Key"
            );
        }
    }

    if ( $Test->{Type} eq 'Create' ) {

        # add assigned user
        my $UserID = $Kernel::OM->Get('User')->UserAdd(
            UserLogin    => 'Login_' . $Setting->{Contact},
            ValidID      => 1,
            ChangeUserID => 1,
            IsCustomer   => 1,
            Silent       => $Test->{Silent}
        );
        $Self->True(
            $UserID,
            $Test->{Number} . "- Assigned UserAdd() - $Setting->{Contact}",
        );

        # add contact
        $ContactID = $Kernel::OM->Get('Contact')->ContactAdd(
            AssignedUserID        => $UserID,
            Firstname             => 'Firstname_' . $Setting->{Contact},
            Lastname              => 'Lastname_' . $Setting->{Contact},
            PrimaryOrganisationID => $Setting->{PrimaryOrganisationID},
            Email                 => $Setting->{Email} || 'some-random-' . $Helper->GetRandomID() . '@example.com',
            ValidID               => 1,
            UserID                => 1,
            Silent                => $Test->{Silent}
        );

        $Self->True(
            $ContactID,
            $Test->{Number} . " - ContactAdd() - $Setting->{Contact}",
        );
    }
    elsif ( $Test->{Type} eq 'Update' ) {
        $ContactID = $Kernel::OM->Get('Contact')->ContactLookup(
            UserLogin => 'Login_' . $Setting->{Contact},
            Silent    => $Test->{Silent} // 1
        );

        $Self->True(
            $ContactID,
            $Test->{Number} . "- ContactLookup() - $Setting->{Contact}",
        );

        next if !$ContactID;

        my %Contact = $Kernel::OM->Get('Contact')->ContactGet(
            ID     => $ContactID,
            Silent => $Test->{Silent}
        );

        # add contact
        my $Success = $Kernel::OM->Get('Contact')->ContactUpdate(
            %Contact,
            UserID  => 1,
            Email   => $Setting->{Email} || $Contact{Email},
            Comment => $Setting->{Comment} || $Contact{Comment},
            ValidID => 1,
            Silent  => $Test->{Silent}
        );

        $Self->True(
            $Success,
            $Test->{Number} . " - ContactUpdate() - $Setting->{Contact}",
        );
    }

    next if !$ContactID;

    my %Contact = $Kernel::OM->Get('Contact')->ContactGet(
        ID     => $ContactID,
        Silent => $Test->{Silent}
    );

    for my $Key ( keys %{$Test->{Result}} ) {
        if ( $Key eq 'PrimaryOrganisationID' ) {
            my $OrgID = $Test->{Result}->{$Key};
            if (
                defined $Test->{Result}->{$Key}
                && $Test->{Result}->{$Key} =~ /.*[@].*/sm
            ) {
                $OrgID = $Kernel::OM->Get('Organisation')->OrganisationLookup(
                    Number => $Test->{Result}->{$Key},
                    Silent => 1
                );
            }
            $Self->Is(
                $Contact{$Key},
                $OrgID,
                $Test->{Number} . q{ - } . $Test->{Name} . q{ (} . $Key . q{)}
            );
        }
        if ( $Key eq 'OrganisationIDs' ) {
            $Self->IsDeeply(
                $Contact{$Key},
                $Test->{Result}->{$Key},
                $Test->{Number} . q{ - } . $Test->{Name} . q{ (} . $Key . q{)},
                1
            );
        }
    }
}

sub _CreateOrganisation {
    my (%Param) = @_;

    my $Rand      = $Helper->GetRandomID();
    my $OrgNumber = 'UT' . $Param{NumberPrefix} . $Rand;
    my $OrgName   = 'Unit Test ' . $Rand;
    my $ID = $Kernel::OM->Get('Organisation')->OrganisationAdd(
        Number => $OrgNumber,
        Name   => $OrgName,
        ValidID => 1,
        UserID  => 1
    );

    $Self->True(
        $ID,
        "OrganisationAdd() - $OrgNumber ($ID)"
    );
    return if ( !$ID );

    # add pattern to "AddressDomainPattern" for the organisation
    my @Patterns = (
        'main.*.com',
        '*.org',
        'test.net',
    );

    my $DynamicField = $Kernel::OM->Get('DynamicField')->DynamicFieldGet(
        Name => 'AddressDomainPattern'
    );

    $Self->True(
        $DynamicField ? 1 : 0,
        'Get DynamicField "AddressDomainPattern"'
    );
    return if ( !$DynamicField );

    $Kernel::OM->Get('DynamicField::Backend')->ValueSet(
        DynamicFieldConfig => $DynamicField,
        Value              => $Param{Pattern} || \@Patterns,
        ObjectID           => $ID,
        UserID             => 1
    );

    $Kernel::OM->ObjectsDiscard(
        Objects => [
            'Organisation',
            'DynamicField::Backend'
        ]
    );

    return {
        Name   => $OrgName,
        Number => $OrgNumber,
        ID     => $ID
    };
};

# rollback transaction on database
$Helper->Rollback();

1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-GPL3 for license information (GPL3). If you did not receive this file, see

<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
