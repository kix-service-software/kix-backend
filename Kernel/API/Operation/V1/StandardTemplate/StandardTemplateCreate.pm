# --
# Kernel/API/Operation/StandardTemplate/StandardTemplateCreate.pm - API StandardTemplate Create operation backend
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

package Kernel::API::Operation::V1::StandardTemplate::StandardTemplateCreate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(IsArrayRefWithData IsHashRefWithData IsString IsStringWithData);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::StandardTemplate::StandardTemplateCreate - API StandardTemplate Create Operation backend

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

perform StandardTemplateCreate Operation. This will return the created StandardTemplateID.

    my $Result = $OperationObject->Run(
        Data => {
            StandardTemplate  => {
                Name         => 'New Standard Template',
                Template     => 'Thank you for your email.',
                ContentType  => 'text/plain; charset=utf-8',
                TemplateType => 'Answer',                     # or 'Forward' or 'Create'
                ValidID     => 1,
            },
        },
    );

    $Result = {
        Success         => 1,                       # 0 or 1
        Code            => '',                      # 
        Message         => '',                      # in case of error
        Data            => {                        # result data payload after Operation
            StandardTemplateID  => '',                         # ID of the created StandardTemplate
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # init webStandardTemplate
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
            'StandardTemplate' => {
                Type     => 'HASH',
                Required => 1
            },
            'StandardTemplate::Name' => {
                Required => 1
            },            
            'StandardTemplate::Template' => {
                Required => 1
            },
            'StandardTemplate::ContentType' => {
                Required => 1
            },
            'StandardTemplate::TemplateType' => {
                Required => 1,
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

    # isolate and trim StandardTemplate parameter
    my $StandardTemplate = $Self->_Trim(
        Data => $Param{Data}->{StandardTemplate}
    );
    
    # check if name already exists
    my $Exist = $Kernel::OM->Get('Kernel::System::StandardTemplate')->NameExistsCheck(
        Name => $StandardTemplate->{Name},
    );
    
    if ( $Exist ) {
        return $Self->_Error(
            Code    => 'Object.AlreadyExists',
            Message => "Can not create StandardTemplate entry. Another StandardTemplate with same name already exists.",
        );
    }
    
    # create StandardTemplate
    my $StandardTemplateID = $Kernel::OM->Get('Kernel::System::StandardTemplate')->StandardTemplateAdd(
        Name         => $StandardTemplate->{Name},
        Template     => $StandardTemplate->{Template},
        ContentType  => $StandardTemplate->{ContentType},
        TemplateType => $StandardTemplate->{TemplateType},
        ValidID      => $StandardTemplate->{ValidID} || 1,
        UserID       => $Self->{Authorization}->{UserID},
    );

    if ( !$StandardTemplateID ) {
        return $Self->_Error(
            Code    => 'Object.UnableToCreate',
            Message => 'Could not create StandardTemplate, please contact the system administrator',
        );
    }
    
    # return result    
    return $Self->_Success(
        Code   => 'Object.Created',
        StandardTemplateID => $StandardTemplateID,
    );    
}

1;
