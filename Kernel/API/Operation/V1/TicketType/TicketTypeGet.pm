# --
# Kernel/API/Operation/V1/TicketType/TicketTypeGet.pm - API TicketType Get operation backend
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

package Kernel::API::Operation::V1::TicketType::TicketTypeGet;

use strict;
use warnings;

use MIME::Base64;

use Kernel::System::VariableCheck qw(IsArrayRefWithData IsHashRefWithData IsStringWithData);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=item new()

usually, you want to create an instance of this
by using Kernel::API::Operation::V1::TicketType::TicketTypeGet->new();

=cut

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};
    bless( $Self, $Type );

    # check needed objects
    for my $Needed (qw(DebuggerObject WebserviceID)) {
        if ( !$Param{$Needed} ) {
            return {
                Success      => 0,
                ErrorMessage => "Got no $Needed!",
            };
        }

        $Self->{$Needed} = $Param{$Needed};
    }

    # get config for this screen
    $Self->{Config} = $Kernel::OM->Get('Kernel::Config')->Get('API::Operation::V1::TicketTypeGet');

    return $Self;
}

=item Run()

perform event get operation. This will return an event.
get Tickettypes attributes

    my $Result = $OperationObject->Run(
        Data => {
            Authorization => {
                ...
            },
            TicketTypeID => 123       # comma separated in case of multiple or arrayref (depending on transport)
        },
    );

    $Result = {
        Success      => 1,                                # 0 or 1
        ErrorMessage => '',                               # In case of an error
        Data         => {
            User => [
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
        $Self->ReturnError(
            ErrorCode    => 'Webservice.InvalidConfiguration',
            ErrorMessage => $Result->{ErrorMessage},
        );
    }

    # prepare data
    $Result = $Self->PrepareData(
        Data       => $Param{Data},
        Parameters => {
            'TicketTypeID' => {
                Type     => 'ARRAY',
                Required => 1
            }                
        }
    );

    # check result
    if ( !$Result->{Success} ) {
        return $Self->ReturnError(
            ErrorCode    => 'TicketTypeGet.PrepareDataError',
            ErrorMessage => $Result->{ErrorMessage},
        );
    }

    my $ErrorMessage = '';
    my @TicketTypeList;

    # start type loop
    TYPE:    
    foreach my $TicketTypeID ( @{$Param{Data}->{TicketTypeID}} ) {

        # get the user data
        my %TicketTypeData = $Kernel::OM->Get('Kernel::System::Type')->TypeGet(
            ID => $TicketTypeID,
        );

        if ( !IsHashRefWithData( \%TicketTypeData ) ) {

            $ErrorMessage = 'Could not get TicketType data'
                . ' in Kernel::API::Operation::V1::TicketType::TicketTypeGet::Run()';

            return $Self->ReturnError(
                ErrorCode    => 'TicketTypeGet.NotValidUserID',
                ErrorMessage => "TicketTypeGet: $ErrorMessage",
            );
        }
        
        # add
        push(@TicketTypeList, \%TicketTypeData);
    }

    if ( !scalar(@TicketTypeList) ) {
        $ErrorMessage = 'Could not get TicketType data'
            . ' in Kernel::API::Operation::V1::TicketType::TicketTypeGet::Run()';

        return $Self->ReturnError(
            ErrorCode    => 'TicketTypeGet.NotUserData',
            ErrorMessage => "TicketTypeGet: $ErrorMessage",
        );

    }

    if ( scalar(@TicketTypeList) == 1 ) {
        return $Self->ReturnSuccess(
            TicketType => $TicketTypeList[0],
        );    
    }

    return $Self->ReturnSuccess(
        TicketType => \@TicketTypeList,
    );
}

1;



