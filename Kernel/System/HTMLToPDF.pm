# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::HTMLToPDF;

use strict;
use warnings;

use vars qw(@ISA);

use Kernel::System::HTMLToPDF::Convert;
use Kernel::System::HTMLToPDF::Render;
use IO::Compress::Zip qw(:all);

our @ObjectDependencies = (
    "Config",
    "Main",
    "Log",
);

use Kernel::System::VariableCheck qw(:all);

=head1 NAME

Kernel::System::HTMLToPDF - print management

=head1 SYNOPSIS

All print functions.

=head1 PUBLIC INTERFACE

=over 4

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    @ISA = qw(
        Kernel::System::HTMLToPDF::Convert
        Kernel::System::HTMLToPDF::Render
    );

    # get and execute object modules
    my $Modules = $Kernel::OM->Get('Config')->Get('HTMLToPDF::Module');
    if (IsHashRefWithData($Modules)) {
        for my $Module (sort keys %{$Modules}) {
            next if !IsHashRefWithData($Modules->{$Module}) || !$Modules->{$Module}->{Module};

            if ( !$Kernel::OM->Get('Main')->Require($Modules->{$Module}->{Module}) ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Object module $Modules->{$Module}->{Module} not found!"
                );
                next;
            }
            my $BackendObject = $Modules->{$Module}->{Module}->new( %{$Self} );

            # if the backend constructor failed, it returns an error hash, skip
            next if ( ref $BackendObject ne $Modules->{$Module}->{Module} );

            $Self->{"Backend$Module"} = $BackendObject;
        }
    }

    # get and execute render modules
    $Modules = $Kernel::OM->Get('Config')->Get('HTMLToPDF::Render::Module');
    if (IsHashRefWithData($Modules)) {
        for my $Module (sort keys %{$Modules}) {
            next if !IsHashRefWithData($Modules->{$Module}) || !$Modules->{$Module}->{Module};

            if ( !$Kernel::OM->Get('Main')->Require($Modules->{$Module}->{Module}) ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Render module $Modules->{$Module}->{Module} not found!"
                );
                next;
            }
            my $RenderObject = $Modules->{$Module}->{Module}->new( %{$Self} );

            # if the render constructor failed, it returns an error hash, skip
            next if ( ref $RenderObject ne $Modules->{$Module}->{Module} );

            $Self->{"Render$Module"} = $RenderObject;
        }
    }

    return $Self;
}

sub Print {
    my ( $Self, %Param ) = @_;

    for my $Needed (
        qw(
            UserID IdentifierType IdentifierIDorNumber
        )
    ) {
        if ( !$Param{$Needed} ) {
            if ( !$Param{Silent} ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Needed $Needed!"
                );
            }
            return;
        }
    }

    if (
        !$Param{TemplateID}
        && !$Param{TemplateName}
    ) {
        return (
            Code    => 'Object.NotFound',
            Message => "Cannot convert pdf. TemplateName and TemplateID not given.",
        );
    }

    my %Template = $Self->TemplateExists(
        %Param
    );

    if ( !%Template ) {
        return (
            Code    => 'Object.NotFound',
            Message => "Cannot convert pdf. Template does not exist.",
        );
    }

    my @IDOrNumbers = split(/,/smx, $Param{IdentifierIDorNumber});

    my $Compress = $Param{Compress} || 0;
    my @Files;
    for my $Identifier ( @IDOrNumbers ) {
        my %File = $Self->Convert(
            %Template,
            Filename             => $Param{Filename} || q{},
            IdentifierType       => $Param{IdentifierType},
            IdentifierIDorNumber => $Identifier,
            Expands              => $Param{Expands} || q{},
            Filters              => $Param{Filters} || q{},
            Allows               => $Param{Allows}  || q{},
            Ignores              => $Param{Ignores} || q{},
            UserID               => $Param{UserID},
        );

        return %File if ( !$Compress );

        push ( @Files, \%File );
    }

    return $Self->_Compress(
        Files => \@Files
    );
}

sub PossibleExpandsGet {
    my ($Self, %Param) = @_;

    return  $Self->{"Backend$Param{Object}"}->GetPossibleExpands();
}

sub TemplateGet {
    my ($Self, %Param) = @_;

    my $LogObject  = $Kernel::OM->Get('Log');
    my $DBObject   = $Kernel::OM->Get('DB');
    my $JSONObject = $Kernel::OM->Get('JSON');

    if (
        !$Param{ID}
        && !$Param{Name}
    ) {
        if ( !$Param{Silent} ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => 'No given ID and Name!'
            );
        }
        return;
    }

    my $Selection = 'id, name';
    if ( !$Param{NoData} ) {
        $Selection .= ', object, valid_id, definition, created, created_by, changed, changed_by';
    }

    my @Bind;
    my $SQL = <<"END";
SELECT $Selection
FROM html_to_pdf
WHERE
END

    if ( $Param{ID} ) {
        $SQL .= ' id = ?';
        push( @Bind, \$Param{ID} );
    }
    else {
        $SQL .= ' name = ?';
        push( @Bind, \$Param{Name} );
    }

    return if !$DBObject->Prepare(
        SQL   => $SQL,
        Bind  => \@Bind,
        Limit => 1
    );

    # fetch the result
    my %Data;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $Data{ID}        = $Row[0];
        $Data{Name}      = $Row[1];

        if ( !$Param{NoData} ) {
            $Data{Definition} = $JSONObject->Decode(
                Data => $Row[4]
            );

            $Data{Object}    = $Row[2];
            $Data{ValidID}   = $Row[3];
            $Data{Created}   = $Row[5];
            $Data{CreatedBy} = $Row[6];
            $Data{Changed}   = $Row[7];
            $Data{ChangedBy} = $Row[8];
            $Data{IDKey}     = $Self->{"Backend$Row[2]"}->{IDKey}     || q{};
            $Data{NumberKey} = $Self->{"Backend$Row[2]"}->{NumberKey} || q{};
        }
    }

    return %Data;
}

sub TemplateAdd {
    my ($Self, %Param) = @_;

    my $LogObject  = $Kernel::OM->Get('Log');
    my $DBObject   = $Kernel::OM->Get('DB');

    for my $Needed ( qw(
            Name Object ValidID Definition UserID
        )
    ) {
        if ( !$Param{$Needed} ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Needed $Needed!"
            );
            return;
        }
    }

    return if !$DBObject->Do(
        SQL  => <<'END',
INSERT INTO html_to_pdf
    (name, description, object, valid_id, definition, created, created_by, changed, changed_by)
VALUES
    (?, ?, ?, ?, ?, current_timestamp, ?, current_timestamp, ?)
END
        Bind => [
            \$Param{Name},   \$Param{Description},
            \$Param{Object},
            \$Param{ValidID},\$Param{Definition},
            \$Param{UserID}, \$Param{UserID},
        ],
    );

    return if !$DBObject->Prepare(
        SQL   => <<'END',
SELECT id
FROM html_to_pdf
WHERE name = ?
END
        Bind  => [ \$Param{Name} ],
        Limit => 1
    );

    # fetch the result
    my $ID;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $ID = $Row[0];
    }

    return $ID;
}

sub TemplateUpdate {
    my ($Self, %Param) = @_;

    my $LogObject  = $Kernel::OM->Get('Log');
    my $DBObject   = $Kernel::OM->Get('DB');

    for my $Needed ( qw(
            ID Name Object ValidID Definition UserID
        )
    ) {
        if ( !$Param{$Needed} ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Needed $Needed!"
            );
            return;
        }
    }

    return if !$DBObject->Do(
        SQL  => <<'END',
UPDATE html_to_pdf
SET
    name       = ?,
    object     = ?,
    definition = ?,
    valid_id   = ?,
    changed    = current_timestamp,
    changed_by = ?
WHERE id = ?
END
        Bind => [
            \$Param{Name},    \$Param{Object},
            \$Param{Definition},
            \$Param{ValidID}, \$Param{UserID},
            \$Param{ID},
        ],
    );

    return 1;
}

sub TemplateDataList {
    my ($Self, %Param) = @_;

    my $LogObject   = $Kernel::OM->Get('Log');
    my $DBObject    = $Kernel::OM->Get('DB');
    my $ValidObject = $Kernel::OM->Get('Valid');

    my $Result = $Param{Result} || 'HASH';

    # set valid option
    my $Valid = $Param{Valid};
    if ( !defined $Valid || $Valid ) {
        $Valid = 1;
    }
    else {
        $Valid = 0;
    }

    # sql query
    my $SQL = <<'END';
SELECT id
FROM html_to_pdf
END
    if ($Valid) {
        $SQL .= " WHERE valid_id IN "
            . "( ${\(join ', ', $ValidObject->ValidIDsGet())} )";
    }

    return if !$DBObject->Prepare(
        SQL => $SQL
    );

    # fetch the result
    my @IDList;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        push(@IDList, $Row[0]);
    }

    if ( $Result eq 'ARRAY' ) {
        return @IDList;
    }

    my %List;
    for my $ID ( @IDList ) {
        %{$List{$ID}} = $Self->TemplateGet(
            ID => $ID
        );
    }

    return %List;
}

sub TemplateExists {
    my ( $Self, %Param ) = @_;

    if (
        !$Param{TemplateID}
        && !$Param{TemplateName}
    ) {
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Needed TemplateID or TemplateName!"
            );
        }
        return;
    }

    # get the template data
    my %Template = $Self->TemplateGet(
        ID     => $Param{TemplateID},
        Name   => $Param{TemplateName},
        NoData => 1
    );

    if (
        !%Template
        && $Param{FallbackTemplate}
    ) {
        %Template = $Self->TemplateGet(
            Name   => $Param{FallbackTemplate},
            NoData => 1
        );
    }

    return %Template;
}

sub _Compress {
    my ( $Self, %Param ) = @_;

    if ( !IsArrayRefWithData($Param{Files}) ) {
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Needed Files!"
            );
        }
        return;
    }

    my $ZipObject;
    my $ZipResult;
    my %ZipFilename = $Self->_ReplacePlaceholders(
        String => 'Ticketlist-<TIME_YYYYMMDDhhmm>.zip'
    );

    for my $File ( @{$Param{Files}} ) {
        if ( !$ZipObject ) {
            $ZipObject = new IO::Compress::Zip(
                \$ZipResult,
                BinModeIn => 1,
                Name      => $File->{Filename},
            );

            if ( !$ZipObject ) {
                return $Self->_Error(
                    Code    => 'Operation.InternalError',
                    Message => 'Unable to create Zip object.',
                );
            }

            $ZipObject->print( $File->{Content} );
            $ZipObject->flush();
        }
        else {
            $ZipObject->newStream( Name => $File->{Filename} );
            $ZipObject->print( $File->{Content} );
            $ZipObject->flush();
        }
    }

    if ($ZipObject) {
        $ZipObject->close();
    }

    my %ZipFile = (
        Content     => $ZipResult,
        Filename    => $ZipFilename{Text},
        ContentType => 'application/zip',
        FilesizeRaw => 0 + length $ZipResult,
    );

    return %ZipFile;
}

1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut