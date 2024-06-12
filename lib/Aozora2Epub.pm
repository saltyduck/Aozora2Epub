package Aozora2Epub;
use utf8;
use strict;
use warnings;
use Aozora2Epub::Gensym;
use Aozora2Epub::CachedGet qw/http_get/;
use Aozora2Epub::Epub;
use Aozora2Epub::XHTML;
use URI;
use HTML::Escape qw/escape_html/;

use base qw(Class::Accessor);
__PACKAGE__->mk_accessors(qw/files title author epub bib_info notation_notes/);

our $VERSION = '0.01';

our $AOZORA_GAIJI_URI = URI->new("https://www.aozora.gr.jp/gaiji/");

sub _base_url {
    my $base = shift;
    $base =~ s{[^/]+\.html$}{}s;
    return $base;
}

sub _get_content {
    my $xhtml = shift;
    if ($xhtml =~ m{/card\d+\.html$}) { # 図書カード
        unless ($xhtml =~ m{^https?://}) { # $xhtml shuld be \d+/card\d+.html
            $xhtml = "https://www.aozora.gr.jp/cards/$xhtml";
        }
        my $text = http_get($xhtml);
        my $tree = Aozora2Epub::XHTML::Tree->new($text);
        my $xhtml_url;
        $tree->process('//a[text()="いますぐXHTML版で読む"]' => sub {
            $xhtml_url = shift->attr('href');
        });
        my $xhtml_uri = URI->new($xhtml_url)->abs(URI->new($xhtml));
        return _get_content($xhtml_uri->as_string);
    }
    if ($xhtml =~ m{/files/\d+_\d+\.html$}) { # XHTML
        unless ($xhtml =~ m{^https?://}) { # $xhtml shuld be \d+/files/xxx_xxx.html
            $xhtml = "https://www.aozora.gr.jp/cards/$xhtml";
        }
        my $text = http_get($xhtml);
        return ($text, _base_url($xhtml));
    }
    # XHTML string
    return (qq{<div class="main_text">$xhtml</div>}, undef);
}

sub new {
    my ($class, $content, %options) = @_;
    my $self =  bless {
        files => [],
        epub => Aozora2Epub::Epub->new,
        title => undef,
        author => undef,
        bib_info => '',
        notation_notes => '',
    }, $class;
    $self->append($content, %options, title=>'') if $content;
    return $self;
}

sub append {
    my ($self, $xhtml_like, %options) = @_;

    my ($xhtml, $base_url) = _get_content($xhtml_like);
    my $doc = Aozora2Epub::XHTML->new_from_string($xhtml);

    unless ($options{no_fetch_assets}) {
        for my $path (@{$doc->gaiji}) {
            my $x = URI->new($path)->abs($AOZORA_GAIJI_URI);
            my $png = http_get(URI->new($path)->abs($AOZORA_GAIJI_URI));
            $self->epub->add_gaiji($png, $path);
        }
        my $base_uri = URI->new($base_url);
        for my $path (@{$doc->fig}) {
            my $png = http_get(URI->new($path)->abs($base_uri));
            $self->epub->add_image($png, $path);
        }
    }
    my @files = $doc->split;
    my $part_title;
    unless (defined $options{title}) {
        $part_title = $doc->title;
    } elsif ($options{title} eq '') {
        $part_title = undef;
    } else {
        $part_title = $options{title};
    }
    if ($files[0] && $part_title) {
        my $title_level = $options{title_level} || 2;
        my $tag = "h$title_level";
        $files[0]->insert_content([ $tag, { id => gensym }, $part_title ]);
    }
    push @{$self->files}, @files;
    $self->title or $self->title($doc->title);
    $self->author or $self->author($doc->author);
    $self->add_bib_info($part_title, $doc->bib_info);
    $self->add_notation_notes($part_title, $doc->notation_notes);
}

sub add_bib_info {
    my ($self, $part_title, $bib_info) = @_;

    $self->bib_info(join('',
                         $self->bib_info,
                         "<br/>",
                         ($part_title
                          ? (q{<h5 class="bib">}, escape_html($part_title), "</h5>")
                          : ()),
                         $bib_info));
}

sub add_notation_notes {
    my ($self, $part_title, $notes) = @_;

    $self->notation_notes(join('',
                               $self->notation_notes,
                               "<br/>",
                               ($part_title
                                ? (q{<h5 class="n-notes">}, escape_html($part_title), "</h5>")
                                : ()),
                               $notes));
}

sub _make_content_iterator {
    my $files = shift;

    my @files = @$files;
    my $file = shift @files;
    my @content = @{$file->content};
    my $last;

    return (
        sub { # get next element
            if ($last) {
                my $x = $last;
                undef $last;
                return $x;
            }
            my $elem = shift @content;
            unless ($elem) {
                $file = shift @files;
                return unless $file;
                @content = @{$file->content};
                $elem = shift @content;
            }
            return { elem=>$elem, file=>$file->name };
        },
        sub { $last  = shift; } # putback
    );
}

sub _toc {
    my ($level, $next, $putback) = @_;

    my @cur;
    while (my $c = $next->()) {
        my $e = $c->{elem};
        next unless $e->isa('HTML::Element');
        my $tag = $e->tag;
        my ($lev) = ($tag =~ m{h(\d)});
        next unless $lev;
        if ($lev > $level) {
            $putback->($c);
            my $children = _toc($lev, $next, $putback);
            if ($cur[-1] && $cur[-1]->{level} < $lev) {
                $cur[-1]->{children} = $children;
            } else {
                push @cur, @{$children};
            }
            next;
        }
        if ($lev < $level) {
            $putback->($c);
            return \@cur;
        }
        push @cur, {
            name => gensym,
            level => $lev,
            id => $e->attr('id'),
            title => $e->as_text,
            file => $c->{file},
        };
    }
    return \@cur;
}

sub toc {
    my $self = shift;
    my ($next, $putback) = _make_content_iterator($self->{files});
    return _toc(1, $next, $putback);
}

sub to_epub {
    my ($self, %options) = @_;

    my $epub_filename = $options{output};
    $epub_filename ||= $self->title . ".epub";

    if ($options{cover}) {
        $self->epub->set_cover($options{cover});
    }
    $self->epub->build_from_doc($self);

    $self->epub->save($epub_filename);
}

sub as_html {
    my $self = shift;
    return join('', map { $_->as_html } @{$self->files});
}
1;
__END__

=encoding utf-8

=head1 NAME

Aozora2Epub - Convert AozoraBunko xhtml to epub

=head1 SYNOPSIS

  use Aozora2Epub;

  # 普通に1っこ
  my $doc = Aozora2Epub->new("000158/card1504.html");
  $doc->to_epub;

  my $doc = Aozora2Epub->new("https://www.aozora.gr.jp/cards/000262/files/48074_40209.html");

  my $doc = Aozora2Epub->new($xhtml_string);

  # 合本 - こんな感じで書きたいかな
  $doc = Aozora2Epub->new();
  $doc->title('夜明け前');
  $doc->author('島崎藤村');
  $doc->append("<h1>第一部</h1>"); # 独立ページで追加される
  $doc->append("000158/card1504.html", title=>'第一部上'); # titleが先頭にh2で追加される
  $doc->append("000158/card1505.html", title=>'第一部下');
  $doc->append(from_string("<h1>第二部</h1>");
  $doc->append("000158/card1506.html", title=>'第二部上');
  $doc->append("000158/card1507.html", title=>'第二部下');
  $doc->bib(undef); # 奥付をつけない
  $doc->to_epub(tocdepth=>4); # kindleのナビは2段まで。目次ページは指定した深さで


  {
      # 「第一部上」を独立ページにしたい場合
      $doc->append("<h2>第一部上</h2>");
      $doc->append("000158/card1504.html", title=>''); # 何も追加されない
  }
  {
      # こういうのもあり
      $doc->append("000158/card1504.html"); # 追加した本のタイトルが、先頭にh2で追加される
  }


=head1 DESCRIPTION

Aozora2Epub は青空文庫のXHTML形式の本をEPUBに変換するモジュールです。

簡単に合本を生成するためのインタフェースも提供しています。

=head2 青空文庫ファイルのキャッシュ

青空文庫からhttpsでファイルを取得する際に、C<~/.aozora2epub> にキャッシュします。
これは環境変数 C<AOZORA2EPUB_CACHE> で指定したディレクトリに変更することが出来ます。

キャッシュされたファイルは30日間有効で、それを過ぎると自動的に削除されます。


=head1 AUTHOR

Yoshimasa Ueno E<lt>saltyduck@gmail.comE<gt>

=head1 COPYRIGHT

Copyright 2024- Yoshimasa Ueno

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

=cut
