#!/usr/bin/env perl

# ----------------------------------------------------------------------------------------
# BIOL595 Final Project: Literature Analysis (Part II)
# For a searching term that returns a large number of articles (>500), the xml file we 
# get will be put into a series of PubmedArticleSets, which is not suitable for
# XML::LibXML module. so we trim the unnecessary lines in the xml file to make it friendly 
# to the XML::LibXML module.
#
# Alexandr Pak, Krittikan Chanpaisaeng, & Xin Wen, May 5  2016
# ----------------------------------------------------------------------------------------

use warnings;
use DBI;
use XML::LibXML;

my $file = "xmloutput.xml";

open (my $out, ">", "out.txt")|| die "Cannot open output file.\n";
my (%tf_idf, %tmp, @AbstractText, @ArticleTitle, $string, %tf, %idf, %rare);

open (my $xml, "<", $file) || die "Cannot open file '$file'\n";
    binmode(STDOUT, ":utf8");
    
    chomp(my @lines = <$xml>);
    
    close( $xml ); 
    
    #my $fh = 'test';
    open( OUT, ">:utf8",$file ); 
    print OUT "$lines[0]\n";
    print OUT "$lines[1]\n";
    print OUT "$lines[2]\n";

    foreach my $line ( @lines [3..$#lines] ) {  

        print OUT "$line\n"  unless ( $line =~ /\?xml|\!D|PubmedArticleSet|<VernacularTitle/ );
     
    } 
    print OUT $lines[-1];
    close(OUT); 
    #print( "Reservation successfully removed.<br/>" ); 
open ( $xml, "<", $file) || die "Cannot open file '$file'\n";

my $parser = XML::LibXML->new;
my $doc    = $parser->parse_fh($xml);
my $i = 0;

for my $item ( $doc->findnodes('//PubmedArticle') ) {
    $AbstractText[$i] = $item->findvalue('.//AbstractText');
    #$ArticleTitle[$i] = $item->findvalue('.//AbstractText');
   
    $i++;
}


__END__

