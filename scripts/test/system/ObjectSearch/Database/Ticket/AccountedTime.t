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

my $AttributeModule = 'Kernel::System::ObjectSearch::Database::Ticket::AccountedTime';

# require module
return if ( !$Kernel::OM->Get('Main')->Require( $AttributeModule ) );

# create backend object
my $AttributeObject = $AttributeModule->new( %{ $Self } );
$Self->Is(
    ref( $AttributeObject ),
    $AttributeModule,
    'Attribute object has correct module ref'
);

# check GetSupportedAttributes
my $AttributeList = $AttributeObject->GetSupportedAttributes();
$Self->IsDeeply(
    $AttributeList,
    {
        AccountedTime => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','LT','GT','LTE','GTE'],
            ValueType    => 'Integer'
        }
    },
    'GetSupportedAttributes provides expected data'
);

# check Search
my @SearchTests = (
    {
        Name     => 'Search: undef search',
        Search   => undef,
        Expected => undef
    },
    {
        Name     => 'Search: Value undef',
        Search   => {
            Field    => 'AccountedTime',
            Operator => 'EQ',
            Value    => undef

        },
        Expected => undef
    },
    {
        Name     => 'Search: Value invalid',
        Search   => {
            Field    => 'AccountedTime',
            Operator => 'EQ',
            Value    => 'Test'
        },
        Expected => undef
    },
    {
        Name     => 'Search: Field undef',
        Search   => {
            Field    => undef,
            Operator => 'EQ',
            Value    => '1'
        },
        Expected => undef
    },
    {
        Name     => 'Search: Field invalid',
        Search   => {
            Field    => 'Test',
            Operator => 'EQ',
            Value    => '1'
        },
        Expected => undef
    },
    {
        Name     => 'Search: Operator undef',
        Search   => {
            Field    => 'AccountedTime',
            Operator => undef,
            Value    => '1'
        },
        Expected => undef
    },
    {
        Name     => 'Search: Operator invalid',
        Search   => {
            Field    => 'AccountedTime',
            Operator => 'Test',
            Value    => '1'
        },
        Expected => undef
    },
    {
        Name     => 'Search: valid search / Operator EQ',
        Search   => {
            Field    => 'AccountedTime',
            Operator => 'EQ',
            Value    => '1'
        },
        Expected => {
            Where => ['st.accounted_time = \'1\'']
        }
    },
    {
        Name     => 'Search: valid search / Operator EQ / negative integer',
        Search   => {
            Field    => 'AccountedTime',
            Operator => 'EQ',
            Value    => '-1'
        },
        Expected => {
            Where => ['st.accounted_time = \'-1\'']
        }
    },
    {
        Name     => 'Search: valid search / Operator LT',
        Search   => {
            Field    => 'AccountedTime',
            Operator => 'LT',
            Value    => '1'
        },
        Expected => {
            Where => ['st.accounted_time < \'1\'']
        }
    },
    {
        Name     => 'Search: valid search / Operator GT',
        Search   => {
            Field    => 'AccountedTime',
            Operator => 'GT',
            Value    => '1'
        },
        Expected => {
            Where => ['st.accounted_time > \'1\'']
        }
    },
    {
        Name     => 'Search: valid search / Operator LTE',
        Search   => {
            Field    => 'AccountedTime',
            Operator => 'LTE',
            Value    => '1'
        },
        Expected => {
            Where => ['st.accounted_time <= \'1\'']
        }
    },
    {
        Name     => 'Search: valid search / Operator GTE',
        Search   => {
            Field    => 'AccountedTime',
            Operator => 'GTE',
            Value    => '1'
        },
        Expected => {
            Where => ['st.accounted_time >= \'1\'']
        }
    }
);
for my $Test ( @SearchTests ) {
    my $Result = $AttributeObject->Search(
        Search => $Test->{Search},
        Silent => defined( $Test->{Expected} ) ? 0 : 1
    );
    $Self->IsDeeply(
        $Result,
        $Test->{Expected},
        $Test->{Name}
    );
}

# check Sort
my @SortTests = (
    {
        Name      => 'Sort: Attribute undef',
        Attribute => undef,
        Expected  => undef
    },
    {
        Name      => 'Sort: Attribute invalid',
        Attribute => 'Test',
        Expected  => undef
    },
    {
        Name      => 'Sort: Attribute "AccountedTime"',
        Attribute => 'AccountedTime',
        Expected  => {
            Select  => [ 'st.accounted_time' ],
            OrderBy => [ 'st.accounted_time' ]
        }
    }
);
for my $Test ( @SortTests ) {
    my $Result = $AttributeObject->Sort(
        Attribute => $Test->{Attribute},
        Silent    => defined( $Test->{Expected} ) ? 0 : 1
    );
    $Self->IsDeeply(
        $Result,
        $Test->{Expected},
        $Test->{Name}
    );
}

1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
