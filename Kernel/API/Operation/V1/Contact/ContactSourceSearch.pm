# --
# Kernel/API/Operation/Contact/ContactSourceSearch.pm - API Contact Search operation backend
# based upon Kernel/API/Operation/Ticket/TicketSearch.pm
# original Copyright (C) 2001-2015 OTRS AG, http://otrs.com/
# Copyright (C) 2006-2016 c.a.p.e. IT GmbH, http://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::API::Operation::V1::Contact::ContactSourceSearch;

use strict;
use warnings;

use Kernel::System::VariableCheck qw( :all );

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::Contact::ContactSourceSearch - API Contact Search Operation backend

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

perform ContactSourceSearch Operation. This will return a Contact ID list.

    my $Result = $OperationObject->Run(
        Data => {
        }
    );

    $Result = {
        Success      => 1,                                # 0 or 1
        Message => '',                               # In case of an error
        Data         => {
            ContactSource => [
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
 
    # perform search
    my %SourceList = $Kernel::OM->Get('Kernel::System::CustomerUser')->CustomerSourceList();

    if (IsHashRefWithData(\%SourceList) ) {        
        my @ResultList;
        foreach my $Key (sort keys %SourceList) {
        	 
            my @AttributeMapping;
            foreach my $Attr (@{$SourceList{$Key}->{Map}}){
                next if !$Attr->{Exposed}; 
                my %AttrDef = %{$Attr};
                
                # remove internal infos
                delete $AttrDef{MappedTo};
                delete $AttrDef{Type};
                delete $AttrDef{Exposed};                

                push(@AttributeMapping, \%AttrDef)   
            }

            push(@ResultList, {
                ID               => $Key,
                Name             => $SourceList{$Key}->{Name},
                ReadOnly         => $SourceList{$Key}->{ReadOnly} ? 1 : 0,
                AttributeMapping => \@AttributeMapping,
            });    
        }

        if ( IsArrayRefWithData(\@ResultList) ) {
            return $Self->_Success(
                ContactSource => \@ResultList,
            )
        }
    }

    # return result
    return $Self->_Success(
        ContactSource => {},
    );
}

1;
