#!/usr/bin/perl
# --
# Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

use strict;
use warnings;

use Cwd;
use Getopt::Long;
use File::Basename;
use JSON;
use JSON::Validator;

my %Options;
GetOptions(
    'source-directory=s'  => \$Options{SourceDirectory},
    'raml-file=s'         => \$Options{RamlFile},
    'output-file=s'       => \$Options{OutputFile},
    'template=s'          => \$Options{Template},
    'schema-directory=s'  => \$Options{SchemaDirectory},
    'example-directory=s' => \$Options{ExampleDirectory},
    'help'                => \$Options{Help},
);

# check required options
my %Missing;
foreach my $Option ( qw(SourceDirectory RamlFile OutputFile Template SchemaDirectory ExampleDirectory) ) {
    $Missing{$Option} = 1 if !$Options{$Option};
}

# check if directory is given
if ( $Options{Help} || %Missing ) {
    print "raml2html - Generates the HTML documentation from the RAML description.\n";
    print "Copyright (c) 2006-2020 c.a.p.e. IT GmbH, http//www.cape-it.de/\n";
    print "\n";
    print "Required Options:\n";
    print "  --source-directory  - The directory where the documentation source is located.\n";
    print "  --raml-file         - The main RAML file.\n";
    print "  --output-file       - The output HTML file.\n";
    print "  --template          - The output template to be used.\n";
    print "  --schema-directory  - The directory where the source schema files are located (needed for transformation of the schema refs and validation).\n";
    print "  --example-directory - The directory where the example files are located (needed for validation of the examples against the schema).\n";
    exit -1;
}

my @ErrorFiles;
my $TargetDirectory = dirname($Options{OutputFile}) || '.';

my $JSONObject      = JSON->new();
my $ValidatorObject = JSON::Validator->new();

$JSONObject->allow_nonref( 1 );
$JSONObject->canonical( [1] );
$JSONObject->pretty( [1,1,1] );

# expand $ref in schema files
if ( -d "$Options{SchemaDirectory}" ) {
    print "expanding JSON schema refs\n";

    if ( ! -d "$TargetDirectory/schemas" ) {
        mkpath("$TargetDirectory/schemas");
    }

    # change working directory
    my $Cwd = cwd();
    chdir "$Options{SchemaDirectory}";

    foreach my $File ( glob("*.json") ) {
        $File = basename($File);

        print "    expanding and validating schema $File...";

        my $Content = FileRead(
            Location => $File
        );
        if ( !$Content ) {
            print STDERR "ERROR: Unable to read schema file $File.\n";
            exit 1;
        }

        my $BundledSchema;
        my $EvalResult = eval {
            $ValidatorObject->schema($Content);
            $BundledSchema = $ValidatorObject->bundle( {ref_key => 'definitions'} );
        };

        if ( !$EvalResult ) {
            print STDERR "ERROR: $@\n";
            # instead of the bundled schema, use the unbundled version
            $BundledSchema = $JSONObject->decode(
                $Content,
            );
        }

        # store schema URI for validation
        my $DraftURI = $BundledSchema->{'$schema'};

        # some adjustments to preserve attribute order and cleanup 
        if ( !IsHashRefWithData($BundledSchema->{definitions}) ) {
            delete $BundledSchema->{definitions};
        }
        $BundledSchema = $JSONObject->encode(
            $BundledSchema || '',
        );
        my $i = 0;
        foreach my $Attr ( qw(description type properties required) ) {
            $i++;
            $BundledSchema =~ s/"$Attr"/"$i$Attr"/g;
        }
        $BundledSchema = $JSONObject->decode(
            $BundledSchema,
        );

        # convert to JSON
        $BundledSchema = $JSONObject->encode(
            $BundledSchema,
        );

        # make the resulting schema pretty and validatable
        my %Boolean = ( 0 => 'false', 1 => 'true' );
        $BundledSchema =~ s/"#\/definitions\/.*?-(.*?)\.json/"#\/definitions\/$1/g;
        $BundledSchema =~ s/".*?-(.*?)\.json/"$1/g;
        $BundledSchema =~ s/"\d+(.*?)"/"$1"/g;
        $BundledSchema =~ s/("readOnly"\s*:\s*)(0|1)/$1$Boolean{$2}/g;

        # validator resulting schema against the OpenAPI spec
        my @Errors;
        eval { 
            @Errors = JSON::Validator->new()->schema($DraftURI)->validate($JSONObject->decode( $BundledSchema ));
        };

        if ( @Errors ) {
            print STDERR "ERROR: Unable to validate bundled schema $File against OpenAPI specification ($DraftURI).\n";
            foreach my $Line (@Errors) {
                 print STDERR "        $Line\n";
            }

            # save for summary
            push(@ErrorFiles, {
                Name => $File,
                Type => 'Schema'
            });
        }
        else {
            print "valid\n";
        }

        my $Result = FileWrite(
            Directory => "$TargetDirectory/schemas",
            Filename  => $File,
            Content   => $BundledSchema
        );
    }

    chdir $Cwd;
}


# validating example files against schema
if ( -d "$Options{ExampleDirectory}" && -d "$TargetDirectory/schemas") {
    print "validating examples\n";

    # change working directory
    my $Cwd = cwd();
    chdir "$Options{ExampleDirectory}";

    foreach my $File ( glob("*.json") ) {
        $File = basename($File);

        print "    validating example $File...";

        # read example file
        my $ExampleContent = FileRead(
            Directory => "$Options{ExampleDirectory}",
            Filename  => $File
        );
        if ( !$ExampleContent ) {
            print STDERR "ERROR: Unable to read example file $File.\n";
            exit 1;
        }

        # read schema file
        my $SchemaContent = FileRead(
            Directory => "$TargetDirectory/schemas",
            Filename  => $File
        );
        if ( !$SchemaContent ) {
            print STDERR "ERROR: Unable to read schema file $File.\n";
            exit 1;
        }

        my @Errors;
        eval {
            $ValidatorObject->schema($SchemaContent);
            @Errors = $ValidatorObject->validate(
                $JSONObject->decode( $ExampleContent )
            );
        };

        if ( @Errors ) {
            print STDERR "ERROR: Unable to validate example $File against schema.\n";
            foreach my $Line (@Errors) {
                print STDERR "        $Line\n";
            }

            # save for summary
            push(@ErrorFiles, {
                Name => $File,
                Type => 'Example'
            });
        }
        else {
            print "valid\n";
        }
    }
}

# print summary in case of error
if ( @ErrorFiles ) {
    print STDERR "\nthe following files contained errors:\n";

    foreach my $File ( @ErrorFiles ) {
        print STDERR "    $File->{Name} ($File->{Type})\n";
    }
    print STDERR "\n";
}

# execute raml2html 
print "executing raml2html -i $Options{SourceDirectory}/$Options{RamlFile} -o $Options{OutputFile} -t $Options{Template}\n";
my $ExecResult = `raml2html -i $Options{SourceDirectory}/$Options{RamlFile} -o $Options{OutputFile} -t $Options{Template}`;
if ( $? ) {
    print STDERR "ERROR: raml2html failed (Code: $?, Message: $ExecResult).";
    exit 1;
}

exit 0;

sub FileRead {
    my %Param = @_;
    my $Content;

    my $Location = $Param{Location} || $Param{Directory}.'/'.$Param{Filename};

    if ( !open(HANDLE, '<', $Location) ) {
        return;
    }

    $Content = do { local $/; <HANDLE> };
    close(HANDLE);

    return $Content;
}

sub FileWrite {
    my %Param = @_;

    my $Location = $Param{Location} || $Param{Directory}.'/'.$Param{Filename};

    if ( !open(HANDLE, '>', $Location) ) {
        return;
    }

    print HANDLE $Param{Content};

    close(HANDLE);

    return 1;
}

sub IsHashRefWithData {
    my $TestData = $_[0];

    return if scalar @_ ne 1;
    return if ref $TestData ne 'HASH';
    return if !%{$TestData};

    return 1;
}

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-GPL3 for license information (GPL3). If you did not receive this file, see

<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
