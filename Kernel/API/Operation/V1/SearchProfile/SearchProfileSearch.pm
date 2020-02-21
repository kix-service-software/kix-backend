# --
# Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::SearchProfile::SearchProfileSearch;

use strict;
use warnings;

use Kernel::API::Operation::V1::SearchProfile::SearchProfileGet;
use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::SearchProfile::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::SearchProfile::SearchProfileSearch - API SearchProfile Search Operation backend

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

perform SearchProfileSearch Operation. This will return a SearchProfile ID list.

    my $Result = $OperationObject->Run(
        Data => {
        }
    );

    $Result = {
        Success => 1,                                # 0 or 1
        Code    => '',                          # In case of an error
        Message => '',                          # In case of an error
        Data    => {
            SearchProfile => [
                {},
                {}
            ]
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # prepare search if given
    my %SearchParam;
    if ( IsArrayRefWithData($Self->{Search}->{SearchProfile}->{AND}) ) {
        foreach my $SearchItem ( @{$Self->{Search}->{SearchProfile}->{AND}} ) {
            # ignore everything that we don't support in the core DB search (the rest will be done in the generic API Searching)
            next if ($SearchItem->{Field} !~ /^(Type|UserLogin|UserType|SubscribeProfileID|Category)$/g);
            next if ($SearchItem->{Operator} ne 'EQ');

            $SearchParam{$SearchItem->{Field}} = $SearchItem->{Value};
        }
    }

    # perform SearchProfile search
    my @SearchProfileList = $Kernel::OM->Get('Kernel::System::SearchProfile')->SearchProfileList(
        %SearchParam
    );

	# get already prepared SearchProfile data from SearchProfileGet operation
    if ( IsArrayRefWithData(\@SearchProfileList) ) {  	
        my $SearchProfileGetResult = $Self->ExecOperation(
            OperationType => 'V1::SearchProfile::SearchProfileGet',
            Data      => {
                SearchProfileID => join(',', @SearchProfileList),
            }
        );    

        if ( !IsHashRefWithData($SearchProfileGetResult) || !$SearchProfileGetResult->{Success} ) {
            return $SearchProfileGetResult;
        }

        my @SearchProfileDataList = IsArrayRef($SearchProfileGetResult->{Data}->{SearchProfile}) ? @{$SearchProfileGetResult->{Data}->{SearchProfile}} : ( $SearchProfileGetResult->{Data}->{SearchProfile} );

        if ( IsArrayRefWithData(\@SearchProfileDataList) ) {
            return $Self->_Success(
                SearchProfile => \@SearchProfileDataList,
            )
        }
    }

    # return result
    return $Self->_Success(
        SearchProfile => [],
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
