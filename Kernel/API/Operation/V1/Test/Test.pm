# --
# Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::Test::Test;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::Test - API Operation Test backend

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

usually, you want to create an instance of this
by using Kernel::API::Operation::V1->new();

=cut

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};
    bless( $Self, $Type );

    # check needed objects
    for my $Needed (qw(DebuggerObject)) {
        if ( !$Param{$Needed} ) {
            return {
                Success      => 0,
                ErrorMessage => "Got no $Needed!"
            };
        }

        $Self->{$Needed} = $Param{$Needed};
    }

    return $Self;
}

=item Run()

perform the selected test Operation. This will return the data that
was handed to the function or return a variable data if 'TestError' and
'ErrorData' params are sent.

    my $Result = $OperationObject->Run(
        Data => {                               # data payload before Operation
            ...
        },
    );

    $Result = {
        Success         => 1,                   # 0 or 1
        ErrorMessage    => '',                  # in case of error
        Data            => {                    # result data payload after Operation
            ...
        },
    };

    my $Result = $OperationObject->Run(
        Data => {                               # data payload before Operation
            TestError   => 1,
            ErrorData   => {
                ...
            },
        },
    );

    $Result = {
        Success         => 0,                                   # it always return 0
        ErrorMessage    => 'Error message for error code: 1',   # including the 'TestError' param
        Data            => {
            ErrorData   => {                                    # same data was sent as
                                                                # 'ErrorData' param

            },
            ...
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # check data - only accept undef or hash ref
    if ( defined $Param{Data} && ref $Param{Data} ne 'HASH' ) {

        return $Self->{DebuggerObject}->Error(
            Summary => 'Got Data but it is not a hash ref in Operation Test backend)!'
        );
    }

    if ( defined $Param{Data} && $Param{Data}->{TestError} ) {

        return {
            Success      => 0,
            ErrorMessage => "Error message for error code: $Param{Data}->{TestError}",
            Data         => {
                ErrorData => $Param{Data}->{ErrorData},
            },
        };
    }

    # copy data
    my $ReturnData;

    if ( ref $Param{Data} eq 'HASH' ) {
        $ReturnData = \%{ $Param{Data} };
    }
    else {
        $ReturnData = undef;
    }

    # return result
    return {
        Success => 1,
        Data    => $ReturnData,
    };
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
