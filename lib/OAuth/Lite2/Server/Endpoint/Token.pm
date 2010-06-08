package OAuth::Lite2::Server::Endpoint::Token;

use strict;
use warnings;

use overload
    q(&{})   => sub { shift->psgi_app },
    fallback => 1;

use Plack::Request;
use Try::Tiny;
use Params::Validate;

use OAuth::Lite2::Server::Action::Token::Refresh;
use OAuth::Lite2::Server::Flows;
use OAuth::Lite2::Server::Context;
use OAuth::Lite2::Formatters;
use OAuth::Lite2::Error;

sub new {
    my $class = shift;
    my %args = Params::Validate::validate(@_, {
        data_handler => 1
    });
    my $self = bless {
        flow_actions => {},
        data_handler => $args{data_handler},
    }, $class;
    $self->{flow_actions}{refresh} =
        OAuth::Lite2::Server::Action::Token::Refresh->new;
    return $self;
}

sub data_handler {
    my ($self, $handler) = @_;
    $self->{data_handler} = $handler if $handler;
    $self->{data_handler};
}

sub support_flow {
    my ($self, $flow_name) = @_;
    my $flow = OAuth::Lite2::Server::Flows->get_flow($flow_name);
    return unless $flow;
    my $actions = $flow->token_endpoint_actions;
    for my $action_name ( @$actions ) {
        $self->{flow_actions}{$action_name} =
            $flow->get_token_endpoint_action($action_name);
    }
}

sub support_flows {
    my ($self, @flow_names) = @_;
    $self->support_flow($_) for @flow_names;
}

sub psgi_app {
    my $self = shift;
    return $self->{psgi_app}
        ||= $self->compile_psgi_app;
}

sub compile_psgi_app {
    my $self = shift;

    my $app = sub {
        my $env = shift;
        my $req = Plack::Request->new($env);
        my $res; try {
            $res = $self->handle_request($req);
        } catch {
            # Internal Server Error
            warn $_;
            $res = $req->new_response(500);
        };
        return $res->finalize;
    };

    return $app;
}

sub handle_request {
    my ($self, $request) = @_;

    my $format = $request->param("format") || "json";
    my $formatter = OAuth::Lite2::Formatters->get_formatter_by_name($format)
        || OAuth::Lite2::Formatters->get_formatter_by_name("json");

    my $res = try {

    my $type = $request->param("type");

    OAuth::Lite2::Error::Server::MissingParam->throw(
        message => "'type' not found"
    ) unless $type;

    my $data_handler = $self->{data_handler}->new;

    my $ctx = OAuth::Lite2::Server::Context->new({
        request      => $request,
        data_handler => $data_handler,
    });

    my $action = $self->{flow_actions}{$type};
    OAuth::Lite2::Error::Server::UnsupportedType->throw(
        message => sprintf(q{unsupported type, "%s"}, $type) )
        unless $action;

    # TODO:
    # $data_handler->validate_client_action($type, $request->param("client_id"))
    #     or OAuth::Lite2::Error::Server::InvalidClientAction->throw;

    my $result = $action->handle_request($ctx);

    return $request->new_response(200,
        [ "Content-Type"  => $formatter->type,
          "Cache-Control" => "no-store"  ],
        [ $formatter->format($result) ]);

    } catch {

    if ($_->isa("OAuth::Lite2::Error::Server")) {

        return $request->new_response(401,
            [ "Content-Type"  => $formatter->type,
              "Cache-Control" => "no-store"  ],
            [ $formatter->format({ error => $_->message }) ]);

    } else {

        die $_;

    }

    };
}

1;
