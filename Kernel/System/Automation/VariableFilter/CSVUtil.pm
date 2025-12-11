# --
# Modified version of the work: Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/ 
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Automation::VariableFilter::CSVUtil;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);
use base qw(
    Kernel::System::Automation::VariableFilter::Common
);

our @ObjectDependencies = ();

sub GetFilterHandler {
    my ( $Self, %Param ) = @_;

    my %Handler = (
        'CSVUtil.AsArrayList' => \&_CSVAsArrayList,
        'CSVUtil.AsObjectList' => \&_CSVAsObjectList,
    );

    return %Handler;
}

sub _CSVAsArrayList {
    my ( $Self, %Param ) = @_;

    if ( !IsStringWithData( $Param{Value} ) ) {
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "\"CSVUtil.CSV2Array\" need string with data!"
            );
        }
        return $Param{Value};
    }

    return $Kernel::OM->Get('CSV')->CSV2Array(
        String    => $Param{Value},
        Separator => $Param{Parameter} || ';',
    );
}

sub _CSVAsObjectList {
    my ( $Self, %Param ) = @_;

    if ( !IsStringWithData( $Param{Value} ) ) {
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "\"CSVUtil.CSV2Array\" need string with data!"
            );
        }
        return $Param{Value};
    }

    my $RefArray = $Kernel::OM->Get('CSV')->CSV2Array(
        String    => $Param{Value},
        Separator => $Param{Parameter} || ';',
    );

    my @Result = ();
    if ( IsArrayRefWithData( $RefArray ) ) {
        my @AttributeArray = ();
        for my $Entry ( @{ $RefArray->[0] } ) {
            push( @AttributeArray, $Entry );
        }

        for my $RowIndex ( 1 .. $#{ $RefArray } ) {
            my %Entry = ();
            for my $ColIndex ( 0 .. $#AttributeArray ) {
                $Entry{ $AttributeArray[ $ColIndex ] } = $RefArray->[ $RowIndex ]->[ $ColIndex ] // '';
            }
            push( @Result, \%Entry );
        }
    }

    return \@Result;
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


