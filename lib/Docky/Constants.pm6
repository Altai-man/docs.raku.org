our @backup-cards is export =
        %( title => 'Language Reference & Tutorials',
           description => 'Documents explaining the various conceptual parts of the language.',
           url => '/language', :icon<fa-graduation-cap> ),
        %( title => 'Type Reference',
           description => 'Index of built-in classes, roles and enums. ',
           url => '/type', :icon<fa-layer-group> ),
        %( title => 'Routine Reference',
           description => 'Index of built-in subroutines and methods.',
           url => '/routine', :icon<fa-paperclip> ),
        %( title => 'Raku Programs',
           description => 'Documents explaining various topics focused on Raku programs rather than the language itself.',
           url => '/programs', :icon<fa-code> ),
        %( title => 'FAQs (Frequently Asked Questions)',
           description => 'A collection of questions that have cropped up often, along with answers.',
           url => '/faq', :icon<fa-question-circle> ),
        %( title => 'Community',
           description => 'Information about the Raku development community, email lists, IRC and IRC bots, and blogs.',
           url => '/community', :icon<fa-user-friends> );

our @community-links is export =
    { :title<Reddit>, :url<https://www.reddit.com/r/rakulang/> },
    { :title<Twitter>, :url<https://twitter.com/raku_news> },
    { :title<Facebook>, :url<https://www.facebook.com/groups/1595443877388632/> },
    { :title<Stack Overflow>, :url<https://stackoverflow.com/questions/tagged/raku> };

our @resource-links is export =
    { :title<The Raku Guide>, :url<https://raku.guide/> },
    { :title<Books>, :url<https://perl6book.com/> },
    { :title<Rosetta Code>, :url<https://www.raku.org/community/rosettacode> },
    { :title<Downloadable docs>, :url</404> };

our @explore-links is export =
    { :title<Raku Blog Aggregator>, :url<https://pl6anet.org/> },
    { :title<Rakudo Weekly>, :url<https://rakudoweekly.blog/> },
    { :title<The Weekly Challenge>, :url<https://perlweeklychallenge.org/> },
    { :title<Raku Advent Calendar>, :url<https://raku-advent.blog/> };
