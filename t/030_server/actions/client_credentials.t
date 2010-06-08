use strict;
use warnings;

use lib 't/lib';
use Test::More tests => 16;

use Plack::Request;
use Try::Tiny;
use TestDataHandler;
use OAuth::Lite2::Server::Context;
use OAuth::Lite2::Server::Action::Token::ClientCredentials;
use OAuth::Lite2::Util qw(build_content);

TestDataHandler->add_client(id => q{foo}, secret => q{bar});
my $dh = TestDataHandler->new;

my $auth_info = $dh->create_or_update_auth_info(
    client_id => q{foo},
    user_id   => q{1},
    scope     => q{email},
);

is($auth_info->refresh_token, "refresh_token_0");

my $action = OAuth::Lite2::Server::Action::Token::ClientCredentials->new;

sub test_success {
    my $params = shift;
    my $expected = shift;
    my $request = Plack::Request->new({
        REQUEST_URI    => q{http://example.org/resource},
        REQUEST_METHOD => q{GET},
        QUERY_STRING   => build_content($params),
    });
    my $ctx = OAuth::Lite2::Server::Context->new({
        request      => $request,
        data_handler => $dh,
    });
    my $res; try {
        $res = $action->handle_request($ctx);
    } catch {
        my $error_message = ($_->isa("OAuth::Lite2::Error"))
            ? $_->message : $_;
    };

    if(exists $expected->{token}) {
        is($res->{access_token}, $expected->{token});
    } else {
        ok(!$res->{access_token});
    }

    if(exists $expected->{secret}) {
        is($res->{access_token_secret}, $expected->{secret});
    } else {
        ok(!$res->{access_token_secret});
    }

    if(exists $expected->{expires_in}) {
        is($res->{expires_in}, $expected->{expires_in});
    } else {
        ok(!$res->{expires_in});
    }

    if(exists $expected->{refresh_token}) {
        is($res->{refresh_token}, $expected->{refresh_token});
    } else {
        ok(!$res->{refresh_token});
    }

    if(exists $expected->{secret_type}) {
        is($res->{secret_type}, $expected->{secret_type});
    } else {
        ok(!$res->{secret_type});
    }

}

sub test_error {
    my $params = shift;
    my $message = shift;
    my $request = Plack::Request->new({
        REQUEST_URI    => q{http://example.org/resource},
        REQUEST_METHOD => q{GET},
        QUERY_STRING   => build_content($params),
    });
    my $ctx = OAuth::Lite2::Server::Context->new({
        request      => $request,
        data_handler => $dh,
    });
    my $error_message; try {
        my $res = $action->handle_request($ctx);
    } catch {
        $error_message = ($_->isa("OAuth::Lite2::Error"))
            ? $_->message : $_;
    };

    like($error_message, qr/$message/);
}

# no client id
&test_error({
    client_secret => q{bar},
}, q{'client_id' not found});

# no client secret
&test_error({
    client_id     => q{foo},
}, q{'client_secret' not found});

# invalid client_id
&test_error({
    client_id     => q{unknown},
    client_secret => q{bar},
}, q{invalid_client});

# invalid client_secret
&test_error({
    client_id     => q{foo},
    client_secret => q{unknown},
}, q{invalid_client});

# invalid secret type
&test_error({
    client_id     => q{foo},
    client_secret => q{bar},
    secret_type   => q{hmac-sha1},
}, q{unsupported_secret_type});

# without secret type
&test_success({
    client_id     => q{foo},
    client_secret => q{bar},
}, {
    token         => q{access_token_1},
    expires_in    => q{3600},
    refresh_token => q{refresh_token_2},
});

# secret type
&test_success({
    client_id     => q{foo},
    client_secret => q{bar},
    secret_type   => q{hmac-sha256},
}, {
    token         => q{access_token_2},
    secret        => q{access_token_secret_2},
    secret_type   => q{hmac-sha256},
    expires_in    => q{3600},
    refresh_token => q{refresh_token_3},
});

# TODO transaction?
