# --
# Kernel/API/Operation/V1/Service/ServiceGet.pm - API Service Get operation backend
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

package Kernel::API::Operation::V1::Service::ServiceGet;

use strict;
use warnings;

use MIME::Base64;

use Kernel::System::VariableCheck qw(IsArrayRefWithData IsHashRefWithData IsStringWithData);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::Service::ServiceGet - API Service Get Operation backend

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

usually, you want to create an instance of this
by using Kernel::API::Operation::V1::Service::ServiceGet->new();

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
    $Self->{Config} = $Kernel::OM->Get('Kernel::Config')->Get('API::Operation::V1::Service::ServiceGet');

    return $Self;
}

=item Run()

perform ServiceGet Operation. This function is able to return
one or more ticket entries in one call.

    my $Result = $OperationObject->Run(
        Data => {
            ServiceID => 123       # comma separated in case of multiple or arrayref (depending on transport)
        },
    );

    $Result = {
        Success      => 1,                           # 0 or 1
        Code         => '',                          # In case of an error
        Message      => '',                          # In case of an error
        Data         => {
            Service => [
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
            Code    => 'Webservice.InvalidConfiguration',
            Message => $Result->{Message},
        );
    }

    # prepare data
    $Result = $Self->PrepareData(
        Data       => $Param{Data},
        Parameters => {
            'ServiceID' => {
                Type     => 'ARRAY',
                DataType => 'NUMERIC',
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

    my @ServiceList;

    # start state loop
    Service:    
    foreach my $ServiceID ( @{$Param{Data}->{ServiceID}} ) {

        # get the Service data
        my %ServiceData = $Kernel::OM->Get('Kernel::System::Service')->ServiceGet(
            ServiceID => $ServiceID,
            IncidentState => $Param{Data}->{include}->{IncidentState} || 0,
            UserID  => $Self->{Authorization}->{UserID},
        );

        if ( !IsHashRefWithData( \%ServiceData ) ) {
            return $Self->_Error(
                Code    => 'Object.NotFound',
                Message => "No data found for ServiceID $ServiceID.",
            );
        }
        
        my @ParentServiceParts = split(/::/, $ServiceData{Name});
        
        # include SubServices if requested
        if ( $Param{Data}->{include}->{SubServices} ) {
            my %SubServiceList = $Kernel::OM->Get('Kernel::System::Service')->GetAllSubServices(
                ServiceID => $ServiceID,
            );

            # filter direct children
            my @DirectSubServices;
            foreach my $SubServiceID ( sort keys %SubServiceList ) {
                my @ServiceParts = split(/::/, $SubServiceList{$SubServiceID});
                next if scalar(@ServiceParts) > scalar(@ParentServiceParts)+1;
                push(@DirectSubServices, $SubServiceID)
            }

            $ServiceData{SubServices} = \@DirectSubServices;
        }

        # move NameShort to Name and delete NameShort
        $ServiceData{Name} = $ServiceData{NameShort};
        delete $ServiceData{NameShort};

        if ( !$ServiceData{ParentID} ) {
            $ServiceData{ParentID} = undef;
        }
        if ( $Param{Data}->{include}->{IncidentState} ){
            # extract attributes to subhash
            my %Tmphash;
            for my $Key ( qw(CurInciStateID CurInciState CurInciStateType) ) {
                $Tmphash{$Key} = $ServiceData{$Key};
                delete $ServiceData{$Key};
            }
            $ServiceData{IncidentState} = \%Tmphash;
        }
        
        # add
        push(@ServiceList, \%ServiceData);
    }

    if ( scalar(@ServiceList) == 1 ) {
        return $Self->_Success(
            Service => $ServiceList[0],
        );    
    }

    # return result
    return $Self->_Success(
        Service => \@ServiceList,
    );
}


1;
