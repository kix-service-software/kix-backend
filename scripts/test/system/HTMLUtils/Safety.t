# --
# Modified version of the work: Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/ 
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

use strict;
use warnings;
use utf8;

use vars (qw($Self));

# get HTMLUtils object
my $HTMLUtilsObject = $Kernel::OM->Get('HTMLUtils');

# Safety tests
my @Tests = (
    {
        Input  => 'Some Text',
        Result => {
            Output  => 'Some Text',
            Replace => 0,
        },
        Name => 'Safety - simple'
    },
    {
        Input  => '<b>Some Text</b>',
        Result => {
            Output  => '<b>Some Text</b>',
            Replace => 0,
        },
        Name => 'Safety - simple'
    },
    {
        Input  => '<a href="javascript:alert(1)">Some Text</a>',
        Result => {
            Output  => '<a>Some Text</a>',
            Replace => 1,
        },
        Name => 'Safety - simple'
    },
    {
        Input =>
            '<a href="https://www.yoururl.tld/sub/online-assessment/index.php" target="_blank">https://www.yoururl.tld/sub/online-assessment/index.php</a>',
        Result => {
            Output =>
                '<a href="https://www.yoururl.tld/sub/online-assessment/index.php" target="_blank">https://www.yoururl.tld/sub/online-assessment/index.php</a>',
            Replace => 0,
        },
        Name => 'Safety - simple'
    },
    {
        Input =>
            "<a href='https://www.yoururl.tld/sub/online-assessment/index.php' target='_blank'>https://www.yoururl.tld/sub/online-assessment/index.php</a>",
        Result => {
            Output =>
                '<a href="https://www.yoururl.tld/sub/online-assessment/index.php" target="_blank">https://www.yoururl.tld/sub/online-assessment/index.php</a>',
            Replace => 0,
        },
        Name => 'Safety - simple'
    },
    {
        Input  => '<a href="http://example.com/" onclock="alert(1)">Some Text</a>',
        Result => {
            Output  => '<a href="http://example.com/">Some Text</a>',
            Replace => 1,
        },
        Name => 'Safety - simple'
    },
    {
        Input =>
            '<a href="http://example.com/" onclock="alert(1)">Some Text <img src="http://example.com/logo.png"/></a>',
        Result => {
            Output  => '<a href="http://example.com/">Some Text <img /></a>',
            Replace => 1,
        },
        Name => 'Safety - simple'
    },
    {
        Input => '<script type="text/javascript" id="topsy_global_settings">
var topsy_style = "big";
</script><script type="text/javascript" id="topsy-js-elem" src="http://example.com/topsy.js?init=topsyWidgetCreator"></script>
<script type="text/javascript" src="/pub/js/podpress.js"></script>
',
        Result => {
            Output => '

',
            Replace => 1,
        },
        Name => 'Safety - script tag'
    },
    {
        Input => '<center>
<applet code="AEHousman.class" width="300" height="150">
Not all browsers can run applets.  If you see this, yours can not.
You should be able to continue reading these lessons, however.
</applet>
</center>',
        Result => {
            Output => '<center>

</center>',
            Replace => 1,
        },
        Name => 'Safety - applet tag'
    },
    {
        Input => '<center>
<object width="384" height="236" align="right" vspace="5" hspace="5"><param name="movie" value="http://www.youtube.com/v/l1JdGPVMYNk&hl=en_US&fs=1&hd=1"></param><param name="allowFullScreen" value="true"></param><param name="allowscriptaccess" value="always"></param><embed src="http://www.youtube.com/v/l1JdGPVMYNk&hl=en_US&fs=1&hd=1" type="application/x-shockwave-flash" allowscriptaccess="always" allowfullscreen="true" width="384" height="236"></embed></object>
</center>',
        Result => {
            Output => '<center>

</center>',
            Replace => 1,
        },
        Name => 'Safety - object tag'
    },
    {
        Input => '<center>
\'\';!--"<XSS>=&{()}
</center>',
        Result => {
            Output => '<center>
&#39;&#39;;!--&quot;<xss>=&amp;{()}
</center>',
            Replace => 1,
        },
        Name => 'Safety - simple'
    },
    {
        Input => '<center>
<SCRIPT SRC=http://ha.ckers.org/xss.js></SCRIPT>
</center>',
        Result => {
            Output => '<center>

</center>',
            Replace => 1,
        },
        Name => 'Safety - script/src tag'
    },
    {
        Input => '<center>
<SCRIPT SRC=http://ha.ckers.org/xss.js><!-- some comment --></SCRIPT>
</center>',
        Result => {
            Output => '<center>

</center>',
            Replace => 1,
        },
        Name => 'Safety - script/src tag'
    },
    {
        Input => '<center>
<IMG SRC="javascript:alert(\'XSS\');">
</center>',
        Result => {
            Output => '<center>
<img />
</center>',
            Replace => 1,
        },
        Name => 'Safety - img tag'
    },
    {
        Input => '<center>
<IMG SRC=javascript:alert(\'XSS\');>
</center>',
        Result => {
            Output => '<center>
<img />
</center>',
            Replace => 1,
        },
        Name => 'Safety - img tag'
    },
    {
        Input => '<center>
<IMG SRC=JaVaScRiPt:alert(\'XSS\')>
</center>',
        Result => {
            Output => '<center>
<img />
</center>',
            Replace => 1,
        },
        Name => 'Safety - img tag'
    },
    {
        Input => '<center>
<img SRC=javascript:alert(&quot;XSS&quot;)>
</center>',
        Result => {
            Output => '<center>
<img />
</center>',
            Replace => 1,
        },
        Name => 'Safety - img tag'
    },
    {
        Input => '<center>
<IMG """><SCRIPT>alert("XSS")</SCRIPT>">
</center>',
        Result => {
            Output => '<center>
<img """="&quot;&quot;&quot;" />&quot;&gt;
</center>',
            Replace => 1,
        },
        Name => 'Safety - script/img tag'
    },
    {
        Input => '<center>
<SCRIPT/XSS SRC="http://ha.ckers.org/xss.js"></SCRIPT>
</center>',
        Result => {
            Output => '<center>

</center>',
            Replace => 1,
        },
        Name => 'Safety - script tag'
    },
    {
        Input => '<center>
<SCRIPT/SRC="http://ha.ckers.org/xss.js"></SCRIPT>
</center>',
        Result => {
            Output => '<center>

</center>',
            Replace => 1,
        },
        Name => 'Safety - script tag'
    },
    {
        Input => '<center>
<<SCRIPT>alert("XSS");//<</SCRIPT>
</center>',
        Result => {
            Output => '<center>
&lt;
</center>',
            Replace => 1,
        },
        Name => 'Safety - script tag'
    },
    {
        Input => '\'<center>
<SCRIPT SRC=http://ha.ckers.org/xss.js?<B>
</center>;\'',
        Result => {
            Output => '&#39;<center>

</center>;\'',
            Replace => 1,
        },
        Name => 'Safety - script tag'
    },
    {
        Input => '<center>
<SCRIPT SRC=//ha.ckers.org/.j>
</center>',
        Result => {
            Output => '<center>

</center>',
            Replace => 1,
        },
        Name => 'Safety - script tag'
    },
    {
        Input => '<center>
    <iframe src=http://ha.ckers.org/scriptlet.html >
</center>',
        Result => {
            Output => '<center>
    <iframe>
</center>',
            Replace => 1,
        },
        Name => 'Safety - iframe'
    },
    {
        Input => '<center>
<BODY ONLOAD=alert(\'XSS\')>
</center>',
        Result => {
            Output => '<center>
<body>
</center>',
            Replace => 1,
        },
        Name => 'Safety - onload'
    },
    {
        Input => '<center>
<TABLE BACKGROUND="javascript:alert(\'XSS\')">
</center>',
        Result => {
            Output => '<center>
<table>
</center>',
            Replace => 1,
        },
        Name => 'Safety - background'
    },
    {
        Input => '<center>
<SCRIPT a=">" SRC="http://ha.ckers.org/xss.js"></SCRIPT>
</center>',
        Result => {
            Output => '<center>

</center>',
            Replace => 1,
        },
        Name => 'Safety - script'
    },
    {
        Input => '<center>
<SCRIPT =">" SRC="http://ha.ckers.org/xss.js"></SCRIPT>
</center>',
        Result => {
            Output => '<center>

</center>',
            Replace => 1,
        },
        Name => 'Safety - script'
    },
    {
        Input => '<center>
<SCRIPT "a=\'>\'"
 SRC="http://ha.ckers.org/xss.js"></SCRIPT>
</center>',
        Result => {
            Output => '<center>

</center>',
            Replace => 1,
        },
        Name => 'Safety - script'
    },
    {
        Input => '<center>
<SCRIPT>document.write("<SCRI");</SCRIPT>PT
 SRC="http://ha.ckers.org/xss.js"></SCRIPT>
</center>',
        Result => {
            Output => '<center>
PT
 SRC=&quot;http://ha.ckers.org/xss.js&quot;&gt;
</center>',
            Replace => 1,
        },
        Name => 'Safety - script'
    },
    {
        Input => '<center>
<A
 HREF="javascript:document.location=\'http://www.example.com/\'">XSS</A>
</center>',
        Result => {
            Output => '<center>
<a>XSS</a>
</center>',
            Replace => 1,
        },
        Name => 'Safety - script'
    },
    {
        Input => '<center>
  <body style="background: #fff; color: #000;" onmouseover     ="var ga = document.createElement(\'script\'); ga.type = \'text/javascript\'; ga.src = (\'https:\' == document.location.protocol ? \'https://\' : \'http://\') + \'ajax.googleapis.com/ajax/libs/jquery/1.4.2/jquery.min.js\'; document.body.appendChild(ga); setTimeout(function() { jQuery(\'body\').append(jQuery(\'<div />\').attr(\'id\', \'hack-me\').css(\'display\', \'none\')); jQuery(\'#hack-me\').load(\'/kix/index.pl?Action=AgentPreferences\', null, function() { jQuery.ajax({url: \'/kix/index.pl\', type: \'POST\', data: ({Action: \'AgentPreferences\', ChallengeToken: jQuery(\'input[name=ChallengeToken]:first\', \'#hack-me\').val(), Group: \'Language\', \'Subaction\': \'Update\', UserLanguage: \'zh_CN\'})}); }); }, 500);">
</center>',
        Result => {
            Output => '<center>
  <body style="background: #fff; color: #000;">
</center>',
            Replace => 1,
        },
        Name => 'Safety - script'
    },
    {
        Input =>
            '<html><head><style type="text/css"> #some_css {color: #FF0000} </style><body>Important Text about "javascript"!<style type="text/css"> #some_more_css{ color: #00FF00 } </style> Some more text.</body></html>',
        Result => {
            Output =>
                '<html><head><style type="text/css"> #some_css {color: #FF0000} </style><body>Important Text about &quot;javascript&quot;!<style type="text/css"> #some_more_css{ color: #00FF00 } </style> Some more text.</body></html>',
            Replace => 1,
        },
        Name =>
            'Safety - Test for bug#7972 - Some mails may not present HTML part when using rich viewing.'
    },
    {
        Input =>
            '<html><head><style type="text/javascript"> alert("some evil stuff!);</style><body>Important Text about "javascript"!<style type="text/css"> #some_more_css{ color: #00FF00 } </style> Some more text.</body></html>',
        Result => {
            Output =>
                '<html><head><body>Important Text about &quot;javascript&quot;!<style type="text/css"> #some_more_css{ color: #00FF00 } </style> Some more text.</body></html>',
            Replace => 1,
        },
        Name =>
            'Safety - Additional test for bug#7972 - Some mails may not present HTML part when using rich viewing.'
    },
    {
        Name  => 'Safety - UTF7 tags',
        Input => <<EOF,
script:+ADw-script+AD4-alert(1);+ADw-/script+AD4-
applet:+ADw-applet+AD4-alert(1);+ADw-/applet+AD4-
embed:+ADw-embed src=test+AD4-
object:+ADw-object+AD4-alert(1);+ADw-/object+AD4-
EOF
        Result => {
            Output => <<EOF,
script:
applet:
embed:
object:
EOF
            Replace => 1,
        },
    },
    {
        Input => <<EOF,
<div style="width: expression(alert(\'XSS\');); height: 200px;" style="width: 400px">
<div style='width: expression(alert("XSS");); height: 200px;' style='width: 400px'>
EOF
        Result => {
            Output => <<EOF,
<div>
<div>
EOF
            Replace => 1,
        },
        Name => 'Safety - Filter out MS CSS expressions'
    },
    {
        Input => <<EOF,
<div><XSS STYLE="xss:expression(alert('XSS'))"></div>
EOF
        Result => {
            Output => <<EOF,
<div><xss></div>
EOF
            Replace => 1,
        },
        Name => 'Safety - Microsoft CSS expression on invalid tag'
    },
    {
        Input => <<EOF,
<div class="svg"><svg some-attribute evil="true"><someevilsvgcontent></svg></div>
EOF
        Result => {
            Output => <<EOF,
<div class="svg"></div>
EOF
            Replace => 1,
        },
        Name => 'Safety - Filter out SVG'
    },
    {
        Input => <<EOF,
<div><script ></script ><applet ></applet ></div >
EOF
        Result => {
            Output => <<EOF,
<div></div>
EOF
            Replace => 1,
        },
        Name => 'Safety - Closing tag with space'
    },
    {
        Input => <<EOF,
<style type="text/css">
div > span {
    width: 200px;
}
</style>
<style type="text/css">
div > span {
    width: expression(evilJS());
}
</style>
<style type="text/css">
div > span > div {
    width: 200px;
}
</style>
EOF
        Result => {
            Output => <<EOF,
<style type="text/css">
div > span {
    width: 200px;
}
</style>
<style type="text/css"></style>
<style type="text/css">
div > span > div {
    width: 200px;
}
</style>
EOF
            Replace => 1,
        },
        Name => 'Safety - Style tags with CSS expressions are filtered out'
    },
    {
        Input => <<EOF,
<s<script>...</script><script>...<cript type="text/javascript">
document.write("Hello World!");
</s<script>//<cript>
EOF
        Result => {
            Output => <<EOF,
<sscript>......<cript type="text/javascript">
document.write("Hello World!");
</sscript>//<cript>
EOF
            Replace => 1,
        },
        Name => 'Safety - Nested script tags'
    },
    {
        Input => <<EOF,
<img src="/img1.png"/>
<iframe src="  javascript:alert('XSS Exploit');"></iframe>
<img src="/img2.png"/>
EOF
        Result => {
            Output => <<EOF,
<img src="/img1.png" />
<iframe></iframe>
<img src="/img2.png" />
EOF
            Replace => 1,
        },
        Name => 'Safety - javascript source with space'
    },
    {
        Input => <<EOF,
<img src="/img1.png"/>
<iframe src='  javascript:alert("XSS Exploit");'></iframe>
<img src="/img2.png"/>
EOF
        Result => {
            Output => <<EOF,
<img src="/img1.png" />
<iframe></iframe>
<img src="/img2.png" />
EOF
            Replace => 1,
        },
        Name => 'Safety - javascript source with space'
    },
    {
        Input => <<EOF,
<img src="/img1.png"/>
<iframe src=javascript:alert('XSS_Exploit');></iframe>
<img src="/img2.png"/>
EOF
        Result => {
            Output => <<EOF,
<img src="/img1.png" />
<iframe></iframe>
<img src="/img2.png" />
EOF
            Replace => 1,
        },
        Name => 'Safety - javascript source without delimiters'
    },
    {
        Input => <<EOF,
<img src="/img1.png"/>
<iframe src="" data-src="javascript:alert('XSS Exploit');"></iframe>
<img src="/img2.png"/>
EOF
        Result => {
            Output => <<EOF,
<img src="/img1.png" />
<iframe src="" data-src="javascript:alert(&#39;XSS Exploit&#39;);"></iframe>
<img src="/img2.png" />
EOF
            Replace => 1,
        },
        Name => 'Safety - javascript source in data tag, keep'
    },
    {
        Input => <<EOF,
Some
<META HTTP-EQUIV="Refresh" CONTENT="2;
URL=http://www.rbrasileventos.com.br/9asdasd/">
Content
EOF
        Result => {
            Output => <<EOF,
Some

Content
EOF
            Replace => 1,
        },
        Name => 'Safety - meta refresh tag removed'
    },
    {
        Input => <<EOF,
<img/onerror="alert(\'XSS1\')"src=a>
EOF
        Result => {
            Output => <<EOF,
<img src="a" />
EOF
            Replace => 1,
        },
        Name => 'Safety - / as attribute delimiter'
    },
    {
        Input => <<EOF,
<iframe src=javasc&#x72ipt:alert(\'XSS2\') >
EOF
        Result => {
            Output => <<EOF,
<iframe>
EOF
            Replace => 1,
        },
        Name => 'Safety - entity encoding in javascript attribute'
    },
    {
        Input => <<EOF,
<iframe/src=javasc&#x72ipt:alert(\'XSS2\') >
EOF
        Result => {
            Output => <<EOF,
<iframe>
EOF
            Replace => 1,
        },
        Name => 'Safety - entity encoding in javascript attribute with / separator'
    },
    {
        Input => <<EOF,
<img src="http://example.com/image.png"/>
EOF
        Result => {
            Output => <<EOF,
<img />
EOF
            Replace => 1,
        },
        Name => 'Safety - external image'
    },
    {
        Input => <<EOF,
<img/src="http://example.com/image.png"/>
EOF
        Result => {
            Output => <<EOF,
<img />
EOF
            Replace => 1,
        },
        Name => 'Safety - external image with / separator'
    },
);

for my $Test (@Tests) {
    my %Result = $HTMLUtilsObject->Safety(
        String       => $Test->{Input},
        NoApplet     => 1,
        NoObject     => 1,
        NoEmbed      => 1,
        NoSVG        => 1,
        NoIntSrcLoad => 0,
        NoExtSrcLoad => 1,
        NoJavaScript => 1,
    );
    if ( $Test->{Result}->{Replace} ) {
        $Self->True(
            $Result{Replace},
            "$Test->{Name} replaced",
        );
    }
    else {
        $Self->False(
            $Result{Replace},
            "$Test->{Name} not replaced",
        );
    }
    $Self->Is(
        $Result{String},
        $Test->{Result}->{Output},
        $Test->{Name},
    );
}

@Tests = (
    {
        Name  => 'Safety - img tag',
        Input => <<EOF,
<img/src="http://example.com/image.png"/>
EOF
        Config => {
            NoImg => 1,
        },
        Result => {
            Output => <<EOF,

EOF
            Replace => 1,
        },
    },
    {
        Name  => 'Safety - img tag replacement',
        Input => <<EOF,
<img/src="http://example.com/image.png"/>
EOF
        Config => {
            NoImg          => 1,
            ReplacementStr => '...'
        },
        Result => {
            Output => <<EOF,
...
EOF
            Replace => 1,
        },
    },
    {
        Name  => 'Safety - Filter out SVG replacement',
        Input => <<EOF,
<div class="svg"><svg some-attribute evil="true"><someevilsvgcontent></svg></div>
EOF
        Config => {
            NoSVG          => 1,
            ReplacementStr => '...'
        },
        Result => {
            Output => <<EOF,
<div class="svg">...</div>
EOF
            Replace => 1,
        },
    },
    {
        Name  => 'Safety - object tag replacement',
        Input => '<center>
<object width="384" height="236" align="right" vspace="5" hspace="5"><param name="movie" value="http://www.youtube.com/v/l1JdGPVMYNk&hl=en_US&fs=1&hd=1"></param><param name="allowFullScreen" value="true"></param><param name="allowscriptaccess" value="always"></param><embed src="http://www.youtube.com/v/l1JdGPVMYNk&hl=en_US&fs=1&hd=1" type="application/x-shockwave-flash" allowscriptaccess="always" allowfullscreen="true" width="384" height="236"></embed></object>
</center>',
        Config => {
            NoObject       => 1,
            ReplacementStr => '...'
        },
        Result => {
            Output => '<center>
...
</center>',
            Replace => 1,
        },
    },
    {
        Name  => 'Safety - embed tag replacement',
        Input => '<center>
<object width="384" height="236" align="right" vspace="5" hspace="5"><param name="movie" value="http://www.youtube.com/v/l1JdGPVMYNk&hl=en_US&fs=1&hd=1"></param><param name="allowFullScreen" value="true"></param><param name="allowscriptaccess" value="always"></param><embed src="http://www.youtube.com/v/l1JdGPVMYNk&hl=en_US&fs=1&hd=1" type="application/x-shockwave-flash" allowscriptaccess="always" allowfullscreen="true" width="384" height="236"></object>
</center>',
        Config => {
            NoEmbed        => 1,
            ReplacementStr => '...'
        },
        Result => {
            Output => '<center>
<object width="384" height="236" align="right" vspace="5" hspace="5"><param name="movie" value="http://www.youtube.com/v/l1JdGPVMYNk&amp;hl=en_US&amp;fs=1&amp;hd=1" /><param name="allowFullScreen" value="true" /><param name="allowscriptaccess" value="always" />...</object>
</center>',
            Replace => 1,
        },
    },
    {
        Name  => 'Safety - applet tag replacement',
        Input => '<center>
<applet code="AEHousman.class" width="300" height="150">
Not all browsers can run applets.  If you see this, yours can not.
You should be able to continue reading these lessons, however.
</applet>
</center>',
        Config => {
            NoApplet       => 1,
            ReplacementStr => '...'
        },
        Result => {
            Output => '<center>
...
</center>',
            Replace => 1,
        },
    },
    {
        Name   => 'Safety - bug 10530 - don\'t destroy URL which looks like an on* JS attribute',
        Input  => '<a href="http://localhost/online/foo/bar.html">www</a>',
        Config => {},
        Result => {
            Output  => '<a href="http://localhost/online/foo/bar.html">www</a>',
            Replace => 0,
        },
    },
    {
        Name   => 'Safety - Remove redirect with > in meta-attribute',
        Input  => '<meta foo=">" http-equiv=refresh content="10;URL=\'http://example.com\'" />',
        Config => {},
        Result => {
            Output  => '',
            Replace => 1,
        },
    },
    {
        Name   => 'Safety - Remove javascript code in href with leading zero in unicode',
        Input  => '<a href=\'javascrip&#0116;:alert(document.location.origin)\'>XSS</a>
<a href=\'javascrip&#x074;:alert(document.location.origin)\'>XSS</a>
<a href=\'java&#x0A;script:alert(document.location.origin)\'>XSS</a>
<a href=\'javascrip&#00116;:alert(document.location.origin)\'>XSS</a>
<a href=\'javascrip&#x0074;:alert(document.location.origin)\'>XSS</a>
<a href=\'java&#x00A;script:alert(document.location.origin)\'>XSS</a>',
        Config => {
            NoJavaScript => 1
        },
        Result => {
            Output  => '<a>XSS</a>
<a>XSS</a>
<a>XSS</a>
<a>XSS</a>
<a>XSS</a>
<a>XSS</a>',
            Replace => 1,
        },
    },
    {
        Name   => 'Safety - Remove javascript code in href with control characters',
        Input  => '<a href=\' &#15; javascript:alert(document.location.origin)\'>XSS</a>
<a href="javas cript:alert(document.location.origin)">XSS</a>',
        Config => {
            NoJavaScript => 1
        },
        Result => {
            Output  => '<a>XSS</a>
<a>XSS</a>',
            Replace => 1,
        },
    },
    {
        Name   => 'Safety - Remove javascript code in form action',
        Input  => '<form><button
formaction=javascript:alert(document.location.origin)>XSS</button></form>
<form action=javascript:alert(document.location.origin)><input
type=submit value=XSS>',
        Config => {
            NoJavaScript => 1
        },
        Result => {
            Output  => '<form><button>XSS</button></form>
<form><input type="submit" value="XSS" />',
            Replace => 1,
        },
    },
    {
        Name   => 'Safety - Remove javascript from srcdoc of iframes',
        Input  => '<iframe srcdoc="&lt;img &#115;rc=x
&#111;nerror=\'fetch(&quot;/otrs/index.pl&quot;,{credentials:&quot;include
&quot;}).then(r=>r.text()).then(s=>alert(s.match(/SessionID:\s*&quot;([a-z
A-Z0-9]*)&quot;/)[1]))\' />" sandbox="allow-same-origin allow-scripts
allow-modals"></iframe>',
        Config => {
            NoJavaScript => 1
        },
        Result => {
            Output  => '<iframe srcdoc="&lt;img src=&quot;x&quot; /&gt;" sandbox="allow-same-origin allow-scripts
allow-modals"></iframe>',
            Replace => 1,
        },
    },
    {
        Name   => 'Safety - Remove javascript from xlink:href',
        Input  => '<math><xss
xlink:href="javascript:alert(document.location.origin)">XSS</xss></math>',
        Config => {
            NoJavaScript => 1
        },
        Result => {
            Output  => '<math><xss>XSS</xss></math>',
            Replace => 1,
        },
    },
    {
        Name   => 'Safety - Remove unclosed svg tags',
        Input  => '<svg width=12cm height=9cm><a><image
href="https://google.com/favicon.ico"></image><set attributeName=href
to="javascript:alert(document.location.origin)"> </set>',
        Config => {
            NoSVG => 1
        },
        Result => {
            Output  => '',
            Replace => 1,
        },
    },
    {
        Name   => 'Safety - Remove javascript code inside of svg tag - set tag with href',
        Input  => '<svg width=12cm height=9cm>
    <a>
        <image href="https://google.com/favicon.ico"></image>
        <set attributeName=href to="javascript:alert(\'XSS\')"> </set>
    </a>
</svg>',
        Config => {
            NoJavaScript => 1
        },
        Result => {
            Output  => '<svg width="12cm" height="9cm">
    <a>
        <image href="https://google.com/favicon.ico"></image>
        
    </a>
</svg>',
            Replace => 1,
        },
    },
    {
        Name   => 'Safety - Remove javascript code inside of svg tag - animate tag with href',
        Input  => '<svg width="12cm" height="9cm">
    <a>
        <image href="https://google.com/favicon.ico"></image>
        <animate attributeName=href values="javascript:alert(\'XSS\')"></animate>
    </a>
</svg>',
        Config => {
            NoJavaScript => 1
        },
        Result => {
            Output  => '<svg width="12cm" height="9cm">
    <a>
        <image href="https://google.com/favicon.ico"></image>
        
    </a>
</svg>',
            Replace => 1,
        },
    },
    {
        Name   => 'Safety - Remove javascript code inside of svg tag - animate tag with xlink:href',
        Input  => '<svg width=12cm height=9cm>
    <a>
        <image href="https://google.com/favicon.ico"></image>
        <animate attributeName=xlink:href begin=0 from="javascript:alert(\'XSS\')" to=&></animate>
    </a>
</svg>',
        Config => {
            NoJavaScript => 1
        },
        Result => {
            Output  => '<svg width="12cm" height="9cm">
    <a>
        <image href="https://google.com/favicon.ico"></image>
        
    </a>
</svg>',
            Replace => 1,
        },
    },
    {
        Name   => 'Safety - Encode html correctly',
        Input  => 'Fix Schwyz! quäkt Jürgen blöd vom Paß ',
        Config => {},
        Result => {
            Output  => 'Fix Schwyz! qu&auml;kt J&uuml;rgen bl&ouml;d vom Pa&szlig; ',
            Replace => 1,
        },
    },
    {
        Name   => 'Safety - Encode html correctly - leave already encoded html',
        Input  => 'Fix&nbsp;Schwyz!&nbsp;qu&auml;kt&nbsp;J&uuml;rgen&nbsp;bl&ouml;d&nbsp;vom&nbsp;Pa&szlig;&nbsp;',
        Config => {},
        Result => {
            Output  => 'Fix&nbsp;Schwyz!&nbsp;qu&auml;kt&nbsp;J&uuml;rgen&nbsp;bl&ouml;d&nbsp;vom&nbsp;Pa&szlig;&nbsp;',
            Replace => 0,
        },
    },
    {
        Name   => 'Safety - Keep opening style-Tag after non-javascript link-Tag',
        Input  => '<LINK rel=stylesheet type=text/css href="https://fonts.googleapis.com/css?family=Open+Sans:400,400italic&amp;subset=latin,cyrillic">
<STYLE type=text/css media=all>
*
{
        -webkit-text-size-adjust:none;
        -ms-text-size-adjust:none
}
</STYLE>',
        Config => {
            NoJavaScript => 1
        },
        Result => {
            Output  => '<link rel="stylesheet" type="text/css" href="https://fonts.googleapis.com/css?family=Open+Sans:400,400italic&amp;subset=latin,cyrillic" />
<style type="text/css" media="all">
*
{
        -webkit-text-size-adjust:none;
        -ms-text-size-adjust:none
}
</style>',
            Replace => 1,
        },
    },
    {
        Name   => 'Safety - Basic XSS Test Without Filter Evasion',
        Input  => '<SCRIPT SRC=http://xss.rocks/xss.js></SCRIPT>',
        Config => {
            NoJavaScript => 1
        },
        Result => {
            Output  => '',
            Replace => 1,
        },
    },
    {
        Name   => 'Safety - XSS Locator (Polygot)',
        Input  => 'javascript:/*--></title></style></textarea></script></xmp><svg/onload=\'+/"/+/onmouseover=1/+/[*/[]/+alert(1)//\'>',
        Config => {
            NoJavaScript => 1
        },
        Result => {
            Output  => 'javascript:/*--&gt;</title></style></textarea></xmp><svg>',
            Replace => 1,
        },
    },
    {
        Name   => 'Safety - Image XSS Using the JavaScript Directive',
        Input  => '<IMG SRC="javascript:alert(\'XSS\');">',
        Config => {
            NoJavaScript => 1
        },
        Result => {
            Output  => '<img />',
            Replace => 1,
        },
    },
    {
        Name   => 'Safety - No Quotes and no Semicolon',
        Input  => '<IMG SRC=javascript:alert(\'XSS\')>',
        Config => {
            NoJavaScript => 1
        },
        Result => {
            Output  => '<img />',
            Replace => 1,
        },
    },
    {
        Name   => 'Safety - Case Insensitive XSS Attack Vector',
        Input  => '<IMG SRC=JaVaScRiPt:alert(\'XSS\')>',
        Config => {
            NoJavaScript => 1
        },
        Result => {
            Output  => '<img />',
            Replace => 1,
        },
    },
    {
        Name   => 'Safety - HTML Entities',
        Input  => '<IMG SRC=javascript:alert(&quot;XSS&quot;)>',
        Config => {
            NoJavaScript => 1
        },
        Result => {
            Output  => '<img />',
            Replace => 1,
        },
    },
    {
        Name   => 'Safety - Grave Accent Obfuscation',
        Input  => '<IMG SRC=`javascript:alert("RSnake says, \'XSS\'")`>',
        Config => {
            NoJavaScript => 1
        },
        Result => {
            Output  => '<img says,="says," \'xss\'")`="&#39;XSS&#39;&quot;)`" />',
            Replace => 1,
        },
    },
    {
        Name   => 'Safety - Malformed A Tags',
        Input  => '\\<a onmouseover="alert(document.cookie)"\\>xxs link\\</a\\>',
        Config => {
            NoJavaScript => 1
        },
        Result => {
            Output  => '\\<a \\="\\">xxs link\\</a>',
            Replace => 1,
        },
    },
    {
        Name   => 'Safety - Malformed A Tags (Chrome)',
        Input  => '\\<a onmouseover=alert(document.cookie)\\>xxs link\\</a\\>',
        Config => {
            NoJavaScript => 1
        },
        Result => {
            Output  => '\\<a>xxs link\\</a>',
            Replace => 1,
        },
    },
    {
        Name   => 'Safety - Malformed IMG Tags',
        Input  => '<IMG """><SCRIPT>alert("XSS")</SCRIPT>"\\>',
        Config => {
            NoJavaScript => 1
        },
        Result => {
            Output  => '<img """="&quot;&quot;&quot;" />&quot;\\&gt;',
            Replace => 1,
        },
    },
    {
        Name   => 'Safety - fromCharCode',
        Input  => '<IMG SRC=javascript:alert(String.fromCharCode(88,83,83))>',
        Config => {
            NoJavaScript => 1
        },
        Result => {
            Output  => '<img />',
            Replace => 1,
        },
    },
    {
        Name   => 'Safety - Default SRC Tag to Get Past Filters that Check SRC Domain',
        Input  => '<IMG SRC=# onmouseover="alert(\'xxs\')">',
        Config => {
            NoJavaScript => 1
        },
        Result => {
            Output  => '<img src="#" />',
            Replace => 1,
        },
    },
    {
        Name   => 'Safety - Default SRC Tag by Leaving it Empty',
        Input  => '<IMG SRC= onmouseover="alert(\'xxs\')">',
        Config => {
            NoJavaScript => 1
        },
        Result => {
            Output  => '<img src="onmouseover=&quot;alert(&#39;xxs&#39;)&quot;" />',
            Replace => 1,
        },
    },
    {
        Name   => 'Safety - Default SRC Tag by Leaving it out Entirely',
        Input  => '<IMG onmouseover="alert(\'xxs\')">',
        Config => {
            NoJavaScript => 1
        },
        Result => {
            Output  => '<img />',
            Replace => 1,
        },
    },
    {
        Name   => 'Safety - On Error Alert',
        Input  => '<IMG SRC=/ onerror="alert(String.fromCharCode(88,83,83))"></img>',
        Config => {
            NoJavaScript => 1
        },
        Result => {
            Output  => '<img src="/" />',
            Replace => 1,
        },
    },
    {
        Name   => 'Safety - IMG onerror and JavaScript Alert Encode',
        Input  => '<img src=x onerror="&#0000106&#0000097&#0000118&#0000097&#0000115&#0000099&#0000114&#0000105&#0000112&#0000116&#0000058&#0000097&#0000108&#0000101&#0000114&#0000116&#0000040&#0000039&#0000088&#0000083&#0000083&#0000039&#0000041">',
        Config => {
            NoJavaScript => 1
        },
        Result => {
            Output  => '<img src="x" />',
            Replace => 1,
        },
    },
    {
        Name   => 'Safety - Decimal HTML Character References',
        Input  => '<IMG SRC=&#106;&#97;&#118;&#97;&#115;&#99;&#114;&#105;&#112;&#116;&#58;&#97;&#108;&#101;&#114;&#116;&#40;&#39;&#88;&#83;&#83;&#39;&#41;>',
        Config => {
            NoJavaScript => 1
        },
        Result => {
            Output  => '<img />',
            Replace => 1,
        },
    },
    {
        Name   => 'Safety - Decimal HTML Character References Without Trailing Semicolons',
        Input  => '<IMG SRC=&#0000106&#0000097&#0000118&#0000097&#0000115&#0000099&#0000114&#0000105&#0000112&#0000116&#0000058&#0000097&#0000108&#0000101&#0000114&#0000116&#0000040&#0000039&#0000088&#0000083&#0000083&#0000039&#0000041>',
        Config => {
            NoJavaScript => 1
        },
        Result => {
            Output  => '<img />',
            Replace => 1,
        },
    },
    {
        Name   => 'Safety - Hexadecimal HTML Character References Without Trailing Semicolons',
        Input  => '<IMG SRC=&#x6A&#x61&#x76&#x61&#x73&#x63&#x72&#x69&#x70&#x74&#x3A&#x61&#x6C&#x65&#x72&#x74&#x28&#x27&#x58&#x53&#x53&#x27&#x29>',
        Config => {
            NoJavaScript => 1
        },
        Result => {
            Output  => '<img />',
            Replace => 1,
        },
    },
    {
        Name   => 'Safety - Embedded Tab',
        Input  => '<IMG SRC="jav ascript:alert(\'XSS\');">',
        Config => {
            NoJavaScript => 1
        },
        Result => {
            Output  => '<img />',
            Replace => 1,
        },
    },
    {
        Name   => 'Safety - Embedded Encoded Tab',
        Input  => '<IMG SRC="jav&#x09;ascript:alert(\'XSS\');">',
        Config => {
            NoJavaScript => 1
        },
        Result => {
            Output  => '<img />',
            Replace => 1,
        },
    },
    {
        Name   => 'Safety - Embedded Newline to Break-up XSS',
        Input  => '<IMG SRC="jav&#x0A;ascript:alert(\'XSS\');">',
        Config => {
            NoJavaScript => 1
        },
        Result => {
            Output  => '<img />',
            Replace => 1,
        },
    },
    {
        Name   => 'Safety - Embedded Carriage Return to Break-up XSS',
        Input  => '<IMG SRC="jav&#x0D;ascript:alert(\'XSS\');">',
        Config => {
            NoJavaScript => 1
        },
        Result => {
            Output  => '<img />',
            Replace => 1,
        },
    },
    {
        Name   => 'Safety - Non-alpha-non-digit XSS',
        Input  => '<SCRIPT/XSS SRC="http://xss.rocks/xss.js"></SCRIPT>',
        Config => {
            NoJavaScript => 1
        },
        Result => {
            Output  => '',
            Replace => 1,
        },
    },
    {
        Name   => 'Safety - Non-alpha-non-digit XSS (Gecko)',
        Input  => '<BODY onload!#$%&()*~+-_.,:;?@[/|\]^`=alert("XSS")>',
        Config => {
            NoJavaScript => 1
        },
        Result => {
            Output  => '<body>',
            Replace => 1,
        },
    },
    {
        Name   => 'Safety - Non-alpha-non-digit XSS (IE)',
        Input  => '<SCRIPT/SRC="http://xss.rocks/xss.js"></SCRIPT>',
        Config => {
            NoJavaScript => 1
        },
        Result => {
            Output  => '',
            Replace => 1,
        },
    },
    {
        Name   => 'Safety - Extraneous Open Brackets',
        Input  => '<<SCRIPT>alert("XSS");//\<</SCRIPT>',
        Config => {
            NoJavaScript => 1
        },
        Result => {
            Output  => '&lt;',
            Replace => 1,
        },
    },
    {
        Name   => 'Safety - No Closing Script Tags',
        Input  => '<SCRIPT SRC=http://xss.rocks/xss.js?< B >',
        Config => {
            NoJavaScript => 1
        },
        Result => {
            Output  => '',
            Replace => 1,
        },
    },
    {
        Name   => 'Safety - Protocol Resolution in Script Tags',
        Input  => '<SCRIPT SRC=//xss.rocks/.j>',
        Config => {
            NoJavaScript => 1
        },
        Result => {
            Output  => '',
            Replace => 1,
        },
    },
    {
        Name   => 'Safety - Half Open HTML/JavaScript XSS Vector',
        Input  => '<IMG SRC="(\'XSS\')"',
        Config => {
            NoJavaScript => 1
        },
        Result => {
            Output  => '',
            Replace => 1,
        },
    },
    {
        Name   => 'Safety - Double Open Angle Brackets',
        Input  => '<iframe src=http://xss.rocks/scriptlet.html <',
        Config => {
            NoJavaScript => 1
        },
        Result => {
            Output  => '',
            Replace => 1,
        },
    },
    {
        Name   => 'Safety - End Title Tag',
        Input  => '</TITLE><SCRIPT>alert("XSS");</SCRIPT>',
        Config => {
            NoJavaScript => 1
        },
        Result => {
            Output  => '</title>',
            Replace => 1,
        },
    },
    {
        Name   => 'Safety - INPUT Image',
        Input  => '<INPUT TYPE="IMAGE" SRC="javascript:alert(\'XSS\');">',
        Config => {
            NoJavaScript => 1
        },
        Result => {
            Output  => '<input type="IMAGE" />',
            Replace => 1,
        },
    },
    {
        Name   => 'Safety - BODY Image',
        Input  => '<BODY BACKGROUND="javascript:alert(\'XSS\')">',
        Config => {
            NoJavaScript => 1
        },
        Result => {
            Output  => '<body>',
            Replace => 1,
        },
    },
    {
        Name   => 'Safety - IMG Dynsrc',
        Input  => '<IMG DYNSRC="javascript:alert(\'XSS\')">',
        Config => {
            NoJavaScript => 1
        },
        Result => {
            Output  => '<img />',
            Replace => 1,
        },
    },
    {
        Name   => 'Safety - IMG Lowsrc',
        Input  => '<IMG LOWSRC="javascript:alert(\'XSS\')">',
        Config => {
            NoJavaScript => 1
        },
        Result => {
            Output  => '<img />',
            Replace => 1,
        },
    },
    {
        Name   => 'Safety - List-style-image',
        Input  => '<STYLE>li {list-style-image: url("javascript:alert(\'XSS\')");}</STYLE><UL><LI>XSS</br>',
        Config => {
            NoJavaScript => 1
        },
        Result => {
            Output  => '<style></style><ul><li>XSS',
            Replace => 1,
        },
    },
    {
        Name   => 'Safety - VBscript in an Image',
        Input  => '<IMG SRC=\'vbscript:msgbox("XSS")\'>',
        Config => {
            NoJavaScript => 1
        },
        Result => {
            Output  => '<img />',
            Replace => 1,
        },
    },
    {
        Name   => 'Safety - Livescript (older versions of Netscape only)',
        Input  => '<IMG SRC="livescript:[code]">',
        Config => {
            NoJavaScript => 1
        },
        Result => {
            Output  => '<img />',
            Replace => 1,
        },
    },
    {
        Name   => 'Safety - SVG Object Tag',
        Input  => '<svg/onload=alert(\'XSS\')>',
        Config => {
            NoJavaScript => 1
        },
        Result => {
            Output  => '<svg>',
            Replace => 1,
        },
    },
    {
        Name   => 'Safety - BODY Tag',
        Input  => '<BODY ONLOAD=alert(\'XSS\')>',
        Config => {
            NoJavaScript => 1
        },
        Result => {
            Output  => '<body>',
            Replace => 1,
        },
    },
    {
        Name   => 'Safety - BODY Tag',
        Input  => '<BODY ONLOAD =alert(\'XSS\')>',
        Config => {
            NoJavaScript => 1
        },
        Result => {
            Output  => '<body>',
            Replace => 1,
        },
    },
    {
        Name   => 'Safety - BGSOUND',
        Input  => '<BGSOUND SRC="javascript:alert(\'XSS\');">',
        Config => {
            NoJavaScript => 1
        },
        Result => {
            Output  => '<bgsound>',
            Replace => 1,
        },
    },
    {
        Name   => 'Safety - & JavaScript includes',
        Input  => '<BR SIZE="&{alert(\'XSS\')}">',
        Config => {
            NoJavaScript => 1
        },
        Result => {
            Output  => '<br size="&amp;{alert(&#39;XSS&#39;)}" />',
            Replace => 1,
        },
    },
    {
        Name   => 'Safety - STYLE sheet',
        Input  => '<LINK REL="stylesheet" HREF="javascript:alert(\'XSS\');">',
        Config => {
            NoJavaScript => 1
        },
        Result => {
            Output  => '<link rel="stylesheet" />',
            Replace => 1,
        },
    },
    {
        Name   => 'Safety - STYLE Tags with Broken-up JavaScript for XSS',
        Input  => '<STYLE>@im\\port\'\\ja\\vasc\\ript:alert("XSS")\';</STYLE>',
        Config => {
            NoJavaScript => 1
        },
        Result => {
            Output  => '<style></style>',
            Replace => 1,
        },
    },
    {
        Name   => 'Safety - STYLE Attribute using a Comment to Break-up Expression',
        Input  => '<IMG STYLE="xss:expr/*XSS*/ession(alert(\'XSS\'))">',
        Config => {
            NoJavaScript => 1
        },
        Result => {
            Output  => '<img />',
            Replace => 1,
        },
    },
    {
        Name   => 'Safety - IMG STYLE with Expression',
        Input  => 'exp/*<A STYLE=\'no\\xss:noxss("*//*");
xss:ex/*XSS*//*/*/pression(alert("XSS"))\'>',
        Config => {
            NoJavaScript => 1
        },
        Result => {
            Output  => 'exp/*<a>',
            Replace => 1,
        },
    },
    {
        Name   => 'Safety - STYLE Tag (Older versions of Netscape only)',
        Input  => '<STYLE TYPE="text/javascript">alert(\'XSS\');</STYLE>',
        Config => {
            NoJavaScript => 1
        },
        Result => {
            Output  => '',
            Replace => 1,
        },
    },
    {
        Name   => 'Safety - STYLE Tag using Background-image',
        Input  => '<STYLE>.XSS{background-image:url("javascript:alert(\'XSS\')");}</STYLE><A CLASS=XSS></A>',
        Config => {
            NoJavaScript => 1
        },
        Result => {
            Output  => '<style></style><a class="XSS"></a>',
            Replace => 1,
        },
    },
    {
        Name   => 'Safety - STYLE Tag using Background',
        Input  => '<STYLE type="text/css">BODY{background:url("javascript:alert(\'XSS\')")}</STYLE>',
        Config => {
            NoJavaScript => 1
        },
        Result => {
            Output  => '<style type="text/css"></style>',
            Replace => 1,
        },
    },
    {
        Name   => 'Safety - STYLE Tag using Background',
        Input  => '<STYLE type="text/css">BODY{background:url("<javascript:alert>(\'XSS\')")}</STYLE>',
        Config => {
            NoJavaScript => 1
        },
        Result => {
            Output  => '<style type="text/css"></style>',
            Replace => 1,
        },
    },
    {
        Name   => 'Safety - Anonymous HTML with STYLE Attribute',
        Input  => '<XSS STYLE="xss:expression(alert(\'XSS\'))">',
        Config => {
            NoJavaScript => 1
        },
        Result => {
            Output  => '<xss>',
            Replace => 1,
        },
    },
    {
        Name   => 'Safety - US-ASCII Encoding',
        Input  => '¼script¾alert(¢XSS¢)¼/script¾',
        Config => {
            NoJavaScript => 1
        },
        Result => {
            Output  => '&frac14;script&frac34;alert(&cent;XSS&cent;)&frac14;/script&frac34;',
            Replace => 1,
        },
    },
    {
        Name   => 'Safety - META',
        Input  => '<META HTTP-EQUIV="refresh" CONTENT="0;url=javascript:alert(\'XSS\');">',
        Config => {
            NoJavaScript => 1
        },
        Result => {
            Output  => '',
            Replace => 1,
        },
    },
    {
        Name   => 'Safety - META using Data',
        Input  => '<META HTTP-EQUIV="refresh" CONTENT="0;url=data:text/html base64,PHNjcmlwdD5hbGVydCgnWFNTJyk8L3NjcmlwdD4K">',
        Config => {
            NoJavaScript => 1
        },
        Result => {
            Output  => '',
            Replace => 1,
        },
    },
    {
        Name   => 'Safety - META with Additional URL Parameter',
        Input  => '<META HTTP-EQUIV="refresh" CONTENT="0; URL=http://;URL=javascript:alert(\'XSS\');">',
        Config => {
            NoJavaScript => 1
        },
        Result => {
            Output  => '',
            Replace => 1,
        },
    },
    {
        Name   => 'Safety - IFRAME',
        Input  => '<IFRAME SRC="javascript:alert(\'XSS\');"></IFRAME>',
        Config => {
            NoJavaScript => 1
        },
        Result => {
            Output  => '<iframe></iframe>',
            Replace => 1,
        },
    },
    {
        Name   => 'Safety - IFRAME Event Based',
        Input  => '<IFRAME SRC=# onmouseover="alert(document.cookie)"></IFRAME>',
        Config => {
            NoJavaScript => 1
        },
        Result => {
            Output  => '<iframe src="#"></iframe>',
            Replace => 1,
        },
    },
    {
        Name   => 'Safety - FRAME',
        Input  => '<FRAMESET><FRAME SRC="javascript:alert(\'XSS\');"></FRAMESET>',
        Config => {
            NoJavaScript => 1
        },
        Result => {
            Output  => '<frameset><frame></frameset>',
            Replace => 1,
        },
    },
    {
        Name   => 'Safety - TABLE',
        Input  => '<TABLE BACKGROUND="javascript:alert(\'XSS\')">',
        Config => {
            NoJavaScript => 1
        },
        Result => {
            Output  => '<table>',
            Replace => 1,
        },
    },
    {
        Name   => 'Safety - TD',
        Input  => '<TABLE><TD BACKGROUND="javascript:alert(\'XSS\')">',
        Config => {
            NoJavaScript => 1
        },
        Result => {
            Output  => '<table><td>',
            Replace => 1,
        },
    },
    {
        Name   => 'Safety - DIV Background-image',
        Input  => '<DIV STYLE="background-image: url(javascript:alert(\'XSS\'))">',
        Config => {
            NoJavaScript => 1
        },
        Result => {
            Output  => '<div>',
            Replace => 1,
        },
    },
    {
        Name   => 'Safety - DIV Expression',
        Input  => '<DIV STYLE="width: expression(alert(\'XSS\'));">',
        Config => {
            NoJavaScript => 1
        },
        Result => {
            Output  => '<div>',
            Replace => 1,
        },
    },
    {
        Name   => 'Safety - Downlevel-Hidden Block',
        Input  => '<!--[if gte IE 4]>
<SCRIPT>alert(\'XSS\');</SCRIPT>
<![endif]-->',
        Config => {
            NoJavaScript => 1
        },
        Result => {
            Output  => '',
            Replace => 1,
        },
    },
    {
        Name   => 'Safety - BASE Tag',
        Input  => '<BASE HREF="javascript:alert(\'XSS\');//">',
        Config => {
            NoJavaScript => 1
        },
        Result => {
            Output  => '<base />',
            Replace => 1,
        },
    },
    {
        Name   => 'Safety - OBJECT Tag',
        Input  => '<OBJECT TYPE="text/x-scriptlet" DATA="http://xss.rocks/scriptlet.html"></OBJECT>',
        Config => {
            NoObject => 1
        },
        Result => {
            Output  => '',
            Replace => 1,
        },
    },
    {
        Name   => 'Safety - EMBED a Flash Movie That Contains XSS',
        Input  => '<EMBED SRC="http://ha.ckers.org/xss.swf" AllowScriptAccess="always"></EMBED>',
        Config => {
            NoEmbed => 1
        },
        Result => {
            Output  => '',
            Replace => 1,
        },
    },
    {
        Name   => 'Safety - EMBED SVG Which Contains XSS Vector',
        Input  => '<EMBED SRC="data:image/svg+xml;base64,PHN2ZyB4bWxuczpzdmc9Imh0dH A6Ly93d3cudzMub3JnLzIwMDAvc3ZnIiB4bWxucz0iaHR0cDovL3d3dy53My5vcmcv MjAwMC9zdmciIHhtbG5zOnhsaW5rPSJodHRwOi8vd3d3LnczLm9yZy8xOTk5L3hs aW5rIiB2ZXJzaW9uPSIxLjAiIHg9IjAiIHk9IjAiIHdpZHRoPSIxOTQiIGhlaWdodD0iMjAw IiBpZD0ieHNzIj48c2NyaXB0IHR5cGU9InRleHQvZWNtYXNjcmlwdCI+YWxlcnQoIlh TUyIpOzwvc2NyaXB0Pjwvc3ZnPg==" type="image/svg+xml" AllowScriptAccess="always"></EMBED>',
        Config => {
            NoEmbed => 1
        },
        Result => {
            Output  => '',
            Replace => 1,
        },
    },
    {
        Name   => 'Safety - Assuming you can only fit in a few characters and it filters against .js',
        Input  => '<SCRIPT SRC="http://xss.rocks/xss.jpg"></SCRIPT>',
        Config => {
            NoJavaScript => 1
        },
        Result => {
            Output  => '',
            Replace => 1,
        },
    },
    {
        Name   => 'Safety - SSI (Server Side Includes)',
        Input  => '<!--#exec cmd="/bin/echo \'<SCR\'"--><!--#exec cmd="/bin/echo \'IPT SRC=http://xss.rocks/xss.js></SCRIPT>\'"-->',
        Config => {
            NoJavaScript => 1
        },
        Result => {
            Output  => '',
            Replace => 1,
        },
    },
    {
        Name   => 'Safety - IMG Embedded Commands',
        Input  => '<IMG SRC="http://www.thesiteyouareon.com/somecommand.php?somevariables=maliciouscode">',
        Config => {
            NoExtSrcLoad => 1
        },
        Result => {
            Output  => '<img />',
            Replace => 1,
        },
    },
    {
        Name   => 'Safety - UTF-7 Encoding',
        Input  => '<HEAD><META HTTP-EQUIV="CONTENT-TYPE" CONTENT="text/html; charset=UTF-7"> </HEAD>+ADw-SCRIPT+AD4-alert(\'XSS\');+ADw-/SCRIPT+AD4-',
        Config => {
            NoJavaScript => 1
        },
        Result => {
            Output  => '<head><meta http-equiv="CONTENT-TYPE" content="text/html; charset=UTF-7" /> </head>',
            Replace => 1,
        },
    },
    {
        Name   => 'Safety - XSS Using HTML Quote Encapsulation 1',
        Input  => '<SCRIPT a=">" SRC="httx://xss.rocks/xss.js"></SCRIPT>',
        Config => {
            NoJavaScript => 1
        },
        Result => {
            Output  => '',
            Replace => 1,
        },
    },
    {
        Name   => 'Safety - XSS Using HTML Quote Encapsulation 2',
        Input  => '<SCRIPT =">" SRC="httx://xss.rocks/xss.js"></SCRIPT>',
        Config => {
            NoJavaScript => 1
        },
        Result => {
            Output  => '',
            Replace => 1,
        },
    },
    {
        Name   => 'Safety - XSS Using HTML Quote Encapsulation 3',
        Input  => '<SCRIPT a=">" \'\' SRC="httx://xss.rocks/xss.js"></SCRIPT>',
        Config => {
            NoJavaScript => 1
        },
        Result => {
            Output  => '',
            Replace => 1,
        },
    },
    {
        Name   => 'Safety - XSS Using HTML Quote Encapsulation 4',
        Input  => '<SCRIPT "a=\'>\'" SRC="httx://xss.rocks/xss.js"></SCRIPT>',
        Config => {
            NoJavaScript => 1
        },
        Result => {
            Output  => '',
            Replace => 1,
        },
    },
    {
        Name   => 'Safety - XSS Using HTML Quote Encapsulation 5',
        Input  => '<SCRIPT a=>SRC="httx://xss.rocks/xss.js"></SCRIPT>',
        Config => {
            NoJavaScript => 1
        },
        Result => {
            Output  => '',
            Replace => 1,
        },
    },
    {
        Name   => 'Safety - XSS Using HTML Quote Encapsulation 6',
        Input  => '<SCRIPT a=">\'>" SRC="httx://xss.rocks/xss.js"></SCRIPT>',
        Config => {
            NoJavaScript => 1
        },
        Result => {
            Output  => '',
            Replace => 1,
        },
    },
    {
        Name   => 'Safety - XSS Using HTML Quote Encapsulation 7',
        Input  => '<SCRIPT>document.write("<SCRI");</SCRIPT>PT SRC="httx://xss.rocks/xss.js"></SCRIPT>',
        Config => {
            NoJavaScript => 1
        },
        Result => {
            Output  => 'PT SRC=&quot;httx://xss.rocks/xss.js&quot;&gt;',
            Replace => 1,
        },
    },
    {
        Name   => 'Safety - Different Syntax or Encoding 1',
        Input  => '"><script >alert(document.cookie)</script >',
        Config => {
            NoJavaScript => 1
        },
        Result => {
            Output  => '&quot;&gt;',
            Replace => 1,
        },
    },
    {
        Name   => 'Safety - Different Syntax or Encoding 2',
        Input  => '"><ScRiPt>alert(document.cookie)</ScRiPt>',
        Config => {
            NoJavaScript => 1
        },
        Result => {
            Output  => '&quot;&gt;',
            Replace => 1,
        },
    },
    {
        Name   => 'Safety - Different Syntax or Encoding 3',
        Input  => '"%3cscript%3ealert(document.cookie)%3c/script%3e',
        Config => {
            NoJavaScript => 1
        },
        Result => {
            Output  => '&quot;%3cscript%3ealert(document.cookie)%3c/script%3e',
            Replace => 1,
        },
    },
    {
        Name   => 'Safety - Bypassing Non-Recursive Filtering',
        Input  => '<scr<script>ipt>alert(document.cookie)</script>',
        Config => {
            NoJavaScript => 1
        },
        Result => {
            Output  => '<scrscript>ipt&gt;alert(document.cookie)',
            Replace => 1,
        },
    },
);

for my $Test (@Tests) {
    my %Result = $HTMLUtilsObject->Safety(
        String => $Test->{Input},
        %{ $Test->{Config} },
    );
    if ( $Test->{Result}->{Replace} ) {
        $Self->True(
            $Result{Replace},
            "$Test->{Name} replaced",
        );
    }
    else {
        $Self->False(
            $Result{Replace},
            "$Test->{Name} not replaced",
        );
    }
    $Self->Is(
        $Result{String},
        $Test->{Result}->{Output},
        $Test->{Name},
    );
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
