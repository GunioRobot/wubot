package Wubot::Reactor::TransformField;
use Moose;

# VERSION

use YAML;

use Wubot::Logger;

sub react {
    my ( $self, $message, $config ) = @_;

    my $text = $message->{ $config->{source_field } };

    my $regexp_search = $config->{regexp_search};
    return $message unless $regexp_search;

    my $regexp_replace = exists $config->{regexp_replace} ? $config->{regexp_replace} : "";

    my @items = ( $text =~ /$regexp_search/g );

    $text =~ s|$regexp_search|$regexp_replace|eg;

    for( reverse 0 .. $#items ){ 
        my $n = $_ + 1; 
        $text =~ s/\\$n/${items[$_]}/g ;
        $text =~ s/\$$n/${items[$_]}/g ;
    }

    $message->{ $config->{target_field}||$config->{source_field} } = $text;

    return $message;
}

1;

__END__

=head1 NAME

Wubot::Reactor::TransformField - use a regexps to transform the data in a field

=head1 DESCRIPTION

TODO: More to come...


=head1 SUBROUTINES/METHODS

=over 8

=item react( $message, $config )

The standard reactor plugin react() method.

=back
