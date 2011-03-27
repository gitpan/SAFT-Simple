package SAFT::Simple;

use warnings;
use strict;
use utf8;
use Carp;

use 5.010;

use version; our $VERSION = qv('1.0.0');

use XML::LibXML;


# Objects of this class have the following attributes:
#
# doc                   - a XML::LibXML::Document, holding the SAFT XML
#                         document
# root                  - a XML::LibXML::Element, holding doc's root element
# classification        - a cache for the classification nodes, where
#                         $self->{classification}->{$branch_number}->[0]
#                         contains a reference to <Klassifikation>, and
#                         $self->{classification}->{$branch_number}->[1]
#                         contains a reference to <Verzeichnungseinheiten>


sub new {
    my $class  = shift;
    my $infile = shift;
    my $self   = {};
    bless $self, $class;

    # load or initialize XML document
    # TODO check if everything works when loading an existing file!
    if ($infile) {
        $self->{doc} = XML::LibXML->new()->parse_file($infile);
        $self->{root} = $self->{doc}->documentElement();
        # TODO initialize classification cache (and other stuff?)
    }
    else {
        $self->{doc} = XML::LibXML::Document->new('1.0', 'UTF-8');
        $self->{doc}->createInternalSubset('Findmittel', undef, 'SAFT.dtd');
        $self->{root} = XML::LibXML::Element->new('Findmittel');
        $self->{doc}->setDocumentElement($self->{root});
        $self->set_creation_date(scalar localtime);
    }

    return $self;
}


sub add_classification {
    my $self          = shift;
    my $branch_number = shift;
    my $branch_title  = shift;

    # parameter error checking
    croak "E: Can't understand format of branch number '$branch_number'"
        if $branch_number !~ m{ ^ [1-9] \d* (?: \. [1-9] \d* )* $ }x;
    
    # analyze branch number
    my @branch_number_parts  = split /\./, $branch_number;
    my $branch_level         = scalar @branch_number_parts;
    my $own_branch_number    = pop @branch_number_parts;
    my $parent_branch_number = join '.', @branch_number_parts;

    if ($branch_level > 10) {
        carp "W: Nested classification with more than 10 levels is not "
           . "allowed by SAFT DTD";
    }
    elsif ($branch_level < 10) {
        $branch_level = "0$branch_level";
    }

    # check if a valid entry for this branch number already exists
    if (defined $self->{classification}->{$branch_number}) {
        my ($existing_title)
            = $self->_get_text_node(
                $self->{classification}->{$branch_number}->[0],
                q(Klass_Titel)
            );

        if ($existing_title eq '') {
            # suppose the existing branch was created (automatically) without
            # a proper title, and adjust that
            $self->set_classification_title($branch_number, $branch_title);
            return;
        }
        elsif ($existing_title eq $branch_title) {
            # suppose the branch we try to create here already exists
            carp "W: Branch $branch_number '$branch_title' already exists, "
               . "repeated attempt to create it was ignored";
            return;
        }
        else {
            croak "E: Can't add classification branch $branch_number "
            . "'$branch_title' - a classification branch with the same "
            . "number already exists";
        }
    }

    # find the new classification branch's parent branch
    my $parent_node;
    if (!$parent_branch_number) {
        $parent_node = $self->{root};
    }
    else {
        # check if we have a cache entry for the parent branch
        if (!defined $self->{classification}->{$parent_branch_number}) {
            # implicitly create one with an empty title
            $self->add_classification($parent_branch_number, '');
        }
        $parent_node
            = $self->{classification}->{$parent_branch_number}->[0];
    }

    # create the new classification branch
    my $new_branch = XML::LibXML::Element->new('Klassifikation');
    $new_branch->setAttribute(    level       => $branch_level  );
    $new_branch->appendTextChild( Klass_Nr    => $branch_number );
    $new_branch->appendTextChild( Klass_Titel => $branch_title  );

    # find a place to append the new classification branch...
    my $closest_predecessor;
    $parent_branch_number .= '.' if $parent_branch_number;
    for (my $i = $own_branch_number - 1; $i > 0; $i--) {
        if (defined $self->{classification}->{"$parent_branch_number$i"}) {
            $closest_predecessor
                = $self->{classification}->{"$parent_branch_number$i"}->[0];
            last;
        }
    }

    # ... and put it there
    if ($closest_predecessor) {
        $parent_node->insertAfter( $new_branch, $closest_predecessor );
    }
    else { # no predecessor found in cache
        no warnings qw(uninitialized);
        my ($closest_successor) = $parent_node->findnodes('Klassifikation');
        $parent_node->insertBefore( $new_branch, $closest_successor );
    }

    # remember a reference to the new classification branch
    $self->{classification}->{$branch_number}->[0] = $new_branch;

    # remember where to append records under the new classification branch
    $self->{classification}->{$branch_number}->[1]
        = $new_branch->appendChild(
            XML::LibXML::Element->new('Verzeichnungseinheiten')
        );
    
    return;
}


sub set_classification_title {
    my $self             = shift;
    my $branch_number    = shift;
    my $new_branch_title = shift;

    # check if we have a cache entry for this classification branch
    if (defined $self->{classification}->{$branch_number}) {
        $self->_set_text_node(
            $self->{classification}->{$branch_number}->[0],
            q(Klass_Titel),
            $new_branch_title
        );
    }
    else {
        croak "E: Can't set title of nonexisting classification branch number "
            . "$branch_number. To create a new branch use add_classification";
    }

    return;
}


sub set_creation_date {
    my $self          = shift;
    my $creation_date = shift;

    $self->_set_text_node(
        $self->{root},
        q(Datei_Info/Erstellung/Datum),
        $creation_date
    );

    return;
}


sub get_creation_date {
    my $self = shift;

    my ($creation_date) = $self->_get_text_node(
        $self->{root},
        q(Datei_Info/Erstellung/Datum)
    );

    return $creation_date ? $creation_date : '';
}


sub set_author {
    my $self   = shift;
    my $author = shift;

    $self->_set_text_node(
        $self->{root},
        q(Datei_Info/Erstellung/Bearbeiter),
        $author
    );

    return;
}


sub get_author {
    my $self = shift;

    my ($author) = $self->_get_text_node(
        $self->{root},
        q(Datei_Info/Erstellung/Bearbeiter)
    );

    return $author ? $author : '';
}


sub set_filename {
    my $self     = shift;
    my $filename = shift;

    $self->_set_text_node(
        $self->{root},
        q(Datei_Info/Dateiname),
        $filename
    );

    return;
}


sub get_filename {
    my $self = shift;

    my ($filename) = $self->_get_text_node(
        $self->{root},
        q(Datei_Info/Dateiname)
    );

    return $filename ? $filename : '';
}


sub set_finding_aid_title {
    my $self  = shift;
    my $title = shift;

    $self->_set_text_node(
        $self->{root},
        q(Findmittel_Info/FM_Name),
        $title
    );

    return;
}


sub get_finding_aid_title {
    my $self = shift;

    my ($title) = $self->_get_text_node(
        $self->{root},
        q(Findmittel_Info/FM_Name)
    );

    return $title ? $title : '';
}


sub set_finding_aid_id {
    my $self = shift;
    my $id   = shift;

    $self->_set_text_node(
        $self->{root},
        q(Findmittel_Info/FM_Sig),
        $id
    );

    return;
}


sub get_finding_aid_id {
    my $self = shift;

    my ($id) = $self->_get_text_node(
        $self->{root},
        q(Findmittel_Info/FM_Sig)
    );

    return $id ? $id : '';
}


sub set_abstract {
    my $self     = shift;
    my $abstract = shift;

    $self->_set_text_node(
        $self->{root},
        q(Findmittel_Info/Einleitung/Text),
        $abstract
    );

    return;
}


sub get_abstract {
    my $self = shift;

    my ($abstract) = $self->_get_text_node(
        $self->{root},
        q(Findmittel_Info/Einleitung/Text)
    );

    return $abstract ? $abstract : '';
}


sub set_finding_aid_note {
    my $self = shift;
    my $note = shift;

    $self->_set_text_node(
        $self->{root},
        q(Findmittel_Info/Bem),
        $note
    );

    return;
}


sub get_finding_aid_note {
    my $self = shift;

    my ($note) = $self->_get_text_node(
        $self->{root},
        q(Findmittel_Info/Bem)
    );

    return $note ? $note : '';
}


sub set_unit_title {
    my $self  = shift;
    my $title = shift;

    $self->_set_text_node(
        $self->{root},
        q(Findmittel_Info/Bestand_Info/Bestandsname),
        $title
    );

    return;
}


sub get_unit_title {
    my $self = shift;

    my ($title) = $self->_get_text_node(
        $self->{root},
        q(Findmittel_Info/Bestand_Info/Bestandsname)
    );

    return $title ? $title : '';
}


sub set_unit_id {
    my $self = shift;
    my $id   = shift;

    $self->_set_text_node(
        $self->{root},
        q(Findmittel_Info/Bestand_Info/Bestand_Sig),
        $id
    );

    return;
}


sub get_unit_id {
    my $self = shift;

    my ($id) = $self->_get_text_node(
        $self->{root},
        q(Findmittel_Info/Bestand_Info/Bestand_Sig)
    );

    return $id ? $id : '';
}


sub set_unit_date {
    my $self = shift;
    my $date = shift;

    $self->_set_text_node(
        $self->{root},
        q(Findmittel_Info/Bestand_Info/Laufzeit/LZ_Text),
        $date
    );

    $self->_set_text_node(
        $self->{root},
        q(Findmittel_Info/Laufzeit/LZ_Text),
        $date
    );

    return;
}


sub get_unit_date {
    my $self = shift;

    my ($date) = $self->_get_text_node(
        $self->{root},
        q(Findmittel_Info/Bestand_Info/Laufzeit/LZ_Text)
    );

    return $date ? $date : '';
}


sub add_file_sachakte {
    my $self           = shift;
    my $classification = shift;
    my $subelem_ref    = shift;

    # create the new file element
    my $file = XML::LibXML::Element->new('Sachakte');

    # add file's sub-elements
    if (defined $subelem_ref->{Signatur}) {
        $file->appendTextChild( Signatur => $subelem_ref->{Signatur} );
    }
    else {
        carp "W: Missing entry or value for element 'Signatur'";
    }

    if (defined $subelem_ref->{Laufzeit}) {
        my $elem = XML::LibXML::Element->new('Laufzeit');
        $elem->appendTextChild( LZ_Text => $subelem_ref->{Laufzeit} );
        $file->appendChild($elem);
    }

    if (defined $subelem_ref->{Titel}) {
        $file->appendTextChild( Titel => $subelem_ref->{Titel} );
    }
    else {
        carp "W: Missing entry or value for element 'Titel' "
           . "(Signatur $subelem_ref->{Signatur})";
    }

    if (defined $subelem_ref->{Enthaelt}) {
        $file->appendTextChild( Enthaelt => $subelem_ref->{Enthaelt} );
    }

    $self->_append_entity_ve_option($file, $subelem_ref);

    if (defined $subelem_ref->{Nr}) {
        $file->appendTextChild( Nr => $subelem_ref->{Nr} );
    }

    if (defined $subelem_ref->{Az}) {
        $file->appendTextChild( Az => $subelem_ref->{Az} );
    }

    # find the file's classification branch and append it
    $self->_append_file_to_classification($file, $classification);

    return;
}


sub add_file_fallakte {
    my $self           = shift;
    my $classification = shift;
    my $subelem_ref    = shift;

    # create the new file element
    my $file = XML::LibXML::Element->new('Fallakte');

    # add (some of) file element's attributes
    if (defined $subelem_ref->{FA_Art}) {
        $file->setAttribute( FA_Art => $subelem_ref->{FA_Art} );
    }

    # add file's sub-elements
    if (defined $subelem_ref->{Signatur}) {
        $file->appendTextChild( Signatur => $subelem_ref->{Signatur} );
    }
    else {
        carp "W: Missing entry or value for element 'Signatur'";
    }

    if (defined $subelem_ref->{Laufzeit}) {
        my $elem = XML::LibXML::Element->new('Laufzeit');
        $elem->appendTextChild( LZ_Text => $subelem_ref->{Laufzeit} );
        $file->appendChild($elem);
    }

    if (defined $subelem_ref->{Titel}) {
        $file->appendTextChild( Titel => $subelem_ref->{Titel} );
    }

    if (defined $subelem_ref->{Enthaelt}) {
        $file->appendTextChild( Enthaelt => $subelem_ref->{Enthaelt} );
    }

    $self->_append_entity_ve_option($file, $subelem_ref);

    if (defined $subelem_ref->{Person}) {
        $self->_append_element_person(
            $file, $subelem_ref->{Person}
        );
    }

    if (defined $subelem_ref->{Institution}) {
        $file->appendTextChild(
            Institution => $subelem_ref->{Institution}
        );
    }

    if (defined $subelem_ref->{Sachverhalt}) {
        $file->appendTextChild(
            Sachverhalt => $subelem_ref->{Sachverhalt}
        );
    }

    if (defined $subelem_ref->{Datum}) {
        $self->_append_element_datum(
            $file, $subelem_ref->{Datum}
        );
    }

    if (defined $subelem_ref->{Nr}) {
        $file->appendTextChild(
            Nr => $subelem_ref->{Nr}
        );
    }

    if (defined $subelem_ref->{Ort}) {
        $self->_append_element_ort(
            $file, $subelem_ref->{Ort}
        );
    }

    if (defined $subelem_ref->{Anschrift}) {
        $file->appendTextChild(
            Anschrift => $subelem_ref->{Anschrift}
        );
    }

    if (defined $subelem_ref->{Az}) {
        $file->appendTextChild(
            Az => $subelem_ref->{Az}
        );
    }

    if (defined $subelem_ref->{Prozessart}) {
        $file->appendTextChild(
            Prozessart => $subelem_ref->{Prozessart}
        );
    }

    if (defined $subelem_ref->{Instanz}) {
        $file->appendTextChild(
            Instanz => $subelem_ref->{Instanz}
        );
    }

    if (defined $subelem_ref->{Beweismittel}) {
        $file->appendTextChild(
            Beweismittel => $subelem_ref->{Beweismittel}
        );
    }

    if (defined $subelem_ref->{Formalbeschreibung}) {
        $file->appendTextChild(
            Formalbeschreibung => $subelem_ref->{Formalbeschreibung}
        );
    }

    # find the file's classification branch and append it
    $self->_append_file_to_classification($file, $classification);

    return;
}


sub to_string {
    my $self = shift;
    return $self->{doc}->toString(1);
}


sub to_file {
    my $self    = shift;
    my $outfile = shift;

    $self->set_filename($outfile);
    $self->{doc}->toFile($outfile, 1);

    return;
}


# purpose   :   set the content of an arbitrary text node
# arguments :   $base_node - a XML::LibXML::Node element, defining where to
#               start looking for the text node
#           :   $text_node_xpath - a XPath string, describing the path to the
#               text node relative to $base_node (this will only work with
#               rather simple XPath!)
#           :   $text_node_value - a string with the node's new value
# returns   :   nothing
# example   :   _set_text_node($root, q(Datei_Info/Dateiname), 'myfile.xml');
#               sets the content of 'Dateiname' to 'myfile.xml'
sub _set_text_node {
    my $self            = shift;
    my $base_node       = shift;
    my $text_node_xpath = shift;
    my $text_node_value = shift;
    my ($parent_xpath, $text_node_name)
        = $text_node_xpath =~ m{ ^ (?: (.*) / )? ( [^/]* ) $ }x;

    my $text_node = XML::LibXML::Element->new($text_node_name);
    $text_node->appendText($text_node_value);

    my @found_nodes = $base_node->findnodes($text_node_xpath);

    # replace existing node...
    if (@found_nodes) {
        # TODO we simply replace the first found node, is this really cool?!
        $found_nodes[0]->replaceNode($text_node);
    }
    # ... or create a new one (and its parents), if necessary
    else {
        my $parent_node
            = $self->_create_node_context($base_node, $parent_xpath);
        $parent_node->appendChild($text_node);
    }

    return;
}


# purpose   :   get the content of an arbitrary text node
# arguments :   $base_node - a XML::LibXML::Node element, defining where to
#               start looking for the text node
#           :   $text_node_xpath - a XPath string, describing the path to the
#               text node relative to $base_node
# returns   :   a list of the text contents of all nodes matching
#               $text_node_xpath relative to $base_node
# example   :   _get_text_node($root, q(Datei_Info/Dateiname));
#               returns the file name tagged in 'Dateiname' (as a one
#               element-list)
sub _get_text_node {
    my $self             = shift;
    my $base_node        = shift;
    my $text_node_xpath  = shift;
    my @text_node_values = ();

    my @found_nodes = $base_node->findnodes($text_node_xpath);

    for my $found_node (@found_nodes) {
        push @text_node_values, $found_node->textContent();
    }

    return @text_node_values;
}


# purpose   :   create a hierarchy of nodes
# arguments :   $base_node - a XML::LibXML::Node element, defining where to
#               append the node hierarchy
#           :   $xpath - a XPath string, describing the nodes below $base_node
# returns   :   the last node described by $xpath
# example   :   _create_node_context($root, q(Datei_Info/Dateiname));
#               returns the element named 'Dateiname', creates 'Datei_Info' if
#               it doesn't exist yet
sub _create_node_context {
    my $self           = shift;
    my $base_node      = shift;
    my $xpath          = shift;
    my @required_nodes = split /\//, $xpath;
    my $current_node   = $base_node;
    my $current_node_path;
    
    for my $current_node_name (@required_nodes) {
        $current_node_path .= $current_node_name;
        my $recent_node = $current_node;

        # find required node...
        $current_node = ($base_node->findnodes($current_node_path))[0];
        # ... or else create it
        if (!$current_node) {
            $current_node = XML::LibXML::Element->new($current_node_name);
            $recent_node->appendChild($current_node);
        }

        $current_node_path .= '/';
    }

    return $current_node;
}


# purpose   :   append a file to a classification
# arguments :   $file - a XML::LibXML::Element, representing the file
#           :   $classification - a string with the classification branch's
#               number
# returns   :   nothing
# example   :   _append_file_to_classification($file, '1.1');
#               appends $file to classification branch with numer 1.1
sub _append_file_to_classification {
    my $self           = shift;
    my $file           = shift;
    my $classification = shift;

    if (defined $self->{classification}->{$classification}) {
        my $classification_branch
            = $self->{classification}->{$classification}->[1];
        $classification_branch->appendChild($file);
    }
    else {
        croak "E: Can't find classification branch number "
            . "$classification to append file";
    }

    return;
}


# purpose   :   append the elements in the entity VE_Option to a file's
#               sub-elements
# arguments :   $file - a XML::LibXML::Element, representing the file
#           :   $subelem_ref - a hash reference containing the file's
#               sub-elements
# returns   :   nothing
# example   :   _append_entity_ve_option($file, $subelem_ref);
#               appends the relevant sub-elements if present in $subelem_ref
sub _append_entity_ve_option {
    my $self        = shift;
    my $file        = shift;
    my $subelem_ref = shift;

    if (defined $subelem_ref->{Bestellsig}) {
        $file->appendTextChild( Bestellsig => $subelem_ref->{Bestellsig} );
    }

    if (defined $subelem_ref->{Altsig}) {
        $file->appendTextChild( Altsig => $subelem_ref->{Altsig} );
    }

    if (defined $subelem_ref->{Provenienz}) {
        $file->appendTextChild( Provenienz => $subelem_ref->{Provenienz} );
    }

    if (defined $subelem_ref->{Vor_Prov}) {
        $file->appendTextChild( Vor_Prov => $subelem_ref->{Vor_Prov} );
    }

    if (defined $subelem_ref->{Abg_Stelle}) {
        $file->appendTextChild( Abg_Stelle => $subelem_ref->{Abg_Stelle} );
    }

    if (defined $subelem_ref->{Akzession}) {
        $file->appendTextChild( Akzession => $subelem_ref->{Akzession} );
    }

    if (defined $subelem_ref->{Sperrvermerk}) {
        $file->appendTextChild( Sperrvermerk => $subelem_ref->{Sperrvermerk} );
    }

    if (defined $subelem_ref->{Umfang}) {
        $file->appendTextChild( Umfang => $subelem_ref->{Umfang} );
    }

    if (defined $subelem_ref->{Lagerung}) {
        $file->appendTextChild( Lagerung => $subelem_ref->{Lagerung} );
    }

    if (defined $subelem_ref->{Zustand}) {
        $file->appendTextChild( Zustand => $subelem_ref->{Zustand} );
    }

    if (defined $subelem_ref->{FM_Seite}) {
        $file->appendTextChild( FM_Seite => $subelem_ref->{FM_Seite} );
    }

    if (defined $subelem_ref->{Bestand_Kurz}) {
        $file->appendTextChild(Bestand_Kurz => $subelem_ref->{Bestand_Kurz});
    }

    if (defined $subelem_ref->{Bem}) {
        $file->appendTextChild( Bem => $subelem_ref->{Bem} );
    }

    if (defined $subelem_ref->{Hilfsfeld}) {
        $file->appendTextChild( Hilfsfeld => $subelem_ref->{Hilfsfeld} );
    }

    if (defined $subelem_ref->{archref}) {
        $file->appendTextChild( archref => $subelem_ref->{archref} );
    }

    if (defined $subelem_ref->{bibref}) {
        $file->appendTextChild( bibref => $subelem_ref->{bibref} );
    }

    if (defined $subelem_ref->{FM_ref}) {
        $file->appendTextChild( FM_ref => $subelem_ref->{FM_ref} );
    }

    if (defined $subelem_ref->{'altübform'}) {
        $file->appendTextChild( 'altübform' => $subelem_ref->{'altübform'} );
    }

    if (defined $subelem_ref->{Register}) {
        $file->appendTextChild( Register => $subelem_ref->{Register} );
    }

    return;
}


# purpose   :   append a Datum element to an element's sub-elements
# arguments :   $parent - the XML::LibXML::Element where Datum should be
#               appended
#           :   $subelem_ref - a hash reference (or a string), containing
#               Datum's sub-elements
# returns   :   nothing
# example   :   _append_element_datum(
#                   $parent, { Dat_Fkt => 'Tod', Jahr => '2000' }
#               );
#               or: _append_element_datum('03.02.2000');
#               appends a Datum element with the given information to $parent
sub _append_element_datum {
    my $self        = shift;
    my $parent      = shift;
    my $subelem_ref = shift;

    my $date_elem = XML::LibXML::Element->new('Datum');
    $parent->appendChild($date_elem);

    if (ref $subelem_ref ne 'HASH') { # allow direct PCDATA
        $date_elem->appendText($subelem_ref);
    }
    else {
        if (defined $subelem_ref->{Dat_Fkt}) {
            $date_elem->setAttribute( Dat_Fkt => $subelem_ref->{Dat_Fkt} );
        }
        if (defined $subelem_ref->{Jahr}) {
            $date_elem->appendTextChild( Jahr => $subelem_ref->{Jahr} );
        }
        if (defined $subelem_ref->{Monat}) {
            $date_elem->appendTextChild( Monat => $subelem_ref->{Monat} );
        }
        if (defined $subelem_ref->{Tag}) {
            $date_elem->appendTextChild( Tag => $subelem_ref->{Tag} );
        }
        if (defined $subelem_ref->{PCDATA}) { # allow indirect PCDATA
            $date_elem->appendText($subelem_ref->{PCDATA});
        }
    }

    return;
}


# purpose   :   append a Ort element to an element's sub-elements
# arguments :   $parent - the XML::LibXML::Element where Ort should be
#               appended
#           :   $subelem_ref - a hash reference (or a string), containing
#               Ort's sub-elements
# returns   :   nothing
# example   :   _append_element_ort(
#                   $parent, { Ort_Fkt => Geburtsort, PCDATA => 'Moria' }
#               );
#               or: _append_element_ort('Moria');
#               appends a Ort element with the given information to $parent
sub _append_element_ort {
    my $self        = shift;
    my $parent      = shift;
    my $subelem_ref = shift;

    my $ort_elem = XML::LibXML::Element->new('Ort');
    $parent->appendChild($ort_elem);

    if (ref $subelem_ref ne 'HASH') { # allow direct PCDATA
        $ort_elem->appendText($subelem_ref);
    }
    else {
        if (defined $subelem_ref->{Ort_Fkt}) {
            $ort_elem->setAttribute( Ort_Fkt => $subelem_ref->{Ort_Fkt} );
        }
        if (defined $subelem_ref->{PCDATA}) { # allow indirect PCDATA
            $ort_elem->appendText($subelem_ref->{PCDATA});
        }
    }

    return;
}


# purpose   :   append a Person element to an element's sub-elements
# arguments :   $parent - the XML::LibXML::Element where Person should be
#               appended
#           :   $subelem_ref - a hash reference (or a string), containing
#               Person's sub-elements
# returns   :   nothing
# example   :   _append_element_person(
#                   $parent, { Pers_Name => 'Aragorn', Rang_Titel => 'King' }
#               );
sub _append_element_person {
    my $self        = shift;
    my $parent      = shift;
    my $subelem_ref = shift;

    my $pers_elem = XML::LibXML::Element->new('Person');
    $parent->appendChild($pers_elem);

    if (ref $subelem_ref ne 'HASH') { # allow direct PCDATA
        $pers_elem->appendText($subelem_ref);
    }
    else {
        # add the element's attributes
        if (defined $subelem_ref->{Pers_Fkt}) {
            $pers_elem->setAttribute( Pers_Fkt => $subelem_ref->{Pers_Fkt} );
        }

        if (defined $subelem_ref->{Fkt}) {
            $pers_elem->setAttribute( Fkt => $subelem_ref->{Fkt} );
        }

        # add the element's sub-elements
        if (defined $subelem_ref->{Pers_Name}) {
            my $name_ref  = $subelem_ref->{Pers_Name}; # cache
            my $name_elem = XML::LibXML::Element->new('Pers_Name');
            $pers_elem->appendChild($name_elem);

            if (ref $name_ref ne 'HASH') { # allow direct PCDATA
                $name_elem->appendText($subelem_ref->{Pers_Name});
            }
            else{
                if (defined $name_ref->{Vorname}) {
                    $name_elem->appendTextChild(
                        Vorname => $name_ref->{Vorname}
                    );
                }
                if (defined $name_ref->{Nachname}) {
                    $name_elem->appendTextChild(
                        Nachname => $name_ref->{Nachname}
                    );
                }
                if (defined $name_ref->{PCDATA}) { # allow indirect PCDATA
                    $name_elem->appendText($name_ref->{PCDATA});
                }
            }
        }

        if (defined $subelem_ref->{Rang_Titel}) {
            $pers_elem->appendTextChild(
                Rang_Titel => $subelem_ref->{Rang_Titel}
            );
        }

        if (defined $subelem_ref->{Beruf_Funktion}) {
            $pers_elem->appendTextChild(
                Beruf_Funktion => $subelem_ref->{Beruf_Funktion}
            );
        }

        if (defined $subelem_ref->{Institution}) {
            $pers_elem->appendTextChild(
                Institution => $subelem_ref->{Institution}
            );
        }

        if (defined $subelem_ref->{Datum}) {
            $self->_append_element_datum(
                $pers_elem, $subelem_ref->{Datum}
            );
        }

        if (defined $subelem_ref->{Ort}) {
            $self->_append_element_ort(
                $pers_elem, $subelem_ref->{Ort}
            );
        }

        if (defined $subelem_ref->{Nationalitaet}) {
            $pers_elem->appendTextChild(
                Nationalitaet => $subelem_ref->{Nationalitaet}
            );
        }

        if (defined $subelem_ref->{Geschlecht}) {
            $pers_elem->appendTextChild(
                Geschlecht => $subelem_ref->{Geschlecht}
            );
        }

        if (defined $subelem_ref->{Konfession}) {
            $pers_elem->appendTextChild(
                Konfession => $subelem_ref->{Konfession}
            );
        }

        if (defined $subelem_ref->{Familienstand}) {
            $pers_elem->appendTextChild(
                Familienstand => $subelem_ref->{Familienstand}
            );
        }

        if (defined $subelem_ref->{Anschrift}) {
            $pers_elem->appendTextChild(
                Anschrift => $subelem_ref->{Anschrift}
            );
        }

        if (defined $subelem_ref->{Bem}) {
            $pers_elem->appendTextChild(
                Bem => $subelem_ref->{Bem}
            );
        }

        if (defined $subelem_ref->{Hilfsfeld}) {
            $pers_elem->appendTextChild(
                Hilfsfeld => $subelem_ref->{Hilfsfeld}
            );
        }

        if (defined $subelem_ref->{archref}) {
            $pers_elem->appendTextChild(
                archref => $subelem_ref->{archref}
            );
        }

        if (defined $subelem_ref->{bibref}) {
            $pers_elem->appendTextChild(
                bibref => $subelem_ref->{bibref}
            );
        }

        if (defined $subelem_ref->{FM_ref}) {
            $pers_elem->appendTextChild(
                FM_ref => $subelem_ref->{FM_ref}
            );
        }

        if (defined $subelem_ref->{'altübform'}) {
            $pers_elem->appendTextChild(
                'altübform' => $subelem_ref->{'altübform'}
            );
        }

        if (defined $subelem_ref->{Register}) {
            $pers_elem->appendTextChild(
                Register => $subelem_ref->{Register}
            );
        }

        if (defined $subelem_ref->{PCDATA}) { # allow indirect PCDATA
            $pers_elem->appendText($subelem_ref->{PCDATA});
        }
    }
}


1; # Magic true value required at end of module


__END__

=head1 NAME

SAFT::Simple - create simple SAFT-XML encoded archival finding aids


=head1 VERSION

This document describes SAFT::Simple version 1.0.0


=head1 SYNOPSIS

    use SAFT::Simple;

    my $saft = SAFT::Simple->new();

    $saft->set_finding_aid_title('Guide to the archives of Gondor');
    $saft->set_abstract('This finding aid describes...');
    $saft->set_author('Gandalf the Grey');

    $saft->add_classification(1    => 'Archive of the Kings');
    $saft->add_classification(2    => 'Archive of the Stewards');
    $saft->add_classification(1.1  => 'Reign of Elendil');
    $saft->add_classification(2.26 => 'Reign of Denethor II.');

    $saft->add_file_sachakte(
        '1.1',
        {
            Signatur => '42',
            Titel    => "Of Denethor's death",
            Enthaelt => 'Includes a testimony',
            Laufzeit => '3019-3020',
        }
    );

    print $saft->to_string();
  
  
=head1 DESCRIPTION

This module provides a convenient way to create archival finding aids in a
format specified by the SAFT XML standard.

If you don't know what a finding aid is in the first place, please refer to
Wikipedia. SAFT is a standard for XML encoding those finding aids. The acronym
SAFT stands for German "Standard-Austauschformat" (s.th. like "standard
interchange format"). You can find the SAFT DTD and more (German)
documentation on SAFT XML on this website:
http://www.archivschule.de/forschung/retrokonversion-252/vorstudien-und-saft-xml/

SAFT XML is not very widely used (in fact, since its tag names are German,
probably nobody uses it outside Germany), a far more widespread format for
such purposes is the American standard Encoded Archival Description (EAD).

So why bother using SAFT anyway? Three reasons: First, it might be better
suited to German archival tradition (personal opinion). Second, it might be
easier to use than EAD (again, personal opinion). Third, I haven't heard of a
Perl module for EAD so far. For SAFT? Here you go.

SAFT::Simple does not, however, provide every feature the SAFT DTD allows you
to use (you guess, that's why it's called 'Simple'). Instead methods are
provided only for common cases and rather simple structures (i.e., cases I
have stumbled upon and structures I have needed so far using SAFT XML).
Anything that's allowed by the SAFT DTD but not provided by SAFT::Simple could
easily be achieved using a general XML module such as XML::LibXML. In fact,
all that SAFT::Simple does is wrapping XML::LibXML, thus making your life
easier (well, much easier compared to writing all code based directly on
XML::LibXML, but whatever).


=head1 INTERFACE 

The following methods are provided by SAFT::Simple.

=over

=item new

    $saft = SAFT::Simple->new( );

This method creates a new SAFT::Simple object, representing the SAFT XML
finding aid.

=item set_finding_aid_title

    $saft->set_finding_aid_title( $title );

This method sets the finding aid's title (element Findmittel_Info/FM_Name).

=item set_finding_aid_id

    $saft->set_finding_aid_id( $id );

This method sets the finding aid's id (element Findmittel_Info/FM_Sig).

=item set_author

    $saft->set_author( $author_name );

This method sets the finding aid's author (element
Datei_Info/Erstellung/Bearbeiter).

=item set_creation_date

    $saft->set_creation_date( $creation_date );

This method sets the finding aid's creation date (element
Datei_Info/Erstellung/Datum).

=item set_filename

    $saft->set_filename( $filename );

This method sets the SAFT XML file's filename (element Datei_Info/Dateiname).
If you call the to_file method later with another filename, this will reset
the content of the relevant element.

=item set_abstract

    $saft->set_abstract( $text );

This method sets the finding aid's abstract (element
Findmittel_Info/Einleitung/Text).

=item set_finding_aid_note

    $saft->set_finding_aid_note( $text );

This method sets the finding aid's note (element Findmittel_Info/Bem).

=item set_unit_title

    $saft->set_unit_title( $title );

This method sets the title of the unit described in the finding aid (element
Findmittel_Info/Bestand_Info/Bestandsname).

=item set_unit_id

    $saft->set_unit_id( $id );

This method sets the id of the unit described in the finding aid (element
Findmittel_Info/Bestand_Info/Bestand_Sig).

=item set_unit_date

    $saft->set_unit_date( $date );

This method sets the date of the unit described in the finding aid (elements
Findmittel_Info/Bestand_Info/Laufzeit/LZ_Text and
Findmittel_Info/Laufzeit/LZ_Text).

=item add_classification

    $saft->add_classification( $branch_number, $branch_title );

This method creates a new classification branch (element Klassifikation) and
adds it to the finding aid. Its title (element Klass_Titel) is determined by
$branch_title and its branch number (element Klass_Nr) by $branch_number
(example: '2.1.3'). The parameter $branch_number also determines where the new
branch will be appended in the classification structure, cf. the following
example:

    branch number '1'
    branch number '2'
        branch number '2.1'
            branch number '2.1.1'
            branch number '2.1.2'
            branch number '2.1.3' <= here it is!
    branch number '3'

When building a classification, it is not necessary to create the
classification branches in a specific order. If you create a branch
referencing (by its branch number) a non-existing parent branch, the missing
parent branch will implicitly be created with an empty title. If this
implicitly created branch is later created explicitly, it will not be created
again, but instead only its title will be set according to the given
parameter. This means, staying with the example above, you could first create
branch 2.1.3, then 2.1.1 and 2.1.2, and after that 2.1 and 2 without messing
up your classification structure.

=item set_classification_title

    $saft->set_classification_title( $branch_number, $branch_title );

This method sets the title of the classification branch determined by its
branch number (example: '2.1.3').

=item add_file_sachakte

    $saft->add_file_sachakte( $branch_number, \%subelems );

This method creates a new record of type Sachakte and appends it at the end of
the classification branch determined by $branch_number (example: '2.1.3'). To
achieve a certain order among the different records in a given classification
branch you have to append them by calling add_file_sachakte in the desired
order (not as with add_classification_branch).

The new Sachakte's content is determined by the key/value pairs in the hash
%subelems (which is passed as a reference). The following keys and value types
will be accepted:

    key                 | value type
    --------------------+--------------------------------------
    Signatur (required) | scalar
    Laufzeit            | scalar
    Titel (required)    | scalar
    Enthaelt            | scalar
    Nr                  | scalar
    Az                  | scalar
    Bestellsig          | scalar
    Altsig              | scalar
    Provenienz          | scalar
    Vor_Prov            | scalar
    Abg_Stelle          | scalar
    Akzession           | scalar
    Sperrvermerk        | scalar
    Umfang              | scalar
    Lagerung            | scalar
    Zustand             | scalar
    FM_Seite            | scalar
    Bestand_Kurz        | scalar
    Bem                 | scalar
    Hilfsfeld           | scalar
    archref             | scalar
    bibref              | scalar
    FM_ref              | scalar
    altübform           | scalar
    Register            | scalar

A possible example for \%subelems might look like this:

    {
        Signatur    => '42',
        Titel       => "Of Denethor's death",
        Enthaelt    => 'Includes a testimony',
        Laufzeit    => '3019-3020',
        'altübform' => 'We have digitized that one!',
        # ...
    }

=item add_file_fallakte

    $saft->add_file_fallakte( $branch_number, \%subelems );

This method creates a new record of type Fallakte and appends it at the end of
the classification branch determined by $branch_number (example: '2.1.3'). To
achieve a certain order among the different records in a given classification
branch you have to append them by calling add_file_fallakte in the desired
order (not as with add_classification_branch).

The new Fallakte's content is determined by the key/value pairs in the hash
%subelems (which is passed as a reference). The following keys and value types
will be accepted:

    key                 | value type
    --------------------+--------------------------------------
    FA_Art (attribute)  | scalar
    Signatur (required) | scalar
    Laufzeit            | scalar
    Titel               | scalar
    Enthaelt            | scalar
    Person              | scalar or hash reference (see below)
    Institution         | scalar
    Sachverhalt         | scalar
    Datum               | scalar or hash reference (see below)
    Nr                  | scalar
    Ort                 | scalar or hash reference (see below)
    Anschrift           | scalar
    Az                  | scalar
    Prozessart          | scalar
    Instanz             | scalar
    Beweismittel        | scalar
    Formalbeschreibung  | scalar
    Bestellsig          | scalar
    Altsig              | scalar
    Provenienz          | scalar
    Vor_Prov            | scalar
    Abg_Stelle          | scalar
    Akzession           | scalar
    Sperrvermerk        | scalar
    Umfang              | scalar
    Lagerung            | scalar
    Zustand             | scalar
    FM_Seite            | scalar
    Bestand_Kurz        | scalar
    Bem                 | scalar
    Hilfsfeld           | scalar
    archref             | scalar
    bibref              | scalar
    FM_ref              | scalar
    altübform           | scalar
    Register            | scalar

Some keys will accept either a simple scalar value or a hash reference, your
choice will depend on the complexity of your data. The following tables list
the keys and value types that will be accepted, respectively. The special key
'PCDATA' can be used to mix child elements and PCDATA content, or to create
elements with attributes (you will need a hash for these, so you can't pass a
scalar with the element's text content - just use the PCDATA key).

    Person
    key                 | value type
    --------------------+--------------------------------------
    Pers_Name           | scalar or hash reference (see below)
    Rang_Titel          | scalar
    Beruf_Funktion      | scalar
    Institution         | scalar
    Datum               | scalar or hash reference (see below)
    Ort                 | scalar or hash reference (see below)
    Nationalitaet       | scalar
    Geschlecht          | scalar
    Konfession          | scalar
    Familienstand       | scalar
    Anschrift           | scalar
    Bem                 | scalar
    Hilfsfeld           | scalar
    archref             | scalar
    bibref              | scalar
    FM_ref              | scalar
    altübform           | scalar
    Register            | scalar
    PCDATA              | scalar

    Pers_Name
    key                 | value type
    --------------------+--------------------------------------
    Vorname             | scalar
    Nachname            | scalar
    PCDATA              | scalar

    Datum
    key                 | value type
    --------------------+--------------------------------------
    Dat_Fkt (attribute) | scalar
    Jahr                | scalar
    Monat               | scalar
    Tag                 | scalar
    PCDATA              | scalar

    Ort
    key                 | value type
    --------------------+--------------------------------------
    Ort_Fkt (attribute) | scalar
    PCDATA              | scalar

A possible example for \%subelems might look like this:

    {
        Signatur    => '42',
        FA_Art      => 'Personal',
        Person      => {
            Pers_Name       => 'Aragorn',
            Rang_Titel      => 'King of Arnor and Gondor',
            Datum           => {
                Dat_Fkt     => 'Geburt',
                PCDATA      => '2931',
            }
        },
        Institution => 'Kingdom of Arnor and Gondor',
        # ...
    }

=item to_string

    $string = $saft->to_string();

This method returns a string representation of the XML structure stored in the
$saft object (cf. the toString method of XML::LibXML).

=item to_file

    $saft->to_file( $filename );

This method creates a file called $filename containing the XML structure
stored in the $saft object. Calling the to_file method implicitly calls
$saft->set_filename( $filename ).

=back


=head1 DIAGNOSTICS

The following errors or warnings may occur while using SAFT::Simple.

=over

=item C<< E: Can't understand format of branch number '...' >>

You have passed the add_classification method a branch number SAFT::Simple
doesn't understand. Branch numbers must look like '3', '4.1', '1.5.2', ... (up
to ten levels), or in other words like this: /[1-9]\d*(\.[1-9]\d*)*/.

=item C<< W: Nested classification with more than 10 levels is not allowed by
SAFT DTD >>

You have passed the add_classification method a branch number with more than
ten levels. SAFT::Simple uses the level attribute of element Klassifikation to
store the depth of a classification branch, and for this attribute only the
values 01..10 are allowed.

=item C<< W: Branch ... '...' already exists, repeated attempt to create it
was ignored >>

You have tried to use the add_classification method to create a classification
branch that already exists (same number, same title). Usually, this is no
problem: You want a branch, you have the branch - nothing to be done ;-)

=item C<< E: Can't add classification branch ... '...' - a classification
branch with the same number already exists >>

You have tried to use the add_classification method to create a classification
branch that already exists (same number, different title). You probably have a
clash of branch numbers here - check your input data!

=item C<< E: Can't set title of nonexisting classification branch number
... . To create a new branch use add_classification >>

You have used the set_classification_title method to set the title of a
nonexisting branch. You either have passed the wrong branch number to
set_classification_title, or you should check you input data.

=item C<< W: Missing entry or value for element 'Signatur' >>

You have created a file (e.g. Sachakte or Fallakte) element without providing
a Signatur value. This will not prevent your element from being created, but
usually you will not want to create files without a Signatur. Either you know
what you are doing, or you should check your input data.

=item C<< W: Missing entry or value for element 'Titel' (Signatur ...) >>

You have created a file (e.g. Sachakte) element without providing a Titel
value. This will not prevent your element from being created, but usually you
will not want to create files without a Titel. Either you know what you are
doing, or you should check your input data.

=item C<< E: Can't find classification branch number ... to append file >>

You have created a file (e.g. Sachakte or Fallakte) and passed the method a
classification branch number SAFT::Simple can't find. Either your branch
number has a format SAFT::Simple does not recognize or a classification branch
with the given number doesn't exist. Check your input data.

=back


=head1 CONFIGURATION AND ENVIRONMENT

SAFT::Simple requires no configuration files or environment variables.


=head1 DEPENDENCIES

SAFT::Simple uses Perl (minimum 5.10) and the following modules and pragmas:

=over

=item warnings

=item strict

=item Carp

=item utf8

=item version

=item XML::LibXML (tested with version 1.70)

=back


=head1 INCOMPATIBILITIES

None reported.


=head1 BUGS AND LIMITATIONS

As mentioned above, SAFT::Simple does not provide every feature that would be
allowed by the SAFT DTD.

No bugs have been reported.

Please report any bugs or feature requests to C<bug-saft-simple@rt.cpan.org>,
or through the web interface at L<http://rt.cpan.org>.


=head1 AUTHOR

Martin Hoppenheit  C<< <martin.hoppenheit@brhf.de> >>


=head1 LICENCE AND COPYRIGHT

Copyright (c) 2011, Martin Hoppenheit C<< <martin.hoppenheit@brhf.de> >>. All
rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.


=head1 DISCLAIMER OF WARRANTY

BECAUSE THIS SOFTWARE IS LICENSED FREE OF CHARGE, THERE IS NO WARRANTY
FOR THE SOFTWARE, TO THE EXTENT PERMITTED BY APPLICABLE LAW. EXCEPT WHEN
OTHERWISE STATED IN WRITING THE COPYRIGHT HOLDERS AND/OR OTHER PARTIES
PROVIDE THE SOFTWARE "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER
EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. THE
ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE OF THE SOFTWARE IS WITH
YOU. SHOULD THE SOFTWARE PROVE DEFECTIVE, YOU ASSUME THE COST OF ALL
NECESSARY SERVICING, REPAIR, OR CORRECTION.

IN NO EVENT UNLESS REQUIRED BY APPLICABLE LAW OR AGREED TO IN WRITING
WILL ANY COPYRIGHT HOLDER, OR ANY OTHER PARTY WHO MAY MODIFY AND/OR
REDISTRIBUTE THE SOFTWARE AS PERMITTED BY THE ABOVE LICENCE, BE
LIABLE TO YOU FOR DAMAGES, INCLUDING ANY GENERAL, SPECIAL, INCIDENTAL,
OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE OR INABILITY TO USE
THE SOFTWARE (INCLUDING BUT NOT LIMITED TO LOSS OF DATA OR DATA BEING
RENDERED INACCURATE OR LOSSES SUSTAINED BY YOU OR THIRD PARTIES OR A
FAILURE OF THE SOFTWARE TO OPERATE WITH ANY OTHER SOFTWARE), EVEN IF
SUCH HOLDER OR OTHER PARTY HAS BEEN ADVISED OF THE POSSIBILITY OF
SUCH DAMAGES.
