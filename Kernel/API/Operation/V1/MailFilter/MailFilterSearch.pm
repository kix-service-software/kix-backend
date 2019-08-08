# --
# Kernel/API/Operation/MailFilter/MailFilterSearch.pm - API MailFilter Search operation backend
# Copyright (C) 2006-2019 c.a.p.e. IT GmbH, http://www.cape-it.de
#
# written/edited by:
# * Ricky(dot)Kaiser(at)cape(dash)it(dot)de
#
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::API::Operation::V1::MailFilter::MailFilterSearch;

use strict;
use warnings;

use Kernel::API::Operation::V1::MailFilter::MailFilterGet;
use Kernel::System::VariableCheck qw(:all);

use base qw(Kernel::API::Operation::V1::Common);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::MailFilter::MailFilterSearch - API MailFilter Search Operation backend

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

perform MailFilterSearch Operation. This will return a MailFilter list.

    my $Result = $OperationObject->Run(
        Data => { }
    );

    $Result = {
        Success => 1,                           # 0 or 1
        Code    => '',                          # In case of an error
        Message => '',                          # In case of an error
        Data    => {
            MailFilter => [
                {},
                {}
            ]
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # perform MailFilter search
    my %MailFilterList = $Kernel::OM->Get('Kernel::System::PostMaster::Filter')->FilterList();

    # get already prepared MailFilter data from MailFilterGet operation
    if ( IsHashRefWithData( \%MailFilterList ) ) {
        my $MailFilterGetResult = $Self->ExecOperation(
            OperationType => 'V1::MailFilter::MailFilterGet',
            Data          => {
                MailFilterID => join( ',', sort keys %MailFilterList )
                }
        );

        if (
            !IsHashRefWithData($MailFilterGetResult)
            || !$MailFilterGetResult->{Success}
            ) {
            return $MailFilterGetResult;
        }

        my @MailFilterDataList = IsArrayRefWithData( $MailFilterGetResult->{Data}->{MailFilter} )
            ? @{ $MailFilterGetResult->{Data}->{MailFilter} }
            : ( $MailFilterGetResult->{Data}->{MailFilter} );

        if ( IsArrayRefWithData( \@MailFilterDataList ) ) {
            return $Self->_Success( MailFilter => \@MailFilterDataList, );
        }
    }

    # return result
    return $Self->_Success( MailFilter => [], );
}

1;
