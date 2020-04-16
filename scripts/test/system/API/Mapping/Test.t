# --
# Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

use strict;
use warnings;
use utf8;

use vars (qw($Self));

use Kernel::API::Debugger;
use Kernel::API::Mapping;

my $DebuggerObject = Kernel::API::Debugger->new(
    DebuggerConfig => {
        DebugThreshold => 'debug',
        TestMode       => 1,
    },
    WebserviceID      => 1,
    CommunicationType => 'Provider',
);

# create a mapping instance
my $MappingObject = Kernel::API::Mapping->new(
    DebuggerObject => $DebuggerObject,
    MappingConfig  => {
        Type => 'Test',
    },
);
$Self->Is(
    ref $MappingObject,
    'API::Mapping',
    'MappingObject was correctly instantiated',
);

my @MappingTests = (
    {
        Name   => 'Test ToUpper',
        Config => { TestOption => 'ToUpper' },
        Data   => {
            one   => 'one',
            two   => 'two',
            three => 'three',
            four  => 'four',
            five  => 'five',
        },
        ResultData => {
            one   => 'ONE',
            two   => 'TWO',
            three => 'THREE',
            four  => 'FOUR',
            five  => 'FIVE',
        },
        ResultSuccess => 1,
        ConfigSuccess => 1,
    },
    {
        Name   => 'Test ToLower',
        Config => { TestOption => 'ToLower' },
        Data   => {
            one   => 'ONE',
            two   => 'TWO',
            three => 'THREE',
            four  => 'FOUR',
            five  => 'FIVE',
        },
        ResultData => {
            one   => 'one',
            two   => 'two',
            three => 'three',
            four  => 'four',
            five  => 'five',
        },
        ResultSuccess => 1,
        ConfigSuccess => 1,
    },
    {
        Name   => 'Test Empty',
        Config => { TestOption => 'Empty' },
        Data   => {
            one   => 'one',
            two   => 'two',
            three => 'three',
            four  => 'four',
            five  => 'five',
        },
        ResultData => {
            one   => '',
            two   => '',
            three => '',
            four  => '',
            five  => '',
        },
        ResultSuccess => 1,
        ConfigSuccess => 1,
    },
    {
        Name   => 'Test without TestOption',
        Config => { TestOption => '' },
        Data   => {
            one   => 'one',
            two   => 'two',
            three => 'three',
            four  => 'four',
            five  => 'five',
        },
        ResultData    => undef,
        ResultSuccess => 0,
        ConfigSuccess => 1,
    },
    {
        Name   => 'Test with unknown TestOption',
        Config => { TestOption => 'blah' },
        Data   => {
            one   => 'one',
            two   => 'two',
            three => 'three',
            four  => 'four',
            five  => 'five',
        },
        ResultData => {
            one   => 'one',
            two   => 'two',
            three => 'three',
            four  => 'four',
            five  => 'five',
        },
        ResultSuccess => 1,
        ConfigSuccess => 1,
    },
    {
        Name          => 'Test with no Data',
        Config        => { TestOption => 'no data' },
        Data          => undef,
        ResultData    => {},
        ResultSuccess => 1,
        ConfigSuccess => 1,
    },
    {
        Name          => 'Test with empty Data',
        Config        => { TestOption => 'empty data' },
        Data          => {},
        ResultData    => {},
        ResultSuccess => 1,
        ConfigSuccess => 1,
    },
    {
        Name          => 'Test with wrong Data',
        Config        => { TestOption => 'no data' },
        Data          => [],
        ResultData    => undef,
        ResultSuccess => 0,
        ConfigSuccess => 1
    },
    {
        Name          => 'Test with wrong TestOption',
        Config        => { TestOption => 7 },
        Data          => 'something for data',
        ResultData    => undef,
        ResultSuccess => 0,
        ConfigSuccess => 1,
    },
    {
        Name   => 'Test with a wrong TestOption',
        Config => { TestOption => 'ThisShouldBeAWrongTestOption' },
        Data   => {
            one   => 'one',
            two   => 'two',
            three => 'three',
            four  => 'four',
            five  => 'five',
        },
        ResultData => {
            one   => 'one',
            two   => 'two',
            three => 'three',
            four  => 'four',
            five  => 'five',
        },
        ResultSuccess => 1,
        ConfigSuccess => 1,
    },

);

TEST:
for my $Test (@MappingTests) {

    # create a mapping instance
    my $MappingObject = Kernel::API::Mapping->new(
        DebuggerObject => $DebuggerObject,
        MappingConfig  => {
            Type   => 'Test',
            Config => $Test->{Config},
        },
    );
    if ( $Test->{ConfigSuccess} ) {
        $Self->Is(
            ref $MappingObject,
            'API::Mapping',
            $Test->{Name} . ' MappingObject was correctly instantiated',
        );
        next TEST if ref $MappingObject ne 'API::Mapping';
    }
    else {
        $Self->IsNot(
            ref $MappingObject,
            'API::Mapping',
            $Test->{Name} . ' MappingObject was not correctly instantiated',
        );
        next TEST;
    }

    my $MappingResult = $MappingObject->Map(
        Data => $Test->{Data},
    );

    # check if function return correct status
    $Self->Is(
        $MappingResult->{Success},
        $Test->{ResultSuccess},
        $Test->{Name} . ' (Success).',
    );

    # check if function return correct data
    $Self->IsDeeply(
        $MappingResult->{Data},
        $Test->{ResultData},
        $Test->{Name} . ' (Data Structure).',
    );

    if ( !$Test->{ResultSuccess} ) {
        $Self->True(
            $MappingResult->{ErrorMessage},
            $Test->{Name} . ' error message found',
        );
    }

    # instantiate another object
    my $SecondMappingObject = Kernel::API::Mapping->new(
        DebuggerObject => $DebuggerObject,
        MappingConfig  => {
            Type   => 'Test',
            Config => $Test->{Config},
        },
    );

    $Self->Is(
        ref $SecondMappingObject,
        'API::Mapping',
        $Test->{Name} . ' SecondMappingObject was correctly instantiated',
    );
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
