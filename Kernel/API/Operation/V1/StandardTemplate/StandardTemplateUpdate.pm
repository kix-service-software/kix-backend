# --
# Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::StandardTemplate::StandardTemplateUpdate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

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
        'StandardTemplateID' => {
            Required => 1
        },
        'StandardTemplate' => {
            Type => 'HASH',
            Required => 1
        },   
    }
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
            Code => 'Object.NotFound',
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
                Code => 'Object.AlreadyExists',
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
            Code => 'Object.UnableToUpdate',
        );
    }

    # return result    
    return $Self->_Success(
        StandardTemplateID => $Param{Data}->{StandardTemplateID},
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
