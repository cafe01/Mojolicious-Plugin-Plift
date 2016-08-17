package Mojolicious::Plugin::Plift;

use Mojo::Base 'Mojolicious::Plugin';
use Plift;
use Mojo::Util qw/decode/;

our $VERSION = "0.01";

__PACKAGE__->attr([qw/ plift config /]);


sub register {
    my ( $self, $app, $config ) = @_;

    $self->config($config || {});
    $self->plift($self->_build_plift($config));

    $app->helper( plift => sub { $self->plift });

    $app->renderer->add_handler(
        plift => sub { $self->_render(@_) }
    );
}


sub snippet_namespaces {
    my ($self, $c) = @_;

    $c->stash->{'plift.snippet_namespaces'}
        || $self->config->{'snippet_namespaces'}
        || [(ref $c->app).'::Snippet'];
}


sub _render {
    my ( $self, $renderer, $c, $output, $options ) = @_;

    # setup plift
    my $plift = $self->plift;
    $plift->paths( $renderer->paths );

    my $template =
        defined $options->{inline} ?  \($options->{inline})
        : defined $options->{template} && $plift->has_template($options->{template}) ? $options->{template}
        : \($renderer->get_data_template($options));

    # TODO prevent render deep recursion when for exception pages when plift
    # is the default handler
    return unless defined $template;
    return if ref $template && !defined $$template;

    # resolve data
    my $stash = $c->stash;
    my $data_key = $stash->{'plift.data_key'} || $self->config->{data_key};
    my $data = defined $data_key ? $stash->{$data_key} : $stash;

    my $plift_tpl = $plift->template($template, {
        encoding => $renderer->encoding,
        paths    => $renderer->paths,
        helper   => $c,
        data     => $data,
        snippet_namespaces => $self->snippet_namespaces($c)
    });

    # metadata
    my $metadata = $plift_tpl->metadata;
    delete $metadata->{layout}; # special key

    # render
    my $document = $plift_tpl->render;

    # meta.layout
    $stash->{layout} = $metadata->{layout}
        if defined $metadata->{layout};

    # insert inner content
    if (defined $stash->{'mojo.content'}->{content}) {

        my $wrapper_selector = $stash->{'plift.wrapper_selector'}
            || $self->config->{wrapper_selector} || '#content';

        $document->find($wrapper_selector)
                 ->append($stash->{'mojo.content'}->{content});
    }

    # pass the rendered result back to the renderer
    $$output = defined $c->res->body && length $c->res->body
        ? $c->res->body : decode 'UTF-8', $document->as_html;
}


sub _build_plift {
    my $self = shift;
    my $cfg = $self->config;

    my $plift = Plift->new(
        plugins => $cfg->{plugins} || []
    );

    # x-link
    $plift->add_handler({
        name => 'link-tag',
        tag => 'x-link',
        handler => sub {
            my ($el, $c) = @_;
            my $node = $el->get(0);
            my $path;

            if ($node->hasAttribute('to')) {

                $path = $node->getAttribute('to');
                $node->removeAttribute('to');
            }

            $node->setAttribute('href', $c->url_for($path));
            $node->setNodeName('a');
        }
    });

    # x-csrf-field
    $plift->add_handler({
        name => 'csrf-field-tag',
        tag => 'x-csrf-field',
        handler => sub {
            my ($el, $c) = @_;
            my $node = $el->get(0);

            $node->setNodeName('input');
            $node->setAttribute('value', $c->helper->csrf_token) ;
            $node->setAttribute('type', 'hidden') ;
            $node->setAttribute('name', 'csrf_token')
                unless $node->hasAttribute('name');
        }
    });


    $plift;
}



1;
__END__

=encoding utf-8

=head1 NAME

Mojolicious::Plugin::Plift - Plift ♥ Mojolicious

=head1 SYNOPSIS

    use Mojolicious::Lite;

    plugin 'Plift';

=head1 DESCRIPTION

Mojolicious::Plugin::Plift is ...

=head1 LICENSE

Copyright (C) Carlos Fernando Avila Gratz.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

Carlos Fernando Avila Gratz E<lt>cafe@kreato.com.brE<gt>

=cut
