# --
# Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::Service::ServiceGet;

use strict;
use warnings;

use MIME::Base64;

use Kernel::System::VariableCheck qw(:all);

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

=item ParameterDefinition()

define parameter preparation and check for this operation

    my $Result = $OperationObject->ParameterDefinition(
        Data => {
            ...
        },
    );

    $Result = {
        ...
    };

=cut

sub ParameterDefinition {
    my ( $Self, %Param ) = @_;

    return {
        'ServiceID' => {
            Type     => 'ARRAY',
            DataType => 'NUMERIC',
            Required => 1
        }                
    }
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

    my @ServiceList;

    # start loop
    foreach my $ServiceID ( @{$Param{Data}->{ServiceID}} ) {

        # get the Service data
        my %ServiceData = $Kernel::OM->Get('Kernel::System::Service')->ServiceGet(
            ServiceID => $ServiceID,
            IncidentState => $Param{Data}->{include}->{IncidentState} || 0,
            UserID  => $Self->{Authorization}->{UserID},
        );

        if ( !IsHashRefWithData( \%ServiceData ) ) {
            return $Self->_Error(
                Code => 'Object.NotFound',
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

        # save full service name
        $ServiceData{Fullname} = $ServiceData{Name};

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

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-GPL3 for license information (GPL3). If you did not receive this file, see

<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
