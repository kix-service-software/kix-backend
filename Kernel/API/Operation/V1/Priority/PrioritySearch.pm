# --
# Kernel/API/Operation/Priority/PriorityCreate.pm - API Priority Create operation backend
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

package Kernel::API::Operation::V1::Priority::PrioritySearch;

use strict;
use warnings;

use Kernel::API::Operation::V1::Priority::PriorityGet;
use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::Priority::PrioritySearch - API Priority Search Operation backend

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

perform PrioritySearch Operation. This will return a Priority ID list.

    my $Result = $OperationObject->Run(
        Data => {
        }
    );

    $Result = {
        Success => 1,                           # 0 or 1
        Message => '',                          # In case of an error
        Data    => {
            PriorityID => [ 1, 2, 3, 4 ],
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    my $Result = $Self->Init(
        WebserviceID => $Self->{WebserviceID},
    );

    if ( !$Result->{Success} ) {
        $Self->_Error(
            Code    => 'Webservice.InvalidConfiguration',
            Message => $Result->{Message},
        );
    }
use Data::Dumper;
print STDERR "Param".Dumper(\%Param);
    # prepare data
    $Result = $Self->PrepareData(
        Data       => $Param{Data},
    );

    # check result
    if ( !$Result->{Success} ) {
        return $Self->_Error(
            Code    => 'Operation.PrepareDataError',
            Message => $Result->{Message},
        );
    }

    # perform Priority search
    my %PriorityList = $Kernel::OM->Get('Kernel::System::Priority')->PriorityList(
        Valid => 1,
    );
use Data::Dumper;
print STDERR "PrioList".Dumper(\%PriorityList);
    if (IsHashRefWithData(\%PriorityList)) {
        my $PriorityGetResult = $Self->ExecOperation(
            OperationType => 'V1::Priority::PriorityGet',
            Data      => {
                PriorityID => join(',', sort keys %PriorityList),
            }
        );
 
        if ( !IsHashRefWithData($PriorityGetResult) || !$PriorityGetResult->{Success} ) {
            return $PriorityGetResult;
        }

        my @PriorityDataList = IsArrayRefWithData($PriorityGetResult->{Data}->{Priority}) ? @{$PriorityGetResult->{Data}->{Priority}} : ( $PriorityGetResult->{Data}->{Priority} );

        if ( IsArrayRefWithData(\@PriorityDataList) ) {
            return $Self->_Success(
                Priority => \@PriorityDataList,
            )
        }
    }

    # return result
    return $Self->_Success(
        Priority => {},
    );
}

1;