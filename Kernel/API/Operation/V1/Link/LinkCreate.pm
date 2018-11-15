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
    Kernel::API::Operation::V1::Link::Common
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

    # isolate and trim Link parameter
    my $Link = $Self->_Trim(
        Data => $Param{Data}->{Link}
    );

    # check attribute values
    my $CheckResult = $Self->_CheckLink( 
        Link => $Link
    );

    if ( !$CheckResult->{Success} ) {
        return $Self->_Error(
            %{$CheckResult},
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
