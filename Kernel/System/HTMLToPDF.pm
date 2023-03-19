# --
# Copyright (C) 2006-2023 c.a.p.e. IT GmbH, https://www.cape-it.de
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
        $LogObject->Log(
            Priority => 'error',
            Message  => 'No given ID or Name!'
        );
        return;
    }
    my @Bind;
    my $SQL = <<'END';
SELECT id, name, object, valid_id, definition, created, created_by, changed, changed_by
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
        $Data{Definition} = $JSONObject->Decode(
            Data => $Row[4]
        );
        $Data{ID}        = $Row[0];
        $Data{Name}      = $Row[1];
        $Data{Object}    = $Row[2];
        $Data{ValidID}   = $Row[3];
        $Data{Created}   = $Row[5];
        $Data{CreatedBy} = $Row[6];
        $Data{Changed}   = $Row[7];
        $Data{ChangedBy} = $Row[8];
        $Data{IDKey}     = $Self->{"Backend$Row[2]"}->{IDKey}     || q{};
        $Data{NumberKey} = $Self->{"Backend$Row[2]"}->{NumberKey} || q{};
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

1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut