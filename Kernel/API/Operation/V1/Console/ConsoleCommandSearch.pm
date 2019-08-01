# --
# Kernel/API/Operation/ConsoleCommand/ConsoleCommandCreate.pm - API ConsoleCommand Create operation backend
# Copyright (C) 2006-2016 c.a.p.e. IT GmbH, http://www.cape-it.de
#
# written/edited by:
# * Rene(dot)Boehm(at)cape(dash)it(dot)de
# 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::API::Operation::V1::Console::ConsoleCommandSearch;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::Console::ConsoleCommandSearch - API ConsoleCommand Search Operation backend

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

usually, you want to create an instance of this
by using Kernel::API::Operation->new();

=cut

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};
    bless( $Self, $Type );

    # check needed objects
    for my $Needed (qw(DebuggerObject WebserviceID)) {
        if ( !$Param{$Needed} ) {
            return $Self->_Error(
                Code    => 'Operation.InternalError',
                Message => "Got no $Needed!"
            );
        }

        $Self->{$Needed} = $Param{$Needed};
    }

    return $Self;
}

=item Run()

perform ConsoleCommandSearch Operation. This will return a ConsoleCommand list.

    my $Result = $OperationObject->Run(
        Data => {
        }
    );

    $Result = {
        Success => 1,                                # 0 or 1
        Code    => '',                          # In case of an error
        Message => '',                          # In case of an error
        Data    => {
            ConsoleCommand => [
                {},
                {}
            ]
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # get command list
    my @CommandList = $Kernel::OM->Get('Kernel::System::Console')->CommandList();

	# get already prepared Command data from CommandGet operation
    if ( IsArrayRefWithData(\@CommandList) ) {  	
        my $CommandGetResult = $Self->ExecOperation(
            OperationType => 'V1::Console::ConsoleCommandGet',
            Data      => {
                Command => join(',', sort @CommandList),
            }
        );    

        if ( !IsHashRefWithData($CommandGetResult) || !$CommandGetResult->{Success} ) {
            return $CommandGetResult;
        }

        my @CommandDataList = IsArrayRefWithData($CommandGetResult->{Data}->{ConsoleCommand}) ? @{$CommandGetResult->{Data}->{ConsoleCommand}} : ( $CommandGetResult->{Data}->{ConsoleCommand} );

        if ( IsArrayRefWithData(\@CommandDataList) ) {
            return $Self->_Success(
                ConsoleCommand => \@CommandDataList,
            )
        }
    }

    # return result
    return $Self->_Success(
        ConsoleCommand => [],
    );
}

1;