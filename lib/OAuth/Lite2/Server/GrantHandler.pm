package OAuth::Lite2::Server::GrantHandler;

use strict;
use warnings;

sub new {
    my $class = shift;
    bless {}, $class;
}

sub handle_request {
    my ($self, $data_handler) = @_;
    die "abstract method";
}

=head1 NAME

OAuth::Lite2::Server::GrantHandler - base class of each grant_type handler

=head1 SYNOPSIS

    my $handler = OAuth::Lite2::Server::GrantHandler->new;
    my $res = $handler->handle_request( $ctx );

=head1 METHODS

=head2 new

Constructor

=head2 handle_request( $data_handler )

processes passed L<OAuth::Lite2::Server::DataHandler>, and return
hash represents that includes response-parameters.

    my $res = $handler->handle_request( $data_handler );

=head1 SEE ALSO

L<OAuth::Lite2::Server::GrantHandlers>
L<OAuth::Lite2::Server::GrantHandler::AuthorizationCode>
L<OAuth::Lite2::Server::GrantHandler::Password>
L<OAuth::Lite2::Server::GrantHandler::RefreshToken>

=head1 AUTHOR

Lyo Kato, E<lt>lyo.kato@gmail.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2010 by Lyo Kato

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.8 or,
at your option, any later version of Perl 5 you may have available.

=cut

1;
