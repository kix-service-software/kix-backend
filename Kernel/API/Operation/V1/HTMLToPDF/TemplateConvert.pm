# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/
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

    if (
        !$Param{Data}->{TemplateID}
        && !$Param{Data}->{TemplateName}
    ) {
        return $Self->_Error(
            Code    => 'Object.NotFound',
            Message => "Cannot convert pdf. TemplateName and TemplateID not given."
        );
    }

    for my $Attribute ( qw(IdentifierType IdentifierIDorNumber) ) {
        next if $Param{Data}->{$Attribute};
        return $Self->_Error(
            Code    => 'Object.NotFound',
            Message => "Cannot convert pdf. IdentifierType and IdentifierIDorNumber not given."
        );
    }

    my %Result = $Kernel::OM->Get('HTMLToPDF')->Print(
        %{$Param{Data}}
    );

    if ( !%Result ) {
        return $Self->_Error(
            Code => 'Object.UnableToConvert',
        );
    }
    elsif ( $Result{Code} ) {
        return $Self->_Error(
            %Result
        );
    }

    if ( !IsBase64($Result{Content}) ) {
        $Result{Content} = MIME::Base64::encode_base64($Result{Content});
    }

    # return result
    return $Self->_Success(
        HTMLToPDF => \%Result,
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