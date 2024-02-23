# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::Console::Command::Admin::HTMLToPDF::Convert;

use strict;
use warnings;

use base qw(Kernel::System::Console::BaseCommand);

our @ObjectDependencies = qw(
    HTMLToPDF
    Main
);

use Kernel::System::VariableCheck qw(:all);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Convert html to pdf.');
    $Self->AddOption(
        Name        => 'name',
        Description => "Name of the object to be generated as a pdf. (Use '--help' to get the list of allowed objects)",
        Required    => 1,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );
    $Self->AddOption(
        Name        => 'filename',
        Description => "(optional) Name of the file. (without extension)",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );
    $Self->AddOption(
        Name        => 'directory',
        Description => "(optional) Path where the generated PDF should be stored. Default is '/tmp/'",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );
    $Self->AddOption(
        Name        => 'number',
        Description => '(required, not for every object) Specification of the number to get the required data',
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/\d+/smx,
    );
    $Self->AddOption(
        Name        => 'id',
        Description => '(required, not for every object) Specification of the id to get the required data',
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/\d+/smx,
    );
    $Self->AddOption(
        Name        => 'user_id',
        Description => '(optional) Specification of the UserID for specifying specific data',
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/\d+/smx,
    );
    $Self->AddOption(
        Name        => 'filter',
        Description => '(optional) "Filter": Restricts the data of the set expands (as JSON). For more information please use "--help".',
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );
    $Self->AddOption(
        Name        => 'allow',
        Description => '(optional) "Allow": Is a whitelist which only fills tables with certain data (as JSON). For more information please use "--help".',
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );
    $Self->AddOption(
        Name        => 'ignore',
        Description => '(optional) "Ignore": Is a blacklist which tables are not filled with certain data (as JSON) . For more information please use "--help".',
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );
    $Self->AddOption(
        Name        => 'expands',
        Description => '(optional) "Expands": Expands the basic data with additional data. For more information please use "--help".',
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );

    $Self->AdditionalHelp(
        $Self->_HelpInstraction()
    );
    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    my $PrintObject = $Kernel::OM->Get('HTMLToPDF');
    my $MainObject  = $Kernel::OM->Get('Main');

    $Self->Print("<yellow>Checking ...</yellow>\n");

    my %Keys = (
        IDKey     => $Self->GetOption('id')     || q{},
        NumberKey => $Self->GetOption('number') || q{}
    );
    my $Filename  = $Self->GetOption('filename')  || q{};
    my $Directory = $Self->GetOption('directory') || '/tmp/';
    my $Object    = $Self->GetOption('name')      || q{};
    my $UserID    = $Self->GetOption('user_id')   || '1';
    my $Filter    = $Self->GetOption('filter')    || q{};
    my $Allow     = $Self->GetOption('allow')     || q{};
    my $Ignore    = $Self->GetOption('ignore')    || q{};
    my $Expands   = $Self->GetOption('expands')   || q{};

    if ( !$Object ) {
        $Self->Print("<red>No object is given!</red>\n");
        return $Self->ExitCodeOk();
    }

    my %Data = $PrintObject->TemplateGet(
        Name   => $Object,
        UserID => $UserID
    );

    if ( !%Data ) {
        $Self->Print("<red>Object '$Object' doesn't exists!</red>\n");
        return $Self->ExitCodeOk();
    }

    my $Backend = $Kernel::OM->Get("Kernel::System::HTMLToPDF::Object::$Data{Object}");

    my %CheckDatas;
    for my $Key ( qw(IDKey NumberKey) ) {
        if ( $Backend->{$Key} ) {
            $CheckDatas{$Backend->{$Key}} = $Keys{$Key};
        }
    }

    my $Success = $Backend->CheckParams(
        %CheckDatas
    );

    if (
        IsHashRefWithData($Success)
        && $Success->{error}
    ) {
        $Self->Print("<red>$Success->{error}</red>\n");
        return $Self->ExitCodeOk();
    }

    $Self->Print("<yellow>Generate PDF...</yellow>\n");
    my %Result = $PrintObject->Convert(
        %CheckDatas,
        Name     => $Object,
        Filename => $Filename,
        UserID   => $UserID,
        Filters  => $Filter,
        Allows   => $Allow,
        Ignores  => $Ignore,
        Expands  => $Expands
    );

    if ( %Result ) {
        $MainObject->FileWrite(
            Directory  => $Directory,
            Filename   => $Result{Filename},
            Content    => \$Result{Content},
            Mode       => 'binmode',
            Type       => 'Local',
            Permission => '640',
        );
        $Self->Print("File stored at \"$Directory$Result{Filename}\"\n");
    }

    $Self->Print("<green>Done.</green>\n");
    return $Self->ExitCodeOk();
}

sub _HelpInstraction {
    my ($Self, %Param) = @_;

    my $PrintObject = $Kernel::OM->Get('HTMLToPDF');
    my %List        = $PrintObject->TemplateDataList(
        Valid => 1
    );

    my $Strg = "List of allowed objects:\n\n"
        . "Object\t\t\tID or Number (Required)\t\t\tExpands\t\t\tFilters\n";

    for my $Key ( sort keys %List ) {
        my $IdNum   = q{};
        my $Filters = q{};
        if ( $List{$Key}->{IDKey} ) {
            $IdNum = $List{$Key}->{IDKey};
        }
        if ( $List{$Key}->{NumberKey} ) {
            $IdNum .= q{,} if $IdNum;
            $IdNum .= $List{$Key}->{NumberKey};
        }
        if ( $List{$Key}->{Filters} ) {
            $Filters = $List{$Key}->{Filters};
        }

        my $Expands = join( q{,}, @{$List{$Key}->{Definition}->{Expands}});
        $Strg .= "$List{$Key}->{Object}\t\t\t$IdNum\t\t\t$Expands\t\t\t$Filters\n";
    }

    $Strg .= <<"END";
\nFor more information about an object use the command 'Admin::HTMLToPDF::Inspect'.

Filter:
With "Filter" the data of the expands can be restricted. Each object has certain expands that can be used.
However, not all are filterable. E.g. only articles (incl. dynamic fields) can be set as filters for tickets.

A filter is structured as follows:
{
    \"ExpandObject\": {
        \"AND|OR\": [
            {
                \"Field\": \"some field\",
                \"Type\": \"CONTAINS or EQ\",
                \"Value\" \"some value or as Array\"
            }
        ]
    }
}

* 'ExpandObject' is the respective object which is defined as Expand.
* 'AND|OR' Determines how the filter should be treated. Only one can be set at a time.
* 'Field' Is the field name of the object. (e.g. TicketNumber or DynamicField_xyz) Caution Dynamic fields are only included if this is also set as Expand.
* 'Type': Is the way the value of the field should be checked. (CONTAINS, EQ)
* 'Value': Is the value to be checked for the field. It is possible to specify an array. These values in the array are then set as "OR".

Allow:
\"Allow\" can be used to restrict the data to be displayed in the \"Table\" type blocks. This is a whitelist.
This means that only the data that match the test value is displayed.
Warning: it is possible to always display the parameter with the check value \"KEY\".

In addition, the table is defined as \"KeyValue\" for \"Columns\" and only the individual parameters are displayed.
If Columns is not defined as \"KeyValue\", the entire row is displayed if the check value is correct.

A allow is structured as follows:
{
    \"BlockID\": {
        \"Attribute\": \"some value or KEY\",
    }
}

Ignore:
\"Ignore\" can be used to restrict the data to be displayed in the \"Table\" type blocks. This is a blacklist.
This means that the respective parameter is not displayed if the test value matches.
Warning: It is possible to always ignore the parameter with the \"KEY\" check value.

In addition, the table is defined as \"KeyValue\" for \"Columns\" and only the individual parameters are hidden.
If Columns is not defined as \"KeyValue\", the whole row is hidden if the check value is correct.

A ignore is structured as follows:
{
    \"BlockID\": {
        \"Attribute\": \"some value or KEY\",
    }
}

Warning: Ignore and Allow cannot be used together in a table.

END

    return $Strg;
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
