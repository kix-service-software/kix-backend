# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

use strict;
use warnings;
use utf8;

use vars (qw($Self));

use Kernel::API::Validator::VersionValidator;

# get validator object
my $ValidatorObject = Kernel::API::Validator::VersionValidator->new();

# get helper object
my $Helper = $Kernel::OM->Get('UnitTest::Helper');


# prepare depl state mapping
my $DeplStateRef = $Kernel::OM->Get('GeneralCatalog')->ItemGet(
    Class => 'ITSM::ConfigItem::DeploymentState',
    Name  => 'Production',
);

# prepare inci state mapping
my $InciStateRef = $Kernel::OM->Get('GeneralCatalog')->ItemGet(
    Class => 'ITSM::Core::IncidentState',
    Name  => 'Operational',
);

my @VersionCheck = (
    {
        Name     => 'Validation: undef Data',
        Data     => undef,
        Expacted => {
            'Code'    => 'Validator.InternalError',
            'Message' => 'Got no Attribute!',
            'Success' => 0
        }
    },
    {
        Name     => 'Validation: Attribute undef',
        Data     => {
            Attribute       => undef,
            ParentAttribute => 'ConfigItem',
            Operation       => 'V1::CMDB::ConfigItemVersionCreate',
            Data            => {
                Version         => {
                    InciStateID => $InciStateRef->{ItemID},
                    DeplStateID => $DeplStateRef->{ItemID},
                    ValidID     => 1
                }
            }
        },
        Expacted => {
            'Code'    => 'Validator.InternalError',
            'Message' => 'Got no Attribute!',
            'Success' => 0
        }
    },
    {
        Name     => 'Validation: ParentAttribute undef',
        Data     => {
            Attribute       => 'Version',
            ParentAttribute => undef,
            Operation       => 'V1::CMDB::ConfigItemVersionCreate',
            Data            => {
                Version         => {
                    InciStateID => $InciStateRef->{ItemID},
                    DeplStateID => $DeplStateRef->{ItemID},
                    ValidID     => 1
                }
            }
        },
        Expacted => {
            'Success' => 1
        }
    },
    {
        Name     => 'Validation: Operation undef',
        Data     => {
            Attribute       => 'Version',
            ParentAttribute => 'ConfigItem',
            Operation       => undef,
            Data            => {
                Version         => {
                    InciStateID => $InciStateRef->{ItemID},
                    DeplStateID => $DeplStateRef->{ItemID},
                    ValidID     => 1
                }
            }
        },
        Expacted => {
            'Code'    => 'Validator.InternalError',
            'Message' => 'Got no Operation!',
            'Success' => 0
        }
    },
    {
        Name     => 'Validation: Data undef',
        Data     => {
            Attribute       => 'Version',
            ParentAttribute => 'ConfigItem',
            Operation       => 'V1::CMDB::ConfigItemVersionCreate',
            Data            => undef,
        },
        Expacted => {
            'Code'    => 'Validator.UnknownAttribute',
            'Message' => 'VersionValidator: cannot validate attribute Version!',
            'Success' => 0
        }
    },
    {
        Name     => 'Validation: Attribute Version not in Data',
        Data     => {
            Attribute       => 'Version',
            ParentAttribute => 'ConfigItem',
            Operation       => 'V1::CMDB::ConfigItemVersionCreate',
            Data            => {
                InciStateID => $InciStateRef->{ItemID},
                DeplStateID => $DeplStateRef->{ItemID},
                ValidID     => 1
            }
        },
        Expacted => {
            'Code'    => 'Validator.UnknownAttribute',
            'Message' => 'VersionValidator: cannot validate attribute Version!',
            'Success' => 0
        }
    },
    {
        Name     => 'Validation: Attribute Version / ParentAttribute ConfigItem',
        Data     => {
            Attribute       => 'Version',
            ParentAttribute => 'ConfigItem',
            Operation       => 'V1::CMDB::ConfigItemVersionCreate',
            Data            => {
                Version         => {
                    InciStateID => $InciStateRef->{ItemID},
                    DeplStateID => $DeplStateRef->{ItemID},
                    ValidID     => 1
                }
            }
        },
        Expacted => {
            'Success' => 1
        }
    },
    {
        Name     => 'Validation: Attribute Version / ParentAttribute ConfigItem / Data has Data with RoleID',
        Data     => {
            Attribute       => 'Version',
            ParentAttribute => 'ConfigItem',
            Operation       => 'V1::CMDB::ConfigItemVersionCreate',
            Data            => {
                Version         => {
                    InciStateID => $InciStateRef->{ItemID},
                    DeplStateID => $DeplStateRef->{ItemID},
                    ValidID     => 1,
                    Data        => {
                        RoleID => 1
                    }
                }
            }
        },
        Expacted => {
            'Success' => 1
        }
    },
    {
        Name     => 'Validation: Attribute Version / ParentAttribute ConfigItem / Data has invalid InciStateID',
        Data     => {
            Attribute       => 'Version',
            ParentAttribute => 'ConfigItem',
            Operation       => 'V1::CMDB::ConfigItemVersionCreate',
            Data            => {
                Version         => {
                    InciStateID => 999,
                    DeplStateID => $DeplStateRef->{ItemID},
                    ValidID     => 1
                }
            }
        },
        Expacted => {
            'Code'    => 'Validator.Failed',
            'Message' => 'Validation of attribute InciStateID failed!',
            'Success' => 0
        }
    },
    {
        Name     => 'Validation: Attribute Version / ParentAttribute ConfigItem / Data has invalid DeplStateID',
        Data     => {
            Attribute       => 'Version',
            ParentAttribute => 'ConfigItem',
            Operation       => 'V1::CMDB::ConfigItemVersionCreate',
            Data            => {
                Version         => {
                    InciStateID => $InciStateRef->{ItemID},
                    DeplStateID => 998,
                    ValidID     => 1
                }
            }
        },
        Expacted => {
            'Code'    => 'Validator.Failed',
            'Message' => 'Validation of attribute DeplStateID failed!',
            'Success' => 0
        }
    },
    {
        Name     => 'Validation: Attribute Version / ParentAttribute ConfigItem / Data has invalid ValidID',
        Data     => {
            Attribute       => 'Version',
            ParentAttribute => 'ConfigItem',
            Operation       => 'V1::CMDB::ConfigItemVersionCreate',
            Data            => {
                Version         => {
                    InciStateID => $InciStateRef->{ItemID},
                    DeplStateID => $DeplStateRef->{ItemID},
                    ValidID     => 4
                }
            }
        },
        Expacted => {
            'Code'    => 'Validator.Failed',
            'Message' => 'Validation of attribute ValidID failed!',
            'Success' => 0
        }
    },
    {
        Name     => 'Validation: Attribute ConfigItemVersion / ParentAttribute undef',
        Data     => {
            Attribute       => 'ConfigItemVersion',
            ParentAttribute => undef,
            Operation       => 'V1::CMDB::ConfigItemCreate',
            Data            => {
                ConfigItemVersion => {
                    InciStateID => $InciStateRef->{ItemID},
                    DeplStateID => $DeplStateRef->{ItemID},
                    ValidID     => 1
                }
            }
        },
        Expacted => {
            'Success' => 1
        }
    },
    {
        Name     => 'Validation: Attribute ConfigItemVersion / ParentAttribute undef / Data has Data with RoleID',
        Data     => {
            Attribute       => 'ConfigItemVersion',
            ParentAttribute => undef,
            Operation       => 'V1::CMDB::ConfigItemCreate',
            Data            => {
                ConfigItemVersion => {
                    InciStateID => $InciStateRef->{ItemID},
                    DeplStateID => $DeplStateRef->{ItemID},
                    ValidID     => 1,
                    Data        => {
                        RoleID => 1
                    }
                }
            }
        },
        Expacted => {
            'Success' => 1
        }
    },
    {
        Name     => 'Validation: Attribute ConfigItemVersion / ParentAttribute undef / Data has invalid InciStateID',
        Data     => {
            Attribute       => 'ConfigItemVersion',
            ParentAttribute => undef,
            Operation       => 'V1::CMDB::ConfigItemVersionCreate',
            Data            => {
                ConfigItemVersion => {
                    InciStateID => 999,
                    DeplStateID => $DeplStateRef->{ItemID},
                    ValidID     => 1
                }
            }
        },
        Expacted => {
            'Code'    => 'Validator.Failed',
            'Message' => 'Validation of attribute InciStateID failed!',
            'Success' => 0
        }
    },
    {
        Name     => 'Validation: Attribute ConfigItemVersion / ParentAttribute undef / Data has invalid DeplStateID',
        Data     => {
            Attribute       => 'ConfigItemVersion',
            ParentAttribute => undef,
            Operation       => 'V1::CMDB::ConfigItemVersionCreate',
            Data            => {
                ConfigItemVersion => {
                    InciStateID => $InciStateRef->{ItemID},
                    DeplStateID => 998,
                    ValidID     => 1
                }
            }
        },
        Expacted => {
            'Code'    => 'Validator.Failed',
            'Message' => 'Validation of attribute DeplStateID failed!',
            'Success' => 0
        }
    },
    {
        Name     => 'Validation: Attribute ConfigItemVersion / ParentAttribute undef / Data has invalid ValidID',
        Data     => {
            Attribute       => 'ConfigItemVersion',
            ParentAttribute => undef,
            Operation       => 'V1::CMDB::ConfigItemVersionCreate',
            Data            => {
                ConfigItemVersion => {
                    InciStateID => $InciStateRef->{ItemID},
                    DeplStateID => $DeplStateRef->{ItemID},
                    ValidID     => 4
                }
            }
        },
        Expacted => {
            'Code'    => 'Validator.Failed',
            'Message' => 'Validation of attribute ValidID failed!',
            'Success' => 0
        }
    },
);

for my $Test ( @VersionCheck ) {
    my $Result = $ValidatorObject->Validate(
        %{$Test->{Data}}
    );

    $Self->IsDeeply(
        $Result,
        $Test->{Expacted},
        $Test->{Name}
    );
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
