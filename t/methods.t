#!/usr/bin/perl -T

# usage: prove -v t/methods.t

use strict;
use warnings;
use utf8;

use SAFT::Simple;
use Test::More tests => 119;

# test method new
my $saft = SAFT::Simple->new();
isa_ok( $saft, 'SAFT::Simple' );

# prepare shortcuts for the following tests
sub get_node_content {
    my $xpath      = shift;
    my $node_order = @_ ? shift : 0;
    return ($saft->{root}->findnodes($xpath))[$node_order]->textContent();
}

sub get_attribute_content {
    my $xpath     = shift;
    my $attr_name = shift;
    return ($saft->{root}->findnodes($xpath))[0]->getAttribute($attr_name);
}

# test method set_finding_aid_title
$saft->set_finding_aid_title('finding aid title');
is(
    get_node_content('/Findmittel/Findmittel_Info/FM_Name'),
    'finding aid title',
    'set_finding_aid_title()'
);

# test method set_finding_aid_id
$saft->set_finding_aid_id('finding aid id');
is(
    get_node_content('/Findmittel/Findmittel_Info/FM_Sig'),
    'finding aid id',
    'set_finding_aid_id()'
);

# test method set_author
$saft->set_author('author');
is(
    get_node_content('/Findmittel/Datei_Info/Erstellung/Bearbeiter'),
    'author',
    'set_author()'
);

# test method set_creation_date
$saft->set_creation_date('creation date');
is(
    get_node_content('/Findmittel/Datei_Info/Erstellung/Datum'),
    'creation date',
    'set_creation_date()'
);

# test method set_filename
$saft->set_filename('filename');
is(
    get_node_content('/Findmittel/Datei_Info/Dateiname'),
    'filename',
    'set_filename()'
);

# test method set_abstract
$saft->set_abstract('abstract');
is(
    get_node_content('/Findmittel/Findmittel_Info/Einleitung/Text'),
    'abstract',
    'set_abstract()'
);

# test method set_finding_aid_note
$saft->set_finding_aid_note('finding aid note');
is(
    get_node_content('/Findmittel/Findmittel_Info/Bem'),
    'finding aid note',
    'set_finding_aid_note()'
);

# test method set_unit_title
$saft->set_unit_title('unit title');
is(
    get_node_content('/Findmittel/Findmittel_Info/Bestand_Info/Bestandsname'),
    'unit title',
    'set_unit_title()'
);

# test method set_unit_id
$saft->set_unit_id('unit id');
is(
    get_node_content('/Findmittel/Findmittel_Info/Bestand_Info/Bestand_Sig'),
    'unit id',
    'set_unit_id()'
);

# test method set_unit_date
$saft->set_unit_date('unit date');
is(
    get_node_content('/Findmittel/Findmittel_Info/Bestand_Info/Laufzeit/LZ_Text'),
    'unit date',
    'set_unit_date() (Bestand)'
);
is(
    get_node_content('/Findmittel/Findmittel_Info/Laufzeit/LZ_Text'),
    'unit date',
    'set_unit_date() (Findmittel)'
);

# test method add_classification
$saft->add_classification( 2   => 'Number 2'   );
$saft->add_classification( 1   => 'Number 1'   );
$saft->add_classification( 1.1 => 'Number 1.1' );
$saft->add_classification( 1.3 => 'Number 1.3' );
$saft->add_classification( 3.2 => 'Number 3.2' );
$saft->add_classification( 3   => 'Number 3'   );
$saft->add_classification( 1.2 => 'Number 1.2' );
$saft->add_classification( 3.1 => 'Number 3.1' );

ok(
    (get_node_content('/Findmittel/Klassifikation/Klass_Nr', 0) eq '1'
    and
    get_node_content('/Findmittel/Klassifikation/Klass_Titel', 0)
        eq  'Number 1'),
    'add_classification() (branch number 1)'
);
ok(
    (get_node_content('/Findmittel/Klassifikation/Klass_Nr', 1) eq '2'
    and
    get_node_content('/Findmittel/Klassifikation/Klass_Titel', 1)
        eq 'Number 2'),
    'add_classification() (branch number 2)'
);
ok(
    (get_node_content('/Findmittel/Klassifikation/Klass_Nr', 2) eq '3'
    and
    get_node_content('/Findmittel/Klassifikation/Klass_Titel', 2)
        eq 'Number 3'),
    'add_classification() (branch number 3)'
);
ok(
    (get_node_content('/Findmittel/Klassifikation/Klassifikation/Klass_Nr', 0)
        eq '1.1'
    and
    get_node_content(
        '/Findmittel/Klassifikation/Klassifikation/Klass_Titel', 0
    )
        eq 'Number 1.1'),
    'add_classification() (branch number 1.1)'
);
ok(
    (get_node_content('/Findmittel/Klassifikation/Klassifikation/Klass_Nr', 1)
        eq '1.2'
    and
    get_node_content(
        '/Findmittel/Klassifikation/Klassifikation/Klass_Titel', 1
    )
        eq 'Number 1.2'),
    'add_classification() (branch number 1.2)'
);
ok(
    (get_node_content('/Findmittel/Klassifikation/Klassifikation/Klass_Nr', 2)
        eq '1.3'
    and
    get_node_content(
        '/Findmittel/Klassifikation/Klassifikation/Klass_Titel', 2
    )
        eq 'Number 1.3'),
    'add_classification() (branch number 1.3)'
);
ok(
    (get_node_content('/Findmittel/Klassifikation/Klassifikation/Klass_Nr', 3)
        eq '3.1'
    and
    get_node_content(
        '/Findmittel/Klassifikation/Klassifikation/Klass_Titel', 3
    )
        eq 'Number 3.1'),
    'add_classification() (branch number 3.1)'
);
ok(
    (get_node_content('/Findmittel/Klassifikation/Klassifikation/Klass_Nr', 4)
        eq '3.2'
    and
    get_node_content(
        '/Findmittel/Klassifikation/Klassifikation/Klass_Titel', 4
    )
        eq 'Number 3.2'),
    'add_classification() (branch number 3.2)'
);

=for error testing
$saft->add_classification( 1.1.1.1.1.1.1.1.1.1.1.1 => 'too deep' ); # warning
$saft->add_classification( 'missing number' );                      # error
$saft->add_classification( 3 => 'Number 3, once again' );           # error
=cut

# test method set_classification_title
$saft->set_classification_title( 3.2 => 'Number 3.2, new title' );
ok(
    (get_node_content('/Findmittel/Klassifikation/Klassifikation/Klass_Nr', 4)
        eq '3.2'
    and
    get_node_content(
        '/Findmittel/Klassifikation/Klassifikation/Klass_Titel', 4
    )
        eq 'Number 3.2, new title'),
    'set_classification_title()'
);

=for error testing
$saft->set_classification_title( 4 => 'Number 4, not existing' );   # error
=cut

# test method add_file_sachakte
$saft->add_file_sachakte(
    '1.2',
    {
        Signatur        => 'Signatur',
        Laufzeit        => 'Laufzeit',
        Titel           => 'Titel',
        Enthaelt        => 'Enthaelt',
        Nr              => 'Nr',
        Az              => 'Az',
        Bestellsig      => 'Bestellsig',
        Altsig          => 'Altsig',
        Provenienz      => 'Provenienz',
        Vor_Prov        => 'Vor_Prov',
        Abg_Stelle      => 'Abg_Stelle',
        Akzession       => 'Akzession',
        Sperrvermerk    => 'Sperrvermerk',
        Umfang          => 'Umfang',
        Lagerung        => 'Lagerung',
        Zustand         => 'Zustand',
        FM_Seite        => 'FM_Seite',
        Bestand_Kurz    => 'Bestand_Kurz',
        Bem             => 'Bem',
        Hilfsfeld       => 'Hilfsfeld',
        archref         => 'archref',
        bibref          => 'bibref',
        FM_ref          => 'FM_ref',
        'altübform'     => 'altübform',
        Register        => 'Register',
    }
);

for my $elem (
    qw(
        Signatur
        Titel
        Enthaelt
        Nr
        Az
        Bestellsig
        Altsig
        Provenienz
        Vor_Prov
        Abg_Stelle
        Akzession
        Sperrvermerk
        Umfang
        Lagerung
        Zustand
        FM_Seite
        Bestand_Kurz
        Bem
        Hilfsfeld
        archref
        bibref
        FM_ref
        altübform
        Register
    )) {
    is(
        get_node_content(
            '/Findmittel/Klassifikation/Klassifikation[Klass_Nr="1.2"]/'
            . "Verzeichnungseinheiten/Sachakte/$elem"
        ),
        $elem,
        "add_file_sachakte() ($elem)"
    )
}

is(
    get_node_content(
        '/Findmittel/Klassifikation/Klassifikation[Klass_Nr="1.2"]/'
        . 'Verzeichnungseinheiten/Sachakte/Laufzeit/LZ_Text'
    ),
    'Laufzeit',
    'add_file_sachakte() (Laufzeit)'
);

# test method add_file_fallakte, part 1 (complete)
$saft->add_file_fallakte(
    '1.1',
    {
        FA_Art              => 'FA_Art',
        Signatur            => 'Signatur',
        Laufzeit            => 'Laufzeit',
        Titel               => 'Titel',
        Enthaelt            => 'Enthaelt',
        Person              => {
            Pers_Name       => {
                Vorname     => 'Vorname',
                Nachname    => 'Nachname',
            },
            Rang_Titel      => 'Rang_Titel',
            Beruf_Funktion  => 'Beruf_Funktion',
            Institution     => 'Institution',
            Datum           => {
                Dat_Fkt     => 'Dat_Fkt',
                Jahr        => 'Jahr',
                Monat       => 'Monat',
                Tag         => 'Tag',
            },
            Ort             => {
                Ort_Fkt     => 'Ort_Fkt',
                PCDATA      => 'Ort',
            },
            Nationalitaet   => 'Nationalitaet',
            Geschlecht      => 'Geschlecht',
            Konfession      => 'Konfession',
            Familienstand   => 'Familienstand',
            Anschrift       => 'Anschrift',
            Bem             => 'Bem',
            Hilfsfeld       => 'Hilfsfeld',
            archref         => 'archref',
            bibref          => 'bibref',
            FM_ref          => 'FM_ref',
            'altübform'     => 'altübform',
            Register        => 'Register',
        },
        Institution         => 'Institution',
        Sachverhalt         => 'Sachverhalt',
        Datum               => {
            Dat_Fkt         => 'Dat_Fkt',
            Jahr            => 'Jahr',
            Monat           => 'Monat',
            Tag             => 'Tag',
        },
        Nr                  => 'Nr',
        Ort                 => {
            Ort_Fkt         => 'Ort_Fkt',
            PCDATA          => 'Ort',
        },
        Anschrift           => 'Anschrift',
        Az                  => 'Az',
        Prozessart          => 'Prozessart',
        Instanz             => 'Instanz',
        Beweismittel        => 'Beweismittel',
        Formalbeschreibung  => 'Formalbeschreibung',
        Bestellsig          => 'Bestellsig',
        Altsig              => 'Altsig',
        Provenienz          => 'Provenienz',
        Vor_Prov            => 'Vor_Prov',
        Abg_Stelle          => 'Abg_Stelle',
        Akzession           => 'Akzession',
        Sperrvermerk        => 'Sperrvermerk',
        Umfang              => 'Umfang',
        Lagerung            => 'Lagerung',
        Zustand             => 'Zustand',
        FM_Seite            => 'FM_Seite',
        Bestand_Kurz        => 'Bestand_Kurz',
        Bem                 => 'Bem',
        Hilfsfeld           => 'Hilfsfeld',
        archref             => 'archref',
        bibref              => 'bibref',
        FM_ref              => 'FM_ref',
        'altübform'         => 'altübform',
        Register            => 'Register',
    }
);

is(
    get_attribute_content(
        '/Findmittel/Klassifikation/Klassifikation[Klass_Nr="1.1"]/'
        . 'Verzeichnungseinheiten/Fallakte',
        'FA_Art'
    ),
    'FA_Art',
    'add_file_fallakte() (FA_Art)'
);

for my $elem (
    qw(
        Signatur
        Titel
        Enthaelt
        Institution
        Sachverhalt
        Nr
        Anschrift
        Az
        Prozessart
        Instanz
        Beweismittel
        Formalbeschreibung
        Bestellsig
        Altsig
        Provenienz
        Vor_Prov
        Abg_Stelle
        Akzession
        Sperrvermerk
        Umfang
        Lagerung
        Zustand
        FM_Seite
        Bestand_Kurz
        Bem
        Hilfsfeld
        archref
        bibref
        FM_ref
        altübform
        Register
    )) {
    is(
        get_node_content(
            '/Findmittel/Klassifikation/Klassifikation[Klass_Nr="1.1"]/'
            . "Verzeichnungseinheiten/Fallakte/$elem"
        ),
        $elem,
        "add_file_fallakte() ($elem)"
    )
}

is(
    get_node_content(
        '/Findmittel/Klassifikation/Klassifikation[Klass_Nr="1.1"]/'
        . 'Verzeichnungseinheiten/Fallakte/Laufzeit/LZ_Text'
    ),
    'Laufzeit',
    'add_file_fallakte() (Laufzeit)'
);

for my $elem (
    qw(
        Rang_Titel
        Beruf_Funktion
        Institution
        Nationalitaet
        Geschlecht
        Konfession
        Familienstand
        Anschrift
        Bem
        Hilfsfeld
        archref
        bibref
        FM_ref
        altübform
        Register
    )) {
    is(
        get_node_content(
            '/Findmittel/Klassifikation/Klassifikation[Klass_Nr="1.1"]/'
            . "Verzeichnungseinheiten/Fallakte/Person/$elem"
        ),
        $elem,
        "add_file_fallakte() (Person/$elem)"
    );
}

for my $elem (
    qw(
        Vorname
        Nachname
    )) {
    is(
        get_node_content(
            '/Findmittel/Klassifikation/Klassifikation[Klass_Nr="1.1"]/'
            . "Verzeichnungseinheiten/Fallakte/Person/Pers_Name/$elem"
        ),
        $elem,
        "add_file_fallakte() (Person/Pers_Name/$elem)"
    );
}

is(
    get_attribute_content(
        '/Findmittel/Klassifikation/Klassifikation[Klass_Nr="1.1"]/'
        . 'Verzeichnungseinheiten/Fallakte/Person/Datum',
        'Dat_Fkt'
    ),
    'Dat_Fkt',
    'add_file_fallakte() (Person/Datum/Dat_Fkt)'
);

for my $elem (
    qw(
        Jahr
        Monat
        Tag
    )) {
    is(
        get_node_content(
            '/Findmittel/Klassifikation/Klassifikation[Klass_Nr="1.1"]/'
            . "Verzeichnungseinheiten/Fallakte/Person/Datum/$elem"
        ),
        $elem,
        "add_file_fallakte() (Person/Datum/$elem)"
    );
}

is(
    get_attribute_content(
        '/Findmittel/Klassifikation/Klassifikation[Klass_Nr="1.1"]/'
        . 'Verzeichnungseinheiten/Fallakte/Person/Ort',
        'Ort_Fkt'
    ),
    'Ort_Fkt',
    'add_file_fallakte() (Person/Ort/Ort_Fkt)'
);
is(
    get_node_content(
        '/Findmittel/Klassifikation/Klassifikation[Klass_Nr="1.1"]/'
        . 'Verzeichnungseinheiten/Fallakte/Person/Ort'
    ),
    'Ort',
    'add_file_fallakte() (Person/Ort)'
);

for my $elem (
    qw(
        Jahr
        Monat
        Tag
    )) {
    is(
        get_node_content(
            '/Findmittel/Klassifikation/Klassifikation[Klass_Nr="1.1"]/'
            . "Verzeichnungseinheiten/Fallakte/Datum/$elem"
        ),
        $elem,
        "add_file_fallakte() (Datum/$elem)"
    );
}

is(
    get_attribute_content(
        '/Findmittel/Klassifikation/Klassifikation[Klass_Nr="1.1"]/'
        . 'Verzeichnungseinheiten/Fallakte/Ort',
        'Ort_Fkt'
    ),
    'Ort_Fkt',
    'add_file_fallakte() (Ort/Ort_Fkt)'
);
is(
    get_node_content(
        '/Findmittel/Klassifikation/Klassifikation[Klass_Nr="1.1"]/'
        . 'Verzeichnungseinheiten/Fallakte/Ort'
    ),
    'Ort',
    'add_file_fallakte() (Ort)'
);

# test method add_file_fallakte, part 2
$saft->add_file_fallakte(
    '1.2',
    {
        Signatur            => 'Signatur',
        Person              => 'Person',
        Datum               => 'Datum',
        Ort                 => 'Ort',
    }
);

for my $elem (
    qw(
        Person
        Datum
        Ort
    )) {
    is(
        get_node_content(
            '/Findmittel/Klassifikation/Klassifikation[Klass_Nr="1.2"]/'
            . "Verzeichnungseinheiten/Fallakte/$elem"
        ),
        $elem,
        "add_file_fallakte() (part 2) ($elem)"
    );
}

# test method add_file_fallakte, part 3
$saft->add_file_fallakte(
    '1.3',
    {
        Signatur            => 'Signatur',
        Person              => { PCDATA => 'Person' },
        Datum               => { PCDATA => 'Datum' },
    }
);

for my $elem (
    qw(
        Person
        Datum
    )) {
    is(
        get_node_content(
            '/Findmittel/Klassifikation/Klassifikation[Klass_Nr="1.3"]/'
            . "Verzeichnungseinheiten/Fallakte/$elem"
        ),
        $elem,
        "add_file_fallakte() (part 3) ($elem)"
    );
}

# test method add_file_fallakte, part 4
$saft->add_file_fallakte(
    '3.1',
    {
        Signatur            => 'Signatur',
        Person              => {
            Pers_Name       => 'Pers_Name',
            Datum           => 'Datum',
            Ort             => 'Ort',
        },
    }
);

for my $elem (
    qw(
        Pers_Name
        Datum
        Ort
    )) {
    is(
        get_node_content(
            '/Findmittel/Klassifikation/Klassifikation[Klass_Nr="3.1"]/'
            . "Verzeichnungseinheiten/Fallakte/Person/$elem"
        ),
        $elem,
        "add_file_fallakte() (part 4) (Person/$elem)"
    );
}

# test method add_file_fallakte, part 5
$saft->add_file_fallakte(
    '3.2',
    {
        Signatur            => 'Signatur',
        Person              => {
            Pers_Name       => { PCDATA => 'Pers_Name' },
            Datum           => { PCDATA => 'Datum' },
            Ort             => { PCDATA => 'Ort' },
        },
    }
);

for my $elem (
    qw(
        Pers_Name
        Datum
        Ort
    )) {
    is(
        get_node_content(
            '/Findmittel/Klassifikation/Klassifikation[Klass_Nr="3.2"]/'
            . "Verzeichnungseinheiten/Fallakte/Person/$elem"
        ),
        $elem,
        "add_file_fallakte() (part 5) (Person/$elem)"
    );
}

# test method to_string
ok( $saft->to_string ne '', 'to_string()' );

# TODO test method to_file
