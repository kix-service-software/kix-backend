# --
# Modified version of the work: Copyright (C) 2006-2024 KIX Service Software GmbH, http://www.kixdesk.com
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::VariableCheck;

use strict;
use warnings;

use Data::Validate::IP qw(is_ipv4 is_ipv6);

use Exporter qw(import);
our %EXPORT_TAGS = (    ## no critic
    all => [
        'IsArrayRef',
        'IsArrayRefWithData',
        'IsBase64',
        'IsCodeRef',
        'IsHashRef',
        'IsHashRefWithData',
        'IsInteger',
        'IsMD5Sum',
        'IsNotEqual',
        'IsNumber',
        'IsObject',
        'IsPositiveInteger',
        'IsString',
        'IsStringWithData',
        'DataIsDifferent',
    ],
);
Exporter::export_ok_tags('all');

=head1 NAME

Kernel::System::VariableCheck - helper functions to check variables

=head1 SYNOPSIS

Provides several helper functions to check variables, e.g.
if a variable is a string, a hash ref etc. This is helpful for
input data validation, for example.

Call this module directly without instantiating:

    use Kernel::System::VariableCheck qw(:all);             # export all functions into the calling package
    use Kernel::System::VariableCheck qw(IsHashRefWitData); # export just one function

    if (IsHashRefWithData($HashRef)) {
        ...
    }

The functions can be grouped as follows:

=head2 Variable type checks

=over 4

=item * L</IsString()>

=item * L</IsStringWithData()>

=item * L</IsArrayRefWithData()>

=item * L</IsHashRefWithData()>

=back

=head2 Number checks

=over 4

=item * L</IsNumber()>

=item * L</IsInteger()>

=item * L</IsPositiveInteger()>

=back

=head2 Special data format checks

=over 4

=item * L</IsMD5Sum()>

=back

=head1 PUBLIC INTERFACE

=over 4

=cut

=item IsString()

test supplied data to determine if it is a string - an empty string is valid

returns 1 if data matches criteria or undef otherwise

    my $Result = IsString(
        'abc', # data to be tested
    );

=cut

sub IsString {
    my $TestData = $_[0];

    return if scalar @_ ne 1;
    return if ref $TestData;
    return if !defined $TestData;

    return 1;
}

=item IsStringWithData()

test supplied data to determine if it is a non zero-length string

returns 1 if data matches criteria or undef otherwise

    my $Result = IsStringWithData(
        'abc', # data to be tested
    );

=cut

sub IsStringWithData {
    my $TestData = $_[0];

    return if !IsString(@_);
    return if $TestData eq '';

    return 1;
}

=item IsArrayRef()

test supplied data to determine if it is an array reference

returns 1 if data matches criteria or undef otherwise

    my $Result = IsArrayRef(
        [ # data to be tested
            'key',
            ...
        ],
    );

=cut

sub IsArrayRef {
    my $TestData = $_[0];

    return ref $TestData eq 'ARRAY';
}

=item IsArrayRefWithData()

test supplied data to determine if it is an array reference and contains at least one key

returns 1 if data matches criteria or undef otherwise

    my $Result = IsArrayRefWithData(
        [ # data to be tested
            'key',
            ...
        ],
    );

=cut

sub IsArrayRefWithData {
    my $TestData = $_[0];

    return if scalar @_ ne 1;
    return if ref $TestData ne 'ARRAY';
    return if !@{$TestData};

    return 1;
}

=item IsCodeRef()

test supplied data to determine if it is a code reference

returns 1 if data matches criteria or undef otherwise

    my $Result = IsCodeRef(
        ...
    );

=cut

sub IsCodeRef {
    my $TestData = $_[0];

    return ref $TestData eq 'CODE';
}

=item IsHashRef()

test supplied data to determine if it is an hash reference

returns 1 if data matches criteria or undef otherwise

    my $Result = IsHashRef(
        [ # data to be tested
            'key',
            ...
        ],
    );

=cut

sub IsHashRef {
    my $TestData = $_[0];

    return ref $TestData eq 'HASH';
}

=item IsHashRefWithData()

test supplied data to determine if it is a hash reference and contains at least one key/value pair

returns 1 if data matches criteria or undef otherwise

    my $Result = IsHashRefWithData(
        { # data to be tested
            'key' => 'value',
            ...
        },
    );

=cut

sub IsHashRefWithData {
    my $TestData = $_[0];

    return if scalar @_ ne 1;
    return if ref $TestData ne 'HASH';
    return if !%{$TestData};

    return 1;
}

=item IsNumber()

test supplied data to determine if it is a number
(integer, floating point, possible exponent, positive or negative)

returns 1 if data matches criteria or undef otherwise

    my $Result = IsNumber(
        999, # data to be tested
    );

=cut

sub IsNumber {
    my $TestData = $_[0];

    return if !IsStringWithData(@_);
    return if $TestData !~ m{
        \A [-]? (?: \d+ | \d* [.] \d+ | (?: \d+ [.]? \d* | \d* [.] \d+ ) [eE] [-+]? \d* ) \z
    }xms;

    return 1;
}

=item IsInteger()

test supplied data to determine if it is an integer (only digits, positive or negative)

returns 1 if data matches criteria or undef otherwise

    my $Result = IsInteger(
        999, # data to be tested
    );

=cut

sub IsInteger {
    my $TestData = $_[0];

    return if !IsStringWithData(@_);
    return if $TestData !~ m{ \A [-]? (?: 0 | [1-9] \d* ) \z }xms;

    return 1;
}

=item IsPositiveInteger()

test supplied data to determine if it is a positive integer (only digits and positive)

returns 1 if data matches criteria or undef otherwise

    my $Result = IsPositiveInteger(
        999, # data to be tested
    );

=cut

sub IsPositiveInteger {
    my $TestData = $_[0];

    return if !IsStringWithData(@_);
    return if $TestData !~ m{ \A [1-9] \d* \z }xms;

    return 1;
}

=item IsMD5Sum()

test supplied data to determine if it is an md5sum (32 hex characters)

returns 1 if data matches criteria or undef otherwise

    my $Result = IsMD5Sum(
        '6f1ed002ab5595859014ebf0951522d9', # data to be tested
    );

=cut

sub IsMD5Sum {
    my $TestData = $_[0];

    return if !IsStringWithData(@_);
    return if $TestData !~ m{ \A [\da-f]{32} \z }xmsi;

    return 1;
}

=item DataIsDifferent()

compares two data structures with each other. Returns 1 if
they are different, undef otherwise.

Data parameters need to be passed by reference and can be SCALAR,
ARRAY or HASH.

    my $DataIsDifferent = DataDiff(
        Data1 => \$Data1,
        Data2 => \$Data2,
    );

=cut

sub DataIsDifferent {
    my (%Param) = @_;

    # check needed stuff
    for (qw(Data1 Data2)) {
        return if ( !defined $Param{$_} );
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
                    return 1 if DataIsDifferent(
                        Data1 => $A[$Count],
                        Data2 => $B[$Count]
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
                return 1 if DataIsDifferent(
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
        return 1 if DataIsDifferent(
            Data1 => ${ $Param{Data1} },
            Data2 => ${ $Param{Data2} }
        );
        return;
    }

    return 1;
}

=item IsBase64()

test supplied string to determine if it's a base64 coded content

returns 1 if data matches criteria or undef otherwise

    my $Result = IsBase64(scalar);

=cut

sub IsBase64 {
    my $TestData = $_[0];

    return if $TestData !~ /^[A-Za-z0-9+\/=]+$/;
    
    return if length($TestData) % 4 != 0;

    return 1;
}

=item IsObject()

test supplied data to determine if it's on object of the given package

returns 1 if data matches criteria or undef otherwise

    my $Result = IsObject(data, package);

=cut

sub IsObject {
    my $TestData = $_[0];
    my $Package = $_[1];

    return ref $TestData eq $Package;
}

1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<http://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
COPYING for license information (AGPL). If you did not receive this file, see

<http://www.gnu.org/licenses/agpl.txt>.

=cut
