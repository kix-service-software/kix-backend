# --
# Kernel/API/Operation/StandardTemplate/StandardTemplateUpdate.pm - API StandardTemplate Update operation backend
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

package Kernel::API::Operation::V1::StandardTemplate::StandardTemplateUpdate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(IsArrayRefWithData IsHashRefWithData IsStringWithData);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::StandardTemplate::StandardTemplateUpdate - API StandardTemplate Update Operation backend

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

    $Self->{Config} = $Kernel::OM->Get('Kernel::Config')->Get('API::Operation::V1::StandardTemplateUpdate');

    return $Self;
}

=item Run()

perform StandardTemplateUpdate Operation. This will return the updated StandardTemplateID.

    my $Result = $OperationObject->Run(
        Data => {
            StandardTemplateID => 123,
            StandardTemplate  => {
                Name         => 'New Standard Template',        # optional
                Template     => 'Thank you for your email.',    # optional
                ContentType  => 'text/plain; charset=utf-8',    # optional
                TemplateType => 'Answer',                       # or 'Forward' or 'Create'
                ValidID     => 1,
            },
        },
    );

    $Result = {
        Success     => 1,                       # 0 or 1
        Code        => '',                      # in case of error
        Message     => '',                      # in case of error
        Data        => {                        # result data payload after Operation
            StandardTemplateID  => 123,              # ID of the updated StandardTemplate 
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
        Data         => $Param{Data},
        Parameters   => {
            'StandardTemplateID' => {
                Required => 1
            },
            'StandardTemplate' => {
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

    # isolate and trim User parameter
    my $StandardTemplate = $Self->_Trim(
        Data => $Param{Data}->{StandardTemplate}
    );
    
    # check if StandardTemplate exists 
    my %StandardTemplateData = $Kernel::OM->Get('Kernel::System::StandardTemplate')->StandardTemplateGet(
        ID => $Param{Data}->{StandardTemplateID},
    );

    if ( !IsHashRefWithData(\%StandardTemplateData) ) {
        return $Self->_Error(
            Code    => 'Object.NotFound',
            Message => "Cannot update StandardTemplate. No StandardTemplate with ID '$Param{Data}->{StandardTemplateID}' found.",
        );
    }

    # check if name already exists
    if ( $StandardTemplate->{Name} ) {
        my $Exist = $Kernel::OM->Get('Kernel::System::StandardTemplate')->NameExistsCheck(
            Name => $StandardTemplate->{Name},
            ID   => $Param{Data}->{StandardTemplateID}
        );
        
        if ( $Exist ) {
            return $Self->_Error(
                Code    => 'Object.AlreadyExists',
                Message => "Can not create StandardTemplate entry. Another StandardTemplate with same name already exists.",
            );
        }
    }

    # update StandardTemplate
    my $Success = $Kernel::OM->Get('Kernel::System::StandardTemplate')->StandardTemplateUpdate(
        ID           => $Param{Data}->{StandardTemplateID},
        Name         => $StandardTemplate->{Name} || $StandardTemplateData{Name},
        Template     => $StandardTemplate->{Template} || $StandardTemplateData{Template},
        ContentType  => $StandardTemplate->{ContentType} || $StandardTemplateData{ContentType},
        TemplateType => $StandardTemplate->{TemplateType} || $StandardTemplateData{TemplateType},
        ValidID      => $StandardTemplate->{ValidID} || $StandardTemplateData{ValidID},
        UserID       => $Self->{Authorization}->{UserID},
    );
    
    if ( !$Success ) {
        return $Self->_Error(
            Code    => 'Object.UnableToUpdate',
            Message => 'Could not update StandardTemplate, please contact the system administrator',
        );
    }

    # return result    
    return $Self->_Success(
        StandardTemplateID => $Param{Data}->{StandardTemplateID},
    );    
}

1;
