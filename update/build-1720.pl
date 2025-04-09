#!/usr/bin/perl
# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

use strict;
use warnings;

use File::Basename;
use FindBin qw($Bin);
use lib dirname($Bin);
use lib dirname($Bin) . '/Kernel/cpan-lib';

use Kernel::System::ObjectManager;
use Kernel::System::VariableCheck qw(:all);

# create object manager
local $Kernel::OM = Kernel::System::ObjectManager->new(
    'Log' => {
        LogPrefix => 'framework_update-to-build-1720',
    },
);

use vars qw(%INC);

_UpdateHTMLToPDF();

sub _UpdateHTMLToPDF {

    my $HTMLTOPDFObject = $Kernel::OM->Get('HTMLToPDF');
    my %NewDefinition = (
        Ticket  => '{"Expands":["DynamicField","Article","LinkObject","Organisation","Contact"],"Page":{"Top":"15","Left":"20","Right":"15","Bottom":"15","SpacingHeader":"12","SpacingFooter":"5"},"Header":[{"ID":"PageLogo","Type":"Image","Value":"agent-portal-logo","TypeOf":"DB","Style":{"Width":"2.5rem","Height":"2.5rem","Float":"left"}},{"ID":"PageTitle","Type":"Text","Value":"<KIX_CONFIG_Ticket::Hook>Ticket.TicketNumber.Value","Style":{"Size":"0.9rem","Float":"right"}}],"Content":[{"ID":"Title","Type":"Text","Value":"Ticket.Title.Value","Style":{"Size":"1.1rem"}},{"ID":"PrintedBy","Type":"Text","Value":["printed by","<Current_User>","<Current_Time>"],"Join":" ","Translate":true},{"Blocks":[{"ID":"InfoTableLeft","Type":"Table","Include":"DynamicField","SubType":"KeyValue","Columns":["<Class_Key><Font_Bold>Key","<Class_Value>Value"],"Allow":{"State":"KEY","Queue":"KEY","Lock":"KEY","CustomerID":"KEY","Owner":"KEY","Responsible":"KEY","Type":"KEY","Priority":"KEY"},"Translate":true,"Style":{"Width":"48%","Float":"left","Class":[{"Selector":" .Key","CSS":"width: 40%;"},{"Selector":" .Value","CSS":"min-width: 40%; max-width: 60%;"}]}},{"ID":"InfoTableRight","Type":"Table","Include":"DynamicField","SubType":"KeyValue","Columns":["<Class_Key><Font_Bold>Key","<Class_Value>Value"],"Allow":{"Age":"KEY","Created":"KEY","CreatedBy":"KEY","CustomerID":"KEY","AccountedTime":"KEY","PendingTime":"KEY"},"Translate":true,"Style":{"Width":"50%","Float":"right","Class":[{"Selector":" .Key","CSS":"width: 40%;"},{"Selector":" .Value","CSS":"min-width: 40%; max-width: 60%;"}]}}]},{"Blocks":[{"ID":"CustomerInformation","Type":"Text","Value":["<Font_Bold>Customer Information"],"Join":" ","Break":true,"Translate":true,"Style":{"Size":"1.1em","Color":"gray"}},{"Type":"List","Object":"Organisation","Data":"Organisation","Expand":"DynamicField","Blocks":[{"ID":"Organisation","Type":"Table","SubType":"Custom","Include":"DynamicField","Columns":["<Class_Col1><Font_Bold>","<Class_Col2>","<Class_Col1><Font_Bold>","<Class_Col2>"],"Rows":[["Organisation","Organisation.Name.Value","Customer No. / Type","Organisation.Number.Value / Organisation.DynamicField_Type.Value.0"],["Street","Organisation.Street.Value","ZIP, City, Country","Organisation.Zip.Value, Organisation.City.Value, Organisation.Country.Value"],["","","URL","Organisation.Url.Value"]],"Translate":true,"Style":{"Class":[{"Selector":" .Col1","CSS":"width: 20%;"},{"Selector":" .Col2","CSS":"width: 30%;"}]}}]},{"Type":"List","Object":"Contact","Data":"Contact","Expand":"DynamicField","Blocks":[{"ID":"Contact","Type":"Table","SubType":"Custom","Include":"DynamicField","Columns":["<Class_Col1><Font_Bold>","<Class_Col2>","<Class_Col1><Font_Bold>","<Class_Col2>"],"Rows":[["Title","Contact.Title.Value","Phone","Contact.Phone.Value"],["Contact","Contact.Fullname.Value","Mobile","Contact.Mobile.Value"],["Street","Contact.Street.Value","Email","Contact.Email.Value"],["ZIP, City, Country","Contact.Zip.Value, Contact.City.Value, Contact.Country.Value","",""]],"Translate":true,"Style":{"Class":[{"Selector":" .Col1","CSS":"width: 20%;"},{"Selector":" .Col2","CSS":"width: 30%;"}]}}]}]},{"Data":"LinkObject","Blocks":[{"ID":"LinkedHeader","Type":"Text","Value":"<Font_Bold>Linked Objects","Translate":true,"Break":true,"Style":{"Size":"1.1em","Color":"gray"}},{"ID":"LinkedTable","Type":"Table","SubType":"KeyValue","Columns":["<Class_Key><Font_Bold>Key","Value"],"Translate":true,"Join":"<br>","Style":{"Class":[{"Selector":" .Key","CSS":"width: 20%;"}]}}]},{"Type":"List","Object":"Article","Expand":"DynamicField","Data":"Article","Blocks":[{"ID":"ArticleHeader","Type":"Text","Value":["<Font_Bold>Article","#<Count>"],"Join":" ","Break":true,"Translate":true,"Style":{"Size":"1.1em","Color":"gray"}},{"ID":"ArticleMeta","Type":"Table","SubType":"KeyValue","Columns":["<Class_Key><Font_Bold>Key","<Class_Value>Value"],"Allow":{"From":"KEY","Subject":"KEY","CreateTime":"KEY","Channel":"KEY"},"Style":{"Class":[{"Selector":" .Key","CSS":"width: 20%;"},{"Selector":" .Value","CSS":"min-width: 20%; max-width: 50%;"}]},"Translate":true},{"ID":"ArticleBody","Type":"Richtext","Value":"Article.Body.Value"}]}],"Footer":[{"ID":"Paging","Type":"Page","PageOf":false,"Translate":true,"Style":{"Float":"right"}}]}',
        Article => '{"Expands":["DynamicField"],"Page":{"Top":"15","Left":"20","Right":"15","Bottom":"15","SpacingHeader":"12","SpacingFooter":"5"},"Header":[{"ID":"PageLogo","Type":"Image","Value":"agent-portal-logo","TypeOf":"DB","Style":{"Width":"2.5rem","Height":"2.5rem","Float":"left"}}],"Content":[{"ID":"Subject","Type":"Text","Value":"Article.Subject.Value","Style":{"Size":"1.1rem"}},{"ID":"PrintedBy","Type":"Text","Value":["printed by","<Current_User>","<Current_Time>"],"Join":" ","Translate":true},{"Blocks":[{"ID":"ArticleMeta","Type":"Table","SubType":"KeyValue","Columns":["<Class_Key><Font_Bold>Key","<Class_Value>Value"],"Allow":{"From":"KEY","Subject":"KEY","CreateTime":"KEY","Channel":"KEY"},"Style":{"Class":[{"Selector":" .Key","CSS":"width: 20%;"},{"Selector":" .Value","CSS":"min-width: 20%; max-width: 50%;"}]},"Translate":true},{"ID":"ArticleBody","Type":"Richtext","Value":"Article.Body.Value"}]}],"Footer":[{"ID":"Paging","Type":"Page","PageOf":0,"Translate":true,"Style":{"Float":"right"}}]}'
    );

    for my $Name ( keys %NewDefinition ) {
        my %Template = $HTMLTOPDFObject->TemplateGet(
            Name   => $Name,
            UserID => 1
        );

        next if !%Template;

        $HTMLTOPDFObject->TemplateUpdate(
            %Template,
            Definition => $NewDefinition{$Name},
            UserID     => 1
        );
    }

    # delete whole cache
    $Kernel::OM->Get('Cache')->CleanUp();

    return 1;
}

exit 0;

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
