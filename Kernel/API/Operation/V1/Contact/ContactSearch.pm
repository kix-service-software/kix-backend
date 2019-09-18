# --
# Copyright (C) 2006-2019 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::Contact::ContactSearch;

use strict;
use warnings;

use Kernel::System::VariableCheck qw( :all );

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::Contact::ContactSearch - API Contact Search Operation backend

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

perform ContactSearch Operation. This will return a Contact ID list.

    my $Result = $OperationObject->Run(
        Data => {
        }
    );

    $Result = {
        Success      => 1,                                # 0 or 1
        Message => '',                               # In case of an error
        Data         => {
            Contact => [
                {
                },
                {                    
                }
            ],
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;
    my %ContactList;

    # prepare search if given
    my %SearchParam;
    if ( IsHashRefWithData( $Self->{Search}->{Contact} ) ) {
        foreach my $SearchType ( keys %{ $Self->{Search}->{Contact} } ) {
            my %SearchTypeResult;
            foreach my $SearchItem ( @{ $Self->{Search}->{Contact}->{$SearchType} } ) {
                my $Value = $SearchItem->{Value};

                if ( $SearchItem->{Operator} eq 'CONTAINS' ) {
                    $Value = '*' . $Value . '*';
                }
                elsif ( $SearchItem->{Operator} eq 'STARTSWITH' ) {
                    $Value = $Value . '*';
                }
                if ( $SearchItem->{Operator} eq 'ENDSWITH' ) {
                    $Value = '*' . $Value;
                }

                if ( $SearchItem->{Field} =~ /^(PrimaryOrganisationID|Login)$/g ) {
                    $SearchParam{ $SearchItem->{Field} } = $Value;
                }
                elsif ( $SearchItem->{Field} =~ /^(ValidID)$/g ) {
                    $SearchParam{Valid} = $Value;
                }
                else {
                    $SearchParam{Search} = $Value;
                }

                # perform Contact search
                my %SearchResult = $Kernel::OM->Get('Kernel::System::Contact')->ContactSearch(
                    %SearchParam,
                    Valid => 0
                );

                if ( $SearchType eq 'AND' ) {
                    if ( !%SearchTypeResult ) {
                        %SearchTypeResult = %SearchResult;
                    }
                    else {
                        # remove all IDs from type result that we don't have in this search
                        foreach my $Key ( keys %SearchTypeResult ) {
                            delete $SearchTypeResult{$Key} if !exists $SearchResult{$Key};
                        }
                    }
                }
                elsif ( $SearchType eq 'OR' ) {

                    # merge results
                    %SearchTypeResult = (
                        %SearchTypeResult,
                        %SearchResult,
                    );
                }
            }

            if ( !%ContactList ) {
                %ContactList = %SearchTypeResult;
            }
            else {
                # combine both results by AND
                # remove all IDs from type result that we don't have in this search
                foreach my $Key ( keys %ContactList ) {
                    delete $ContactList{$Key} if !exists $SearchTypeResult{$Key};
                }
            }
        }
    }
    else {
        # perform Contact search without any search params
        %ContactList = $Kernel::OM->Get('Kernel::System::Contact')->ContactSearch(
            Valid => 0
        );
    }

    if ( IsHashRefWithData( \%ContactList ) ) {

        # get already prepared Contact data from ContactGet operation
        my $ContactGetResult = $Self->ExecOperation(
            OperationType => 'V1::Contact::ContactGet',
            Data          => {
                ContactID => join( ',', sort keys %ContactList ),
                }
        );
        if ( !IsHashRefWithData($ContactGetResult) || !$ContactGetResult->{Success} ) {
            return $ContactGetResult;
        }

        my @ResultList = IsArrayRefWithData( $ContactGetResult->{Data}->{Contact} ) ? @{ $ContactGetResult->{Data}->{Contact} } : ( $ContactGetResult->{Data}->{Contact} );

        if ( IsArrayRefWithData( \@ResultList ) ) {
            return $Self->_Success(
                Contact => \@ResultList,
                )
        }
    }

    # return result
    return $Self->_Success(
        Contact => [],
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
