requires 'HTML::Escape';
requires 'HTTP::Tiny';
requires 'Cache::FileCache';
requires 'Text::Xslate';
requires 'File::ShareDir';
requires 'Path::Tiny';
requires 'UUID';
requires 'Archive::Zip';
requires 'HTML::TreeBuilder::XPath';
requires 'HTML::Selector::XPath';

on test => sub {
    requires 'Test::More', '0.96';
    requires 'Test::Base';
};
