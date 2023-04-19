# --
# Modified version of the work: Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com 
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

    # get all supported object types
    my $ObjectTypes = $Kernel::OM->Get('Config')->Get('DynamicFields::ObjectType') || {};

    foreach my $ObjectType ( sort keys %{$ObjectTypes} ) {

        my $Tag = $Self->{Start} . 'KIX_'.uc($ObjectType).'_DynamicField_';

        # get objects
        my $Object;
        if ( $ObjectType eq 'Ticket' && (IsHashRefWithData($Param{Ticket}) || $Param{TicketID}) ) {
            $Object = $Param{Ticket};
            if ( !IsHashRefWithData($Object) && $Param{TicketID} ) {
                my %Ticket = $Kernel::OM->Get('Ticket')->TicketGet(
                    TicketID      => $Param{TicketID},
                    DynamicFields => 1,
                );
                $Object = \%Ticket;
            }
        }
        elsif ( $ObjectType eq 'Contact' && ($Param{Data}->{ContactID} || $Param{Ticket}->{ContactID}) ) {
            my %Contact = $Kernel::OM->Get('Contact')->ContactGet(
                ID            => $Param{Data}->{ContactID} || $Param{Ticket}->{ContactID},
                DynamicFields => 1,
            );
            $Object = \%Contact;
        }
        elsif ( $ObjectType eq 'Organisation' && ($Param{Data}->{OrganisationID} || $Param{Ticket}->{OrganisationID}) ) {
            my %Organisation = $Kernel::OM->Get('Organisation')->OrganisationGet(
                ID            => $Param{Data}->{OrganisationID} || $Param{Ticket}->{OrganisationID},
                DynamicFields => 1,
            );
            $Object = \%Organisation;

            # use right tag, but with backward compatibility
            $Tag = $Self->{Start} . 'KIX_(?:ORG|'.uc($ObjectType).')_DynamicField_';
        }

        if ( IsHashRefWithData($Object) ) {

            # Dropdown, Checkbox and MultipleSelect DynamicFields, can store values (keys) that are
            # different from the the values to display, i.e.
            # <KIX_TICKET_DynamicField_NameX> returns the display value
            # <KIX_TICKET_DynamicField_NameX_Value> also returns the display value
            # <KIX_TICKET_DynamicField_NameX_Key> returns the stored key for select fields (multiselect, reference)
            # <KIX_TICKET_DynamicField_NameX_HTML> returns a special HTML display value (e.g. checklist) or default display value
            # <KIX_TICKET_DynamicField_NameX_Short> returns a short display value (e.g. checklist) or default display value
            # <KIX_TICKET_DynamicField_NameX_ObjectValue> returns the raw value(s) - with position ("_0" at the end) a certain value can be used, wihtout the value with index 0 is used

            my %DynamicFields;

            # For systems with many Dynamic fields we do not want to load them all unless needed
            # Find what Dynamic Field Values are requested
            while ( $Param{Text} =~ m/$Tag(\S+?)(_Value|_Key|_HTML|_Short|_ObjectValue(_\d+)?)? $Self->{End}/gixms ) {
                $DynamicFields{$1} = 1;
            }

            # to store all the required DynamicField display values
            my %DynamicFieldDisplayValues;

            # get dynamic field objects
            my $DynamicFieldObject        = $Kernel::OM->Get('DynamicField');
            my $DynamicFieldBackendObject = $Kernel::OM->Get('DynamicField::Backend');

            # get the dynamic fields for ticket object
            my $DynamicFieldList = $DynamicFieldObject->DynamicFieldListGet(
                Valid      => 1,
                ObjectType => [ $ObjectType ],
            ) || [];

            DYNAMICFIELD:
            for my $DynamicFieldConfig ( @{$DynamicFieldList} ) {
                next DYNAMICFIELD if !IsHashRefWithData($DynamicFieldConfig);

                # only prepare values of the requested ones
                next DYNAMICFIELD if !$DynamicFields{ $DynamicFieldConfig->{Name} };

                # "prepare" object value
                my @Values;
                if ( ref $Object->{ 'DynamicField_' . $DynamicFieldConfig->{Name} } eq 'ARRAY' ) {
                    @Values = @{ $Object->{ 'DynamicField_' . $DynamicFieldConfig->{Name} } };
                } else {
                    @Values = ( $Object->{ 'DynamicField_' . $DynamicFieldConfig->{Name} } );
                }
                my $Index = 0;
                for my $ObjectValue (@Values) {
                    if ($Index == 0) {
                        $DynamicFieldDisplayValues{ $DynamicFieldConfig->{Name} . '_ObjectValue' } = $ObjectValue;
                    }
                    $DynamicFieldDisplayValues{ $DynamicFieldConfig->{Name} . '_ObjectValue_' . $Index } = $ObjectValue;
                    $Index++;
                }

                # get the display values for each dynamic field
                my $DisplayValueStrg = $DynamicFieldBackendObject->DisplayValueRender(
                    DynamicFieldConfig => $DynamicFieldConfig,
                    Value              => $Object->{ 'DynamicField_' . $DynamicFieldConfig->{Name} },
                    HTMLOutput         => $Param{RichText}
                );
                if ( IsHashRefWithData($DisplayValueStrg) ) {
                    $DynamicFieldDisplayValues{ $DynamicFieldConfig->{Name} . '_Value' }
                        = $DisplayValueStrg->{Value};
                    $DynamicFieldDisplayValues{ $DynamicFieldConfig->{Name} }
                        = $DisplayValueStrg->{Value};
                }

                # get the display keys for each dynamic field
                my $DisplayKeyStrg = $DynamicFieldBackendObject->DisplayKeyRender(
                    DynamicFieldConfig => $DynamicFieldConfig,
                    Value              => $Object->{ 'DynamicField_' . $DynamicFieldConfig->{Name} },
                );

                if (IsHashRefWithData($DisplayKeyStrg) && defined $DisplayKeyStrg->{Value} && $DisplayKeyStrg->{Value} ne '') {
                    $DynamicFieldDisplayValues{ $DynamicFieldConfig->{Name} . '_Key' }
                        = $DisplayKeyStrg->{Value} ;
                } elsif (IsHashRefWithData($DisplayValueStrg)) {
                    $DynamicFieldDisplayValues{ $DynamicFieldConfig->{Name} . '_Key' }
                        = $DisplayValueStrg->{Value};
                }

                # get the html display values for each dynamic field
                my $HTMLDisplayValueStrg = $DynamicFieldBackendObject->HTMLDisplayValueRender(
                    DynamicFieldConfig => $DynamicFieldConfig,
                    Value              => $Object->{ 'DynamicField_' . $DynamicFieldConfig->{Name} },
                );
                if ( IsHashRefWithData($HTMLDisplayValueStrg) && $HTMLDisplayValueStrg->{Value} ) {
                    $DynamicFieldDisplayValues{ $DynamicFieldConfig->{Name} . '_HTML' }
                        = $HTMLDisplayValueStrg->{Value};
                } elsif (IsHashRefWithData($DisplayValueStrg)) {
                    $DynamicFieldDisplayValues{ $DynamicFieldConfig->{Name} . '_HTML' }
                        = $DisplayValueStrg->{Value};
                }

                # get the short display values for each dynamic field
                my $ShortDisplayValueStrg = $DynamicFieldBackendObject->ShortDisplayValueRender(
                    DynamicFieldConfig => $DynamicFieldConfig,
                    Value              => $Object->{ 'DynamicField_' . $DynamicFieldConfig->{Name} },
                );
                if ( IsHashRefWithData($ShortDisplayValueStrg) && $ShortDisplayValueStrg->{Value} ) {
                    $DynamicFieldDisplayValues{ $DynamicFieldConfig->{Name} . '_Short' }
                        = $ShortDisplayValueStrg->{Value};
                } elsif (IsHashRefWithData($DisplayValueStrg)) {
                    $DynamicFieldDisplayValues{ $DynamicFieldConfig->{Name} . '_Short' }
                        = $DisplayValueStrg->{Value};
                }
            }

            # replace it
            $Param{Text} = $Self->_HashGlobalReplace( $Param{Text}, $Tag, %DynamicFieldDisplayValues );
        }

        # cleanup
        $Param{Text} =~ s/$Tag.+?$Self->{End}/$Param{ReplaceNotFound}/gi;
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
