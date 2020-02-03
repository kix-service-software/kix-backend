# --
# Copyright (C) 2006-2019 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
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

    # perform StandardTemplate search
    my %StandardTemplateList = $Kernel::OM->Get('Kernel::System::StandardTemplate')->StandardTemplateList();

	# get already prepared StandardTemplate data from StandardTemplateGet operation
    if ( IsHashRefWithData(\%StandardTemplateList) ) {  	
        my $StandardTemplateGetResult = $Self->ExecOperation(
            OperationType => 'V1::StandardTemplate::StandardTemplateGet',
            Data      => {
                StandardTemplateID => join(',', sort keys %StandardTemplateList),
            }
        );    

        if ( !IsHashRefWithData($StandardTemplateGetResult) || !$StandardTemplateGetResult->{Success} ) {
            return $StandardTemplateGetResult;
        }

        my @StandardTemplateDataList = IsArrayRef($StandardTemplateGetResult->{Data}->{StandardTemplate}) ? @{$StandardTemplateGetResult->{Data}->{StandardTemplate}} : ( $StandardTemplateGetResult->{Data}->{StandardTemplate} );

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
=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-GPL3 for license information (GPL3). If you did not receive this file, see

<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
