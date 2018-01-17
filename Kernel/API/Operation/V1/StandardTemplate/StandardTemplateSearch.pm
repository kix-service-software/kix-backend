# --
# Kernel/API/Operation/StandardTemplate/StandardTemplateSearch.pm - API StandardTemplate Search operation backend
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

package Kernel::API::Operation::V1::StandardTemplate::StandardTemplateSearch;

use strict;
use warnings;

use Kernel::API::Operation::V1::StandardTemplate::StandardTemplateGet;
use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::StandardTemplate::StandardTemplateSearch - API StandardTemplate Search Operation backend

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

perform StandardTemplateSearch Operation. This will return a StandardTemplate ID list.

    my $Result = $OperationObject->Run(
        Data => {
        }
    );

    $Result = {
        Success => 1,                                # 0 or 1
        Code    => '',                          # In case of an error
        Message => '',                          # In case of an error
        Data    => {
            StandardTemplate => [
                {},
                {}
            ]
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
            Code    => 'WebService.InvalidConfiguration',
            Message => $Result->{Message},
        );
    }

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

    # perform StandardTemplate search
    my %StandardTemplateList = $Kernel::OM->Get('Kernel::System::StandardTemplate')->StandardTemplateList();

	# get already prepared StandardTemplate data from StandardTemplateGet operation
    if ( IsHashRefWithData(\%StandardTemplateList) ) {  	
        my $StandardTemplateGetResult = $Self->ExecOperation(
            OperationType => 'V1::StandardTemplate::StandardTemplateGet',
            Data      => {
                TemplateID => join(',', sort keys %StandardTemplateList),
            }
        );    

        if ( !IsHashRefWithData($StandardTemplateGetResult) || !$StandardTemplateGetResult->{Success} ) {
            return $StandardTemplateGetResult;
        }

        my @StandardTemplateDataList = IsArrayRefWithData($StandardTemplateGetResult->{Data}->{StandardTemplate}) ? @{$StandardTemplateGetResult->{Data}->{StandardTemplate}} : ( $StandardTemplateGetResult->{Data}->{StandardTemplate} );

        if ( IsArrayRefWithData(\@StandardTemplateDataList) ) {
            return $Self->_Success(
                StandardTemplate => \@StandardTemplateDataList,
            )
        }
    }

    # return result
    return $Self->_Success(
        StandardTemplate => [],
    );
}

1;