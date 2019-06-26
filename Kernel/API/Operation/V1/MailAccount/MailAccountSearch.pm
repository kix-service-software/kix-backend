# --
# Kernel/API/Operation/MailAccount/MailAccountSearch.pm - API MailAccount Search operation backend
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

package Kernel::API::Operation::V1::MailAccount::MailAccountSearch;

use strict;
use warnings;

use Kernel::API::Operation::V1::MailAccount::MailAccountGet;
use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::MailAccount::MailAccountSearch - API MailAccount Search Operation backend

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

perform MailAccountSearch Operation. This will return a MailAccount list.

    my $Result = $OperationObject->Run(
        Data => {
        }
    );

    $Result = {
        Success => 1,                                # 0 or 1
        Code    => '',                          # In case of an error
        Message => '',                          # In case of an error
        Data    => {
            MailAccount => [
                {},
                {}
            ]
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # perform MailAccount search
    my %MailAccountList = $Kernel::OM->Get('Kernel::System::MailAccount')->MailAccountList();

    # get already prepared MailAccount data from MailAccountGet operation
    if ( IsHashRefWithData( \%MailAccountList ) ) {
        my $MailAccountGetResult = $Self->ExecOperation(
            OperationType => 'V1::MailAccount::MailAccountGet',
            Data          => {
                MailAccountID => join( ',', sort keys %MailAccountList ),
                }
        );

        if ( !IsHashRefWithData($MailAccountGetResult) || !$MailAccountGetResult->{Success} ) {
            return $MailAccountGetResult;
        }

        my @MailAccountDataList = IsArrayRefWithData( $MailAccountGetResult->{Data}->{MailAccount} )
            ? @{ $MailAccountGetResult->{Data}->{MailAccount} }
            : ( $MailAccountGetResult->{Data}->{MailAccount} );

        if ( IsArrayRefWithData( \@MailAccountDataList ) ) {
            return $Self->_Success(
                MailAccount => \@MailAccountDataList,
            );
        }
    }

    # return result
    return $Self->_Success(
        MailAccount => [],
    );
}

1;
