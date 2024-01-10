# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::UnitTest::Method;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = (
    'Config',
);

=head1 NAME

Kernel::System::UnitTest::Method - test method extension for UnitTest module

=head1 SYNOPSIS

All test methods functions.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item True()

test for a scalar value that evaluates to true.

Send a scalar value to this function along with the test's name:

    $UnitTestObject->True(1, 'Test Name');

    $UnitTestObject->True($ParamA, 'Test Name');

Internally, the function receives this value and evaluates it to see
if it's true, returning 1 in this case or undef, otherwise.

    my $TrueResult = $UnitTestObject->True(
        $TestValue,
        'Test Name',
    );

=cut

sub True {
    my ( $Self, $True, $Name ) = @_;

    $True = 0 if ($True && $True =~ /^\d+$/ && $True < 0 && $Self->{Output}->{ASCII});

    if ( !$Name ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Need Name! E. g. True(\$A, \'Test Name\')!'
        );
        $Self->_Print( 0, 'ERROR: Need Name! E. g. True(\$A, \'Test Name\')' );
        return;
    }

    if ($True) {
        $Self->_Print( 1, $Name );
        return 1;
    }
    else {
        $Self->_Print( 0, $Name );
        return;
    }
}

=item False()

test for a scalar value that evaluates to false.

It has the same interface as L</True()>, but tests
for a false value instead.

=cut

sub False {
    my ( $Self, $False, $Name ) = @_;

    $False = 0 if ($False && $False =~ /^\d+$/ && $False < 0 && $Self->{Output}->{ASCII});

    if ( !$Name ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Need Name! E. g. False(\$A, \'Test Name\')!'
        );
        $Self->_Print( 0, 'ERROR: Need Name! E. g. False(\$A, \'Test Name\')' );
        return;
    }

    if ( !$False ) {
        $Self->_Print( 1, $Name );
        return 1;
    }
    else {
        $Self->_Print( 0, $Name );
        return;
    }
}

=item Is()

compares two scalar values for equality.

To this function you must send a pair of scalar values to compare them,
and the name that the test will take, this is done as shown in the examples
below.

    $UnitTestObject->Is($A, $B, 'Test Name');

Returns 1 if the values were equal, or undef otherwise.

    my $IsResult = $UnitTestObject->Is(
        $ValueFromFunction,      # test data
        1,                       # expected value
        'Test Name',
    );

=cut

sub Is {
    my ( $Self, $Test, $ShouldBe, $Name ) = @_;

    $Test = 0 if ($Test && $Test =~ /^\d+$/ && $Test < 0 && $Self->{Output}->{ASCII});

    if ( !$Name ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Need Name! E. g. Is(\$A, \$B, \'Test Name\')!'
        );
        $Self->_Print( 0, 'ERROR: Need Name! E. g. Is(\$A, \$B, \'Test Name\')' );
        return;
    }

    if ( !defined $Test && !defined $ShouldBe ) {
        $Self->_Print( 1, "$Name (is 'undef')" );
        return 1;
    }
    elsif ( !defined $Test && defined $ShouldBe ) {
        $Self->_Print( 0, "$Name (is 'undef' should be '$ShouldBe')" );
        return;
    }
    elsif ( defined $Test && !defined $ShouldBe ) {
        $Self->_Print( 0, "$Name (is '$Test' should be 'undef')" );
        return;
    }
    elsif ( $Test eq $ShouldBe ) {
        $Self->_Print( 1, "$Name (is '$ShouldBe')" );
        return 1;
    }
    else {
        $Self->_Print( 0, "$Name (is '$Test' should be '$ShouldBe')" );
        return;
    }
}

=item IsNot()

compares two scalar values for inequality.

It has the same interface as L</Is()>, but tests
for inequality instead.

=cut

sub IsNot {
    my ( $Self, $Test, $ShouldBe, $Name ) = @_;

    $Test = 0 if ($Test && $Test =~ /^\d+$/ && $Test < 0 && $Self->{Output}->{ASCII});

    if ( !$Name ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Need Name! E. g. IsNot(\$A, \$B, \'Test Name\')!'
        );
        $Self->_Print( 0, 'ERROR: Need Name! E. g. IsNot(\$A, \$B, \'Test Name\')' );
        return;
    }

    if ( !defined $Test && !defined $ShouldBe ) {
        $Self->_Print( 0, "$Name (is 'undef') but should not be 'undef'" );
        return;
    }
    elsif ( !defined $Test && defined $ShouldBe ) {
        $Self->_Print( 1, "$Name (is 'undef')" );
        return 1;
    }
    elsif ( defined $Test && !defined $ShouldBe ) {
        $Self->_Print( 1, "$Name (is '$Test')" );
        return 1;
    }
    if ( $Test ne $ShouldBe ) {
        $Self->_Print( 1, "$Name (is '$Test')" );
        return 1;
    }
    else {
        $Self->_Print( 0, "$Name (is '$Test' should not be '$ShouldBe')" );
        return;
    }
}

=item IsDeeply()

compares complex data structures for equality.

To this function you must send the references to two data structures to be compared,
and the name that the test will take, this is done as shown in the examples
below.

    $UnitTestObject-> IsDeeply($ParamA, $ParamB, 'Test Name');

Where $ParamA and $ParamB must be references to a structure (scalar, list or hash).

Returns 1 if the data structures are the same, or undef otherwise.

    my $IsDeeplyResult = $UnitTestObject->IsDeeply(
        \%ResultHash,           # test data
        \%ExpectedHash,         # expected value
        'Dummy Test Name',
    );

=cut

sub IsDeeply {
    my ( $Self, $Test, $ShouldBe, $Name ) = @_;

    $Test = 0 if ($Test && $Test =~ /^\d+$/ && $Test < 0 && $Self->{Output}->{ASCII});

    if ( !$Name ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Need Name! E. g. Is(\$A, \$B, \'Test Name\')!'
        );
        $Self->_Print( 0, 'ERROR: Need Name! E. g. Is(\$A, \$B, \'Test Name\')' );
        return;
    }

    if ( !defined $Test && !defined $ShouldBe ) {
        $Self->_Print( 1, "$Name (is 'undef')" );
        return 1;
    }
    elsif ( !defined $Test && defined $ShouldBe ) {
        $Self->_Print( 0, "$Name (is 'undef' should be defined)" );
        return;
    }
    elsif ( defined $Test && !defined $ShouldBe ) {
        $Self->_Print( 0, "$Name (is defined should be 'undef')" );
        return;
    }

    my $Diff = $Self->_DataDiff(
        Data1 => $Test,
        Data2 => $ShouldBe,
    );
    if ( !$Diff ) {
        $Self->_Print( 1, "$Name matches expected value" );
        return 1;
    }
    else {
        my $ShouldBeDump = $Kernel::OM->Get('Main')->Dump($ShouldBe);
        my $TestDump     = $Kernel::OM->Get('Main')->Dump($Test);
        $Self->_Print( 0, "$Name (is '$TestDump' should be '$ShouldBeDump')" );
        return;
    }
}

=item IsNotDeeply()

compares two data structures for inequality.

It has the same interface as L</IsDeeply()>, but tests
for inequality instead.

=cut

sub IsNotDeeply {
    my ( $Self, $Test, $ShouldBe, $Name ) = @_;

    $Test = 0 if ($Test && $Test =~ /^\d+$/ && $Test < 0 && $Self->{Output}->{ASCII});

    if ( !$Name ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Need Name! E. g. IsNot(\$A, \$B, \'Test Name\')!'
        );
        $Self->_Print( 0, 'ERROR: Need Name! E. g. IsNot(\$A, \$B, \'Test Name\')' );
        return;
    }

    my $Diff = $Self->_DataDiff(
        Data1 => $Test,
        Data2 => $ShouldBe,
    );

    if ( !defined $Test && !defined $ShouldBe ) {
        $Self->_Print( 0, "$Name (is 'undef')" );
        return;
    }
    elsif ( !defined $Test && defined $ShouldBe ) {
        $Self->_Print( 1, "$Name (is 'undef')" );
        return 1;
    }
    elsif ( defined $Test && !defined $ShouldBe ) {
        $Self->_Print( 1, "$Name (differs from expected value)" );
        return 1;
    }

    if ($Diff) {
        $Self->_Print( 1, "$Name (The structures are not equal.)" );
        return 1;
    }
    else {

        #        $Self->_Print( 0, "$Name (matches the expected value)" );
        my $TestDump = $Kernel::OM->Get('Main')->Dump($Test);
        $Self->_Print( 0, "$Name (The structures are equal: '$TestDump')" );

        return;
    }
}

=item ContainedIn()

checks if a list contains a value.

To this function you must send a value, an array-ref,
and the name that the test will take, this is done as shown in the examples
below.

    $UnitTestObject->ContainedIn($A, $B, 'Test Name');

Returns 1 if the list contains the value, or undef otherwise.

    my $ContainedInResult = $UnitTestObject->ContainedIn(
        $ValueFromFunction,      # test data
        [ value1, value2, ...],  # list with values
        'Test Name',
    );

=cut

sub ContainedIn {
    my ( $Self, $Test, $List, $Name ) = @_;

    $Test = 0 if ($Test && $Test =~ /^\d+$/ && $Test < 0 && $Self->{Output}->{ASCII});

    if ( !$Name ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Need Name! E. g. Is(\$A, \$B, \'Test Name\')!'
        );
        $Self->_Print( 0, 'ERROR: Need Name! E. g. Is(\$A, \$B, \'Test Name\')' );
        return;
    }

    if ( !IsArrayRefWithData($List) ) {
        $Self->_Print( 0, "$Name (list is not given or empty)" );
        return;
    } elsif ( !defined $Test ) {
        $Self->_Print( 0, "$Name (value is 'undef')" );
        return;
    }

    # get checkable but ignore undef
    my %Values = map { defined $_ ? ($_ => 1) : () } @{$List};
    if ( $Values{$Test} ) {
        $Self->_Print( 1, "$Name (list contains value \"$Test\")" );
        return 1;
    } else {
        $Self->_Print( 0, "$Name (list does not contain value \"$Test\" but should)" );
        return;
    }
}

=item NotContainedIn()

checks if a list does not contain a value.

To this function you must send a value, an array-ref,
and the name that the test will take, this is done as shown in the examples
below.

    $UnitTestObject->NotContainedIn($A, $B, 'Test Name');

Returns 1 if the list does not contain the value, or undef otherwise.

    my $NotContainedInResult = $UnitTestObject->NotContainedIn(
        $ValueFromFunction,      # test data
        [ value1, value2, ...],  # list with values
        'Test Name',
    );

=cut

sub NotContainedIn {
    my ( $Self, $Test, $List, $Name ) = @_;

    $Test = 0 if ($Test && $Test =~ /^\d+$/ && $Test < 0 && $Self->{Output}->{ASCII});

    if ( !$Name ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Need Name! E. g. Is(\$A, \$B, \'Test Name\')!'
        );
        $Self->_Print( 0, 'ERROR: Need Name! E. g. Is(\$A, \$B, \'Test Name\')' );
        return;
    }

    if ( !IsArrayRefWithData($List) ) {
        $Self->_Print( 1, "$Name (list is not given or empty)" );
        return 1;
    } elsif ( !defined $Test ) {
        $Self->_Print( 1, "$Name (value is 'undef')" );
        return 1;
    }

    # get checkable but ignore undef
    my %Values = map { defined $_ ? ($_ => 1) : () } @{$List};
    if ( $Values{$Test} ) {
        $Self->_Print( 0, "$Name (list contains value \"$Test\" but should not)" );
        return;
    } else {
        $Self->_Print( 1, "$Name (list does not contain value \"$Test\")" );
        return 1;
    }
}

=begin Internal:

=cut

=item _DataDiff()

compares two data structures with each other. Returns 1 if
they are different, undef otherwise.

Data parameters need to be passed by reference and can be SCALAR,
ARRAY or HASH.

    my $DataIsDifferent = $UnitTestObject->_DataDiff(
        Data1 => \$Data1,
        Data2 => \$Data2,
    );

=cut

sub _DataDiff {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(Data1 Data2)) {
        if ( !defined $Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    # ''
    if ( ref $Param{Data1} eq '' && ref $Param{Data2} eq '' ) {

        # do nothing, it's ok
        return if !defined $Param{Data1} && !defined $Param{Data2};

        # return diff, because its different
        return 1 if !defined $Param{Data1} || !defined $Param{Data2};

        # return diff, because its different
        return 1 if $Param{Data1} ne $Param{Data2};

        # return, because its not different
        return;
    }

    # SCALAR
    if ( ref $Param{Data1} eq 'SCALAR' && ref $Param{Data2} eq 'SCALAR' ) {

        # do nothing, it's ok
        return if !defined ${ $Param{Data1} } && !defined ${ $Param{Data2} };

        # return diff, because its different
        return 1 if !defined ${ $Param{Data1} } || !defined ${ $Param{Data2} };

        # return diff, because its different
        return 1 if ${ $Param{Data1} } ne ${ $Param{Data2} };

        # return, because its not different
        return;
    }

    # ARRAY
    if ( ref $Param{Data1} eq 'ARRAY' && ref $Param{Data2} eq 'ARRAY' ) {
        my @A = @{ $Param{Data1} };
        my @B = @{ $Param{Data2} };

        # check if the count is different
        return 1 if $#A ne $#B;

        # compare array
        COUNT:
        for my $Count ( 0 .. $#A ) {

            # do nothing, it's ok
            next COUNT if !defined $A[$Count] && !defined $B[$Count];

            # return diff, because its different
            return 1 if !defined $A[$Count] || !defined $B[$Count];

            if ( $A[$Count] ne $B[$Count] ) {
                if ( ref $A[$Count] eq 'ARRAY' || ref $A[$Count] eq 'HASH' ) {
                    return 1 if $Self->_DataDiff(
                        Data1 => $A[$Count],
                        Data2 => $B[$Count]
                    );
                    next COUNT;
                }
                elsif ( ref $A[$Count] eq 'SCALAR' && ref $B[$Count] eq 'SCALAR' ) {
                    return 1 if $Self->_DataDiff(
                        Data1 => ${ $A[$Count] },
                        Data2 => ${ $A[$Count] }
                    );
                    next COUNT;
                }
                return 1;
            }
        }
        return;
    }

    # HASH
    if ( ref $Param{Data1} eq 'HASH' && ref $Param{Data2} eq 'HASH' ) {
        my %A = %{ $Param{Data1} };
        my %B = %{ $Param{Data2} };

        # compare %A with %B and remove it if checked
        KEY:
        for my $Key ( sort keys %A ) {

            # Check if both are undefined
            if ( !defined $A{$Key} && !defined $B{$Key} ) {
                delete $A{$Key};
                delete $B{$Key};
                next KEY;
            }

            # return diff, because its different
            return 1 if !defined $A{$Key} || !defined $B{$Key};

            if ( $A{$Key} eq $B{$Key} ) {
                delete $A{$Key};
                delete $B{$Key};
                next KEY;
            }

            # return if values are different
            if ( ref $A{$Key} eq 'ARRAY' || ref $A{$Key} eq 'HASH' ) {
                return 1 if $Self->_DataDiff(
                    Data1 => $A{$Key},
                    Data2 => $B{$Key}
                );
                delete $A{$Key};
                delete $B{$Key};
                next KEY;
            }
            return 1;
        }

        # check rest
        return 1 if %B;
        return;
    }

    if ( ref $Param{Data1} eq 'REF' && ref $Param{Data2} eq 'REF' ) {
        return 1 if $Self->_DataDiff(
            Data1 => ${ $Param{Data1} },
            Data2 => ${ $Param{Data2} }
        );
        return;
    }

    return 1;
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
