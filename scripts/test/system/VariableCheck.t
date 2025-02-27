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

# get needed objects
my $ConfigObject = $Kernel::OM->Get('Config');

# standard variables
my $ExpectedTestResults = {};
my $TestVariables       = {};

my $RunTests = sub {
    my ( $FunctionName, $Variables, $ExpectedResults ) = @_;

    for my $VariableKey ( sort keys %{$Variables} ) {

        # variable names defined for this function should return 1
        if ( $ExpectedResults->{$VariableKey} ) {
            $Self->True(
                ( \&$FunctionName )->( $Variables->{$VariableKey} ) || 0,
                "VariableCheck $FunctionName True ($VariableKey)",
            );
        }

        # variable names not defined for this function should return undef
        else {
            $Self->False(
                ( \&$FunctionName )->( $Variables->{$VariableKey} ) || 0,
                "VariableCheck $FunctionName False ($VariableKey)",
            );
        }
    }

    # all functions should only accept a single param
    $Self->False(
        ( \&$FunctionName )->( undef, undef ) || 0,
        "VariableCheck $FunctionName False (Array)",
    );

    return;
};

# test variables for all types
my @CommonVariables = (
    ArrayRef      => [0],
    ArrayRefEmpty => [],
    HashRef       => { 0 => 0 },
    HashRefEmpty  => {},
    ObjectRef     => $ConfigObject,
    RefRef        => \\0,
    ScalarRef     => \0,
    String        => 0,
    StringEmpty   => '',
    Undef         => undef,
);

# test variables for numerical checks
my @NumberVariables = (
    Number1  => 1,
    Number2  => 99,
    Number3  => -987654321,
    Number4  => '.00000001',
    Number5  => '-.9999999',
    Number6  => '9.999e+99',
    Number7  => '-9.999e+99',
    Number8  => '1.111e-99',
    Number9  => '-9.999e-99',
    Number10 => '1.e1',
    Number11 => '1.E2',
    Number12 => 'a.E2',
    Number13 => '1.E2.2',
    Number14 => '1.-e1',
    Number15 => '1€+1',
);

# IsArrayRefWithData
$ExpectedTestResults = {
    ArrayRef => 1,
};
$TestVariables = {
    @CommonVariables,
};
$RunTests->( 'IsArrayRefWithData', $TestVariables, $ExpectedTestResults );

# IsHashRefWithData
$ExpectedTestResults = {
    HashRef => 1,
};
$TestVariables = {
    @CommonVariables,
};
$RunTests->( 'IsHashRefWithData', $TestVariables, $ExpectedTestResults );

# IsInteger
$ExpectedTestResults = {
    String  => 1,
    Number1 => 1,
    Number2 => 1,
    Number3 => 1,
};
$TestVariables = {
    @CommonVariables,
    @NumberVariables,
};
$RunTests->( 'IsInteger', $TestVariables, $ExpectedTestResults );

# IsMD5Sum
$ExpectedTestResults = {
    MD5Sum1 => 1,
    MD5Sum2 => 1,
    MD5Sum3 => 1,
};
$TestVariables = {
    @CommonVariables,
    @NumberVariables,
    MD5Sum1 => '0123456789abcdef0123456789ABCDEF',
    MD5Sum2 => '00000000000000000000000000000000',
    MD5Sum3 => 'ffffffffffffffffffffffffffffffff',
    MD5Sum4 => '0000000000000000000000000000000g',
    MD5Sum5 => '0123456789abcdef',
    MD5Sum6 => '000000000000000000000000000000000',
    MD5Sum7 => '000000000000000000-00000000000000',
};
$RunTests->( 'IsMD5Sum', $TestVariables, $ExpectedTestResults );

# IsNumber
$ExpectedTestResults = {
    String   => 1,
    Number1  => 1,
    Number2  => 1,
    Number3  => 1,
    Number4  => 1,
    Number5  => 1,
    Number6  => 1,
    Number7  => 1,
    Number8  => 1,
    Number9  => 1,
    Number10 => 1,
    Number11 => 1,
};
$TestVariables = {
    @CommonVariables,
    @NumberVariables,
};
$RunTests->( 'IsNumber', $TestVariables, $ExpectedTestResults );

# IsPositiveInteger
$ExpectedTestResults = {
    Number1 => 1,
    Number2 => 1,
};
$TestVariables = {
    @CommonVariables,
    @NumberVariables,
};
$RunTests->( 'IsPositiveInteger', $TestVariables, $ExpectedTestResults );

# IsString
$ExpectedTestResults = {
    String      => 1,
    StringEmpty => 1,
    String1     => 1,
    String2     => 1,
    String3     => 1,
    String4     => 1,
    String5     => 1,
};
$TestVariables = {
    @CommonVariables,
    String1 => '123',
    String2 => 'abc',
    String3 => 'äöüß€ис',
    String4 => ' ',
    String5 => "\t",
};
$RunTests->( 'IsString', $TestVariables, $ExpectedTestResults );

# IsStringWithData
$ExpectedTestResults = {
    String  => 1,
    String1 => 1,
    String2 => 1,
    String3 => 1,
    String4 => 1,
    String5 => 1,
};
$TestVariables = {
    @CommonVariables,
    String1 => '123',
    String2 => 'abc',
    String3 => 'äöüß€ис',
    String4 => ' ',
    String5 => "\t",
};
$RunTests->( 'IsStringWithData', $TestVariables, $ExpectedTestResults );

#
# DataIsDifferent tests
#

my $Undef = undef;

my %Hash1 = (
    key1 => '1',
    key2 => '2',
    key3 => {
        test  => 2,
        test2 => [
            1, 2, 3,
        ],
    },
    key4 => undef,
);

my %Hash2 = %Hash1;
$Hash2{AdditionalKey} = 1;

my @List1 = ( 1, 2, 3, );
my @List2 = (
    1,
    2,
    4,
    [ 1, 2, 3 ],
    {
        test => 'test',
    },
);

my $Scalar1 = 1;
my $Scalar2 = {
    test => [ 1, 2, 3 ],
};

my $Count = 0;
for my $Value1 ( \%Hash1, \%Hash2, \@List1, \@List2, \$Scalar1, \$Scalar2, $Undef ) {
    $Count++;
    $Self->Is(
        scalar DataIsDifferent(
            Data1 => $Value1,
            Data2 => $Value1
        ),
        scalar undef,
        'DataIsDifferent() - Test ' . $Count,
    );

    my $Count2 = 0;
    VALUE2: for my $Value2 ( \%Hash1, \%Hash2, \@List1, \@List2, \$Scalar1, \$Scalar2, $Undef ) {
        $Count2++;
        if ( $Count == $Count2 ) {
            next VALUE2;
        }

        $Self->Is(
            scalar DataIsDifferent(
                Data1 => $Value1,
                Data2 => $Value2
            ),
            1,
            'DataIsDifferent() - Test ' . $Count . ':' . $Count2,
        );
    }
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
