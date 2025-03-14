package Test::BDD::Cucumber::Harness::Allure;

use strict;
use warnings;

use Moo;
use Time::HiRes qw(time);
use Types::Standard qw(Num HashRef ArrayRef FileHandle);

use Kernel::System::UnitTest::AllureAdapter;

extends 'Test::BDD::Cucumber::Harness::Data';

has currentContainerId => (is => 'rw');
has currentTestId => (is => 'rw');
has currentStepStartTime => (is => 'rw', isa => Num);

my $adapter = Kernel::System::UnitTest::AllureAdapter::new();

$adapter->SetExecutorInfo('name' => 'pherkin Cucumber');
$adapter->AddEnvironmentInfoFromSystem;

sub feature {
    my ($Self, $feature) = @_;
    my $feature_ref = {
        object    => $feature,
        scenarios => []
    };
    $Self->current_feature($feature_ref);
}

sub scenario {
    my ($Self, $scenario, $dataset) = @_;
    $Self->currentContainerId($adapter->NewContainer($scenario->{name}));
    $adapter->SetContainerStartTime($Self->currentContainerId, $Self->getEpochInMs);

    $Self->currentTestId($adapter->NewTest($scenario->{name}, '', $Self->currentContainerId));
    $adapter->SetTestStartTime($Self->currentTestId, $Self->getEpochInMs);
    $adapter->SetTestPackage($Self->currentTestId, 'Backend Cucumber API Tests');
    $adapter->SetTestParentSuite($Self->currentTestId, 'Backend Cucumber API Tests');
    $adapter->SetTestSuite($Self->currentTestId, $Self->current_feature->{object}->{name});
    # $adapter->SetTestSubSuite($Self->currentTestId, $adapter->GetContainerNameById($Self->currentContainerId));
}

sub scenario_done {
    my ($Self, $scenario, $dataset) = @_;
    $adapter->SetContainerStopTime($Self->currentContainerId, $Self->getEpochInMs);
    $adapter->SetTestStopTime($Self->currentTestId, $Self->getEpochInMs);
    my $stat = 'passed';

    for my $v (@{$adapter->{Containers}->{$Self->currentContainerId}->{befores}}) {
        if ($v->{status} ne 'passed') {
            $stat = 'failed';
            last;
        }
    }
    for my $v (@{$adapter->{Tests}->{$Self->currentTestId}->{steps}}) {
        if ($v->{status} ne 'passed') {
            $stat = 'failed';
            last;
        }
    }
    $adapter->AddTestProperty($Self->currentTestId, 'status', $stat);
}

sub step {
    my ($Self, $context) = @_;
    $Self->currentStepStartTime($Self->getEpochInMs);
}

sub step_done {
    my ($Self, $context, $result) = @_;

    my $stat = 'unknown';
    ($stat = $result->{result}) =~ s/passing/passed/gi if ($result->{result} eq 'passing');
    ($stat = $result->{result}) =~ s/failing/failed/gi if ($result->{result} eq 'failing');
    ($stat = $result->{result}) =~ s/pending/skipped/gi if ($result->{result} eq 'pending');

    my @testParameters;
    for my $k (keys %{$context->{stash}->{scenario}}) {
        if ($k ne 'Response' && $k ne 'ResponseContent' && $k ne 'SystemInfoArray') {
            my $v = $context->{stash}->{scenario}->{$k};

            if (ref $v eq 'ARRAY') {
                $v = join("; ", @$v);
            }

            if (ref $v eq 'HASH') {
                my %h = %$v;
                $v = join("; ", map {uc("$_: ") . $h{$_}} keys %h);
            }

            push(@testParameters, { 'name', $k, 'value', $v });
        }
    }

    if ($context->{scenario}->{background}) {
        $adapter->AddContainerBefores($Self->currentContainerId, (
            'stop'       => $Self->getEpochInMs,
            'start'      => $Self->currentStepStartTime,
            'name'       => uc($context->{verb}) . " " . $context->{text},
            'status'     => $stat,
            'parameters' => \@testParameters
        ));
    }
    else {
        $adapter->NewTestStep($Self->currentTestId, (
            'stop'       => $Self->getEpochInMs,
            'start'      => $Self->currentStepStartTime,
            'name'       => uc($context->{verb}) . " " . $context->{text},
            'status'     => $stat,
            'parameters' => \@testParameters

        ));
        if ($stat eq 'failed' && !$adapter->GetTestTrace($Self->currentTestId)) {
            $adapter->SetTestTrace($Self->currentTestId, $result->{output});
            $adapter->SetTestMessage($Self->currentTestId, $context->{text});
        }
    }
}

sub getEpochInMs {
    return(int(time() * 1000));
}

sub DESTROY {
    my $dir = $ENV{PHERKIN_ALLURE_OUTDIR} || '.';
    $adapter->CreateResults($dir);
}

1;

