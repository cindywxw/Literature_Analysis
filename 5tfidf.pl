#!/usr/bin/env perl

# ----------------------------------------------------------------------------------------
# BIOL595 Final Project: Literature Analysis (Part IV)
# This script will generate report on top keywords found by tfidf.
# As a bonus rare words will be included
# tf - term frequency   idf - inverse document frequency
# Alexandr Pak, Krittikan Chanpaisaeng, Xin Wen     7 May 2016
# ----------------------------------------------------------------------------------------


use strict;
use warnings;


use Data::Dumper;
use Lingua::EN::Tagger;
use XML::LibXML;



my $file = 'xmloutput.xml';

open (my $xml, "<", $file) || die "Cannot open file '$file'\n";
open (my $out, ">", "out.txt")|| die "Cannot open output file.\n";

my (%tf_idf, %tmp, @AbstractText, @ArticleTitle, $string, %tf, %idf, %rare);

# create xml parser
my $parser = XML::LibXML->new;
my $doc    = $parser->parse_fh($xml);
my $i = 0;

# parse xml and extract abstract text
for my $item ( $doc->findnodes('//PubmedArticle') ) {
    $AbstractText[$i] = $item->findvalue('.//AbstractText');
    $i++;
}
# create tag
my $tag = Lingua::EN::Tagger->new(
longest_noun_phrase => 1,
weight_noun_phrases => 0,
relax => 0,
stem => 0,
);

# join all abstracts in one string
$string = join(' ', @AbstractText);

print "Abstracts extracted\n";

# get words count from all abstracts key - word, value - count
%tf = $tag->get_words($string);

# remove anythin that is not a word from hash of words
foreach my $key (keys %tf) {
    if ($key =~ /[^a-z]/ or length($key) <3) {
        delete $tf {$key};
    }
}

map{$idf{$_} = 1} keys %tf; # copy hash keys and set values to 1 for document frequency calculation

print "Term Frequency calculated\n";

# copy tf hash to $rare, which willl store rare words found in abstracts
%rare = %tf;

for my $word (@AbstractText) {
    
    foreach my $key (keys %rare) {
        my $val = $rare {$key}; # save value in different variable to later change it
        
        
        if ($word =~ /\b$key\b/g) {
            $rare {$key} = $val/2; # penalize every word for appearing in this abstract
            $idf{$key}++; # calculating document frequency
        }
    }
}



my $docs = $#AbstractText; #total number of abstracts
foreach my $x (values %idf) { $x = log($docs/$x); } #calculate inverse document frequency

my $words = keys %tf; #total number of words
foreach my $y (values %tf) { $y = $y/$words; } # calculate term frequency

print "Inverse document frequency calculated\n";

# calculate tf-idf
foreach my $key (keys %tf) {
    
    if (exists($idf{$key}))
    {
        $tf_idf{$key} = $tf{$key}*$idf{$key}
    }
    
    
    
}

# sort hashes by values to find words with top scores
my @sorted_tfidf = sort {$tf_idf {$b} <=> $tf_idf {$a} or  "\L$a" cmp "\L$b"} keys %tf_idf;

my @sorted_rare = sort {$rare {$b} <=> $rare {$a} or  "\L$a" cmp "\L$b"} keys %rare;

# print to output file the words with top tf-idf scores
print $out "Words with top tfidf scores\n";

foreach my $j ( @sorted_tfidf[ 0 .. 24 ] ) {
    print $out "$j\t\t\t\t\t$tf_idf{$j}\n";
}

print $out "\n\n\nRelevant Words\n";

foreach my $k ( @sorted_rare[ 0 .. 24 ] ) {
    print $out "$k\t\t\t\t\t$rare{$k}\n";
}



close($xml);
close($out);
print "Report generated\n";
