#!/usr/bin/perl
# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
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
use File::Path;
use File::Copy;
use JSON::MaybeXS;
use JSON::Validator;

STDOUT->autoflush(1);

my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = localtime();
my $CURRENT_YEAR = $year + 1900;

my %Options;
GetOptions(
    'source-directory=s@' => \$Options{SourceDirectory},
    'raml-file=s'         => \$Options{RamlFile},
    'output-file=s'       => \$Options{OutputFile},
    'template=s'          => \$Options{Template},
    'schema-directory=s'  => \$Options{SchemaDirectory},
    'example-directory=s' => \$Options{ExampleDirectory},
    'variable=s@'         => \$Options{Variables},
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
    print "Copyright (C) 2006-$CURRENT_YEAR KIX Service Software GmbH, https://www.kixdesk.com/\n";
    print "\n";
    print "Required Options:\n";
    print "  --source-directory  - The directories where the documentation sources are located. All directories will be \"merged\" in the given order. The bundled schema files will also be created in these directories, depending on their schema sources.\n";
    print "  --raml-file         - The main RAML file.\n";
    print "  --output-file       - The output HTML file.\n";
    print "  --template          - The output template to be used.\n";
    print "  --schema-directory  - The directory relative to the source directory where the source schema files are located (needed for transformation of the schema refs and validation).\n";
    print "  --example-directory - The directory relative to the source directory where the example files are located (needed for validation of the examples against the schema).\n";
    print "  --variable          - A variable to replace. Format: <Variable>=<Value>. You can use multiple \"variable\" parameters.\n";
    exit -1;
}

my @ErrorFiles;
my $TargetDirectory = dirname($Options{OutputFile}) || '.';

my $JSONObject      = JSON::MaybeXS->new();
my $ValidatorObject = JSON::Validator->new();

$JSONObject->allow_nonref( 1 );
$JSONObject->canonical( [1] );
$JSONObject->pretty( [1,1,1] );

 # merge source directories
my $TmpDir = `mktemp -d`;
if ( $? ) {
    print STDERR "ERROR: unable to create tmp directory (Code: $?, Message: $TmpDir).";
    exit 1;
}
chomp $TmpDir;

print "merging source directories into $TmpDir\n";
foreach my $Directory ( @{$Options{SourceDirectory}} ) {
    print "    executing rsync --archive --copy-links --recursive $Directory/* $TmpDir\n";
    my $ExecResult = `rsync --archive --copy-links --recursive $Directory/* $TmpDir`;
    if ( $? ) {
        print STDERR "ERROR: unable to merge source directory $Directory (Code: $?, Message: $ExecResult).";
        exit 1;
    }
}

# change working directory
my $Cwd = cwd();
chdir $TmpDir;

# expand $ref in schema files
if ( -d "$Options{SchemaDirectory}" ) {
    print "\nexpanding JSON schema refs\n";

    if ( ! -d "$TmpDir/schemas" ) {
        mkpath("$TmpDir/schemas");
    }

    # change working directory
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
            @Errors = JSON::Validator->schema($DraftURI)->validate(
                $JSONObject->decode( $BundledSchema )
            );
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
            Directory => "$TmpDir/schemas",
            Filename  => $File,
            Content   => $BundledSchema
        );
        if ( !$Result ) {
            print STDERR "ERROR: Unable to save bundled schema $File.\n";
            exit 1;
        }
    }

    # copy all bundled schema files that exist in the schema source directory to the relevant directory
    print "\ncopying bundled schema files to corresponding directories\n";
    foreach my $Directory ( @{$Options{SourceDirectory}} ) {
        chdir "$TmpDir/schemas\n";
        my $TargetDirectory;
        if ( $Directory !~ /^\// ) {
            $TargetDirectory = "$Cwd/$Directory/schemas";
        }
        else {
            $TargetDirectory = "$Directory/schemas";
        }
        if ( -d "$TargetDirectory" && !rmtree("$TargetDirectory") ) {
            print STDERR "ERROR: Unable to remove directory $TargetDirectory.\n";
            next;
        }
        if ( ! -d "$TargetDirectory" && !mkpath("$TargetDirectory") ) {
            print STDERR "ERROR: Unable to create directory $TargetDirectory.\n";
            next;
        }

        my $Count = 0;
        my $Total = 0;
        foreach my $File ( glob("$TmpDir/schemas/*.json") ) {
            my $Filename = basename $File;
            $Total++;
            if ( !copy($File, "$TargetDirectory/$Filename") ) {
                print STDERR "ERROR: Unable to copy bundled schema $Filename to $TargetDirectory.\n";
            }
            $Count++;
        }
        printf "    target $TargetDirectory...%i/%i files\n", $Count, $Total;
    }

    chdir $Cwd;
}

# validating example files against schema
if ( -d "$TmpDir/$Options{ExampleDirectory}" && -d "$TmpDir/schemas") {
    print "\nvalidating examples\n";

    # change working directory
    my $Cwd = cwd();
    chdir "$TmpDir/$Options{ExampleDirectory}";

    foreach my $File ( glob("*.json") ) {
        $File = basename($File);

        print "    validating example $File...";

        # read example file
        my $ExampleContent = FileRead(
            Location => $File
        );
        if ( !$ExampleContent ) {
            print STDERR "ERROR: Unable to read example file $File.\n";
            exit 1;
        }

        # read schema file
        my $SchemaContent = FileRead(
            Directory => "$TmpDir/schemas",
            Filename  => $File
        );
        if ( !$SchemaContent ) {
            print STDERR "ERROR: Unable to read schema file $File.\n";
            exit 1;
        }

        my @Errors;
        eval {
            @Errors = $ValidatorObject->schema($SchemaContent)->validate(
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

# replace variables (create a copy of the source directory)
if ( ref $Options{Variables} eq 'ARRAY' && @{$Options{Variables}} ) {
    print "\nreplacing variables\n";
    chdir $Cwd;
    foreach my $Variable ( @{$Options{Variables}} ) {
        my ($Name, $Value) = split(/=/, $Variable);
        $Value =~ s/\//\\\//g;
        my $ExecResult = `find $TmpDir -type f -exec sed -i 's/\${$Name}/$Value/g' {} +`;
        if ( $? ) {
            print STDERR "ERROR: unable to replace variable \"$Name\" (Code: $?, Message: $ExecResult).";
            exit 1;
        }
    }
}

# execute raml2html
print "\nexecuting raml2html -i $TmpDir/$Options{RamlFile} -o $Options{OutputFile} -t $Options{Template}\n";
my $ExecResult = `raml2html -i $TmpDir/$Options{RamlFile} -o $Options{OutputFile} -t $Options{Template}`;
print STDERR "$ExecResult\n";
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
