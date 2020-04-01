# --
# Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::Console::Command::Dev::Doc::Raml2Html;

use strict;
use warnings;

use Cwd;
use File::Basename;
use File::Copy;
use File::Path;
use JSON::Validator;

use Kernel::System::VariableCheck qw(:all);

use base qw(Kernel::System::Console::BaseCommand);

our @ObjectDependencies = (
    'Config',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Generates the HTML documentation from the RAML description.');
    $Self->AddOption(
        Name        => 'source-directory',
        Description => "Specify the directory where the documentation source is located.",
        Required    => 1,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );
    $Self->AddOption(
        Name        => 'raml-file',
        Description => "Specify the main RAML file.",
        Required    => 1,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );
    $Self->AddOption(
        Name        => 'output-file',
        Description => "Specify the output HTML file.",
        Required    => 1,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );
    $Self->AddOption(
        Name        => 'template',
        Description => "Specify the output template to be used.",
        Required    => 1,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );
    $Self->AddOption(
        Name        => 'schema-directory',
        Description => "Specify the directory where the source schema files are located (needed for transformation of the schema refs and validation).",
        Required    => 1,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );
    $Self->AddOption(
        Name        => 'example-directory',
        Description => "Specify the directory where the example files are located (needed for validation of the examples against the schema).",
        Required    => 1,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );
    return;
}

sub Run {
    my ( $Self, %Param ) = @_;
    my @ErrorFiles;

    my $SourceDirectory = $Self->GetOption('source-directory');
    my $SchemaDirectory = $Self->GetOption('schema-directory');
    my $ExampleDirectory = $Self->GetOption('example-directory');
    my $RamlFile = $Self->GetOption('raml-file');
    my $OutputFile = $Self->GetOption('output-file');
    my $Template = $Self->GetOption('template');

    my $TargetDirectory = dirname($OutputFile) || '.';

    # expand $ref in schema files
    if ( -d "$SchemaDirectory" ) {
        $Self->Print("expanding JSON schema refs\n");

        if ( ! -d "$TargetDirectory/schemas" ) {
            mkpath("$TargetDirectory/schemas");
        }

        # change working directory
        my $Cwd = cwd();
        chdir "$SchemaDirectory";

        my @Files = $Kernel::OM->Get('Main')->DirectoryRead(
            Directory => ".",
            Filter    => '*.json'
        );

        my $JSONObject =$Kernel::OM->Get('JSON');
        my $MainObject = $Kernel::OM->Get('Main');
        my $ValidatorObject = JSON::Validator->new();

        foreach my $File ( @Files ) {
            $File = basename($File);

            $Self->Print("    $File...");

            my $Content = $MainObject->FileRead(
                Location => $File
            );
            if ( !$Content ) {
                $Self->Print("<red>Unable to read schema file $File.</red>\n");
                return $Self->ExitCodeError();
            }

            my $BundledSchema;
            my $EvalResult = eval {
                $ValidatorObject->schema($$Content);
                $BundledSchema = $ValidatorObject->bundle( {ref_key => 'definitions'} );
            };

            if ( !$EvalResult ) {
                $Self->Print("<red>$@</red>");
                # instead of the bundled schema, use the unbundled version
                $BundledSchema = $JSONObject->Decode(
                    Data => $$Content,
                );
            }

            # store schema URI for validation
            my $DraftURI = $BundledSchema->{'$schema'};

            # some adjustments to preserve attribute order and cleanup 
            if ( !IsHashRefWithData($BundledSchema->{definitions}) ) {
                delete $BundledSchema->{definitions};
            }
            $BundledSchema = $JSONObject->Encode(
                Data => $BundledSchema,
            );
            my $i = 0;
            foreach my $Attr ( qw(description type properties required) ) {
                $i++;
                $BundledSchema =~ s/"$Attr"/"$i$Attr"/g;
            }
            $BundledSchema = $JSONObject->Decode(
                Data => $BundledSchema,
            );

            # convert to JSON
            $BundledSchema = $JSONObject->Encode(
                Data     => $BundledSchema,
                SortKeys => 1,
                Pretty   => 1,
            );

            # make the resulting schema pretty and validatable
            my %Boolean = ( 0 => 'false', 1 => 'true' );
            $BundledSchema =~ s/"#\/definitions\/.*?-(.*?)\.json/"#\/definitions\/$1/g;
            $BundledSchema =~ s/".*?-(.*?)\.json/"$1/g;
            $BundledSchema =~ s/"\d+(.*?)"/"$1"/g;
            $BundledSchema =~ s/("readOnly"\s*:\s*)(0|1)/$1$Boolean{$2}/g;

            # validator resulting schema against the OpenAPI spec
            my $ValidationResult = eval {
                $ValidatorObject->load_and_validate_schema($BundledSchema, {schema => $DraftURI});
            };

            if ( !$ValidationResult ) {
                $Self->Print("<red>Unable to validate bundled schema $File against OpenAPI specification ($DraftURI).</red>\n");

                # save for summary
                push(@ErrorFiles, {
                    Name => $File,
                    Type => 'Schema'
                });
            }
            else {
                $Self->Print("<green>valid</green>\n");
            }

            my $Result = $MainObject->FileWrite(
                Directory => "$TargetDirectory/schemas",
                Filename  => $File,
                Content   => \$BundledSchema
            );
        }

        chdir $Cwd;
    }

    # validating example files against schema
    if ( -d "$ExampleDirectory" && -d "$TargetDirectory/schemas") {
        $Self->Print("validating examples\n");

        my @Files = $Kernel::OM->Get('Main')->DirectoryRead(
            Directory => "$ExampleDirectory",
            Filter    => '*.json'
        );

        my $JSONObject =$Kernel::OM->Get('JSON');
        my $MainObject = $Kernel::OM->Get('Main');
        my $ValidatorObject = JSON::Validator->new();

        foreach my $File ( @Files ) {
            $File = basename($File);

            $Self->Print("    $File...");

            # read example file
            my $ExampleContent = $MainObject->FileRead(
                Directory => "$ExampleDirectory",
                Filename  => $File
            );
            if ( !$ExampleContent ) {
                $Self->PrintError("<red>Unable to read example file $File.</red>\n");
                return $Self->ExitCodeError();
            }

            # read schema file
            my $SchemaContent = $MainObject->FileRead(
                Directory => "$TargetDirectory/schemas",
                Filename  => $File
            );
            if ( !$SchemaContent ) {
                $Self->PrintError("<red>Unable to read schema file $File.</red>\n");
                return $Self->ExitCodeError();
            }

            my @ValidationResult;
            eval {
                $ValidatorObject->schema($$SchemaContent);
                @ValidationResult = $ValidatorObject->validate(
                    $JSONObject->Decode( Data => $$ExampleContent )
                );
            };

            if ( @ValidationResult ) {
                $Self->Print("<red>Unable to validate example $File against schema.</red>\n");
                foreach my $Line (@ValidationResult) {
                    $Self->Print("        <red>$Line</red>\n");
                }

                # save for summary
                push(@ErrorFiles, {
                    Name => $File,
                    Type => 'Example'
                });
            }
            else {
                $Self->Print("<green>valid</green>\n");
            }
        }
    }

    # print summary in case of error
    if ( @ErrorFiles ) {
        $Self->Print("\nthe following files contained errors:\n");

        foreach my $File ( @ErrorFiles ) {
            $Self->Print("    <red>$File->{Name} ($File->{Type})</red>\n");
        }
        $Self->Print("\n");
    }

    # execute raml2html 
    $Self->Print("executing raml2html -i $SourceDirectory/$RamlFile -o $OutputFile -t $Template\n");
    my $ExecResult = `raml2html -i $SourceDirectory/$RamlFile -o $OutputFile --template $Template`;
    if ( $? ) {
        $Self->PrintError("raml2html failed (Code: $?, Message: $ExecResult).");
        return $Self->ExitCodeError();
    }

    return $Self->ExitCodeOk();
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
