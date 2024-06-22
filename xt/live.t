use strict;
use warnings;
use utf8;
use Test::More;
use Aozora2Epub;
use lib qw/./;
use t::Util;

plan skip_all => "LIVE_TEST not enabled" unless $ENV{LIVE_TEST};


sub dotest {
    my ($url, $title, $author) = @_;

    my $book = Aozora2Epub->new($url);
    is $book->title, $title, "title  $url";
    is $book->author, $author, "author $url";
}

dotest('001637/files/59055_69954.html', 'ある日', '中野鈴子');
dotest('001637/card59055.html', 'ある日', '中野鈴子');

done_testing();
