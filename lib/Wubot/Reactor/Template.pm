package Wubot::Reactor::Template;
use Moose;

# VERSION

use Log::Log4perl;
use Text::Template;
use YAML;

has 'logger'  => ( is => 'ro',
                   isa => 'Log::Log4perl::Logger',
                   lazy => 1,
                   default => sub {
                       return Log::Log4perl::get_logger( __PACKAGE__ );
                   },
               );


sub react {
    my ( $self, $message, $config ) = @_;

    my $template_contents;

    if ( $config->{source_field} ) {
        return $message unless $message->{ $config->{source_field} };
        $template_contents = $message->{ $config->{source_field} };
    }
    elsif ( $config->{template} ) {
        $template_contents = $config->{template};
    }
    elsif ( $config->{template_file} ) {
        return $message unless $config->{template_file};

        open(my $fh, "<", $config->{template_file})
            or die "Couldn't open $config->{template_file} for reading: $!\n";
        local undef $/;
        $template_contents = <$fh>;
        close $fh or die "Error closing file: $!\n";

    }
    else {
        $self->logger->error( "ERROR: Template reactor: no template specified" );
        return $message;
    }

    my $template = Text::Template->new(TYPE => 'STRING', SOURCE => $template_contents );

    unless ( $config->{target_field} ) {
        $self->logger->error( "ERROR: template reactor: no target_field specified" );
        return $message;
    }

    $message->{ $config->{target_field} } = $template->fill_in( HASH => $message );

    return $message;
}

1;
