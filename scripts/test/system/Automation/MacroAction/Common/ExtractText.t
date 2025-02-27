# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

use strict;
use warnings;
use utf8;

use vars (qw($Self));

use Kernel::System::VariableCheck qw(:all);

# get helper object
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

# begin transaction on database
$Helper->BeginWork();

# create macro
my $MacroID = $Kernel::OM->Get('Automation')->MacroAdd(
    Name    => 'ExtractText - Macro',
    Type    => 'Synchronisation',
    ValidID => 1,
    UserID  => 1,
);
$Self->True(
    $MacroID,
    'MacroAdd',
);

# create macro action
my $MacroActionID = $Kernel::OM->Get('Automation')->MacroActionAdd(
    MacroID    => $MacroID,
    Type       => 'ExtractText',
    Parameters => {
        RegEx => '^$',
    },
    ValidID    => 1,
    UserID     => 1,
);
$Self->True(
    $MacroActionID,
    'MacroActionAdd',
);

# update macro - set ExecOrder
my $Success = $Kernel::OM->Get('Automation')->MacroUpdate(
    ID        => $MacroID,
    ExecOrder => [ $MacroActionID ],
    UserID    => 1,
);
$Self->True(
    $Success,
    'MacroUpdate - ExecOrder',
);

my @Tests = (
    {
        Name  => 'RegEx without Text - No match without CaptureGroup',
        Input => {
            RegEx => '^Test$',
        },
        Result => {},
    },
    {
        Name  => 'RegEx without Text - No match with CaptureGroup',
        Input => {
            RegEx => '^(Test)$',
        },
        Result => {},
    },
    {
        Name  => 'RegEx without Text - No match with CaptureGroup and CaptureGroupNames',
        Input => {
            RegEx             => '^(Test)$',
            CaptureGroupNames => 'Test',
        },
        Result => {},
    },
    {
        Name  => 'RegEx with Text - No match without CaptureGroup',
        Input => {
            RegEx => '^Test$',
            Text  => <<'END',
Lorem ipsum dolor sit amet, consetetur sadipscing elitr, sed diam nonumy eirmod tempor invidunt ut labore et dolore magna aliquyam
END
        },
        Result => {},
    },
    {
        Name  => 'RegEx with Text - No match with CaptureGroup',
        Input => {
            RegEx => '^(Test)$',
            Text  => <<'END',
Lorem ipsum dolor sit amet, consetetur sadipscing elitr, sed diam nonumy eirmod tempor invidunt ut labore et dolore magna aliquyam
END
        },
        Result => {},
    },
    {
        Name  => 'RegEx with Text - No match with named CaptureGroup',
        Input => {
            RegEx => '^(?<Test>Test)$',
            Text  => <<'END',
Lorem ipsum dolor sit amet, consetetur sadipscing elitr, sed diam nonumy eirmod tempor invidunt ut labore et dolore magna aliquyam
END
        },
        Result => {},
    },
    {
        Name  => 'RegEx with Text - No match with CaptureGroup and CaptureGroupNames',
        Input => {
            RegEx             => '^(Test)$',
            Text              => <<'END',
Lorem ipsum dolor sit amet, consetetur sadipscing elitr, sed diam nonumy eirmod tempor invidunt ut labore et dolore magna aliquyam
END
            CaptureGroupNames => 'Test',
        },
        Result => {},
    },
    {
        Name  => 'RegEx with Text - Match without CaptureGroup',
        Input => {
            RegEx => '(?:Lorem)',
            Text  => <<'END',
Lorem ipsum dolor sit amet, consetetur sadipscing elitr, sed diam nonumy eirmod tempor invidunt ut labore et dolore magna aliquyam
END
        },
        Result => {
            '1' => '1',
        },
    },
    {
        Name  => 'RegEx with Text - Match with CaptureGroup',
        Input => {
            RegEx => '(tempor)',
            Text  => <<'END',
Lorem ipsum dolor sit amet, consetetur sadipscing elitr, sed diam nonumy eirmod tempor invidunt ut labore et dolore magna aliquyam
END
        },
        Result => {
            '1' => 'tempor',
        },
    },
    {
        Name  => 'RegEx with Text - Match with named CaptureGroup',
        Input => {
            RegEx => '(?<Test>elitr)',
            Text  => <<'END',
Lorem ipsum dolor sit amet, consetetur sadipscing elitr, sed diam nonumy eirmod tempor invidunt ut labore et dolore magna aliquyam
END
        },
        Result => {
            'Test' => 'elitr',
        },
    },
    {
        Name  => 'RegEx with Text - Match with CaptureGroup and CaptureGroupNames',
        Input => {
            RegEx             => '.+,\s*(.+?)\s.+?,\s*(.+?)\s',
            Text              => <<'END',
Lorem ipsum dolor sit amet, consetetur sadipscing elitr, sed diam nonumy eirmod tempor invidunt ut labore et dolore magna aliquyam
END
            CaptureGroupNames => 'Test,Name,Empty',
        },
        Result => {
            'Test'  => 'consetetur',
            'Name'  => 'sed',
            'Empty' => undef,
        },
    },
);

for my $Test ( @Tests ) {
    if ( $Test->{FixedTimeSet} ) {
        $Helper->FixedTimeSet(
            $Kernel::OM->Get('Time')->TimeStamp2SystemTime(
                String => $Test->{FixedTimeSet},
            ),
        );
    }

    # update parameters of MacroAction
    $Success = $Kernel::OM->Get('Automation')->MacroActionUpdate(
        ID         => $MacroActionID,
        Parameters => {
            %{ $Test->{Input} },
        },
        UserID     => 1,
        ValidID    => 1,
    );
    $Self->True(
        $Success,
        $Test->{Name} . ': MacroActionUpdate',
    );

    # check if placeholder is used
    $Success = $Kernel::OM->Get('Automation')->MacroExecute(
        ID       => $MacroID,
        ObjectID => 1,
        UserID   => 1,
    );
    $Self->True(
        $Success,
        $Test->{Name} . ': MacroExecute',
    );

    $Self->IsDeeply(
        $Kernel::OM->Get('Automation')->{MacroVariables}->{ExtractedText},
        $Test->{Result},
        $Test->{Name} . ': MacroExecute - macro variables "ExtractedText"',
    );

    if ( $Test->{FixedTimeSet} ) {
        $Helper->FixedTimeUnset();
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
