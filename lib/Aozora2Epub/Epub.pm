package Aozora2Epub::Epub;
use strict;
use warnings;
use utf8;
use File::ShareDir qw(dist_dir);
use Path::Tiny;
use Text::Xslate qw/mark_raw/;
use UUID qw/uuid/;
use HTTP::Date qw/time2isoz/;
use File::Find qw//;
use Archive::Zip qw( :ERROR_CODES :CONSTANTS );
use Aozora2Epub::CachedGet;
use Aozora2Epub::Gensym;
use base qw/Class::Accessor/;
__PACKAGE__->mk_accessors(qw/assets/);

our $VERSION = '0.01';

sub new {
    my $class = shift;

    my $tmpdir = ($ENV{EPUB_TMP_DIR} || Path::Tiny->tempdir);
    my $sharedir = path(dist_dir('Aozora2Epub'), 'basic');
    my $tx = Text::Xslate->new();
    return bless {
        tmpdir=>$tmpdir,
        sharedir=>$sharedir,
        xslate=>$tx,
        assets=>[],
    }, $class;
}

sub dest_file {
    my ($self, @path) = @_;
    my $dest = path($self->{tmpdir}, @path);
    my $dir = path($dest->dirname);
    $dir->is_dir or $dir->mkdir;
    return $dest;
}

sub copy {
    my ($self, $file) = @_;
    my $dest = $self->dest_file($file);
    path($self->{sharedir}, $file)->copy($dest);
}

sub slurp {
    my ($self, $file) = @_;
    return path($self->{sharedir}, $file)->slurp_utf8;
}

sub render_to {
    my ($self, $template, $to, $args) = @_;
    my $dest = $self->dest_file($to);
    my $text = $self->{xslate}->render_string($self->slurp($template), $args);
    $dest->spew_utf8($text);
}

sub render {
    my ($self, $template, $args) = @_;
    $self->render_to($template, $template, $args);
}

sub write_string {
    my ($self, $bin, $to) = @_;
    my $dest = $self->dest_file($to);
    $dest->spew({binmode => ":raw"}, $bin);
}

sub files_in_dir {
    my $dir = shift;
    my @files;
    File::Find::find(sub { push @files, $File::Find::name unless -d || /^\./ },
                     $dir);
    return \@files;
}

sub save {
    my ($self, $epub_path) = @_;

    my $zip_error;
    Archive::Zip::setErrorHandler( sub { $zip_error = shift } );
    my $zip = Archive::Zip->new();
    my $dir = $self->{tmpdir};
    my $files = files_in_dir($dir);
    for my $file (@$files) {
        my $relative_path = $file;
        $relative_path =~ s{^$dir/}{};
        $zip->addFile($file, $relative_path)
            or die "Error adding file $file to zip: not a readable plain file";
    }

    unless ($zip->writeToFileNamed($epub_path) == AZ_OK) {
        die 'Error writing zip file: ', $zip_error;
    }
}

sub add_gaiji {
    my ($self, $bin, $path) = @_;
    $self->write_string($bin, "EPUB/gaiji/$path");
    push @{$self->assets}, "gaiji/$path";
}

sub add_image {
    my ($self, $bin, $path) = @_;
    $self->write_string($bin, "EPUB/images/$path");
    push @{$self->assets}, "images/$path";
}

sub _add_name_to_array {
    my $array = shift;
    return [ map {
            {
                name => gensym,
                value => $_
            }
        } @$array ];
}

sub set_cover {
    my ($self, $cover_jpg) = @_;
    path($cover_jpg)->copy($self->dest_file('EPUB/cover.jpg'));
    $self->{has_coverpage} = 1;
}

sub build_from_doc {
    my ($self, $doc) = @_;

    $self->{doc} = $doc;

    my $toc = $doc->toc;
    my $resnum = 0;
    my $args = {
        has_coverpage => $self->{has_coverpage},
        uuid => uuid(),
        title => $self->{doc}->title,
        author => $self->{doc}->author,
        date => time2isoz(time),
        sections => $toc,
        has_sections => (@$toc ? 1 : 0),
        files => $self->{doc}->files,
        has_okuzuke => $doc->bib_info || $doc->notation_notes,
        bib_info => mark_raw($self->{doc}->bib_info),
        notation_notes => mark_raw($self->{doc}->notation_notes),
        assets => _add_name_to_array($self->assets),
    };

    $self->copy("mimetype");
    $self->copy("META-INF/container.xml");
    $self->copy("META-INF/com.apple.ibooks.display-options.xml");
    $self->copy("EPUB/styles/style.css");

    $self->render("EPUB/content.opf", $args);
    $self->render("EPUB/nav.xhtml", $args);
    $self->render("EPUB/toc.ncx", $args);
    $self->render("EPUB/toc.xhtml", $args);
    if ($self->{has_coverpage}) {
        $self->render("EPUB/text/cover_page.xhtml", $args);
    }
    $self->render("EPUB/text/title_page.xhtml", $args);
    if ($args->{has_okuzuke}) {
        $self->render("EPUB/text/okuzuke.xhtml", $args);
    }

    for my $f (@{$args->{files}}) {
        $self->render_to("EPUB/text/file.xhtml", "EPUB/text/$f->{name}.xhtml",
                         {
                             name => $f->{name},
                             content => mark_raw($f->as_html),
                         } );
    }
}

1;
__END__

=encoding utf-8

=head1 NAME

App::Aozora2EPUB - Convert Aozora-bunko XHTML to EPUB

=head1 SYNOPSIS

  aozora2epub https://www.aozora.gr.jp/cards/000055/files/550_51255.html

=head1 DESCRIPTION

aozora2epubは L<青空文庫|https://www.aozora.gr.jp/>のXHTML形式のファイルを
EPUB3に変換するスクリプトです。

=head1 OPTIONS

=over 4

=item --output -o

出力するEPUBファイル名を指定します。デフォルトは S<F<本のタイトル>.epub>です。

=item --cover -c

表紙を指定します。C<none> を指定すると表紙無しになります。
C<auto>だと本のタイトルと著者名を使って、表紙を自動生成します。
JPEGファイルのパスを指定すると、そのファイルを表紙にします。
デフォルトはautoです。

  aozora2epub -c none https://www.aozora... # 表紙無し
  aozora2epub -c auto https://www.aozora... # 表紙を自動生成する
  aozora2epub -c my-cover.jpeg https://w...  # my-cover.jpegを表紙にする

表紙の生成には、FreeTypeとJPEGサポートが有効なL<Imager>がインストールされている必要があります。
インストールされていない場合、C<--cover none>を指定した場合同じ挙動になります。
つまり表紙は生成されません。

L<Imager>のインストールの詳細はL<Imager::Install|https://metacpan.org/dist/Imager/view/lib/Imager/Install.pod>をご参照下さい。

=item --verbose -v

処理経過などを表示します。

=item --help -h

ヘルプを表示します。

=back

=head1 AUTHOR

Yoshimasa Ueno E<lt>saltyduck@gmail.comE<gt>

=head1 COPYRIGHT

Copyright 2024- Yoshimasa Ueno

=head1 LICENSE

This is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

同梱のIPAフォントは
L<IPAフォントライセンスv1.0|https://moji.or.jp/ipafont/license/> に従います。

=head1 SEE ALSO

L<青空文庫|https://www.aozora.gr.jp/>

L<Imager>

L<Imager::Install|https://metacpan.org/dist/Imager/view/lib/Imager/Install.pod>

=cut

1;

__END__

=encoding utf8

=head1 NAME

A - blah blah blah

=head1 SYNOPSIS

  use A;

=head1 DESCRIPTION

A is

=head1 AUTHOR

Yoshimasa Ueno

=head1 COPYRIGHT

Copyright 2012- Yoshimasa Ueno


=head1 LICENSE

Same as Perl.

=head1 NO WARRANTY

This software is provided "as-is," without any express or implied
warranty. In no event shall the author be held liable for any damages
arising from the use of the software.

=head1 SEE ALSO

=cut
