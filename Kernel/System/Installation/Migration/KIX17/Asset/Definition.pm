# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::Installation::Migration::KIX17::Asset::Definition;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::System::Installation::Migration::KIX17::Common
);

our @ObjectDependencies = (
    'Config',
    'DB',
    'Log',
);

our %TypeMapping = (
    'BaselineReference'   => \&_MigrateBaselineReference,
    'CIACCustomerCompany' => 'Organisation',
    'CIAttachment'        => 'Attachment',
    'CIGroupAccess'       => undef,
    'CIClassReference'    => 'CIClassReference',
    'CustomerCompany'     => 'Organisation',
    'Customer'            => 'Contact',
    'CustomerUserCompany' => 'Organisation',
    'Date'                => 'Date',
    'DateTime'            => 'DateTime',
    'Dummy'               => 'Dummy',
    'DummyX'              => 'Dummy',
    'DynamicField'        => 'Text',
    'EncryptedText'       => 'Text',
    'GeneralCatalog'      => 'GeneralCatalog',
    'Integer'             => 'Text',
    'QueueReference'      => 'Text',
    'ServiceReference'    => 'Text',
    'SLAReference'        => 'Text',
    'TextArea'            => 'TextArea',
    'TextLink'            => 'Text',
    'Text'                => 'Text',
    'TicketReference'     => 'Text',
    'TypeReference'       => 'Text',
    'User'                => 'Text',
);

=item Describe()

describe what is supported and what is required

=cut

sub Describe {
    my ( $Self, %Param ) = @_;

    return {
        Supports => [
            'configitem_definition'
        ],
        Depends => {
            'create_by' => 'users',
            'class_id'  => 'general_catalog',
        },
    }
}

=item Run()

create a new item in the DB

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # get source data
    my $SourceData = $Self->GetSourceData(Type => 'configitem_definition', OrderBy => 'ID desc');

    # bail out if we don't have something to todo
    return if !IsArrayRefWithData($SourceData);

    $Self->{ClassList} = $Kernel::OM->Get('GeneralCatalog')->ItemList(
        Class => 'ITSM::ConfigItem::Class',
    ) || {};

    my $MainObject = $Kernel::OM->Get('Main');

    $Self->InitProgress(Type => $Param{Type}, ItemCount => scalar(@{$SourceData}));

    foreach my $Item ( @{$SourceData} ) {

        # check if this object is already mapped
        my $MappedID = $Self->GetOIDMapping(
            ObjectType     => 'configitem_definition',
            SourceObjectID => $Item->{id}
        );
        if ( $MappedID ) {
            $Self->UpdateProgress($Param{Type}, 'Ignored');
            next;
        }

        # check if this item already exists (i.e. some initial data)
        my $ID = $Self->Lookup(
            Table        => 'configitem_definition',
            PrimaryKey   => 'id',
            Item         => $Item,
            RelevantAttr => [
                'create_time',
                'version',
                'class_id',
            ]
        );

        # insert row
        if ( !$ID ) {
            # replace attribute type
            my $Definition = $Self->_ReplaceAttributeTypes(
                Definition => eval $Item->{configitem_definition}
            );
            # add new attribute "CIAttachments"
            push @{$Definition}, {
                Key              => 'CIAttachments',
                Name             => 'CI Attachments',
                Searchable       => 1,
                CustomerVisible  => 0,
                Input            => {
                    Type => 'Attachment',
                },
                CountMin => 0,
                CountDefault => 0,
                CountMax => 32,
            };
            $Item->{configitem_definition} = $MainObject->Dump(
                $Definition
            );
            $Item->{configitem_definition} =~ s/^\$VAR1 = //g;

            $ID = $Self->Insert(
                Table          => 'configitem_definition',
                PrimaryKey     => 'id',
                Item           => $Item,
                AutoPrimaryKey => 1,
            );
        }

        if ( $ID ) {
            $Self->UpdateProgress($Param{Type}, 'OK');
        }
        else {
            $Self->UpdateProgress($Param{Type}, 'Error');
        }
    }

    return 1;
}

sub _ReplaceAttributeTypes {
    my ( $Self, %Param ) = @_;
    my @Result;

    return if !$Param{Definition} || !IsArrayRefWithData($Param{Definition});

    foreach my $Attr ( @{$Param{Definition}} ) {
        # if the target typ is undef we have to ignore the whole attribute
        next if exists $TypeMapping{$Attr->{Input}->{Type}} && !$TypeMapping{$Attr->{Input}->{Type}};

        if ( IsCodeRef($TypeMapping{$Attr->{Input}->{Type}}) ) {
            $Attr->{Input}->{MigratedType} = $Attr->{Input}->{Type};
            $Attr = $TypeMapping{$Attr->{Input}->{Type}}->(
                $Self,
                Attribute => $Attr
            );
        }
        else {
            # if no mapping exists we migrate to Text
            if ( !$TypeMapping{$Attr->{Input}->{Type}} ) {
                $Attr->{Input}->{MigratedType} = $Attr->{Input}->{Type};
                $Attr->{Input}->{Type} = 'Text';
            }
            elsif ( $TypeMapping{$Attr->{Input}->{Type}} ne $Attr->{Input}->{Type} ) {
                $Attr->{Input}->{MigratedType} = $Attr->{Input}->{Type};
                # assign new type
                $Attr->{Input}->{Type} = $TypeMapping{$Attr->{Input}->{Type}};
            }

            if ( IsArrayRefWithData($Attr->{Sub}) ) {
                $Attr->{Sub} = $Self->_ReplaceAttributeTypes(
                    Definition => $Attr->{Sub}
                );
            }
        }

        push @Result, $Attr;
    }

    return \@Result;
}

sub _MigrateBaselineReference {
    my ( $Self, %Param ) = @_;
    my %Result;

    # check needed params
    for my $Needed (qw(Attribute)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!"
            );
            return;
        }
    }

    %Result = %{$Param{Attribute}};

    $Result{Input}->{Type} = 'CIClassReference';

    if ( $Result{Input}->{ReferencedCIClassName} ) {
        if ( !$Self->{SourceClassList} ) {
            my $SourceData = $Self->GetSourceData(Type => 'general_catalog', Where => "general_catalog_class='ITSM::ConfigItem::Class'", NoProgress => 1);
            if ( IsArrayRefWithData($SourceData) ) {
                $Self->{SourceClassList} = { map { $_->{name} => $_->{id} } @{$SourceData} };
            }
        }

        my @Value = IsArrayRefWithData($Result{Input}->{ReferencedCIClassName}) ? {$Result{Input}->{ReferencedCIClassName}} : ( $Result{Input}->{ReferencedCIClassName} );
        my @MigratedReferences;
        foreach my $ReferencedCIClassName ( @Value ) {
            my $MappedID = $Self->GetOIDMapping(
                ObjectType     => 'general_catalog',
                SourceObjectID => $Self->{SourceClassList}->{$ReferencedCIClassName}
            );
            if ( !$MappedID ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Unable to lookup referenced class \"$ReferencedCIClassName\"!"
                );
                next;
            }

            push @MigratedReferences, $Self->{ClassList}->{$MappedID};
        }

        $Result{Input}->{ReferencedCIClassName} = \@MigratedReferences;
    }

    return \%Result;
}

# needed for definition eval
sub Translatable { return @_ }

1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-GPL3 for license information (GPL3). If you did not receive this file, see

<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
