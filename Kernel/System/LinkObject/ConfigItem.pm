# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::LinkObject::ConfigItem;

use strict;
use warnings;

our @ObjectDependencies = qw(
    Config
    GeneralCatalog
    ITSMConfigItem
    Log
    ObjectSearch
);

=head1 NAME

Kernel/System/LinkObject/ConfigItem.pm - LinkObject module for ITSMConfigItem

=over 4

=cut

=item new()

create an object. Do not use it directly, instead use:

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $LinkObjectConfigItemObject = $Kernel::OM->Get('LinkObject::ConfigItem');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

=item LinkListWithData()

fill up the link list with data

    $Success = $LinkObjectBackend->LinkListWithData(
        LinkList => $HashRef,
        UserID   => 1,
    );

=cut

sub LinkListWithData {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Argument (qw(LinkList UserID)) {
        if ( !$Param{$Argument} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Argument!",
            );
            return;
        }
    }

    # check link list
    if ( ref $Param{LinkList} ne 'HASH' ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'LinkList must be a hash reference!',
        );
        return;
    }

    for my $LinkType ( sort keys %{ $Param{LinkList} } ) {

        for my $Direction ( sort keys %{ $Param{LinkList}->{$LinkType} } ) {

            CONFIGITEMID:
            for my $ConfigItemID ( sort keys %{ $Param{LinkList}->{$LinkType}->{$Direction} } ) {

                # get last version data
                my $VersionData = $Kernel::OM->Get('ITSMConfigItem')->VersionGet(
                    ConfigItemID => $ConfigItemID,
                    XMLDataGet   => 0,
                    UserID       => $Param{UserID},
                );

                # remove id from hash if config item can not get
                if ( !$VersionData || ref $VersionData ne 'HASH' || !%{$VersionData} ) {
                    delete $Param{LinkList}->{$LinkType}->{$Direction}->{$ConfigItemID};
                    next CONFIGITEMID;
                }

                # add version data
                $Param{LinkList}->{$LinkType}->{$Direction}->{$ConfigItemID} = $VersionData;

                # check for access rights
                my $Access = $Kernel::OM->Get('ITSMConfigItem')->Permission(
                    Scope   => 'Class',
                    ClassID => $Param{LinkList}->{$LinkType}->{$Direction}->{$ConfigItemID}->{ClassID},
                    UserID => $Param{UserID},
                    Type   => 'rw',
                ) || 0;

                $Param{LinkList}->{$LinkType}->{$Direction}->{$ConfigItemID}->{Access} = $Access;
            }
        }
    }

    return 1;
}

=item ObjectDescriptionGet()

return a hash of object descriptions

Return
    %Description = (
        Normal => "ConfigItem# 1234455",
        Long   => "ConfigItem# 1234455: The Config Item Title",
    );

    %Description = $LinkObject->ObjectDescriptionGet(
        Key     => 123,
        UserID  => 1,
    );

=cut

sub ObjectDescriptionGet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Argument (qw(Object Key UserID)) {
        if ( !$Param{$Argument} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Argument!",
            );
            return;
        }
    }

    # create description
    my %Description = (
        Normal => 'ConfigItem',
        Long   => 'ConfigItem',
    );

    return %Description if $Param{Mode} && $Param{Mode} eq 'Temporary';

    # get last version data
    my $VersionData = $Kernel::OM->Get('ITSMConfigItem')->VersionGet(
        ConfigItemID => $Param{Key},
        XMLDataGet   => 0,
        UserID       => $Param{UserID},
    );

    return if !$VersionData;
    return if ref $VersionData ne 'HASH';
    return if !%{$VersionData};

    # create description
    %Description = (
        Normal => "ConfigItem# $VersionData->{Number}",
        Long   => "ConfigItem# $VersionData->{Number}: $VersionData->{Name}",
    );

    return %Description;
}

=item ObjectSearch()

return a hash list of the search results

Return
    $SearchList = {
        NOTLINKED => {
            Source => {
                12  => $DataOfItem12,
                212 => $DataOfItem212,
                332 => $DataOfItem332,
            },
        },
    };

    $SearchList = $LinkObjectBackend->ObjectSearch(
        SubObject    => '25',        # (optional)
        SearchParams => $HashRef,    # (optional)
        UserID       => 1,
    );

=cut

sub ObjectSearch {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{UserID} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Need UserID!',
        );
        return;
    }

    # set default params
    $Param{SearchParams} ||= {};

    # set focus
    my @SearchParams;

    if ( !$Param{SubObject} ) {

        # get the config with the default subobjects
        my $DefaultSubobject = $Kernel::OM->Get('Config')->Get('LinkObject::DefaultSubObject') || {};

        # extract default class name
        my $DefaultClass = $DefaultSubobject->{ITSMConfigItem} || q{};

        # get class list
        my $ClassList = $Kernel::OM->Get('GeneralCatalog')->ItemList(
            Class => 'ITSM::ConfigItem::Class',
        );

        return if !$ClassList;
        return if ref $ClassList ne 'HASH';

        # lookup the class id
        my %ClassListReverse = reverse %{$ClassList};
        $Param{SubObject} = $ClassListReverse{$DefaultClass} || q{};
    }

    return if !$Param{SubObject};

    my @ClassIDArray;
    my %SearchWhat;
    if ( $Param{SubObject} ne 'All' ) {

        my $XMLFormData   = [];
        my $XMLDefinition = $Kernel::OM->Get('ITSMConfigItem')->DefinitionGet(
            ClassID => $Param{SubObject},
        );

        $Self->_XMLSearchFormGet(
            XMLDefinition => $XMLDefinition->{DefinitionRef},
            XMLFormData   => \@SearchParams,
            SearchWhat    => \%SearchWhat,
            %Param,
        );

        @ClassIDArray = $Param{SubObject};
    }
    else {
        # get class list
        my $ClassList = $Kernel::OM->Get('GeneralCatalog')->ItemList(
            Class => 'ITSM::ConfigItem::Class',
        );

        @ClassIDArray = keys %{ $ClassList };
    }

    for my $Key ( sort keys %{$Param{SearchParams}} ) {
        next if $SearchWhat{$Key};

        my $Value    = $Param{SearchParams}->{$Key};
        my $Operator = 'EQ';
        my $Type     = 'STRING';

        if ( $Key =~ /^(?:Name|Number)$/sm ) {
            next if ( !$Param{SearchParams}->{$Key} );
            $Operator = 'CONTAINS';
        }
        elsif( ref $Value eq 'ARRAY' ) {
            $Operator = 'IN';
        }

        if ( $Key =~ /ID(?:s|)$/sm ) {
            $Type = 'NUMERIC';
        }

        push(
            @SearchParams,
            {
                Field    => $Key,
                Operator => $Operator,
                Type     => $Type,
                Value    => $Value
            }
        );
    }

    push (
        @SearchParams,
        {
            Field    => 'ClassID',
            Operator => 'IN',
            Type     => 'NUMERIC',
            Value    => \@ClassIDArray
        }
    );

    # search the config items
    my @ConfigItemIDs = $Kernel::OM->Get('ObjectSearch')->Search(
        ObjectType => 'ConfigItem',
        Result     => 'ARRAY',
        Search     => {
            AND => \@SearchParams
        },
        Sort    => [
            {
                Field     => 'Number',
                Direction => 'ASCENDING'
            }
        ],
        UsingWildcards => 1,
        Limit          => 50,
        UserID         => $Param{UserID},
    );

    my %SearchList;
    CONFIGITEMID:
    for my $ConfigItemID ( @ConfigItemIDs ) {

        # get last version data
        my $VersionData = $Kernel::OM->Get('ITSMConfigItem')->VersionGet(
            ConfigItemID => $ConfigItemID,
            XMLDataGet   => 0,
            UserID       => $Param{UserID},
        );

        next CONFIGITEMID if !$VersionData;
        next CONFIGITEMID if ref $VersionData ne 'HASH';
        next CONFIGITEMID if !%{$VersionData};

        # add version data
        $SearchList{NOTLINKED}->{Source}->{$ConfigItemID} = $VersionData;
    }

    return \%SearchList;
}

=item LinkAddPre()

link add pre event module

    $True = $LinkObject->LinkAddPre(
        Key          => 123,
        SourceObject => 'ConfigItem',
        SourceKey    => 321,
        Type         => 'Normal',
        UserID       => 1,
    );

    or

    $True = $LinkObject->LinkAddPre(
        Key          => 123,
        TargetObject => 'ConfigItem',
        TargetKey    => 321,
        Type         => 'Normal',
        UserID       => 1,
    );

=cut

sub LinkAddPre {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Argument (qw(Key Type UserID)) {
        if ( !$Param{$Argument} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Argument!",
            );
            return;
        }
    }

    return 1;
}

=item LinkAddPost()

link add pre event module

    $True = $LinkObject->LinkAddPost(
        Key          => 123,
        SourceObject => 'ConfigItem',
        SourceKey    => 321,
        Type         => 'Normal',
        UserID       => 1,
    );

    or

    $True = $LinkObject->LinkAddPost(
        Key          => 123,
        TargetObject => 'ConfigItem',
        TargetKey    => 321,
        Type         => 'Normal',
        UserID       => 1,
    );

=cut

sub LinkAddPost {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Argument (qw(Key Type UserID)) {
        if ( !$Param{$Argument} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Argument!",
            );
            return;
        }
    }

    # get information about linked object
    my $ID     = $Param{TargetKey}    || $Param{SourceKey};
    my $Object = $Param{TargetObject} || $Param{SourceObject};

    # recalculate the current incident state of this CI
    $Kernel::OM->Get('ITSMConfigItem')->RecalculateCurrentIncidentState(
        ConfigItemID => $Param{Key},
        Event        => 'LinkAdd',
    );

    # trigger LinkAdd event
    $Kernel::OM->Get('ITSMConfigItem')->EventHandler(
        Event => 'LinkAdd',
        Data  => {
            ConfigItemID => $Param{Key},
            Comment      => $ID . q{%%} . $Object,
        },
        UserID => $Param{UserID},
    );

    return 1;
}

=item LinkDeletePre()

link delete pre event module

    $True = $LinkObject->LinkDeletePre(
        Key          => 123,
        SourceObject => 'ConfigItem',
        SourceKey    => 321,
        Type         => 'Normal',
        UserID       => 1,
    );

    or

    $True = $LinkObject->LinkDeletePre(
        Key          => 123,
        TargetObject => 'ConfigItem',
        TargetKey    => 321,
        Type         => 'Normal',
        UserID       => 1,
    );

=cut

sub LinkDeletePre {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Argument (qw(Key Type UserID)) {
        if ( !$Param{$Argument} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Argument!",
            );
            return;
        }
    }

    return 1;
}

=item LinkDeletePost()

link delete post event module

    $True = $LinkObject->LinkDeletePost(
        Key          => 123,
        SourceObject => 'ConfigItem',
        SourceKey    => 321,
        Type         => 'Normal',
        UserID       => 1,
    );

    or

    $True = $LinkObject->LinkDeletePost(
        Key          => 123,
        TargetObject => 'ConfigItem',
        TargetKey    => 321,
        Type         => 'Normal',
        UserID       => 1,
    );

=cut

sub LinkDeletePost {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Argument (qw(Key Type UserID)) {
        if ( !$Param{$Argument} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Argument!",
            );
            return;
        }
    }

    # get information about linked object
    my $ID     = $Param{TargetKey}    || $Param{SourceKey};
    my $Object = $Param{TargetObject} || $Param{SourceObject};

    # recalculate the current incident state of this CI
    $Kernel::OM->Get('ITSMConfigItem')->RecalculateCurrentIncidentState(
        ConfigItemID => $Param{Key},
        Event        => 'LinkDelete',
    );

    # trigger LinkDelete event
    $Kernel::OM->Get('ITSMConfigItem')->EventHandler(
        Event => 'LinkDelete',
        Data  => {
            ConfigItemID => $Param{Key},
            Comment      => $ID . q{%%} . $Object,
        },
        UserID => $Param{UserID},
    );

    return 1;
}

sub _XMLSearchFormGet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    return if !$Param{XMLDefinition};
    return if !$Param{XMLFormData};
    return if ref $Param{XMLDefinition} ne 'ARRAY';
    return if ref $Param{XMLFormData} ne 'ARRAY';

    $Param{Level} ||= 0;

    ITEM:
    for my $Item ( @{ $Param{XMLDefinition} } ) {

        # create inputkey
        my $InputKey = $Item->{Key};
        if ( $Param{Prefix} ) {
            $InputKey = $Param{Prefix} . q{::} . $InputKey;
        }

        # get search form data
        my @ValueArray = qw{};
        my $Values     = $Param{SearchParams}->{$InputKey};

        if ( defined $Values ) {
            $Param{SearchWhat}->{$InputKey} = 1;
        }

        if ( ref($Values) eq 'ARRAY' ) {
            @ValueArray = @{$Values};
        }
        else {
            push( @ValueArray, $Values );
        }

        # create search array
        my @SearchValues;
        VALUE:
        for my $Value (@ValueArray) {
            next VALUE if !$Value;
            push @SearchValues, $Value;
        }

        if (@SearchValues) {

            # create search key
            my $SearchKey = (!$Param{Prefix} ? 'CurrentVersion.Data.' : q{} ) . $InputKey;
            $SearchKey =~ s/::/./gsm;

            push (
                @{ $Param{XMLFormData} },
                {
                    Field    => $SearchKey,
                    Operator => 'IN',
                    Type     => 'STRING',
                    Value    => \@SearchValues
                }
            );
        }

        next ITEM if !$Item->{Sub};

        # start recursion, if "Sub" was found
        $Self->_XMLSearchFormGet(
            XMLDefinition => $Item->{Sub},
            XMLFormData   => $Param{XMLFormData},
            Level         => $Param{Level} + 1,
            Prefix        => $InputKey,
            SearchParams  => $Param{SearchParams},
        );
    }

    return 1;
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
