# --
# Modified version of the work: Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com 
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Console::Command::Dev::UnitTest::Run;

use strict;
use warnings;

use base qw(Kernel::System::Console::BaseCommand);

our @ObjectDependencies = (
    'Config',
    'UnitTest',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Executes unit tests.');
    $Self->AddOption(
        Name        => 'plugin',
        Description => "Refer to the plugin tests instead of the framework tests.",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );
    $Self->AddOption(
        Name        => 'test',
        Description => "Run single test files, e.g. 'Ticket' or 'Ticket:Queue'.",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );
    $Self->AddOption(
        Name        => 'exclude',
        Description => "Exclude one or more test. You can give a RegEx pattern.",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );
    $Self->AddOption(
        Name        => 'directory',
        Description => "Run all test files in specified directory.",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );
    $Self->AddOption(
        Name        => 'output',
        Description => "Select output format (ASCII|HTML|XML|Allure).Separate multiple formats by comma.",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );
    $Self->AddOption(
        Name        => 'submit-url',
        Description => "Send unit test results to a server (url).",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );
    $Self->AddOption(
        Name => 'submit-result-as-exit-code',
        Description =>
            "Specify if command return code should not indicate if tests were ok/not ok, but if submission was successful instead.",
        Required => 0,
        HasValue => 0,
    );
    $Self->AddOption(
        Name        => 'product',
        Description => "Specify a different product name.",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );
    $Self->AddOption(
        Name        => 'verbose',
        Description => "Show details for all tests, not just failing.",
        Required    => 0,
        HasValue    => 0,
    );
    $Self->AddOption(
        Name        => 'pretty',
        Description => "Break lines in non-verbose mode.",
        Required    => 0,
        HasValue    => 0,
    );
    $Self->AddOption(
        Name        => 'allure-ignore-skipped',
        Description => "Hides skipped tests in report if output ALLURE is chosen.",
        Required    => 0,
        HasValue    => 0,
    );
    $Self->AddOption(
        Name        => 'allure-output-dir',
        Description => "Defines where the Allure adapter should output the result files. Default: /tmp/unit-test/allure-results.",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );
}

sub PreRun {
    my ( $Self, %Param ) = @_;

    if ( $Self->GetOption('submit-result-as-exit-code') && !$Self->GetOption('submit-url') ) {
        die "Please specify a valid 'submit-url'.";
    }
    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    $Kernel::OM->ObjectParamAdd(
        'UnitTest' => {
            Output => $Self->GetOption('output') || '',
            ANSI => $Self->{ANSI},
        },
    );

    my $FunctionResult = $Kernel::OM->Get('UnitTest')->Run(
        Name                   => $Self->GetOption('test')                       || '',
        Exclude                => $Self->GetOption('exclude')                    || '',
        Directory              => $Self->GetOption('directory')                  || '',
        Plugin                 => $Self->GetOption('plugin')                     || '',
        Product                => $Self->GetOption('product')                    || '',
        SubmitURL              => $Self->GetOption('submit-url')                 || '',
        SubmitResultAsExitCode => $Self->GetOption('submit-result-as-exit-code') || '',
        Verbose                => $Self->GetOption('verbose')                    || '',
        Pretty                 => $Self->GetOption('pretty')                     || '',
        AllureIgnoreSkipped    => $Self->GetOption('allure-ignore-skipped')      || '',
        AllureOutputDir        => $Self->GetOption('allure-output-dir')          || '',
    );

    if ($FunctionResult) {
        return $Self->ExitCodeOk();
    }
    return $Self->ExitCodeError();
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
