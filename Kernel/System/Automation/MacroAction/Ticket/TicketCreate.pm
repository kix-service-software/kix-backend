# --
# Modified version of the work: Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Automation::MacroAction::Ticket::TicketCreate;

use strict;
use warnings;
use utf8;

use Kernel::System::VariableCheck qw(:all);

use base qw(Kernel::System::Automation::MacroAction::Ticket::ArticleCreate);

our @ObjectDependencies = (
    'Config',
    'DynamicField',
    'DynamicField::Backend',
    'LinkObject',
    'Log',
    'State',
    'Ticket',
    'Time',
    'User',
);

=head1 NAME

Kernel::System::Automation::MacroAction::Ticket::TicketCreate - A module to create a ticket

=head1 SYNOPSIS

All TicketCreate functions.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item Describe()

Describe this macro action module.

=cut

sub Describe {
    my ( $Self, %Param ) = @_;

    $Self->SUPER::Describe(%Param);
    $Self->Description(Kernel::Language::Translatable('Creates an ticket.'));
    $Self->AddOption(
        Name        => 'ContactEmailOrID',
        Label       => Kernel::Language::Translatable('Contact'),
        Description => Kernel::Language::Translatable('The ID or email of the contact of the new ticket.'),
        Required    => 1,
    );
    $Self->AddOption(
        Name        => 'Lock',
        Label       => Kernel::Language::Translatable('Lock'),
        Description => Kernel::Language::Translatable('The lock state of the new ticket.'),
        Required    => 0,
    );
    $Self->AddOption(
        Name        => 'OrganisationNumberOrID',
        Label       => Kernel::Language::Translatable('Organisation'),
        Description => Kernel::Language::Translatable('The ID or number of the organisation of the new ticket. Primary organisation of contact will be used if omitted.'),
        Required    => 0,
    );
    $Self->AddOption(
        Name        => 'OwnerLoginOrID',
        Label       => Kernel::Language::Translatable('Owner'),
        Description => Kernel::Language::Translatable('The ID or login of the owner of the new ticket. Current user will be used if omitted.'),
        Required    => 0,
    );
    $Self->AddOption(
        Name        => 'Priority',
        Label       => Kernel::Language::Translatable('Priority'),
        Description => Kernel::Language::Translatable('The name of the priority of the new ticket.'),
        Required    => 1
    );
    $Self->AddOption(
        Name        => 'ResponsibleLoginOrID',
        Label       => Kernel::Language::Translatable('Responsible'),
        Description => Kernel::Language::Translatable('The ID or login of the responsible of the new ticket. Root user (ID = 1) will be used if omitted.'),
        Required    => 0,
    );
    $Self->AddOption(
        Name        => 'State',
        Label       => Kernel::Language::Translatable('State'),
        Description => Kernel::Language::Translatable('The name of the state of the new ticket.'),
        Required    => 1,
    );
    $Self->AddOption(
        Name        => 'PendingTimeDiff',
        Label       => Kernel::Language::Translatable('Pending Time Difference'),
        Description => Kernel::Language::Translatable('(Optional) The pending time in seconds. Will be added to the actual time when the macro action is executed. Used for pending states only.'),
        Required    => 0,
    );
    $Self->AddOption(
        Name        => 'Title',
        Label       => Kernel::Language::Translatable('Title'),
        Description => Kernel::Language::Translatable('The title of the new ticket and subject of the first article.'),
        Required    => 1,
    );
    $Self->AddOption(
        Name        => 'Team',
        Label       => Kernel::Language::Translatable('Team'),
        Description => Kernel::Language::Translatable('The name of the team of the new ticket. If it is as sub-team, the full path-name has to be used (separated by two colons - e.g. "NameOfParentTeam::NameOfTeamToBeSet").'),
        Required    => 1,
    );
    $Self->AddOption(
        Name        => 'Type',
        Label       => Kernel::Language::Translatable('Type'),
        Description => Kernel::Language::Translatable('The name of the type of the new ticket. Configured default will be used (Ticket::Type::Default) if omitted.'),
        Required    => 0,
    );
    $Self->AddOption(
        Name        => 'DynamicFieldList',
        Label       => Kernel::Language::Translatable('Dynamic Fields'),
        Description => Kernel::Language::Translatable('The dynamic fields of the new ticket.'),
        Required    => 0,
    );
    delete $Self->{Definition}->{Options}->{Subject};

    return;
}

=item Run()

Run this module. Returns 1 if everything is ok.

Example:
    my $Success = $Object->Run(
        TicketID => 123,
        Config   => {
            # ticket required
            Title         => 'Some Ticket Title',
            Team          => 'Junk',
            Lock          => 'unlock',
            Priority      => '3 normal',
            State         => 'new',
            Contact       => 'someContactLogin',

            # optional parameter
            Owner            => 'someUserLogin',            # if omitted, current user is used
            Organisation     => 'someOrganisationNumber',   # if omitted, primary organisation of contact is used
            Type             => 'Incident',
            Responsible      => 'someUserLogin',
            PendingTimeDiff  => 3600 ,                      # optional (for pending states)
            DynamicFieldList => [
                [ 'DynamicFieldName', 'Value' ],
                [ ... ],
                ...
            ]

            # article parameter, see ArticleCreate
        },
        UserID   => 123
    );

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # check incoming parameters
    return if !$Self->_CheckParams(%Param);
    return if !$Self->_CheckTicketParams(
        %{$Param{Config}},
        UserID => $Param{UserID}
    );

    # collect ticket params (organisation have to be before contact)
    my %TicketParam;
    for my $Attribute (
        qw(OrganisationNumberOrID ContactEmailOrID Lock OwnerLoginOrID Priority ResponsibleLoginOrID State Title Team Type)
    ) {
        if ( defined $Param{Config}->{$Attribute} ) {

            $Param{Config}->{$Attribute} = $Kernel::OM->Get('TemplateGenerator')->ReplacePlaceHolder(
                RichText => 0,
                Text     => $Param{Config}->{$Attribute},
                TicketID => $Param{TicketID},
                Data     => {},
                UserID   => $Param{UserID},
            );

            if ( ($Attribute eq 'OwnerLoginOrID' || $Attribute eq 'ResponsibleLoginOrID') && $Param{Config}->{$Attribute} ) {
                my $TicketAttribute = $Attribute;
                $TicketAttribute =~ s/(.+)LoginOrID/$1/;

                $TicketParam{$TicketAttribute . 'ID'} = $Kernel::OM->Get('User')->UserLookup(
                    UserLogin => $Param{Config}->{$Attribute},
                    Silent    => 1
                );
                if ( !$TicketParam{$TicketAttribute . 'ID'} && $Param{Config}->{$Attribute} =~ m/^\d+$/ ) {
                    my $UserLogin = $Kernel::OM->Get('User')->UserLookup(
                        UserID => $Param{Config}->{$Attribute},
                        Silent => 1
                    );
                    if ($UserLogin) {
                        $TicketParam{$TicketAttribute . 'ID'} = $Param{Config}->{$Attribute};
                    }
                }
            } elsif ($Attribute eq 'OrganisationNumberOrID' && $Param{Config}->{OrganisationNumberOrID}) {
                $TicketParam{OrganisationID} = $Kernel::OM->Get('Organisation')->OrganisationLookup(
                    Number => $Param{Config}->{OrganisationNumberOrID},
                    Silent => 1
                );
                if ( !$TicketParam{OrganisationID} && $Param{Config}->{OrganisationNumberOrID} =~ m/^\d+$/ ) {
                    my $OrgNumber = $Kernel::OM->Get('Organisation')->OrganisationLookup(
                        ID     => $Param{Config}->{OrganisationNumberOrID},
                        Silent => 1
                    );
                    if ($OrgNumber) {
                        $TicketParam{OrganisationID} = $Param{Config}->{OrganisationNumberOrID};
                    }
                }
            } elsif ($Attribute eq 'ContactEmailOrID' && $Param{Config}->{ContactEmailOrID}) {
                my $ContactID;
                if ($Param{Config}->{ContactEmailOrID} =~ m/^\d+$/) {
                    my $Mail = $Kernel::OM->Get('Contact')->ContactLookup(
                        ID  => $Param{Config}->{ContactEmailOrID},
                        Silent => 1
                    );
                    if ($Mail) {
                        $ContactID = $Param{Config}->{ContactEmailOrID};
                    }
                } else {
                    $ContactID = $Kernel::OM->Get('Contact')->ContactLookup(
                        Email  => $Param{Config}->{ContactEmailOrID},
                        Silent => 1
                    );
                }

                if (!$TicketParam{OrganisationID} && $ContactID) {
                    my %Contact = $Kernel::OM->Get('Contact')->ContactGet(
                        ID => $ContactID
                    );
                    $TicketParam{OrganisationID} = $Contact{PrimaryOrganisationID};
                }

                $TicketParam{ContactID} = $ContactID || $Param{Config}->{ContactEmailOrID};
            } elsif ($Attribute eq 'Team') {
                $TicketParam{Queue} = $Param{Config}->{Team};
            } else {
                $TicketParam{$Attribute} = $Param{Config}->{$Attribute}
            }
        }
    }

    if (!$TicketParam{OwnerID}) {
        $TicketParam{OwnerID} = $Param{UserID};
    }

    if (!$TicketParam{Lock}) {
        $TicketParam{Lock} = 'unlock';
    }

    my $TicketObject = $Kernel::OM->Get('Ticket');

    # $TicketParam{Title} = $Kernel::OM->Get('TemplateGenerator')->ReplacePlaceHolder(
    #     RichText => 0,
    #     Text     => $TicketParam{Title},
    #     TicketID => $Param{TicketID},
    #     Data     => {
    #         # TODO: currently not used
    #         %TicketParam
    #     },
    #     UserID   => $Param{UserID},
    # );

    # create ticket
    my $TicketID = $TicketObject->TicketCreate(
        %TicketParam,
        UserID => $Param{UserID}
    );

    if ( !$TicketID ) {
        $Kernel::OM->Get('Automation')->LogError(
            Referrer => $Self,
            Message  => "Couldn't create new ticket!",
            UserID   => $Param{UserID}
        );
        return;
    }

    # get state information
    my %StateData = $Kernel::OM->Get('State')->StateGet(
        Name => $TicketParam{State},
    );

    if ( %StateData && $StateData{TypeName} =~ /^close/i ) {

        # closed tickets get unlocked
        $TicketObject->TicketLockSet(
            TicketID => $TicketID,
            Lock     => 'unlock',
            UserID   => $Param{UserID},
        );
    } elsif ( %StateData && $StateData{TypeName} =~ m{\A pending}msxi ) {
        $Param{Config}->{PendingTimeDiff} = $Kernel::OM->Get('TemplateGenerator')->ReplacePlaceHolder(
            RichText => 0,
            Text     => $Param{Config}->{PendingTimeDiff},
            TicketID => $Param{TicketID},
            Data     => {},
            UserID   => $Param{UserID},
        );

        # set pending time
        $TicketObject->TicketPendingTimeSet(
            UserID   => $Param{UserID},
            TicketID => $TicketID,
            Diff     => $Param{Config}->{PendingTimeDiff},
        );
    }

    $Self->_SetDynamicFields(%Param, NewTicketID => $TicketID);

    # remember ticket definition
    my $TicketDef = $Self->{Definition}->{Options};

    # use article definition
    $Self->{Definition}->{Options} = {};
    $Self->SUPER::Describe(%Param);

    # collect article params based on definition
    my %ArticleParam;
    if ( IsHashRefWithData($Self->{Definition}->{Options}) ) {
        for my $Attribute ( %{$Self->{Definition}->{Options}} ) {
            if ( defined $Param{Config}->{$Attribute} ) {
                $ArticleParam{$Attribute} = $Param{Config}->{$Attribute}
            }
        }
    }
    $ArticleParam{Subject} = $TicketParam{Title};
    $ArticleParam{Body} = $Kernel::OM->Get('TemplateGenerator')->ReplacePlaceHolder(
        RichText => 1,
        Text     => $ArticleParam{Body},
        TicketID => $Param{TicketID},
        Data     => {
            # TODO: currently not used
            %TicketParam
        },
        UserID   => $Param{UserID},
    );

    # create article
    my $ArticleBackendResult = $Self->SUPER::Run(
        Config   => \%ArticleParam,
        TicketID => $TicketID,
        UserID   => $Param{UserID}
    );

    # reset definition
    $Self->{Definition}->{Options} = $TicketDef;

    if ( !$ArticleBackendResult ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Couldn't create Article on Ticket: $TicketID!",
        );
        return;
    }

    return 1;
}

=item ValidateConfig()

Validates the parameters of the config.

Example:
    my $Valid = $Self->ValidateConfig(
        Config => {}                # required
    );

=cut

sub ValidateConfig {
    my ( $Self, %Param ) = @_;

    return if !$Self->SUPER::ValidateConfig(%Param);

    my %State = $Kernel::OM->Get('State')->StateGet(
        Name => $Param{Config}->{State}
    );

    if (%State) {
        if ( $State{TypeName} =~ m{\A pending}msxi && !IsNumber( $Param{Config}->{PendingTimeDiff} ) ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Validation of parameter \"PendingTimeDiff\" failed!"
            );
            return;
        }
    }

    return 1;
}

sub _CheckTicketParams {
    my ( $Self, %Param ) = @_;

    # if ($Param{Contact}) {
    #     my $ContactID = $Kernel::OM->Get('Contact')->ContactLookup(
    #         Login  => $Param{Contact},
    #         Silent => 1
    #     );

    #     if ( !$ContactID ) {
    #         $Kernel::OM->Get('Automation')->LogError(
    #             Referrer => $Self,
    #             Message  => "Couldn't create new ticket - can't find contact with login \"$Param{Contact}\"!",
    #             UserID   => $Param{UserID}
    #         );
    #         return;
    #     }
    # }

    if ($Param{Lock}) {
        my $LockID = $Kernel::OM->Get('Lock')->LockLookup(
            Lock => $Param{Lock},
        );

        if ( !$LockID ) {
            $Kernel::OM->Get('Automation')->LogError(
                Referrer => $Self,
                Message  => "Couldn't create new ticket - can't find lock state \"$Param{Lock}\"!",
                UserID   => $Param{UserID}
            );
            return;
        }
    }

    # if ($Param{Organisation}) {
    #     my $OrganisationID = $Kernel::OM->Get('Organisation')->OrganisationLookup(
    #         Number => $Param{Organisation},
    #         Silent => 1
    #     );

    #     if ( !$OrganisationID ) {
    #         $Kernel::OM->Get('Automation')->LogError(
    #             Referrer => $Self,
    #             Message  => "Couldn't create new ticket - can't find organisation with number \"$Param{Organisation}\"!",
    #             UserID   => $Param{UserID}
    #         );
    #         return;
    #     }
    # }

    for my $UserType ( qw(Owner Responsible) ) {
        if ($Param{$UserType}) {
            my $UserID = $Kernel::OM->Get('User')->UserLookup(
                UserLogin => $Param{$UserType},
            );

            if ( !$UserID ) {
                $Kernel::OM->Get('Automation')->LogError(
                    Referrer => $Self,
                    Message  => "Couldn't create new ticket - can't find user with login \"$Param{$UserType}\"!",
                    UserID   => $Param{UserID}
                );
                return;
            }
        }
    }

    if ($Param{Priority}) {
        my $PriorityID = $Kernel::OM->Get('Priority')->PriorityLookup(
            Priority => $Param{Priority}
        );

        if ( !$PriorityID ) {
            $Kernel::OM->Get('Automation')->LogError(
                Referrer => $Self,
                Message  => "Couldn't create new ticket - can't find ticket priority \"$Param{Priority}\"!",
                UserID   => $Param{UserID}
            );
            return;
        }
    }

    if ($Param{State}) {
        my %State = $Kernel::OM->Get('State')->StateGet(
            Name => $Param{State}
        );

        if ( !%State ) {
            $Kernel::OM->Get('Automation')->LogError(
                Referrer => $Self,
                Message  => "Couldn't create new ticket - can't find ticket state \"$Param{State}\"!",
                UserID   => $Param{UserID}
            );
            return;
        }

        if ( $State{TypeName} =~ m{\A pending}msxi && !IsNumber( $Param{PendingTimeDiff} ) ) {
            $Kernel::OM->Get('Automation')->LogError(
                Referrer => $Self,
                Message  => "Couldn't create new ticket - \"PendingTimeDiff\" value ($Param{PendingTimeDiff}) is not valid!",
                UserID   => $Param{UserID}
            );
            return;
        }
    }

    if ($Param{Team}) {
        my $QueueID = $Kernel::OM->Get('Queue')->QueueLookup(
            Queue => $Param{Team}
        );

        if ( !$QueueID ) {
            $Kernel::OM->Get('Automation')->LogError(
                Referrer => $Self,
                Message  => "Couldn't create new ticket - can't find ticket team \"$Param{Team}\"!",
                UserID   => $Param{UserID}
            );
            return;
        }
    }

    if ($Param{Type}) {
        my $TypeID = $Kernel::OM->Get('Type')->TypeLookup(
            Type => $Param{Type},
        );

        if ( !$TypeID ) {
            $Kernel::OM->Get('Automation')->LogError(
                Referrer => $Self,
                Message  => "Couldn't create new ticket - can't find ticket type \"$Param{Type}\"!",
                UserID   => $Param{UserID}
            );
            return;
        }
    }

    return 1;
}

sub _SetDynamicFields {
    my ( $Self, %Param ) = @_;

    # set dynamic fields
    if ( $Param{NewTicketID} && IsArrayRefWithData( $Param{Config}->{DynamicFieldList} ) ) {

        my $TemplateGeneratorObject   = $Kernel::OM->Get('TemplateGenerator');
        my $DynamicFieldBakcendObject = $Kernel::OM->Get('DynamicField::Backend');

        # get the dynamic fields
        my $DynamicFieldList = $Kernel::OM->Get('DynamicField')->DynamicFieldListGet(
            Valid      => 1,
            ObjectType => [ 'Ticket' ],
        );

        # create a Dynamic Fields lookup table (by name)
        my %DynamicFieldLookup;
        for my $DynamicField ( @{$DynamicFieldList} ) {
            next if !$DynamicField;
            next if !IsHashRefWithData($DynamicField);
            next if !$DynamicField->{Name};
            $DynamicFieldLookup{ $DynamicField->{Name} } = $DynamicField;
        }

        DYNAMICFIELD:
        foreach my $DynamicField ( @{ $Param{Config}->{DynamicFieldList} } ) {
            next if (
                !IsArrayRefWithData($DynamicField)
                || !$DynamicField->[0]
                || !IsHashRefWithData( $DynamicFieldLookup{$DynamicField->[0]} )
            );

            my $Value = $TemplateGeneratorObject->ReplacePlaceHolder(
                RichText => 0,
                Text     => $DynamicField->[1],
                TicketID => $Param{TicketID}, # id of start ticket
                Data     => {},
                UserID   => $Param{UserID},
            );

            # check value structure
            next if ( !IsString( $Value ) && ref $Value ne 'ARRAY' && defined($Value) );

            my $Success = $DynamicFieldBakcendObject->ValueSet(
                DynamicFieldConfig => $DynamicFieldLookup{$DynamicField->[0]},
                ObjectID           => $Param{NewTicketID},
                Value              => $Value,
                UserID             => $Param{UserID},
            );
        }
    }
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
