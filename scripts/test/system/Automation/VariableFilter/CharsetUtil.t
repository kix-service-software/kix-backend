# --
# Modified version of the work: Copyright (C) 2006-2026 KIX Service Software GmbH, https://www.kixdesk.com/ 
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
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

# begin transaction on database
$Helper->BeginWork();

# get module
if ( !$Kernel::OM->Get('Main')->Require('Kernel::System::Automation::VariableFilter::CharsetUtil') ) {
        $Self->True(
        0,
        'Cannot find CharsetUtil module!',
    );
    return;

}
my $Module = Kernel::System::Automation::VariableFilter::CharsetUtil->new();
if ( !$Module ) {
        $Self->True(
        0,
        'Get module instance failed!',
    );
    return;
}

# get handler
if ( !$Module->can('GetFilterHandler') ) {
    $Self->True(
        0,
        "Module cannot \"GetFilterHandler\"!"
    );
    return;
}
my %Handler = $Module->GetFilterHandler();
$Self->True(
    IsHashRefWithData(\%Handler) || 0,
    'GetFilterHandler()',
);
if (!IsHashRefWithData(\%Handler)) {
    $Self->True(
        0,
        'GetFilterHandler()',
    );
}
$Self->True(
    (keys %Handler) == 4,
    'GetFilterHandler() returns 4 handler',
);

# check ConvertFrom
if (!$Handler{'CharsetUtil.ConvertFrom'}) {
    $Self->True(
        0,
        '"ConvertFrom" handler is missing',
    );
} else {
    my @ConvertFromTests = (
        {
            Name      => 'Undefined value, undefined parameter',
            Value     => undef,
            Parameter => undef,
            Expected  => undef,
            Silent    => 1
        },
        {
            Name      => 'Empty string value, undefined parameter',
            Value     => '',
            Parameter => undef,
            Expected  => '',
            Silent    => 1
        },
        {
            Name      => 'String value, undefined parameter',
            Value     => 'abc123',
            Parameter => undef,
            Expected  => 'abc123',
            Silent    => 1
        },
        {
            Name      => 'Empty string value, valid parameter (utf8)',
            Value     => '',
            Parameter => 'utf8',
            Expected  => '',
            Silent    => 0
        },
        {
            Name      => 'String value, valid parameter (ascii)',
            Value     => 'abc123',
            Parameter => 'ascii',
            Expected  => 'abc123',
            Silent    => 0
        },
        {
            Name      => 'String value, valid parameter (us-ascii)',
            Value     => 'abc123',
            Parameter => 'us-ascii',
            Expected  => 'abc123',
            Silent    => 0
        },
        {
            Name      => 'String value, valid parameter (utf8)',
            Value     => 'abc123���',
            Parameter => 'utf8',
            Expected  => 'abc123���',
            Silent    => 0
        },
        {
            Name      => 'String value, valid parameter (iso-8859-15)',
            Value     => 'abc123���',
            Parameter => 'iso-8859-15',
            Expected  => 'abc123���',
            Silent    => 0
        }
    );
    for my $Test ( @ConvertFromTests ) {
        my $Result = $Handler{'CharsetUtil.ConvertFrom'}->(
            {},
            Value     => $Test->{Value},
            Parameter => $Test->{Parameter},
            Silent    => $Test->{Silent}
        );

        $Self->IsDeeply(
            $Result,
            $Test->{Expected},
            'CharsetUtil.ConvertFrom:' . $Test->{Name}
        );
    }
}

# check ConvertTo
if (!$Handler{'CharsetUtil.ConvertTo'}) {
    $Self->True(
        0,
        '"ConvertTo" handler is missing',
    );
} else {
    my @ConvertToTests = (
        {
            Name      => 'Undefined value, undefined parameter',
            Value     => undef,
            Parameter => undef,
            Expected  => undef,
            Silent    => 1
        },
        {
            Name      => 'Empty string value, undefined parameter',
            Value     => '',
            Parameter => undef,
            Expected  => '',
            Silent    => 1
        },
        {
            Name      => 'String value, undefined parameter',
            Value     => 'abc123',
            Parameter => undef,
            Expected  => 'abc123',
            Silent    => 1
        },
        {
            Name      => 'Empty string value, valid parameter (utf8)',
            Value     => '',
            Parameter => 'utf8',
            Expected  => '',
            Silent    => 0
        },
        {
            Name      => 'String value, valid parameter (utf8)',
            Value     => 'abc123���',
            Parameter => 'utf8',
            Expected  => 'abc123���',
            Silent    => 0
        },
        {
            Name      => 'String value, valid parameter (iso-8859-15)',
            Value     => 'abc123���',
            Parameter => 'iso-8859-15',
            Expected  => 'abc123���',
            Silent    => 0
        }
    );
    for my $Test ( @ConvertToTests ) {
        my $Result = $Handler{'CharsetUtil.ConvertTo'}->(
            {},
            Value     => $Test->{Value},
            Parameter => $Test->{Parameter},
            Silent    => $Test->{Silent}
        );

        $Self->IsDeeply(
            $Result,
            $Test->{Expected},
            'CharsetUtil.ConvertTo:' . $Test->{Name}
        );
    }
}

# check EncodeInput
if (!$Handler{'CharsetUtil.EncodeInput'}) {
    $Self->True(
        0,
        '"EncodeInput" handler is missing',
    );
} else {
    my @EncodeInputToTests = (
        {
            Name      => 'Undefined valuer',
            Value     => undef,
            Parameter => undef,
            Expected  => undef,
            Silent    => 1
        },
        {
            Name      => 'Empty string value, undefined parameter',
            Value     => '',
            Parameter => undef,
            Expected  => '',
            Silent    => 0
        },
        {
            Name      => 'String value',
            Value     => 'abc123���',
            Parameter => undef,
            Expected  => 'abc123���',
            Silent    => 0
        }
    );
    for my $Test ( @EncodeInputToTests ) {
        my $Result = $Handler{'CharsetUtil.EncodeInput'}->(
            {},
            Value     => $Test->{Value},
            Parameter => $Test->{Parameter},
            Silent    => $Test->{Silent}
        );

        $Self->IsDeeply(
            $Result,
            $Test->{Expected},
            'CharsetUtil.EncodeInput:' . $Test->{Name}
        );
    }
}

# check EncodeOutput
if (!$Handler{'CharsetUtil.EncodeOutput'}) {
    $Self->True(
        0,
        '"EncodeOutput" handler is missing',
    );
} else {
    my @EncodeOutputToTests = (
        {
            Name      => 'Undefined valuer',
            Value     => undef,
            Parameter => undef,
            Expected  => undef,
            Silent    => 1
        },
        {
            Name      => 'Empty string value, undefined parameter',
            Value     => '',
            Parameter => undef,
            Expected  => '',
            Silent    => 0
        },
        {
            Name      => 'String value',
            Value     => 'abc123���',
            Parameter => undef,
            Expected  => 'abc123���',
            Silent    => 0
        }
    );
    for my $Test ( @EncodeOutputToTests ) {
        my $Result = $Handler{'CharsetUtil.EncodeOutput'}->(
            {},
            Value     => $Test->{Value},
            Parameter => $Test->{Parameter},
            Silent    => $Test->{Silent}
        );

        $Self->IsDeeply(
            $Result,
            $Test->{Expected},
            'CharsetUtil.EncodeOutput:' . $Test->{Name}
        );
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
