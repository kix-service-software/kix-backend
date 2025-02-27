# --
# Modified version of the work: Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com 
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::ITSMConfigItem::Definition;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::System::ITSMConfigItem::Definition - sub module of Kernel::System::ITSMConfigItem

=head1 SYNOPSIS

All definition functions.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item DefinitionList()

return a config item definition list as arrayhash reference

    my $DefinitionListRef = $ConfigItemObject->DefinitionList(
        ClassID => 123,
    );

returns

    my $DefinitionListRef = [
          {
            'Version'      => '1',
            'CreateTime'   => '2012-06-12 14:09:43',
            'DefinitionID' => '1',
            'CreateBy'     => '123',
            'Definition'   => '[
                {
                    Key => \'Vendor\',
                    Name => \'Vendor\',
                    Searchable => 1,
                    Input => {
                        Type => \'Text\',
                        Size => 50,
                        MaxLength => 50,
                    },
                },
                {
                    Key => \'Description\',
                    Name => \'Description\',
                    Searchable => 1,
                    Input => {
                        Type => \'TextArea\',
                    },
                },
                {
                    Key => \'Type\',
                    Name => \'Type\',
                    Searchable => 1,
                    Input => {
                        Type => \'GeneralCatalog\',
                        Class => \'ITSM::ConfigItem::Computer::Type\',
                        Translation => 1,
                    },
                },
                ... etc ...
            ];',
          }
        ];

=cut

sub DefinitionList {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{ClassID} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Need ClassID!',
        );
        return;
    }

    my $CacheKey = 'DefinitionList::'.$Param{ClassID};
    my $Cache = $Kernel::OM->Get('Cache')->Get(
        Type => $Self->{CacheType},
        Key  => $CacheKey,
    );
    return $Cache if $Cache;

    # ask database
    $Kernel::OM->Get('DB')->Prepare(
        SQL => 'SELECT id, configitem_definition, version, create_time, create_by '
            . 'FROM configitem_definition WHERE class_id = ? ORDER BY version',
        Bind => [ \$Param{ClassID} ],
    );

    my @DefinitionList;
    while ( my @Row = $Kernel::OM->Get('DB')->FetchrowArray() ) {
        my %Definition;
        $Definition{DefinitionID} = $Row[0];
        $Definition{Definition}   = $Row[1];
        $Definition{Version}      = $Row[2];
        $Definition{CreateTime}   = $Row[3];
        $Definition{CreateBy}     = $Row[4];

        push @DefinitionList, \%Definition;
    }

    # cache the result
    $Kernel::OM->Get('Cache')->Set(
        Type  => $Self->{CacheType},
        TTL   => $Self->{CacheTTL},
        Key   => $CacheKey,
        Value => \@DefinitionList,
    );

    return \@DefinitionList;
}

=item DefinitionGet()

return a config item definition as hash reference

Return
    $Definition->{DefinitionID}
    $Definition->{ClassID}
    $Definition->{Class}
    $Definition->{Definition}
    $Definition->{DefinitionRef}
    $Definition->{Version}
    $Definition->{CreateTime}
    $Definition->{CreateBy}

    my $DefinitionRef = $ConfigItemObject->DefinitionGet(
        DefinitionID => 123,
    );

    or

    my $DefinitionRef = $ConfigItemObject->DefinitionGet(
        ClassID => 123,
    );

=cut

sub DefinitionGet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{DefinitionID} && !$Param{ClassID} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Need DefinitionID or ClassID!',
        );
        return;
    }

    my $CacheKey = 'DefinitionGet::'.($Param{DefinitionID}||'').'::'.($Param{ClassID}||'');
    my $Cache = $Kernel::OM->Get('Cache')->Get(
        Type => $Self->{CacheType},
        Key  => $CacheKey,
    );
    return $Cache if $Cache;

    if ( $Param{DefinitionID} ) {

        # ask database
        $Kernel::OM->Get('DB')->Prepare(
            SQL => 'SELECT id, class_id, configitem_definition, version, create_time, create_by '
                . 'FROM configitem_definition WHERE id = ?',
            Bind  => [ \$Param{DefinitionID} ],
            Limit => 1,
        );
    }
    else {

        # ask database
        $Kernel::OM->Get('DB')->Prepare(
            SQL => 'SELECT id, class_id, configitem_definition, version, create_time, create_by '
                . 'FROM configitem_definition '
                . 'WHERE class_id = ? ORDER BY version DESC',
            Bind  => [ \$Param{ClassID} ],
            Limit => 1,
        );
    }

    # fetch the result
    my %Definition;
    while ( my @Row = $Kernel::OM->Get('DB')->FetchrowArray() ) {
        $Definition{DefinitionID} = $Row[0];
        $Definition{ClassID}      = $Row[1];
        $Definition{Definition}   = $Row[2];
        $Definition{Version}      = $Row[3];
        $Definition{CreateTime}   = $Row[4];
        $Definition{CreateBy}     = $Row[5];

        $Definition{DefinitionRef} = eval $Definition{Definition};    ## no critic
    }

    return {} if !$Definition{DefinitionID};

    # prepare definition
    if ( $Definition{DefinitionRef} && ref $Definition{DefinitionRef} eq 'ARRAY' ) {
        $Self->_DefinitionPrepare(
            DefinitionRef => $Definition{DefinitionRef},
        );
    }
    else {
        $Definition{DefinitionRef} = '';
    }

    # get class list
    my $ClassList = $Kernel::OM->Get('GeneralCatalog')->ItemList(
        Class => 'ITSM::ConfigItem::Class',
    );

    # add class
    $Definition{Class} = $ClassList->{ $Definition{ClassID} };

    # cache the result
    $Kernel::OM->Get('Cache')->Set(
        Type  => $Self->{CacheType},
        TTL   => $Self->{CacheTTL},
        Key   => $CacheKey,
        Value => \%Definition,
    );

    return \%Definition;
}

=item DefinitionAdd()

add a new definition

    my $DefinitionID = $ConfigItemObject->DefinitionAdd(
        ClassID    => 123,
        Definition => 'the definition code',
        UserID     => 1,
    );

=cut

sub DefinitionAdd {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Argument (qw(ClassID Definition UserID)) {
        if ( !$Param{$Argument} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Argument!",
            );
            return;
        }
    }

    # check definition
    my $Check = $Self->DefinitionCheck(
        Definition => $Param{Definition},
    );

    return if !$Check;

    # get last definition
    my $LastDefinition = $Self->DefinitionGet(
        ClassID => $Param{ClassID},
    );

    # stop add, if definition was not changed
    if ( $LastDefinition->{DefinitionID} && $LastDefinition->{Definition} eq $Param{Definition} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Can't add new definition! The definition was not changed.",
        );
        return;
    }

    #---------------------------------------------------------------------------
    # KIX4OTRS-capeIT
    # trigger Pre-DefinitionCreate event
    my $Result = $Self->PreEventHandler(
        Event => 'DefinitionCreate',
        Data  => {
            ClassID          => $Param{ClassID},
            DefinitionID     => $Param{Definition},
            LastDefinitionID => $LastDefinition,
            UserID           => $Param{UserID},
        },
        UserID => $Param{UserID},
    );
    if ( ( ref($Result) eq 'HASH' ) && ( $Result->{Error} ) ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'notice',
            Message  => "Pre-DefinitionCreate refused DefinitionAdd.",
        );
        return $Result;
    }
    elsif ( ref($Result) eq 'HASH' ) {
        for my $ResultKey ( keys %{$Result} ) {
            $Param{$ResultKey} = $Result->{$ResultKey};
        }
    }

    # EO KIX4OTRS-capeIT
    #---------------------------------------------------------------------------

    # set version
    my $Version = 1;
    if ( $LastDefinition->{Version} ) {
        $Version = $LastDefinition->{Version};
        $Version++;
    }

    # insert new definition
    my $Success = $Kernel::OM->Get('DB')->Do(
        SQL => 'INSERT INTO configitem_definition '
            . '(class_id, configitem_definition, version, create_time, create_by) VALUES '
            . '(?, ?, ?, current_timestamp, ?)',
        Bind => [ \$Param{ClassID}, \$Param{Definition}, \$Version, \$Param{UserID} ],
    );

    return if !$Success;

    # get id of new definition
    $Kernel::OM->Get('DB')->Prepare(
        SQL => 'SELECT id FROM configitem_definition WHERE '
            . 'class_id = ? AND version = ? '
            . 'ORDER BY version DESC',
        Bind  => [ \$Param{ClassID}, \$Version ],
        Limit => 1,
    );

    # fetch the result
    my $DefinitionID;
    while ( my @Row = $Kernel::OM->Get('DB')->FetchrowArray() ) {
        $DefinitionID = $Row[0];
    }

    # clear cache
    $Kernel::OM->Get('Cache')->CleanUp(
        Type => $Self->{CacheType},
    );
    $Kernel::OM->Get('Cache')->CleanUp(
        Type => $Self->{OSCacheType},
    );

    # trigger DefinitionCreate event
    $Self->EventHandler(
        Event => 'DefinitionCreate',
        Data  => {
            Comment => $DefinitionID,
            ClassID => $Param{ClassID}
        },
        UserID => $Param{UserID},
    );

    # push client callback event
    $Kernel::OM->Get('ClientNotification')->NotifyClients(
        Event     => 'CREATE',
        Namespace => 'CMDB.Class.Definition',
        ObjectID  => $Param{ClassID}.'::'.$DefinitionID,
    );

    return $DefinitionID;
}

=item DefinitionCheck()

check the syntax of a new definition

    my $True = $ConfigItemObject->DefinitionCheck(
        Definition      => 'the definition code',
        CheckSubElement => 1,                 # (optional, default 0, to check sub elements recursively)
    );

=cut

sub DefinitionCheck {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{Definition} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Need Definition!',
        );
        return;
    }

    # if check sub elements is enabled, we must not evaluate the expression
    # because this has been done in an earlier recursion step already
    my $Definition;
    if ( $Param{CheckSubElement} ) {
        $Definition = $Param{Definition};
    }
    else {
        $Definition = eval $Param{Definition};    ## no critic
        my $EvalFault = $@ || '';
        if ( $EvalFault ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => 'Invalid Definition! You have an syntax error in the definition (' . $EvalFault. ').',
            );
            return;
        }
    }

    # check if definition exists at all
    if ( !$Definition ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Invalid Definition! You have an syntax error in the definition.',
        );
        return;
    }

    # definition must be an array
    if ( ref $Definition ne 'ARRAY' ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Invalid Definition! Definition is not an array reference.',
        );
        return;
    }

    # check each definition attribute
    for my $Attribute ( @{$Definition} ) {

        # each definition attribute must be a hash reference with data
        if ( !$Attribute || ref $Attribute ne 'HASH' || !%{$Attribute} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => 'Invalid Definition! At least one definition attribute is not a hash reference.',
            );
            return;
        }

        if ( IsHashRefWithData($Attribute->{Input}) && $Attribute->{Input}->{Type} ) {

            # create module instance
            my $Module = 'ITSMConfigItem::XML::Type::'.$Attribute->{Input}->{Type};
            my $Object;
            eval {
                $Object = $Kernel::OM->Get($Module);
            };
            if (!$Object || ref $Object ne $Kernel::OM->GetModuleFor($Module)) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message => "Invalid definition! Type '$Attribute->{Input}->{Type}' of key '$Attribute->{Key}' is unknown!",
                );
                return;
            }
        }

        # check if the key contains no spaces
        if ( $Attribute->{Key} && $Attribute->{Key} =~ m{ \s }xms ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Invalid Definition! Key '$Attribute->{Key}' must not contain whitespace!",
            );
            return;
        }

        # check if the key contains non-ascii characters
        if ( $Attribute->{Key} && $Attribute->{Key} =~ m{ ([^\x{00}-\x{7f}]) }xms ) {

            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Invalid Definition! Key '$Attribute->{Key}' must not contain non ASCII characters '$1'!",
            );
            return;
        }

        # recursion check for Sub-Elements
        for my $Key ( sort keys %{$Attribute} ) {

            my $Value = $Attribute->{$Key};

            if ( $Key eq 'Sub' && ref $Value eq 'ARRAY' ) {

                # check the sub array
                my $Check = $Self->DefinitionCheck(
                    Definition      => $Value,
                    CheckSubElement => 1,
                );

                if ( !$Check ) {
                    $Kernel::OM->Get('Log')->Log(
                        Priority => 'error',
                        Message =>
                            "Invalid Sub-Definition of element with the key '$Attribute->{Key}'.",
                    );
                    return;
                }
            }
        }
    }

    return 1;
}

=item _DefinitionPrepare()

Prepare the syntax of a new definition

    my $True = $ConfigItemObject->_DefinitionPrepare(
        DefinitionRef => $ArrayRef,
    );

=cut

sub _DefinitionPrepare {
    my ( $Self, %Param ) = @_;

    # check definition
    if ( !$Param{DefinitionRef} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Need DefinitionRef!',
        );
        return;
    }

    for my $Item ( @{ $Param{DefinitionRef} } ) {

        # set CountMin
        if ( !defined $Item->{CountMin} ) {
            $Item->{CountMin} = 1;
        }

        # set CountMax
        $Item->{CountMax} ||= 1;

        # set CountMin
        if ( $Item->{CountMin} > $Item->{CountMax} ) {
            $Item->{CountMin} = $Item->{CountMax};
        }

        # set CountDefault
        if ( !defined $Item->{CountDefault} ) {
            $Item->{CountDefault} = 1;
        }
        if ( $Item->{CountDefault} < $Item->{CountMin} ) {
            $Item->{CountDefault} = $Item->{CountMin};
        }
        if ( $Item->{CountDefault} > $Item->{CountMax} ) {
            $Item->{CountDefault} = $Item->{CountMax};
        }

        # start recursion, if "Sub" is defined.
        if ( $Item->{Sub} && ref $Item->{Sub} eq 'ARRAY' ) {
            $Self->_DefinitionPrepare(
                DefinitionRef => $Item->{Sub},
            );
        }
        else {
            delete $Item->{Sub};
        }
    }

    return 1;
}

=item DefinitionDelete()

return a $DefinitionID are be deleted

    my $DefinitionID = $ConfigItemObject->DefinitionDelete(
        DefinitionID => 123,
    );

=cut

sub DefinitionDelete {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{DefinitionID} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Need DefinitionID!',
        );
        return;
    }

    my $Definition = $Self->DefinitionGet(
        DefinitionID => $Param{DefinitionID}
    );

    # delete in database
    my $Success = $Kernel::OM->Get('DB')->Do(
        SQL => 'DELETE FROM configitem_definition WHERE id = ?',
        Bind  => [ \$Param{DefinitionID} ],
    );
    return if !$Success;

    # clear cache
    $Kernel::OM->Get('Cache')->CleanUp(
        Type => $Self->{CacheType},
    );
    $Kernel::OM->Get('Cache')->CleanUp(
        Type => $Self->{OSCacheType},
    );

    # push client callback event
    $Kernel::OM->Get('ClientNotification')->NotifyClients(
        Event     => 'DELETE',
        Namespace => 'CMDB.Class.Definition',
        ObjectID  => $Definition->{ClassID}.'::'.$Param{DefinitionID},
    );

    return $Param{DefinitionID};
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
