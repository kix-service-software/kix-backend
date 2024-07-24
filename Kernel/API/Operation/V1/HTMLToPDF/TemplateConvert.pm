# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::HTMLToPDF::TemplateConvert;

use strict;
use warnings;

use MIME::Base64;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Ticket::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::HTMLToPDF::TemplateConvert - API HTMLToPDF Template Convert Operation backend

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

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
        'TemplateID' => {
            DataType => 'NUMERIC',
            Type     => 'STRING',
            RequiredIfNot => [
                'TemplateName'
            ]
        },
        'TemplateName' => {
            Type     => 'STRING',
            RequiredIfNot => [
                'TemplateID'
            ]
        },
        'IdentifierType' => {
            Type     => 'STRING',
            Required => 1
        },
        'IdentifierIDorNumber' => {
            Type     => 'STRING',
            Required => 1
        },
    }
}

=item Run()

perform TemplateConvert Operation. This function is able to return
one or more ticket entries in one call.

    my $Result = $OperationObject->Run(
        Data => {
            TemplateName         => 'some text',         # required (or TemplateID), name of original template
            TemplateID           => '123',               # required (or TemplateName), id of original template
            Filters              => 'JSON string',       # optional, filters that restrict the data for the template
            Allows               => 'JSON string',       # optional, overrides the "Allows" of the tables
            Ignores              => 'JSON string',       # optional, overrides the "Ignores" of the tables
            Expends              => 'String or ARRAY',   # optional, overrides the "Expends" of template object
            Filename             => 'same name',         # optional, defines the file name of the PDF
            IdentifierType       => 'IDKey or IDNumber', # required, determines the identification type through which the object obtains its data
            IdentifierIDOrNumber => '132',               # required, determines the identification value that the object should fetch.
            FallbackTemplate     => 'some template name' # optional, fallback template if no entry was found for the original template.
        },
    );

    $Result = {
        Success      => 1,                           # 0 or 1
        Code         => '',                          # In case of an error
        Message      => '',                          # In case of an error
        Data         => {
            HTMLToPDF => [
                {
                    Filename    => 'generated name',
                    Content     => 'base64'
                    ContentType => 'application/...'
                }
            ]
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    my %TemplateParam;
    if ( $Param{Data}->{TemplateID} ) {
        $TemplateParam{ID} = $Param{Data}->{TemplateID};
    }
    elsif ( $Param{Data}->{TemplateName} ) {
        $TemplateParam{Name} = $Param{Data}->{TemplateName};
    }
    else {
        return $Self->_Error(
            Code    => 'Object.NotFound',
            Message => "Cannot convert pdf. TemplateName or TemplateID not given.",
        );
    }

    for my $Attribute ( qw(IdentifierType IdentifierIDorNumber) ) {
        next if $Param{Data}->{$Attribute};
        return $Self->_Error(
            Code    => 'Object.NotFound',
            Message => "Cannot convert pdf. IdentifierType or IdentifierIDorNumber not given.",
        );
    }

    # get the template data
    my %Template = $Kernel::OM->Get('HTMLToPDF')->TemplateGet(
        %TemplateParam
    );

    if (
        !%Template
        && defined $Param{Data}->{FallbackTemplate}
        && $Param{Data}->{FallbackTemplate}
    ) {
        %Template = $Kernel::OM->Get('HTMLToPDF')->TemplateGet(
            %Param,
            Name => $Param{Data}->{FallbackTemplate}
        );

        if ( %Template ) {
            $TemplateParam{ID}   = $Template{ID};
            $TemplateParam{Name} = $Template{Name};
        }
    }

    if ( !%Template ) {
        return $Self->_Error(
            Code    => 'Object.NotFound',
            Message => "Cannot convert pdf. Template does not exist.",
        );
    }

    my %File = $Kernel::OM->Get('HTMLToPDF')->Convert(
        %TemplateParam,
        Filename             => $Param{Data}->{Filename} || q{},
        IdentifierType       => $Param{Data}->{IdentifierType},
        IdentifierIDorNumber => $Param{Data}->{IdentifierIDorNumber},
        Expands              => $Param{Data}->{Expands} || q{},
        Filters              => $Param{Data}->{Filters} || q{},
        Allows               => $Param{Data}->{Allows}  || q{},
        Ignores              => $Param{Data}->{Ignores} || q{},
        UserID               => $Param{Data}->{UserID},
    );

    if ( !%File ) {
        return $Self->_Error(
            Code => 'Object.UnableToConvert',
        );
    }

    if ( !IsBase64($File{Content}) ) {
        $File{Content} = MIME::Base64::encode_base64($File{Content});
    }

    # return result
    return $Self->_Success(
        HTMLToPDF => \%File,
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