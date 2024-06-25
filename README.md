# NAME

Aozora2Epub - Convert Aozora Bunko XHTML to EPUB

# SYNOPSIS

    use Aozora2Epub;

    my $book = Aozora2Epub->new("https://www.aozora.gr.jp/cards/000262/files/48074_40209.html");
    $book->to_epub;

    # 合本の作成
    $book = Aozora2Epub->new();
    $book->append("000879/card179.html"); # 藪の中
    $book->append("000879/card127.html"); # 羅生門
    $book->title('芥川竜之介作品集');
    $book->to_epub;

# DESCRIPTION

Aozora2Epub は青空文庫のXHTML形式の本をEPUBに変換するモジュールです。

簡単に合本を生成するためのインタフェースも提供しています。

# METHODS

## new

    my $book = Aozora2Epub->new($book_url);
    my $book = Aozora2Epub->new($xhtml_string);
    my $book = Aozora2Epub->new(); # 空のドキュメントを作る

`$bool_url`で指定した青空文庫の本を読み込みます。
あるいは、文字列として指定された整形式のXHTMLを本の内容として読み込みます。

本は以下のいずれかの形式で指定します。
いずれも、URL先頭の `https://www.aozora.gr.jp/cards/`の部分を省略することが可能です。

- 図書カードのURL

    青空文庫の図書カードのURLです。以下に例を示します。

        https://www.aozora.gr.jp/cards/001569/card59761.html
        
        001569/card59761.html # URLの先頭部分を省略

- XHTMLのURL

    青空文庫のXHTMLファイルのURLです。以下に例を示します。

        https://www.aozora.gr.jp/cards/001569/files/59761_74795.html
        
        001569/files/59761_74795.html # URLの先頭部分を省略

## append

    $book->append($book_url); # 追加する本のタイトルを章タイトルとして使用
    $book->append($book_url, use_subtitle=>1); # 追加する本のサブタイトルを章タイトルとして使用
    $book->append($book_url, title=>"第2部"); # 章タイトルを明示的に指定
    $book->append($book_url, title=>"第2部", title_level=>1); # <h1>第2部</h1>を章タイトルに使用
    $book->append($book_url, title_html=>'<h1>Part1</h1>><h2>Chapter1<h2>'); # 指定したXHTML章タイトルとして使用
    $book->append($xhtml_string);

指定した本の内容を追加します。本の指定方法は`new`メソッドと同じです。

追加される本のタイトルが章タイトルとして。追加される本の内容の先頭に `<h2>タイトル</h2>` という形で付加されます。
このとき、`use_subtitle`オプションが真値なら、タイトルではなくサブタイトルが使われます。
`title`オプションによって、このタイトルを指定することができます。
`title=>''`とすると、ヘッダ要素を追加しません。
`title_level`オプションで、付加されるヘッダ要素のレベルを変更することができます。

`title_html`オプションを使うと、先頭に加える要素を自由に設定できます。
このオプションを指定した場合、`title`, `title_level`, `use_subtile`
はすべて無視されます。

これらのオプションの使用例は、["合本の作成"](#合本の作成)を参照して下さい。

## title

    $book->title; # タイトルを取得
    $book->title('随筆集'); # タイトルを設定

タイトルを取得/設定します。

## author

    $book->author; # 著者を取得
    $book->author('山田太郎'); # 著者を設定

著者を取得/設定します。

## bib\_info

    $book->bib_info; # 奥付の内容を取得
    $book->bib_info(undef); # 奥付を消去

奥付の内容を取得/設定します。
`undef`を設定して奥付を消去すると、EPUBに奥付が含まれなくなります。

## to\_epub

    $book->to_epub();
    $book->to_epub(output=>'my.epub', cover=>'mycover.jpg');

EPUBを出力します。オプションは以下の通りです。

- output

    出力するEPUBファイルのパスを指定します。デフォルトは`本のタイトル.epub`です。

- cover

    表紙のイメージファイルを指定します。JPEGファイルでなければなりません。
    指定しない場合は、表紙イメージを持たないEPUBが出力されます。

## as\_html

    my $html = $book->as_html;

本の内容をHTMLで返します。

# 合本の作成

最もシンプルなのは、合本に含めたい本を`append`で連結して行くことです。

    my $book = Aozora2Epub->new();
    $book->append("000879/card179.html"); # 藪の中
    $book->append("000879/card127.html"); # 羅生門
    $book->title('芥川竜之介作品集');
    $book->to_epub;

タイトルはほとんどの場合、明示的に設定することになるでしょう。
上記の例でタイトルを設定しなかった場合、合本のタイトルは最初の本のタイトル、つまり「藪の中」になります。

以下は、少し凝った例です。

    my $book = Aozora2Epub->new();
    $book->title('春夏秋冬料理王国');

    # 青空文庫の本のタイトルは "「春夏秋冬　料理王国」序にかえて" なので、タイトルを変更する
    $book->append("001403/card59653.html", title=>'序にかえて');

    $book->append(q{<h1 class="tobira">料理する心</h1>}); # 中扉を入れる
    $book->append("001403/card54984.html"); # 道は次第に狭し
    $book->append("001403/card50009.html"); # 料理の第一歩
    $book->append(q{<h1 class="tobira">お茶漬の味</h1>});   # 中扉を入れる
    $book->append("001403/card54975.html"); # 納豆の茶漬
    $book->append("001403/card54976.html"); # 海苔の茶漬

    # 青空文庫の本のタイトルは "小生のあけくれ" なので変更する。
    # 「お茶漬の味」のサブセクションにならない様に title_level も指定する
    $book->append("001403/card49981.html", title=>'あとがき',
                  title_level=>1);
    $book->to_epub;

上記のコードは、6冊の本から合本を作り、以下の目次構造のEPUBを出力します。

    序にかえて
    料理する心
      道は次第に狭し
      料理の第一歩
    お茶漬の味
      納豆の茶漬け
      海苔
    あとがき

「料理する心」を中扉にせず、「道は次第に狭し」と同じページにいれるには、上記のコードの

    $book->append(q{<h1 class="tobira">料理する心</h1>}); # 中扉を入れる
    $book->append("001403/card54984.html"); # 道は次第に狭し

の部分を以下のように変更します。

    $book->append("001403/card54984.html",
                  title_html=>q{<h1>料理する心</h1><h2>道は次第に狭し</h2>});

# 青空文庫ファイルのキャッシュ

青空文庫からファイルを取得する際に、`~/.aozora2epub` にキャッシュします。
これは環境変数 `AOZORA2EPUB_CACHE` で指定したディレクトリに変更することができます。

キャッシュされたファイルは30日間有効で、それを過ぎると自動的に削除されます。

# AUTHOR

Yoshimasa Ueno <saltyduck@gmail.com>

# COPYRIGHT

Copyright 2024- Yoshimasa Ueno

# LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

# SEE ALSO

[aozora2epub](https://metacpan.org/pod/aozora2epub)

[青空文庫](https://www.aozora.gr.jp/)
