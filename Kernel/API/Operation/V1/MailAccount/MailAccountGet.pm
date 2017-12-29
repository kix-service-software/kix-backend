# --
# Kernel/API/Operation/V1/MailAccount/MailAccountGet.pm - API MailAccount Get operation backend
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

package Kernel::API::Operation::V1::MailAccount::MailAccountGet;

use strict;
use warnings;

use MIME::Base64;

use Kernel::System::VariableCheck qw(IsArrayRefWithData IsHashRefWithData IsStringWithData);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::MailAccount::MailAccountGet - API MailAccount Get Operation backend

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

usually, you want to create an instance of this
by using Kernel::API::Operation::V1::MailAccount::MailAccountGet->new();

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

    # get config for this screen
    $Self->{Config} = $Kernel::OM->Get('Kernel::Config')->Get('API::Operation::V1::MailAccount::MailAccountGet');

    return $Self;
}

=item Run()

perform MailAccountGet Operation. This function is able to return
one or more ticket entries in one call.

    my $Result = $OperationObject->Run(
        Data => {
            MailAccountID => 123       # comma separated in case of multiple or arrayref (depending on transport)
        },
    );

    $Result = {
        Success      => 1,                           # 0 or 1
        Code         => '',                          # In case of an error
        Message      => '',                          # In case of an error
        Data         => {
            MailAccount => [
                {
                    ...
                },
                {
                    ...
                },
            ]
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # init webservice
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
        Parameters => {
            'MailAccountID' => {
                Type     => 'ARRAY',
                Required => 1
            }                
        }
    );

    # check result
    if ( !$Result->{Success} ) {
        return $Self->_Error(
            Code    => 'Operation.PrepareDataError',
            Message => $Result->{Message},
        );
    }

    my @MailAccountList;

    # start state loop
    MailAccount:    
    foreach my $MailAccountID ( @{$Param{Data}->{MailAccountID}} ) {

        # get the MailAccount data
        my %MailAccountData = $Kernel::OM->Get('Kernel::System::MailAccount')->MailAccountGet(
            ID => $MailAccountID,
        );

        if ( !IsHashRefWithData( \%MailAccountData ) ) {
            return $Self->_Error(
                Code    => 'Object.NotFound',
                Message => "No data found for MailAccountID $MailAccountID.",
            );
        }
        
        # add
        if ( $MailAccountData{ID} ){
            push(@MailAccountList, \%MailAccountData);
        }
    }

    if ( scalar(@MailAccountList) == 1 ) {
        return $Self->_Success(
            MailAccount => $MailAccountList[0],
        );    
    }

    # return result
    return $Self->_Success(
        MailAccount => \@MailAccountList,
    );
}

1;
