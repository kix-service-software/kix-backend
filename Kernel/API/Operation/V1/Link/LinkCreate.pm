# --
# Kernel/API/Operation/Link/LinkCreate.pm - API Link Create operation backend
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

package Kernel::API::Operation::V1::Link::LinkCreate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(IsArrayRefWithData IsHashRefWithData IsString IsStringWithData);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::Link::LinkCreate - API Link LinkCreate Operation backend

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

    return $Self;
}

=item Run()

perform LinkCreate Operation. This will return the created LinkID.

    my $Result = $OperationObject->Run(
        Data => {
            Link  => {
                SourceObject => '...',
                SourceKey    => '...',
                TargetObject => '...',
                TargetKey    => '...',
                Type         => '...'
            },
        },
    );

    $Result = {
        Success         => 1,                       # 0 or 1
        Code            => '',                      # 
        Message         => '',                      # in case of error
        Data            => {                        # result data payload after Operation
            LinkID  => '',                         # ID of the created Link
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # init webLink
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
            'Link' => {
                Type     => 'HASH',
                Required => 1
            },
            'Link::SourceObject' => {
                Required => 1
            },
            'Link::SourceKey' => {
                Required => 1
            },            
            'Link::TargetObject' => {
                Required => 1
            },
            'Link::TargetKey' => {
                Required => 1
            },            
            'Link::Type' => {
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

    # isolate Link parameter
    my $Link = $Param{Data}->{Link};

    # remove leading and trailing spaces
    for my $Attribute ( sort keys %{$Link} ) {
        if ( ref $Attribute ne 'HASH' && ref $Attribute ne 'ARRAY' ) {

            #remove leading spaces
            $Link->{$Attribute} =~ s{\A\s+}{};

            #remove trailing spaces
            $Link->{$Attribute} =~ s{\s+\z}{};
        }
    }   

    # check if this link type is allowed
    my %PossibleTypesList = $Kernel::OM->Get('Kernel::System::LinkObject')->PossibleTypesList(
        Object1 => $Link->{SourceObject},
        Object2 => $Link->{TargetObject},
    );

    # check if wanted link type is possible
    if ( !$PossibleTypesList{ $Link->{Type} } ) {
        return $Self->_Error(
            Code    => 'BadRequest',
            Message => "Can not create Link. The given link type is not supported by the given objects.",
        );
    }
        	
    # check if Link exists
    my $LinkList = $Kernel::OM->Get('Kernel::System::LinkObject')->LinkSearch(
        %{$Link},
        UserID => $Self->{Authorization}->{UserID},
    );

    if ( IsArrayRefWithData($LinkList) ) {
        return $Self->_Error(
            Code    => 'Object.AlreadyExists',
            Message => "Can not create Link. A link with these parameters already exists.",
        );
    }

    # create Link
    my $LinkID = $Kernel::OM->Get('Kernel::System::LinkObject')->LinkAdd(
        %{$Link},
        State   => 'Valid',
        UserID  => $Self->{Authorization}->{UserID},        
    );

    if ( !$LinkID ) {
        return $Self->_Error(
            Code    => 'Object.UnableToCreate',
            Message => 'Could not create Link, please contact the system administrator',
        );
    }
    
    # return result    
    return $Self->_Success(
        Code   => 'Object.Created',
        LinkID => $LinkID,
    );    
}


1;
