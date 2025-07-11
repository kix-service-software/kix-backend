# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/ 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Validator::UserPasswordValidator;

use strict;
use warnings;

use base qw(
    Kernel::API::Validator::Common
);

# prevent 'Used once' warning for Kernel::OM
use Kernel::System::ObjectManager;

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Validator::UserPasswordValidator - validator module

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

=item Validate()

validate given data attribute

    my $Result = $ValidatorObject->Validate(
        Attribute => '...',                     # required
        Data      => {                          # required but may be empty
            ...
        }
    );

    $Result = {
        Success         => 1,                   # 0 or 1
        ErrorMessage    => '',                  # in case of error
    };

=cut

sub Validate {
    my ( $Self, %Param ) = @_;

    # check params
    if ( !$Param{Attribute} ) {
        return $Self->_Error(
            Code    => 'Validator.InternalError',
            Message => 'Got no Attribute!',
        );
    }

    my $RequirementMessage = $Param{Config}->{RequirementMessage} || 'Given password does not match the requirements';

    if ( $Param{Attribute} eq 'UserPw' ) {
        if (
            $Param{Config}->{MinSize}
            && length( $Param{Data}->{ $Param{Attribute} } ) < $Param{Config}->{MinSize}
        ) {
            return $Self->_Error(
                Code    => 'Validator.Failed',
                Message => $Kernel::OM->Get('Language')->Translate($RequirementMessage)
            );
        }

        if (
            $Param{Config}->{MaxSize}
            && (
                !$Param{Config}->{MinSize}
                || $Param{Config}->{MinSize} <= $Param{Config}->{MaxSize}
            )
            && length( $Param{Data}->{ $Param{Attribute} } ) > $Param{Config}->{MaxSize}
        ) {
            return $Self->_Error(
                Code    => 'Validator.Failed',
                Message => $Kernel::OM->Get('Language')->Translate($RequirementMessage)
            );
        }

        my $CheckCount = 0;
        if ( ref( $Param{Config}->{Checks} ) eq 'ARRAY' ) {
            for my $Check ( @{ $Param{Config}->{Checks} } ) {
                my $MatchCount = () = $Param{Data}->{ $Param{Attribute} } =~ /$Check->{RegExp}/g;

                my $CheckFulfillment = 1;
                if (
                    $Check->{MinCount}
                    && $MatchCount < $Check->{MinCount}
                ) {
                    $CheckFulfillment = 0;
                }
                elsif (
                    $Check->{MaxCount}
                    && $MatchCount > $Check->{MaxCount}
                ) {
                    $CheckFulfillment = 0;
                }

                if ( $CheckFulfillment ) {
                    $CheckCount += 1;
                }
                elsif ( $Check->{Required} ) {
                    return $Self->_Error(
                        Code    => 'Validator.Failed',
                        Message => $Kernel::OM->Get('Language')->Translate($RequirementMessage)
                    );
                }
            }
        }
        if (
            $Param{Config}->{MinChecks}
            && $CheckCount < $Param{Config}->{MinChecks}
        ) {
            return $Self->_Error(
                Code    => 'Validator.Failed',
                Message => $Kernel::OM->Get('Language')->Translate($RequirementMessage)
            );
        }

        if ( ref( $Param{Config}->{Stopwords} ) eq 'ARRAY' ) {
            for my $Stopword ( @{$Param{Config}->{Stopwords}} ) {
                if ( $Param{Data}->{ $Param{Attribute} } =~ /\Q$Stopword\E/i ) {
                    return $Self->_Error(
                        Code    => 'Validator.Failed',
                        Message => $Kernel::OM->Get('Language')->Translate(
                            '%s must not contain "%s"!',
                            $Param{Attribute}, $Stopword
                        )
                    );
                }
            }
        }
    }
    else {
        return $Self->_Error(
            Code    => 'Validator.UnknownAttribute',
            Message => "UserPasswordValidator: cannot validate attribute $Param{Attribute}!",
        );
    }

    return $Self->_Success();
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
