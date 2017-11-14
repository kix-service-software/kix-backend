# --
# Kernel/API/Operation/SLA/SLAUpdate.pm - API SLA Update operation backend
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

package Kernel::API::Operation::V1::SLA::SLAUpdate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(IsArrayRefWithData IsHashRefWithData IsStringWithData);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::SLA::SLAUpdate - API SLA Create Operation backend

=head1 SYNOPSIS

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
    for my $Needed (qw( DebuggerObject WebserviceID )) {
        if ( !$Param{$Needed} ) {
            return $Self->_Error(
                Code    => 'Operation.InternalError',
                Message => "Got no $Needed!"
            );
        }

        $Self->{$Needed} = $Param{$Needed};
    }

    $Self->{Config} = $Kernel::OM->Get('Kernel::Config')->Get('API::Operation::V1::SLAUpdate');

    return $Self;
}

=item Run()

perform SLAUpdate Operation. This will return the updated TypeID.

    my $Result = $OperationObject->Run(
        Data => {
            SLAID => 123,
            SLA  => {
                Name                    => '...',
                Calendar                => '...',        # (optional)
                FirstResponseTime       => 120,          # (optional)
                FirstResponseNotify     => 60,           # (optional) notify agent if first response escalation is 60% reached
                UpdateTime              => 180,          # (optional)
                UpdateNotify            => 80,           # (optional) notify agent if update escalation is 80% reached
                SolutionTime            => 580,          # (optional)
                SolutionNotify          => 80,           # (optional) notify agent if solution escalation is 80% reached
                ValidID                 => 1,
                Comment                 => '...',        # (optional)
                TypeID                  => 2,
                MinTimeBetweenIncidents => 3443,     # (optional)
            },
        },
    );
    

    $Result = {
        Success     => 1,                       # 0 or 1
        Code        => '',                      # in case of error
        Message     => '',                      # in case of error
        Data        => {                        # result data payload after Operation
            SLAID  => 123,                     # ID of the updated SLA 
        },
    };
   
=cut


sub Run {
    my ( $Self, %Param ) = @_;

    # init websla
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
        Data         => $Param{Data},
        Parameters   => {
            'SLAID' => {
                Required => 1
            },
            'SLA' => {
                Type => 'HASH',
                Required => 1
            },
        }        
    );

    # check result
    if ( !$Result->{Success} ) {
        return $Self->_Error(
            Code    => 'Operation.PrepareDataError',
            Message => $Result->{Message},
        );
    }

    # isolate SLA parameter
    my $SLA = $Param{Data}->{SLA};

    # remove leading and trailing spaces
    for my $Attribute ( sort keys %{$SLA} ) {
        if ( ref $Attribute ne 'HASH' && ref $Attribute ne 'ARRAY' ) {

            #remove leading spaces
            $SLA->{$Attribute} =~ s{\A\s+}{};

            #remove trailing spaces
            $SLA->{$Attribute} =~ s{\s+\z}{};
        }
    }   

    # check if SLA exists 
    my %SLAData = $Kernel::OM->Get('Kernel::System::SLA')->SLAGet(
        SLAID => $Param{Data}->{SLAID},
        UserID      => $Self->{Authorization}->{UserID},        
    );
 
    if ( !%SLAData ) {
        return $Self->_Error(
            Code    => 'Object.NotFound',
            Message => "Cannot update SLA. No SLA with ID '$Param{Data}->{SLAID}' found.",
        );
    }

    # update SLA
    my $Success = $Kernel::OM->Get('Kernel::System::SLA')->SLAUpdate(
        SLAID                   => $Param{Data}->{SLAID},    
        Name                    => $SLA->{Name} || $SLAData{Name},
        Comment                 => $SLA->{Comment} || $SLAData{Comment},
        ValidID                 => $SLA->{ValidID} || $SLAData{ValidID},
        TypeID                  => $SLA->{TypeID} || $SLAData{TypeID},        
        Calendar                => $SLA->{Calendar} || $SLAData{Calendar},
        FirstResponseTime       => $SLA->{FirstResponseTime} || $SLAData{FirstResponseTime},
        FirstResponseNotify     => $SLA->{FirstResponseNotify} || $SLAData{FirstResponseNotify},
        UpdateTime              => $SLA->{UpdateTime} || $SLAData{UpdateTime},
        UpdateNotify            => $SLA->{UpdateNotify} || $SLAData{UpdateNotify},
        SolutionTime            => $SLA->{SolutionTime} || $SLAData{SolutionTime},
        SolutionNotify          => $SLA->{SolutionNotify} || $SLAData{SolutionNotify},
        MinTimeBetweenIncidents => $SLA->{MinTimeBetweenIncidents} || $SLAData{MinTimeBetweenIncidents},
        UserID                  => $Self->{Authorization}->{UserID},

    if ( !$Success ) {
        return $Self->_Error(
            Code    => 'Object.UnableToUpdate',
            Message => 'Could not update SLA, please contact the system administrator',
        );
    }

    # return result    
    return $Self->_Success(
        SLAID => $Param{Data}->{SLAID},
    );    
}

1;
