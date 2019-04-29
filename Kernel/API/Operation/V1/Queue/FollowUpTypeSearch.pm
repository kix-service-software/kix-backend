# --
# Kernel/API/Operation/Role/RoleCreate.pm - API Role Create operation backend
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

package Kernel::API::Operation::V1::Queue::FollowUpTypeSearch;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::Queue::FollowUpTypeSearch - API FollowUp Type Search Operation backend

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

perform FollowUpTypeSearch Operation. This will return a FollowUpType list.

    my $Result = $OperationObject->Run(
        Data => {
            RoleID => 123
        }
    );

    $Result = {
        Success => 1,                                # 0 or 1
        Code    => '',                          # In case of an error
        Message => '',                          # In case of an error
        Data    => {
            FollowUpType => [
                {},
                {}
            ]
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # perform search
    my %FollowUpTypeList = $Kernel::OM->Get('Kernel::System::Queue')->FollowUpTypeList();

	# get prepare 
    if ( IsHashRefWithData(\%FollowUpTypeList) ) {  	

        my @Result;
        foreach my $TypeID ( sort keys %FollowUpTypeList ) {
            my %TypeData = $Kernel::OM->Get('Kernel::System::Queue')->FollowUpTypeGet(
                ID => $TypeID,
            );

            push(@Result, \%TypeData);
        }

        return $Self->_Success(
            FollowUpType => \@Result,
        )
    }

    # return result
    return $Self->_Success(
        FollowUpType => [],
    );
}

1;