# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::UnitTest::AllureAdapter;

use strict;
use warnings;

use Data::UUID;
use JSON::MaybeXS;

our @ObjectDependencies = ();

sub new {
    my $Self = {};
    $Self->{Containers} = {};
    $Self->{Tests} = {};
    $Self->{Executor} = {};
    $Self->{Environment} = {};
    $Self->{IgnoreSkippedTests} = 0; # if true, don't print skipped tests in Report

    bless($Self);

    return $Self;
}

sub IgnoreSkipped {
    my ($Self, $Value) = @_;

    $Value //= 1;

    return $Self->{IgnoreSkippedTests} = $Value;
}

########################################################################################################################
##################################################CONTAINER SUBROUTINES#################################################
########################################################################################################################

sub NewContainer {
    my ($Self, $Name) = @_;
    return undef if (!$Name);
    my $ContainerId = Data::UUID->new->create_str();
    $Self->{Containers}->{$ContainerId} = {};
    $Self->AddContainerProperty($ContainerId, 'name', $Name);
    $Self->AddContainerProperty($ContainerId, 'uuid', $ContainerId);
    return $ContainerId;
}

sub GetContainerIdByName {
    my ($Self, $Name) = @_;
    return undef if (!$Name);
    for my $ContainerId (keys %{$Self}) {
        return $ContainerId if ($Self->{Containers}->{$ContainerId}->{name} eq $Name);
    }
    return undef;
}

sub GetContainerNameById {
    my ($Self, $id) = @_;
    return undef if (!$id);
    return($Self->{Containers}->{$id}->{name});
}

sub AddContainerProperty {
    my ($Self, $ContainerId, $Property, $Value) = @_;
    return undef if (!$Property || !$ContainerId || !$Value);
    return $Self->{Containers}->{$ContainerId}->{$Property} = $Value;
}

sub SetContainerStartTime {
    my ($Self, $ContainerId, $Value) = @_;
    return undef if (!$ContainerId || !$Value);
    return $Self->{Containers}->{$ContainerId}->{start} = $Value;
}

sub SetContainerStopTime {
    my ($Self, $ContainerId, $Value) = @_;
    return undef if (!$ContainerId || !$Value);
    return $Self->{Containers}->{$ContainerId}->{stop} = $Value;
}

sub AddContainerBefores {
    my ($Self, $ContainerId, %Infos) = @_;
    return undef if (!%Infos || !$ContainerId);
    # delete($Infos{parameters}) if (!$Infos{parameters});
    return push(@{$Self->{Containers}->{$ContainerId}->{befores}}, { %Infos });
}

sub AddContainerAfters {
    my ($Self, $ContainerId, %Infos) = @_;
    return undef if (!%Infos || !$ContainerId);
    # delete($Infos{parameters}) if (!$Infos{parameters});
    return push(@{$Self->{Containers}->{$ContainerId}->{afters}}, { %Infos });
}

sub AddTestToContainer {
    my ($Self, $TestId, $ContainerId) = @_;
    return undef if (!$TestId || !$ContainerId);
    return push(@{$Self->{Containers}->{$ContainerId}->{children}}, $TestId);
}

########################################################################################################################
#####################################################TEST SUBROUTINES###################################################
########################################################################################################################
sub NewTest {
    my ( $Self, $Name, $Status, $ContainerId, $File ) = @_;
    return undef if ( !$Name );

    $Status    //= 'unknown';
    my $TestId = Data::UUID->new->create_str();

    $Self->{Tests}->{$TestId} = {};

    $Self->AddTestProperty($TestId, 'name', $Name);
    $Self->AddTestProperty($TestId, 'status', $Status);
    $Self->AddTestProperty($TestId, 'uuid', $TestId);

    $Self->SetTestSeverityLevel($TestId, 'normal');

    $Self->SetTestFullName($TestId, $File) if ( $File );

    $Self->AddTestToContainer($TestId, $ContainerId) if ( $ContainerId );

    return $TestId;
}

sub GetTesIdByName() {
    my ($Self, $Name) = @_;
    return undef if (!$Name);
    for my $id (keys %{$Self}) {
        return $id if ($Self->{Tests}->{$id}->{name} eq $Name);
    }
    return undef;
}


sub AddTestProperty {
    my ($Self, $TestId, $Property, $Value) = @_;
    return undef if (!$TestId || !$Property || !$Value);
    return $Self->{Tests}->{$TestId}->{$Property} = $Value;
}

sub SetTestFullName {
    my ($Self, $TestId, $Value) = @_;
    return undef if (!$TestId || !$Value);
    return $Self->AddTestProperty($TestId, 'fullname', $Value);
}

sub SetTestBroken {
    my ($Self, $TestId) = @_;
    return undef if (!$TestId);
    return $Self->AddTestProperty($TestId, 'status', 'broken');
}

sub SetTestPassed {
    my ($Self, $TestId) = @_;
    return undef if (!$TestId);
    return $Self->AddTestProperty($TestId, 'status', 'passed');
}

sub SetTestFailed {
    my ($Self, $TestId) = @_;
    return undef if (!$TestId);
    return $Self->AddTestProperty($TestId, 'status', 'failed');
}

sub SetTestSkipped {
    my ($Self, $TestId) = @_;
    return undef if (!$TestId);
    return $Self->AddTestProperty($TestId, 'status', 'skipped');
}

sub SetTestStartTime {
    my ($Self, $TestId, $Value) = @_;
    return undef if (!$TestId || !$Value);
    return $Self->{Tests}->{$TestId}->{'start'} = $Value;
}

sub SetTestStopTime {
    my ($Self, $TestId, $Value) = @_;
    return undef if (!$TestId || !$Value);
    return $Self->{Tests}->{$TestId}->{'stop'} = $Value;
}

sub AddTestParameter {
    my ($Self, $TestId, $Parameter, $Value) = @_;
    return undef if (!$TestId || !$Value || !$Parameter);
    return push(@{$Self->{Tests}->{$TestId}->{'parameters'}}, { 'name', $Parameter, 'value', $Value });
}

sub AddTestLabel {
    my ($Self, $TestId, $Label, $Value) = @_;
    return undef if (!$TestId || !$Value || !$Label);
    return push(@{$Self->{Tests}->{$TestId}->{'labels'}}, { 'name', $Label, 'value', $Value });
}

sub AddTestLink {
    my ($Self, $TestId, $Name, $Url, $Type) = @_;
    return undef if (!$TestId || !$Name || !$Url || !$Type);
    return push(@{$Self->{Tests}->{$TestId}->{'links'}}, { 'name', $Name, 'url', $Url, 'type', $Type });
}

sub AddTestIssue {
    my ($Self, $TestId, $Name, $Url) = @_;
    $Url = "http://jira.intra.cape-it.de:8080/browse/$Name" if ($Name =~ /KIX2018-\d+$/);
    return undef if (!$TestId || !$Name || !$Url);
    return $Self->AddTestLink($TestId, $Name, $Url, 'issue');
}

sub AddTestUserStory {
    my ($Self, $TestId, $Name, $Url) = @_;
    $Url = "http://jira.intra.cape-it.de:8080/browse/$Name" if ($Name =~ /KIX2018-\d+$/);
    return undef if (!$TestId || !$Name || !$Url);
    return $Self->AddTestLink($TestId, $Name, $Url, 'tms');
}

sub SetTestAsFlaky {
    my ($Self, $TestId, $Value) = @_;
    $Value //= 'true';
    return $Self->{Tests}->{$TestId}->{statusDetails}->{flaky} = $Value;
}

sub SetTestAsMuted {
    my ($Self, $TestId, $Value) = @_;
    $Value //= 'true';
    return $Self->{Tests}->{$TestId}->{statusDetails}->{muted} = $Value;
}

sub SetTestAsKnown {
    my ($Self, $TestId, $Value) = @_;
    $Value //= 'true';
    return $Self->{Tests}->{$TestId}->{statusDetails}->{known} = $Value;
}

sub SetTestMessage {
    my ($Self, $TestId, $Value) = @_;
    return undef if (!$Value);
    return $Self->{Tests}->{$TestId}->{statusDetails}->{message} = $Value;
}

sub SetTestTrace {
    my ($Self, $TestId, $Value) = @_;
    return undef if (!$Value);
    return $Self->{Tests}->{$TestId}->{statusDetails}->{trace} = $Value;
}

sub GetTestTrace {
    my ($Self, $TestId) = @_;
    return undef if (!$TestId);
    return $Self->{Tests}->{$TestId}->{statusDetails}->{trace};
}

sub SetTestSeverityLevel {
    use constant SEVERITY_LEVEL => qw/blocker critical normal minor trivial/;
    my ($Self, $TestId, $Value) = @_;
    return undef if (!$TestId);
    return undef if (grep ( /^$Value$/, SEVERITY_LEVEL ));
    return $Self->AddTestLabel($TestId, 'severity', $Value);
}

sub SetTestSuite {
    my ($Self, $TestId, $Value) = @_;
    return undef if (!$TestId || !$Value);
    return $Self->AddTestLabel($TestId, 'suite', $Value);
}

sub SetTestSubSuite {
    my ($Self, $TestId, $Value) = @_;
    return undef if (!$TestId || !$Value);
    return $Self->AddTestLabel($TestId, 'subSuite', $Value);
}

sub SetTestParentSuite {
    my ($Self, $TestId, $Value) = @_;
    return undef if (!$TestId || !$Value);
    return $Self->AddTestLabel($TestId, 'parentSuite', $Value);
}

sub SetTestPackage {
    my ($Self, $TestId, $Value) = @_;
    return undef if (!$TestId || !$Value);
    return $Self->AddTestLabel($TestId, 'package', $Value);
}

sub SetTestDescription {
    my ($Self, $TestId, $Value) = @_;
    return undef if (!$TestId || !$Value);
    return $Self->AddTestProperty($TestId, 'description', $Value);
}

sub AddTestAttachment {
    #TODO: Implement method  AddTestAttachment
}

sub AddEnvironmentInfo {
    my ($Self, $env_key, $env_value) = @_;
    return undef if (!$env_key || !defined($env_value));
    $Self->{Environment}->{$env_key} = $env_value;
    return 1;
}

sub AddEnvironmentInfoFromSystem {
    my ($Self, %EnvKeys) = @_;
    if (!%EnvKeys) {
        for my $k (keys %ENV) {
            $Self->AddEnvironmentInfo($k, $ENV{$k});
        }
    }
    else {
        for my $k (keys %EnvKeys) {
            $Self->AddEnvironmentInfo($k, $ENV{$k}) if ($ENV{$k});
        }
        return 1;
    }
}

sub NewTestStep {
    my ($Self, $TestId, %Infos) = @_;
    return undef if (!$TestId || !%Infos);
    # delete($Infos{parameters}) if (!$Infos{parameters});
    return push(@{$Self->{Tests}->{$TestId}->{'steps'}}, { %Infos });
}


########################################################################################################################
#################################################MISCELLANEOUS SUBROUTINES##############################################
########################################################################################################################

sub SetExecutorInfo {
    my ($Self, %Param) = @_;
    $Param{name} //= 'Perl Unit Tester';
    $Param{buildName} //= '';
    $Param{buildUrl} //= 'http://git.intra.cape-it.de/Softwareentwicklung/KIXng/backend/app/tree/' . $Param{buildName};

    $Self->{Executor}->{name} = $Param{name};
    $Self->{Executor}->{buildName} = $Param{buildName};
    $Self->{Executor}->{buildUrl} = $Param{buildUrl};
}

sub CreateResults {
    my ($Self, $Directory) = @_;

    File::Path::rmtree($Directory);
    File::Path::make_path($Directory);

    my $fh;
    open $fh, ">", "$Directory/environment.properties" or die("ERROR: Allure Adapter cannot write file $Directory/environment.properties");;
    for my $k (keys %{$Self->{Environment}}) {
        print $fh "$k=$Self->{Environment}->{$k}\n";
    }
    close($fh);

    open $fh, ">", "$Directory/executor.json" or die("ERROR: Allure Adapter cannot write file $Directory/executor.json");;
    print $fh encode_json($Self->{Executor});
    close($fh);

    for my $container (keys %{$Self->{Containers}}) {
        open $fh, ">", "$Directory/$container-container.json" or die("ERROR: Allure Adapter cannot write file $Directory/$container-container.json");;
        print $fh encode_json($Self->{Containers}->{$container});
    }
    close($fh);

    for my $test (keys %{$Self->{Tests}}) {
        if (!(($Self->{IgnoreSkippedTests} && $Self->{Tests}->{$test}->{status} eq 'skipped'))) {
            open $fh, ">", "$Directory/$test-result.json" or die("ERROR: Allure Adapter cannot write file $Directory/$test-result.json");;
            print $fh encode_json($Self->{Tests}->{$test});
        }
    }
    close($fh);
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
