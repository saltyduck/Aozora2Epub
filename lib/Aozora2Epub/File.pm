package Aozora2Epub::File;
use strict;
use warnings;
use utf8;
use Aozora2Epub::Gensym;
use HTML::Element;
use base qw(Class::Accessor);
__PACKAGE__->mk_accessors(qw/content name/);

sub new {
    my ($class, $content) = @_;
    return bless {
        name => gensym,
        content => $content,
    }, $class;
}

sub _to_html {
    my $e = shift;
    unless ($e->isa('HTML::Element')) {
        return $e;
    }
    return $e->as_HTML('<>&', undef, {});
}

sub as_html {
    my $self = shift;
    return join('', map { _to_html($_) } @{$self->{content}});
}

sub insert_content {
    my ($self, $lol) = @_;

    my $c = HTML::Element->new_from_lol($lol);
    unshift @{$self->{content}}, $c;
}

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
