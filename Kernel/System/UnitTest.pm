# --
# Modified version of the work: Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com 
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::UnitTest;

use strict;
use warnings;

use base qw(
    Kernel::System::UnitTest::Method
);

use Term::ANSIColor ();
use FileHandle;
use Time::HiRes qw(time);

use Kernel::System::ObjectManager;

# UnitTest helper must be loaded to override the builtin time functions!
use Kernel::System::UnitTest::Helper;

use Kernel::System::UnitTest::AllureAdapter;

use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = (
    'Config',
    'DB',
    'Encode',
    'Environment',
    'Installation',
    'Log',
    'Main',
    'Time',
    'Kernel::System::UnitTest::AllureAdapter',
);

=head1 NAME

Kernel::System::UnitTest - global test interface

=head1 SYNOPSIS

Functions to run existing unit tests, as well as
functions to define test cases.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create unit test object. Do not use it directly, instead use:

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $UnitTestObject = $Kernel::OM->Get('UnitTest');

=cut

sub new {
    my ($Type, %Param) = @_;

    # allocate new hash for object
    my $Self = {};
    bless($Self, $Type);

    $Self->{Debug} = $Param{Debug} || 0;

    $Self->{Output} = { map {$_ => 1} split(/[,]/sm, $Param{Output} || 'ASCII') };

    $Self->{ANSI} = $Param{ANSI};
    if ($Self->{Output}->{Allure}) {
        $Self->{Adapter} = $Kernel::OM->Get('Kernel::System::UnitTest::AllureAdapter')->new();
    }

    if ($Self->{Output}->{HTML}) {
        print <<"END";
<html>
    <head>
        <title>$Kernel::OM->Get('Config')->Get('Product') $Kernel::OM->Get('Config')->Get('Version') - Test Summary</title>
        <style>
            body, td {
                font-family: Courier New;
                font-size: 0.75em;
            }
            table {
                border: 2px solid #aaa;
                border-collapse: collapse;
                table-layout: fixed;
            }
            td {
                padding: 2px 5px;
                border: 1px solid #ccc;
                vertical-align: top;
                word-wrap: break-word;
            }
            .Counter {
                width: 60px;
                text-align: right;
            }
            .Tests {
                width: 600px;
            }
            .Time {
                width: 170px;
            }
            .State {
                width: 50px;
            }
            .Ok {
                color: green;
            }
            .Failed {
                color: red;
            }
            .Pointer {
                cursor: pointer;
            }
        </style>
    </head>
    <a name='top'></a>
    <body>
END
        $Self->{Content} = "<table width='100%'>\n";
    }

    $Self->{XML} = undef;
    $Self->{XMLUnit} = q{};

    $Self->{OriginalSTDOUT} = *STDOUT;
    $Self->{OriginalSTDOUT}->autoflush(1);
    $Self->{OriginalSTDERR} = *STDERR;
    $Self->{OriginalSTDERR}->autoflush(1);

    return $Self;
}

=item Run()

Run all tests located in scripts/test/*.t and print result to stdout.

    $UnitTestObject->Run(
        Name                   => 'JSON:User:Auth',  # optional, control which tests to select
        Exclude                => '(Cache|Auth)',    # optional, which tests should not be executed
        Directory              => 'Selenium',        # optional, control which tests to select
        Plugin                 => 'KIXPro',          # optional, use the plugin directory as the base directory
        SubmitURL              => $URL,              # optional, send results to unit test result server
        SubmitResultAsExitCode => $URL,              # optional, specify if exit code should not indicate if
                                                     #   tests were ok/not ok, but if submission was successful instead.
        Verbose                => 1,                 # optional (default 0), only show result details for all tests, not just failing
    );

=cut

sub Run {
    my ($Self, %Param) = @_;
    # set environment
    $ENV{UnitTest} = 1;

    if ( $Param{AllureIgnoreSkipped} ) {
        $Self->{Adapter}->IgnoreSkipped();
    }

    my %ResultSummary;
    my $Home = $Kernel::OM->Get('Config')->Get('Home');

    # use a plugin as base
    if ( $Param{Plugin} ) {
        my @PluginList = $Kernel::OM->Get('Installation')->PluginList();
        my %Plugins = map { $_->{Product} => $_ } @PluginList;
        if ( !$Plugins{$Param{Plugin}} ) {
            print {*STDERR} "Plugin doesn't exist!\n";
            return;
        }
        $Home = $Plugins{$Param{Plugin}}->{Directory};
    }

    my $Directory = "$Home/scripts/test";

    # custom subdirectory passed
    if ($Param{Directory}) {
        my $TmpDir = "/$Param{Directory}";
        $TmpDir    =~ s/[.]//gsm;

        $Directory .= $TmpDir;
    }

    $Self->{Verbose}         = $Param{Verbose};
    $Self->{Pretty}          = $Param{Pretty};
    $Self->{AllureOutputDir} = $Param{AllureOutputDir} || '/tmp/unit-test/allure-results';

    my @Files = $Kernel::OM->Get('Main')->DirectoryRead(
        Directory => $Directory,
        Filter    => '*.t',
        Recursive => 1,
    );

    my $StartTime = $Kernel::OM->Get('Time')->SystemTime();

    if ($Self->{Output}->{Allure}) {
        $Self->{Adapter}->SetContainerStartTime($Self->{runningContainerId}, int(time() * 1000));
    }

    my $Product = $Param{Product}
        || $Kernel::OM->Get('Config')->Get('Product')
            . q{ }
            . $Kernel::OM->Get('Config')->Get('Version');

    if ( !$Param{Product} && $Param{Plugin}) {
        $Product .= " (Plugin: $Param{Plugin})";
    }

    $Self->{Product} = $Product; # we need this in the Selenium object

    my @Names = split(/:/sm, $Param{Name} || q{});

    my $FileCount = 0;
    my $FileTotal = scalar(@Files);

    $Self->{TestCountOk} = 0;
    $Self->{TestCountNotOk} = 0;
    FILE:
    for my $File (sort @Files) {
        if ($Self->{Output}->{Allure}) {
            $Self->{runningTestId} = q{};
            $Self->{runningContainerId} = $Self->{Adapter}->NewContainer($File =~ /(?:.+\/test\/)(.+)/);
        }
        # check if only some tests are requested
        if (@Names) {
            my $Use = 0;
            for my $Name (@Names) {
                if ($Name && $File =~ /\/\Q$Name\E\.t$/) {
                    $Use = 1;
                }
            }
            if (!$Use) {
                #$Self->_Print(-1, 'Tests skipped by user request');
                next FILE;
            }
        }

        # check if we have to exclude something
        if ($Param{Exclude} && $File =~ /$Param{Exclude}/) {
            #$Self->_Print(-1, 'Tests skipped by user request');
            next FILE;
        }

        $Self->{TestCount} = 0;
        my $UnitTestFile = $Kernel::OM->Get('Main')->FileRead(Location => $File);

        if (!$UnitTestFile) {
            print {*STDERR} "ERROR: $!: $File\n";
            $Self->_Print(0, "ERROR: $!: $File");
            $Self->{OutputBuffer} = "$File is no Unit Test File! \n \$EVAL_ERROR:\n$@\n---\n\$EXTENDED_OS_ERROR\n$^E\n---\n\$CHILD_ERROR\n$?\n";

            if ($Self->{Output}->{Allure}) {
                $Self->_Print(-2, $Self->{Adapter}->GetContainerNameById($Self->{runningContainerId}), $File);
            }
        }
        else {
            $Self->_PrintHeadlineStart($File, ++$FileCount, $FileTotal);

            # create a new scope to be sure to destroy local object of the test files
            {
                # Make sure every UT uses its own clean environment.
                local $Kernel::OM = Kernel::System::ObjectManager->new(
                    'Log' => {
                        LogPrefix => 'KIX.UnitTest',
                    },
                );

                # Provide $Self as 'UnitTest' for convenience.
                $Kernel::OM->ObjectInstanceRegister(
                    Package      => 'UnitTest',
                    Object       => $Self,
                    Dependencies => [],
                );

                push @{$Self->{NotOkInfo}}, [ $File ];

                $Self->_ResetSelfOutputBuffer;

                # HERE the actual tests are run!!!
                $Self->{StartTime} = int(time() * 1000);
                if (!eval ${$UnitTestFile}) {
                    $Self->{OutputBuffer} = "\$EVAL_ERROR:\n$@\n---\n\$EXTENDED_OS_ERROR\n$^E\n---\n\$CHILD_ERROR\n$?\n";
                    if ($@) {
                        $Self->_Print(0, "ERROR: Error in $File: $@");
                        if ($Self->{Output}->{Allure}) {
                            $Self->_Print(-2, $Self->{Adapter}->GetContainerNameById($Self->{runningContainerId}), $File);
                        }
                    }
                    else {
                        $Self->_Print(0, "ERROR: $File did not return a true value.");
                        if ($Self->{Output}->{Allure}) {
                            $Self->{OutputBuffer} = "Did not return a true value.\n " . $Self->{OutputBuffer};
                            $Self->_Print(-2, $Self->{Adapter}->GetContainerNameById($Self->{runningContainerId}), $File);
                        }
                    }
                }
            }

            $Self->_PrintHeadlineEnd($Self->{XMLUnit});

            if ($Self->{Output}->{Allure}) {
                $Self->{Adapter}->SetContainerStopTime($Self->{runningContainerId}, int(time() * 1000));
            }
        }
    }
    my $Time = $Kernel::OM->Get('Time')->SystemTime() - $StartTime;
    $ResultSummary{TimeTaken} = $Time;
    $ResultSummary{Time}      = $Kernel::OM->Get('Time')->SystemTime2TimeStamp(
        SystemTime => $Kernel::OM->Get('Time')->SystemTime(),
    );

    my %OSInfo = $Kernel::OM->Get('Environment')->OSInfoGet();
    $ResultSummary{Product} = $Product;

    my $FQDN = $Kernel::OM->Get('Config')->Get('FQDN');
    if (IsHashRefWithData($FQDN)) {
        $FQDN = $FQDN->{Backend}
    }

    $ResultSummary{Host}      = $FQDN;
    $ResultSummary{Perl}      = sprintf "%vd", $^V;
    $ResultSummary{OS}        = $OSInfo{OS};
    $ResultSummary{Vendor}    = $OSInfo{OSName};
    $ResultSummary{Database}  = lc $Kernel::OM->Get('DB')->Version();
    $ResultSummary{TestOk}    = $Self->{TestCountOk};
    $ResultSummary{TestNotOk} = $Self->{TestCountNotOk};

    $Self->_PrintSummary(%ResultSummary);
    if ($Self->{Content}) {
        print $Self->{Content};
    }

    my $XML = "<?xml version=\"1.0\" encoding=\"utf-8\" ?>\n";
    $XML .= "<kix_test>\n";
    $XML .= "<Summary>\n";
    for my $Key (sort keys %ResultSummary) {
        $ResultSummary{$Key} =~ s/&/&amp;/gsm;
        $ResultSummary{$Key} =~ s/</&lt;/gsm;
        $ResultSummary{$Key} =~ s/>/&gt;/gsm;
        $ResultSummary{$Key} =~ s/"/&quot;/gsm;
        $XML .= "  <Item Name=\"$Key\">$ResultSummary{$Key}</Item>\n";
    }
    $XML .= "</Summary>\n";
    for my $Key (sort keys %{$Self->{XML}->{Test}}) {

        # extract duration time
        my $Duration = $Self->{Duration}->{$Key} || 0;

        $XML .= "<Unit Name=\"$Key\" Duration=\"$Duration\">\n";

        for my $TestCount (sort {$a <=> $b} keys %{$Self->{XML}->{Test}->{$Key}->{Tests}}) {
            my $Result = $Self->{XML}->{Test}->{$Key}->{Tests}->{$TestCount}->{Result};
            my $Content = $Self->{XML}->{Test}->{$Key}->{Tests}->{$TestCount}->{Name};
            $Content =~ s/&/&amp;/gsm;
            $Content =~ s/</&lt;/gsm;
            $Content =~ s/>/&gt;/gsm;

            # Replace characters that are invalid in XML (https://www.w3.org/TR/REC-xml/#charsets)
            $Content =~ s/[^\x{0009}\x{000a}\x{000d}\x{0020}-\x{D7FF}\x{E000}-\x{FFFD}]+/"\x{FFFD}" /eg;
            $XML .= qq|  <Test Result="$Result" Count="$TestCount">$Content</Test>\n|;
        }

        $XML .= "</Unit>\n";
    }
    $XML .= "</kix_test>\n";

    if ($Self->{Output}->{XML}) {
        print $XML;
    }

    if ($Param{SubmitURL}) {
        $Kernel::OM->Get('Encode')->EncodeOutput(\$XML);
    }
    if ($Self->{Output}->{Allure}) {
        $Self->{Adapter}->SetExecutorInfo();
        $Self->{Adapter}->AddEnvironmentInfoFromSystem();
        $Self->{Adapter}->CreateResults($Self->{AllureOutputDir});
    }
    return $ResultSummary{TestNotOk} ? 0 : 1;
}

sub _PrintHeadlineStart {
    my ($Self, $Name, $FileCount, $FileTotal) = @_;

    # set default name
    $Name ||= '->>No Name!<<-';

    my $Home = $Kernel::OM->Get('Config')->Get('Home');
    $Name =~ s/^$Home\/scripts\/test\///;

    if ($Self->{Output}->{HTML}) {
        $Self->{Content} .= <<"END";
    <tr>
        <td nowrap class="Counter">$FileCount/$FileTotal</td>
        <td nowrap>$Name</td>
        <td class="Tests">
END
    }

    if ($Self->{Output}->{ASCII}) {
        printf("(%4i/%i) %s ", $FileCount, $FileTotal, $Name);
    }

    $Self->{XMLUnit} = $Name;
    $Self->{CurrentColor} = undef;

    # set duration start time
    $Self->{DurationStartTime}->{$Name} = time();

    return 1;
}

sub _PrintHeadlineEnd {
    my ($Self, $Name) = @_;

    # set default name
    $Name ||= '->>No Name!<<-';

    # calculate duration time
    my $Duration = q{};
    if ($Self->{DurationStartTime}->{$Name}) {

        $Duration = time() - $Self->{DurationStartTime}->{$Name};

        delete $Self->{DurationStartTime}->{$Name};
    }
    $Self->{Duration}->{$Name} = $Duration;

    if ($Self->{Output}->{HTML}) {
        if ($Self->{CurrentColor}) {
            $Self->{Content} .= "</span>";
        }
        my $Color = 'green';
        my $Result = 'Ok';
        if ($Self->{XML}->{Test}->{ $Name }->{Result} && $Self->{XML}->{Test}->{ $Name }->{Result} eq 'FAILED') {
            $Color = 'red';
            $Result = 'Failed';
        }
        $Self->{Content} .= "</td><td nowrap class=\"Time\">" . sprintf "%i tests in %i ms", scalar(keys %{$Self->{XML}->{Test}->{ $Name }->{ Tests }}), $Duration * 1000;
        $Self->{Content} .= "<td class=\"State $Result\">". uc($Result) . "</td>\n";
        $Self->{Content} .= "</tr>\n";
    }

    if ($Self->{Output}->{ASCII}) {
        if ($Self->{Pretty} || $Self->{Verbose}) {
            print {$Self->{OriginalSTDOUT}} "\n";
        }
        if (!$Self->{Verbose}) {
            if ($Self->{XML}->{Test}->{ $Name }->{Result} && $Self->{XML}->{Test}->{ $Name }->{Result} eq 'FAILED') {
                print {$Self->{OriginalSTDOUT}} $Self->_Color('red', 'FAILED');
            }
            else {
                print {$Self->{OriginalSTDOUT}} $Self->_Color('green', 'OK');
            }

            printf {$Self->{OriginalSTDOUT}} " (%i tests in %i ms)\n", scalar(keys %{$Self->{XML}->{Test}->{ $Name }->{ Tests }}), $Duration * 1000;
        }
    }

    return 1;
}

sub _PrintSummary {
    my ($Self, %ResultSummary) = @_;

    # show result
    if ($Self->{Output}->{HTML}) {
        print "</table>\n";
        print "<table width='600' border='0'>\n";
        if ($ResultSummary{TestNotOk}) {
            print "<tr><td bgcolor='red' colspan='2'>Summary</td></tr>\n";
        }
        else {
            print "<tr><td bgcolor='green' colspan='2'>Summary</td></tr>\n";
        }
        print "<tr><td>Product:  </td><td>$ResultSummary{Product}</td></tr>\n";
        print "<tr><td>Test Time:</td><td>$ResultSummary{TimeTaken} s</td></tr>\n";
        print "<tr><td>Time:     </td><td>$ResultSummary{Time}</td></tr>\n";
        print "<tr><td>Host:     </td><td>$ResultSummary{Host}</td></tr>\n";
        print "<tr><td>Perl:     </td><td>$ResultSummary{Perl}</td></tr>\n";
        print "<tr><td>OS:       </td><td>$ResultSummary{OS}</td></tr>\n";
        print "<tr><td>Vendor:   </td><td>$ResultSummary{Vendor}</td></tr>\n";
        print "<tr><td>Database: </td><td>$ResultSummary{Database}</td></tr>\n";
        print "<tr><td>Test OK:   </td><td>$ResultSummary{TestOk}</td></tr>\n";
        print "<tr><td>Test FAILED:</td><td>$ResultSummary{TestNotOk}</td></tr>\n";
        print "</table><br>\n";
    }

    if ($Self->{Output}->{ASCII}) {
        print "=====================================================================\n";
        print " Product:     $ResultSummary{Product}\n";
        print " Test Time:   $ResultSummary{TimeTaken} s\n";
        print " Time:        $ResultSummary{Time}\n";
        print " Host:        $ResultSummary{Host}\n";
        print " Perl:        $ResultSummary{Perl}\n";
        print " OS:          $ResultSummary{OS}\n";
        print " Vendor:      $ResultSummary{Vendor}\n";
        print " Database:    $ResultSummary{Database}\n";
        print " Test OK:     $ResultSummary{TestOk}\n";
        print " Test FAILED: $ResultSummary{TestNotOk}\n";

        if ($ResultSummary{TestNotOk}) {
            print " Failed Tests:\n";
            FAILEDFILE:
            for my $FailedFile (@{$Self->{NotOkInfo} || []}) {
                my ($File, @Tests) = @{$FailedFile || []};
                next FAILEDFILE if !@Tests;
                print sprintf "  %s #%s\n", $File, join ", ", @Tests;
            }
        }

        print "=====================================================================\n";
    }
    return 1;
}

sub _Print {
    my ($Self, $Test, $Name, $File) = @_;

    if (
        $Test
        && $Test =~ /^\d+$/sm
        && $Test < 0
    ) {
        $Test = 0
    }

    $Name ||= '->>No Name!<<-';
    $File ||= '->>No Filename!<<-';

    my $TestStep = $Name;
    $TestStep =~ s/^(.*?)\s\(.+?\)$/$1/s;

    if ($Self->{Output}->{Allure}) {

        $Self->{runningTestId} = $Self->{Adapter}->NewTest($Name, q{}, $Self->{runningContainerId}, $File);
        $Self->{Adapter}->SetTestSubSuite($Self->{runningTestId}, $Self->{Adapter}->GetContainerNameById($Self->{runningContainerId}));
        $Self->{Adapter}->SetTestStartTime($Self->{runningTestId}, $Self->{StartTime});
        $Self->{Adapter}->SetTestStopTime($Self->{runningTestId}, int(time() * 1000));
        $Self->{Adapter}->SetTestSuite($Self->{runningTestId}, 'KIX18 Backend Unit Tests');
        $Self->{Adapter}->SetTestPackage($Self->{runningTestId}, 'KIX18 Backend Unit Tests');
        #PASSED tests
        if ($Test == 1) {
            $Self->{Adapter}->SetTestPassed($Self->{runningTestId});

        }

        #FAILED tests
        if ($Test == 0) {
            $Self->{Adapter}->SetTestFailed($Self->{runningTestId});
            if ($Self->{OutputBuffer}) {
                $Self->{Adapter}->SetTestTrace($Self->{runningTestId}, $Self->{OutputBuffer});
                $Self->{Adapter}->SetTestMessage($Self->{runningTestId}, "Error in File: $Name \n $Self->{OutputBuffer}");
            }
        }

        #SKIPPED tests
        if ($Test == -1) {
            $Self->{Adapter}->SetTestSkipped($Self->{runningTestId});
            $Self->{Adapter}->SetTestMessage($Self->{runningTestId}, 'Test was skipped by user request.');
        }

        #BROKEN tests
        if ($Test == -2) {
            $Self->{Adapter}->SetTestBroken($Self->{runningTestId});
            $Self->{Adapter}->SetTestTrace($Self->{runningTestId}, $Self->{OutputBuffer});
            $Self->{Adapter}->SetTestMessage($Self->{runningTestId}, "Error in File: $Name \n $Self->{OutputBuffer}");
        }
        $Self->_ResetSelfOutputBuffer;
        $Self->{StartTime} = int(time() * 1000);
    }

    my $PrintName = $Name;
    if (length $PrintName > 1000) {
        $PrintName = substr($PrintName, 0, 1000) . "...";
    }

    if ($Self->{Output}->{ASCII} && $Self->{Verbose}) {
        print {$Self->{OriginalSTDOUT}} ($Self->{OutputBuffer} || q{});
    }

    $Self->{TestCount}++;
    if ($Self->{Pretty} && ($Self->{TestCount} == 1 || $Self->{TestCount} % 160 == 1) && !$Self->{Verbose}) {
        print {$Self->{OriginalSTDOUT}} "\n";
    }
    if ($Test) {

        $Self->{TestCountOk}++;

        if ($Self->{Output}->{HTML}) {
            if ($Self->{Verbose}) {
                $Self->{Content} .= "<span class=\"Ok\">OK</span> $Self->{TestCount} - $PrintName<br/>";
            }
            else {
                $TestStep = $Kernel::OM->Get('HTMLUtils')->ToHTML( String => $TestStep );
                $Self->{Content} .= "<span class=\"Ok Pointer\" title=\"($Self->{TestCount}) OK: $TestStep\">&#x25FC</span>";
            }
        }

        if ($Self->{Output}->{ASCII}) {
            if ($Self->{Verbose}) {
                print {$Self->{OriginalSTDOUT}} q{ } . $Self->_Color('green', "\n OK") . " $Self->{TestCount} - $PrintName\n";
            }
            else {
                print {$Self->{OriginalSTDOUT}} $Self->_Color('green', q{.});
            }
        }

        $Self->{XML}->{Test}->{ $Self->{XMLUnit} }->{ Tests }->{ $Self->{TestCount} }->{Result} = 'OK';
        $Self->{XML}->{Test}->{ $Self->{XMLUnit} }->{ Tests }->{ $Self->{TestCount} }->{Name} = $Name;
        return 1;
    }
    else {
        $Self->{XML}->{Test}->{ $Self->{XMLUnit} }->{Result} = 'FAILED';

        $Self->{TestCountNotOk}++;
        if ($Self->{Output}->{HTML}) {
            if ($Self->{Verbose}) {
                $Self->{Content} .= "<span class=\"Failed\">FAILED</span> $Self->{TestCount} - $PrintName<br/>";
            }
            else {
                $TestStep = $Kernel::OM->Get('HTMLUtils')->ToHTML( String => $TestStep );
                $Self->{Content} .= "<span class=\"Failed Pointer\" title=\"($Self->{TestCount}) FAILED: $TestStep\">&#x25FC</span>";
            }
        }

        if ($Self->{Output}->{ASCII}) {
            if ($Self->{Verbose}) {
                print {$Self->{OriginalSTDOUT}} "\n";
                print {$Self->{OriginalSTDOUT}} q{ }
                    . $Self->_Color('red', "FAILED")
                    . " $Self->{TestCount} - $PrintName\n";

                my $TestFailureDetails = $Name;
                $TestFailureDetails =~ s{\(.+\)$}{};
                if (length $TestFailureDetails > 200) {
                    $TestFailureDetails = substr($TestFailureDetails, 0, 200) . "...";
                }

                # Store information about failed tests, but only if we are running in a toplevel unit test object
                #   that is actually processing filed, and not in an embedded object that just runs individual tests.
                if (ref $Self->{NotOkInfo} eq 'ARRAY') {
                    push @{$Self->{NotOkInfo}->[-1]}, sprintf "%s - %s", $Self->{TestCount},
                        $TestFailureDetails;
                }
            }
            else {
                print {$Self->{OriginalSTDOUT}} $Self->_Color('red', "x");
            }
        }
        $Self->{XML}->{Test}->{ $Self->{XMLUnit} }->{ Tests }->{ $Self->{TestCount} }->{Result} = 'FAILED';
        $Self->{XML}->{Test}->{ $Self->{XMLUnit} }->{ Tests }->{ $Self->{TestCount} }->{Name} = $Name;
    }
    return;
}

=item _Color()

this will color the given text (see Term::ANSIColor::color()) if
ANSI output is available and active, otherwise the text stays unchanged.

    my $PossiblyColoredText = $CommandObject->_Color('green', $Text);

=cut

sub _Color {
    my ($Self, $Color, $Text) = @_;

    if ($Self->{Output}->{HTML}) {
        if (!$Self->{CurrentColor}) {
            $Text = "<span style='color:$Color'>$Text";
        }
        elsif ($Self->{CurrentColor} ne $Color) {
            $Text = "</span><span style='color:$Color'>$Text";
        }
        $Self->{CurrentColor} = $Color;
    }

    if ($Self->{Output}->{ASCII} ) {
        return $Text if !$Self->{ANSI};
        return Term::ANSIColor::color($Color) . $Text . Term::ANSIColor::color('reset');
    }

    return $Text;
}

sub _ResetSelfOutputBuffer {
    my ($Self, %Param) = @_;

    $Self->{OutputBuffer} = q{};
    local *STDOUT = *STDOUT;
    local *STDERR = *STDERR;
    if (!$Param{Verbose}) {
        undef * STDOUT;
        undef * STDERR;
        open STDOUT, '>:utf8', \$Self->{OutputBuffer}; ## no critic
        open STDERR, '>:utf8', \$Self->{OutputBuffer}; ## no critic
    }
    return;
}

sub DESTROY {
    my $Self = shift;

    if ($Self->{Output} eq 'HTML') {
        print "</table>\n";
        print "</body>\n";
        print "</html>\n";
    }
    return;
}

1;

=end Internal:

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
