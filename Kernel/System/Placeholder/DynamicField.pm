# --
# Modified version of the work: Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Placeholder::DynamicField;

use strict;
use warnings;

use Kernel::Language;

use Kernel::System::VariableCheck qw(:all);

use base qw(Kernel::System::Placeholder::Base);

our @ObjectDependencies = (
    'DynamicField',
    'DynamicField::Backend',
    'Log'
);

=head1 NAME

Kernel::System::Placeholder::DynamicField

=cut

=begin Internal:

=cut

sub _Replace {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(Text UserID)) {
        if ( !defined $Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    # get dynamic field objects
    $Self->{DynamicFieldObject}        = $Kernel::OM->Get('DynamicField');
    $Self->{DynamicFieldBackendObject} = $Kernel::OM->Get('DynamicField::Backend');

    # get all supported object types
    my $ObjectTypes = $Kernel::OM->Get('Config')->Get('DynamicFields::ObjectType') || {};

    for my $ObjectType ( sort keys %{$ObjectTypes}, 'Owner', 'Responsible', 'Current' ) {
        my $Tag = $Self->{Start} . 'KIX_'.uc($ObjectType).'_DynamicField_';

        # use right tag, but with backward compatibility
        if ( $ObjectType eq 'Organisation' ) {
            $Tag = $Self->{Start} . 'KIX_(?:ORG|ORGANISATION)_DynamicField_';
        } elsif ( $ObjectType eq 'Owner' ) {
            $Tag = $Self->{Start} . 'KIX_(?:TICKET_?)?OWNER_DynamicField_';
        } elsif ( $ObjectType eq 'Responsible' ) {
            $Tag = $Self->{Start} . 'KIX_(?:TICKET_?)?RESPONSIBLE_DynamicField_';
        } elsif ( $ObjectType eq 'FAQArticle' ) {
            $Tag = $Self->{Start} . 'KIX_FAQ_DynamicField_';
        }

        if ($Param{Text} =~ m/$Tag/) {
            if ( $ObjectType eq 'Ticket' ) {
                my $Ticket = $Param{Ticket};
                if ( !IsHashRefWithData($Ticket) ) {
                    my $TicketID = $Param{TicketID} ||
                        (IsHashRefWithData($Param{Data}) && $Param{Data}->{TicketID}) ? $Param{Data}->{TicketID} :
                            ( $Param{ObjectType} && $Param{ObjectType} eq 'Ticket' && $Param{ObjectID} ) ? $Param{ObjectID} : undef;
                    if ( $TicketID ) {
                        my %Ticket = $Kernel::OM->Get('Ticket')->TicketGet(
                            TicketID      => $TicketID,
                            DynamicFields => 1,
                            UserID        => $Param{UserID}
                        );
                        if (%Ticket) {
                            $Ticket = \%Ticket;
                        }
                    }
                }
                if (IsHashRefWithData($Ticket)) {
                    $Param{Text} = $Self->_ReplaceDynamicFieldPlaceholder(
                        %Param,
                        Tag        => $Tag,
                        Object     => $Ticket,
                        ObjectType => $ObjectType
                    );
                }
            }
            elsif ( $ObjectType eq 'Contact' ) {
                my $ContactID =
                    ( IsHashRefWithData($Param{Data}) && $Param{Data}->{ContactID} ) ? $Param{Data}->{ContactID} :
                        ( $Param{ObjectType} && $Param{ObjectType} eq 'Contact' && $Param{ObjectID} ) ? $Param{ObjectID} :
                            ( IsHashRefWithData($Param{Ticket}) && $Param{Ticket}->{ContactID} ) ? $Param{Ticket}->{ContactID} : undef;
                if ( $ContactID ) {
                    my %Contact = $Kernel::OM->Get('Contact')->ContactGet(
                        ID            => $ContactID,
                        DynamicFields => 1,
                        UserID        => $Param{UserID}
                    );
                    if (%Contact) {
                        $Param{Text} = $Self->_ReplaceDynamicFieldPlaceholder(
                            %Param,
                            Tag        => $Tag,
                            Object     => \%Contact,
                            ObjectType => $ObjectType
                        );
                    }
                }
            }
            elsif ( $ObjectType eq 'Organisation' ) {
                my $OrgID =
                    ( IsHashRefWithData($Param{Data}) && $Param{Data}->{OrganisationID} ) ? $Param{Data}->{OrganisationID}:
                        ( $Param{ObjectType} && $Param{ObjectType} eq 'Organisation' && $Param{ObjectID} ) ? $Param{ObjectID} :
                            ( IsHashRefWithData($Param{Ticket}) && $Param{Ticket}->{OrganisationID} ) ? $Param{Ticket}->{OrganisationID} : undef;
                if ( $OrgID ) {
                    my %Organisation = $Kernel::OM->Get('Organisation')->OrganisationGet(
                        ID            => $OrgID,
                        DynamicFields => 1,
                        UserID        => $Param{UserID}
                    );
                    if (%Organisation) {
                        $Param{Text} = $Self->_ReplaceDynamicFieldPlaceholder(
                            %Param,
                            Tag        => $Tag,
                            Object     => \%Organisation,
                            ObjectType => $ObjectType
                        );
                    }
                }
            }
            elsif ( $ObjectType eq 'FAQArticle' ) {
                my $FAQID =
                    ( IsHashRefWithData($Param{Data}) && $Param{Data}->{FAQID} ) ? $Param{Data}->{FAQID}:
                        ( $Param{ObjectType} && $Param{ObjectType} eq 'FAQ' && $Param{ObjectID} ) ? $Param{ObjectID} : undef;
                if ( $FAQID ) {
                    my %FAQArticle = $Kernel::OM->Get('FAQ')->FAQGet(
                        ItemID        => $FAQID,
                        DynamicFields => 1,
                        UserID        => $Param{UserID}
                    );
                    if (%FAQArticle) {
                        $Param{Text} = $Self->_ReplaceDynamicFieldPlaceholder(
                            %Param,
                            Tag        => $Tag,
                            Object     => \%FAQArticle,
                            ObjectType => $ObjectType
                        );
                    }
                }
            }

            # get contact object by user
            elsif (
                $ObjectType eq 'Owner' &&
                IsHashRefWithData($Param{Ticket}) && $Param{Ticket}->{OwnerID}
            ) {
                my %Contact = $Kernel::OM->Get('Contact')->ContactGet(
                    UserID        => $Param{Data}->{OwnerID} || $Param{Ticket}->{OwnerID},
                    DynamicFields => 1,
                    UserID        => $Param{UserID}
                );
                if (%Contact) {
                    $Param{Text} = $Self->_ReplaceDynamicFieldPlaceholder(
                        %Param,
                        Tag        => $Tag,
                        Object     => \%Contact,
                        ObjectType => 'Contact'
                    );
                }
            }
            elsif (
                $ObjectType eq 'Responsible' &&
                IsHashRefWithData($Param{Ticket}) && $Param{Ticket}->{ResponsibleID}
            ) {
                my %Contact = $Kernel::OM->Get('Contact')->ContactGet(
                    UserID        => $Param{Data}->{ResponsibleID} || $Param{Ticket}->{ResponsibleID},
                    DynamicFields => 1,
                    UserID        => $Param{UserID}
                );
                if (%Contact) {
                    $Param{Text} = $Self->_ReplaceDynamicFieldPlaceholder(
                        %Param,
                        Tag        => $Tag,
                        Object     => \%Contact,
                        ObjectType => 'Contact'
                    );
                }
            }
            elsif ( $ObjectType eq 'Current' && $Param{UserID} ) {
                my %Contact = $Kernel::OM->Get('Contact')->ContactGet(
                    UserID        => $Param{UserID},
                    DynamicFields => 1,
                    UserID        => $Param{UserID}
                );
                if (%Contact) {
                    $Param{Text} = $Self->_ReplaceDynamicFieldPlaceholder(
                        %Param,
                        Tag        => $Tag,
                        Object     => \%Contact,
                        ObjectType => 'Contact'
                    );
                }
            }

            # cleanup
            $Param{Text} =~ s/$Tag.+?$Self->{End}/$Param{ReplaceNotFound}/gi;
        }
    }

    return $Param{Text};
}

sub _ReplaceDynamicFieldPlaceholder {
    my ( $Self, %Param ) = @_;

    if ( IsHashRefWithData($Param{Object}) ) {

        # Dropdown, Checkbox and MultipleSelect DynamicFields, can store values (keys) that are
        # different from the the values to display, i.e.
        # <KIX_TICKET_DynamicField_NameX> returns the display value
        # <KIX_TICKET_DynamicField_NameX_Value> also returns the display value
        # <KIX_TICKET_DynamicField_NameX_Key> returns the stored key for select fields (multiselect, reference)
        # <KIX_TICKET_DynamicField_NameX_HTML> returns a special HTML display value (e.g. checklist) or default display value
        # <KIX_TICKET_DynamicField_NameX_Short> returns a short display value (e.g. checklist) or default display value
        # <KIX_TICKET_DynamicField_NameX_ObjectValue...> returns the raw value(s) - with position ("_0" at the end) a certain value can be used, without position the array of values will be returned
        # <KIX_TICKET_DynamicField_NameX_Object...> returns the value of the corresponding object (for reference types) - something like "_0_Name" is needed (would be the name of the first object)
        # <KIX_TICKET_DynamicField_NameX!> same as _ObjectValue

        my %DynamicFields;
        my %DynamicFieldsObject;

        # For systems with many Dynamic fields we do not want to load them all unless needed
        # Find what Dynamic Field Values are requested
        while ( $Param{Text} =~ m/$Param{Tag}(\S+?)(!|_Value|_Key|_HTML|_Short|_ObjectValue(_\d+)?|_Object_\d+.+?)?$Self->{End}/gixms ) {
                my $DFName = $1;
                my $Type = $2;
                $DynamicFields{$DFName} = 1;
                if ($Type && $Type =~ m/_Object_/) {
                    # remember every object placeholder
                    if (!IsArrayRefWithData($DynamicFieldsObject{$DFName})) {
                        $DynamicFieldsObject{$DFName} = [];
                    }
                    push( @{ $DynamicFieldsObject{$DFName} }, $Type);
                }
        }

        # to store all the required DynamicField display values
        my %DynamicFieldDisplayValues;

        # get the dynamic fields for object
        my $DynamicFieldList = $Self->{DynamicFieldObject}->DynamicFieldListGet(
            Valid      => 1,
            ObjectType => [ $Param{ObjectType} ],
        ) || [];

        DYNAMICFIELD:
        for my $DynamicFieldConfig ( @{$DynamicFieldList} ) {
            next DYNAMICFIELD if !IsHashRefWithData($DynamicFieldConfig);

            # only prepare values of the requested ones
            next DYNAMICFIELD if !$DynamicFields{ $DynamicFieldConfig->{Name} };

            # "prepare" object value
            my @Values;
            if ( ref $Param{Object}->{ 'DynamicField_' . $DynamicFieldConfig->{Name} } eq 'ARRAY' ) {
                @Values = @{ $Param{Object}->{ 'DynamicField_' . $DynamicFieldConfig->{Name} } };
            } elsif ( defined $Param{Object}->{ 'DynamicField_' . $DynamicFieldConfig->{Name} } ) {
                @Values = ( $Param{Object}->{ 'DynamicField_' . $DynamicFieldConfig->{Name} } );
            }

            # return object value if text is just "_ObjectValue" placeholder (no surrounding text)
            my $ReturnObjectValue;
            if ($Param{Text} =~ m/^$Param{Tag}(\S+?)(ObjectValue|!)$Self->{End}$/gixms) {

                # but not (now) if _Object_ is included => handle sub object value
                if ($Param{Text} !~ m/_Object_/) {
                    return \@Values;
                }

                $ReturnObjectValue = 1;
            }

            my $Index = 0;
            for my $ObjectValue (@Values) {
                $DynamicFieldDisplayValues{ $DynamicFieldConfig->{Name} . '_ObjectValue_' . $Index } = $ObjectValue;
                $Index++;
            }
            $DynamicFieldDisplayValues{ $DynamicFieldConfig->{Name} . '_ObjectValue' } = join(',',@Values);
            $DynamicFieldDisplayValues{ $DynamicFieldConfig->{Name} . '!' } = join(',',@Values);

            # get the display values for each dynamic field
            my $DisplayValueStrg = $Self->{DynamicFieldBackendObject}->DisplayValueRender(
                DynamicFieldConfig => $DynamicFieldConfig,
                Value              => $Param{Object}->{ 'DynamicField_' . $DynamicFieldConfig->{Name} },
                HTMLOutput         => $Param{RichText}
            );
            if ( IsHashRefWithData($DisplayValueStrg) ) {
                $DynamicFieldDisplayValues{ $DynamicFieldConfig->{Name} . '_Value' }
                    = $DisplayValueStrg->{Value};
                $DynamicFieldDisplayValues{ $DynamicFieldConfig->{Name} }
                    = $DisplayValueStrg->{Value};
            }

            # get the display keys for each dynamic field
            my $DisplayKeyStrg = $Self->{DynamicFieldBackendObject}->DisplayKeyRender(
                DynamicFieldConfig => $DynamicFieldConfig,
                Value              => $Param{Object}->{ 'DynamicField_' . $DynamicFieldConfig->{Name} },
            );

            if (IsHashRefWithData($DisplayKeyStrg) && defined $DisplayKeyStrg->{Value} && $DisplayKeyStrg->{Value} ne '') {
                $DynamicFieldDisplayValues{ $DynamicFieldConfig->{Name} . '_Key' }
                    = $DisplayKeyStrg->{Value} ;
            } elsif (IsHashRefWithData($DisplayValueStrg)) {
                $DynamicFieldDisplayValues{ $DynamicFieldConfig->{Name} . '_Key' }
                    = $DisplayValueStrg->{Value};
            }

            # get the html display values for each dynamic field
            my $HTMLDisplayValueStrg = $Self->{DynamicFieldBackendObject}->HTMLDisplayValueRender(
                DynamicFieldConfig => $DynamicFieldConfig,
                Value              => $Param{Object}->{ 'DynamicField_' . $DynamicFieldConfig->{Name} },
            );
            if ( IsHashRefWithData($HTMLDisplayValueStrg) && $HTMLDisplayValueStrg->{Value} ) {
                $DynamicFieldDisplayValues{ $DynamicFieldConfig->{Name} . '_HTML' }
                    = $HTMLDisplayValueStrg->{Value};
            } elsif (IsHashRefWithData($DisplayValueStrg)) {
                $DynamicFieldDisplayValues{ $DynamicFieldConfig->{Name} . '_HTML' }
                    = $DisplayValueStrg->{Value};
            }

            # get the short display values for each dynamic field
            my $ShortDisplayValueStrg = $Self->{DynamicFieldBackendObject}->ShortDisplayValueRender(
                DynamicFieldConfig => $DynamicFieldConfig,
                Value              => $Param{Object}->{ 'DynamicField_' . $DynamicFieldConfig->{Name} },
            );
            if ( IsHashRefWithData($ShortDisplayValueStrg) && $ShortDisplayValueStrg->{Value} ) {
                $DynamicFieldDisplayValues{ $DynamicFieldConfig->{Name} . '_Short' }
                    = $ShortDisplayValueStrg->{Value};
            } elsif (IsHashRefWithData($DisplayValueStrg)) {
                $DynamicFieldDisplayValues{ $DynamicFieldConfig->{Name} . '_Short' }
                    = $DisplayValueStrg->{Value};
            }

            # prepare object values if needed
            if ( IsArrayRefWithData( $DynamicFieldsObject{ $DynamicFieldConfig->{Name} } ) ) {
                for my $ObjectPlaceholder ( @{ $DynamicFieldsObject{ $DynamicFieldConfig->{Name} } } ) {
                    my $ObjectValueStrg = $Self->{DynamicFieldBackendObject}->DFValueObjectReplace(
                        DynamicFieldConfig => $DynamicFieldConfig,
                        Value              => $Param{Object}->{ 'DynamicField_' . $DynamicFieldConfig->{Name} },
                        Placeholder        => $ObjectPlaceholder,
                        UserID             => $Param{UserID},
                        Language           => $Param{Language},
                        KeepValueAsIs      => $Param{KeepValueAsIs}
                    );
                    if ( $ObjectValueStrg ) {
                        $DynamicFieldDisplayValues{ $DynamicFieldConfig->{Name} . $ObjectPlaceholder } = $ObjectValueStrg;
                    }

                    # return value - no text replacement
                    return $ObjectValueStrg if ($ReturnObjectValue);
                }
            }
        }

        # replace it
        $Param{Text} = $Self->_HashGlobalReplace( $Param{Text}, $Param{Tag}, %DynamicFieldDisplayValues );
    }
    return $Param{Text};
}

1;

=end Internal:

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
