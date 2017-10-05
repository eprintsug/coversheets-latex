package EPrints::Plugin::Coverpage;

#
# $Id: Coverpage.pm 16839 2011-04-19 12:32:36Z bergolth $
# $URL: https://svn.wu.ac.at/repo/bach/trunk/epub/coverpage-plugin/cfg/plugins/EPrints/Plugin/Coverpage.pm $
#

use strict;
use warnings;
use Scalar::Util;

our @ISA = qw/ EPrints::Plugin /;

sub new {
  my( $class, %opts ) = @_;
  my $self = $class->SUPER::new( %opts );
  $self->{name} = "Coverpage";
  return $self;
}

sub _get_coverpages {
  my ($self, $doc) = @_;
  my @relations = (EPrints::Utils::make_relation('hasCoverPageVersion'), );
  # EPrints::Utils::make_relation( "hasVolatileVersion")
  return @{$doc->get_related_objects(@relations)};
}

sub get_coverpage {
  my ($self, $doc) = @_;
  my @cpages = $self->_get_coverpages($doc);
  if (@cpages == 0) {
    $self->log("No CP found for doc id ".$doc->get_id());
  } elsif (@cpages > 1) {
    $self->log("More than one CP found for doc id ".
			       $doc->get_id());
  }
  return $cpages[0];
};

sub doc_type_supported { shift->get_conversion_plugin( @_ ) }

sub get_conversion_plugin {
  my ($self, $doc) = @_;
  my $convert = $self->{'repository'}->plugin('Convert');
  my %handler = $convert->can_convert($doc, 'coverpage');
  unless (%handler) {
    return undef;
  }
  return $handler{'coverpage'}{'plugin'};
}

sub make_coverpage {
  my ($self, $doc, %opts) = @_;
  my $repo = $self->{'repository'};

  my $c_plugin = $self->get_conversion_plugin($doc);
  unless ($c_plugin) {
    $self->log("no convert handler for coverpage (doc name: ".
	       $doc->get_main().", type: ".$doc->get_type.") found!");
    return undef;
  }

  if (exists $opts{'coverpage_template'}) {
    $c_plugin->set_content_template($opts{'coverpage_template'});
  }

  # use $doc->get_type since a coverpage convert plugin will not change the type
  my $cpdoc = $c_plugin->convert($doc->get_parent, $doc, $doc->get_type);
  if ($cpdoc) {
    $doc->add_object_relations($cpdoc,
			       EPrints::Utils::make_relation( "hasCoverPageVersion" ) =>
			       EPrints::Utils::make_relation( "isCoverPageVersionOf" ));
    $cpdoc->commit;
    $doc->commit;
    # $doc->commit also triggers a $eprint->commit
    # fake the mtime of the coverpage to be at least the lastmod time of the eprint
    my $cpfile = $cpdoc->get_stored_file($cpdoc->get_main);
    my $eprint = $doc->get_parent();
    if ($cpfile && $eprint) {
      $cpfile->set_value('mtime', $eprint->get_value('lastmod'));
      $cpfile->commit;
    }
  } else {
    $self->log("Unable to convert document!");
  }
  
  return $cpdoc;
};

sub remove_coverpage {
  my ($self, $doc, @cpages) = @_;
  unless (@cpages) {
    @cpages = $self->_get_coverpages($doc);
  }
  for my $cp (@cpages) {
    $self->log("Removing CP id ".$cp->get_id().
			       " from doc id ".$doc->get_id());
    $doc->remove_object_relations($cp);
    $cp->remove();
  }
  $doc->commit();
}

sub replace_coverpage {
  my ($self, $doc) = @_;
  $self->remove_coverpage($doc);
  return $self->make_coverpage($doc);
}

sub is_current {
  my ($self, $doc, $cp) = @_;
  my $repo = $self->{'repository'};

  unless ($cp) {
    $cp = $self->get_coverpage($doc);
  }
  unless ($cp) {
    return 0;
  }

  my $doc_mtime = $self->get_doc_main_file_mtime($doc);
  unless ($doc_mtime) {
    $self->log("Unable to get mtime of the documents main file!");
    return undef;
  }

  my $eprint = $doc->get_parent();
  my $ep_lastmod = 0;
  if ($eprint) {
    my $lastmod = $eprint->get_value('lastmod');
    if ($lastmod) {
      $ep_lastmod = EPrints::Time::datestring_to_timet($repo, $lastmod);
    }
  }

  my $cp_mtime = $self->get_doc_main_file_mtime($cp);
  if ($doc_mtime < $cp_mtime &&
      $ep_lastmod <= $cp_mtime) {
    $self->log("CP is current.");
    return 1;
  } else {
    $self->log("CP needs to be updated.");
    return 0;
  }
}

sub get_current_coverpage {
  my ($self, $doc) = @_;
  my $repo = $self->{'repository'};
  my $cp = $self->get_coverpage($doc);
  my $is_current;
  if ($cp) {
    $is_current = $self->is_current($doc, $cp);
    unless (defined $is_current) {
      return undef;
    }
  }
  unless ($cp && $is_current) {
    $cp = $self->replace_coverpage($doc);
  }
  return $cp;
}

sub get_doc_main_file_mtime {
  my ($self, $doc) = @_;
  my $file = $doc->get_stored_file($doc->get_main);
  unless ($file) {
    return undef;
  }
  my $mtime_str = $file->get_value('mtime');
  unless ($mtime_str) {
    return undef;
  }
  return EPrints::Time::datestring_to_timet(undef, $mtime_str);
}

sub log {
  my $self = shift;
  $self->{'repository'}->log('['.$self->{'id'}."]: @_");
}
