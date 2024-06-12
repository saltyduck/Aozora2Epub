# NAME

Aozora2Epub - Convert AozoraBunko xhtml to epub

# SYNOPSIS

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

# DESCRIPTION

Aozora2Epub は青空文庫のXHTML形式の本をEPUBに変換するモジュールです。

簡単に合本を生成するためのインタフェースも提供しています。

## 青空文庫ファイルのキャッシュ

青空文庫からhttpsでファイルを取得する際に、`~/.aozora2epub` にキャッシュします。
これは環境変数 `AOZORA2EPUB_CACHE` で指定したディレクトリに変更することが出来ます。

キャッシュされたファイルは30日間有効で、それを過ぎると自動的に削除されます。

# AUTHOR

Yoshimasa Ueno <saltyduck@gmail.com>

# COPYRIGHT

Copyright 2024- Yoshimasa Ueno

# LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

# SEE ALSO
