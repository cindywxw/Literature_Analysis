#!/usr/bin/env perl

# ----------------------------------------------------------------------------------------
# BIOL595 Final Project: Literature Analysis (Part VI)
# The function of script is to connect to MySQL localhost database created previously, 
# execute SQL query to obtain the abstracts. Then, use Lingua::EN::Tagger module and the
# tf-idf method (Part V) to calculate the frequency of the topics in each year as well as 
# in the pool of abstracts in all these years, then export the top 30 related topics and 
# their trends of popularity to a csv file.
#
# Alexandr Pak, Krittikan Chanpaisaeng, & Xin Wen, May 8 2016
# ----------------------------------------------------------------------------------------

use strict;
use warnings;
use Data::Dumper;
use Lingua::EN::Tagger;
use DBI;
use Time::localtime;

print "\nThis may take several minutes...\n";

# database information
my ($host, $user, $pass, $port, $db);
open (my $in, "<", "dbinfo.txt") || die "Cannot open file dbinfo.txt\n";

while (my $line = <$in>) {
	chomp $line;
	($host, $user, $pass, $port, $db) = split " ", $line;
}
my $dbh;
my $sth;
my %Abstracts;
my $thisyear = (localtime->year + 1900);
my ($first, $last) = ($thisyear, 0);

# connect to database
$dbh = DBI->connect("DBI:mysql:$db:$host:$port", $user, $pass,{
	PrintError       => 0,
	RaiseError       => 1,
	AutoCommit       => 1,
} ) or die "Can't connect to $db: $dbh->errstr\n";

# open (my $out, ">", "keycount.csv")|| die "Cannot open output file.\n";
my $query = "Count Keyword frequency";
my $sql = <<'END_SQL';
SELECT
	Articles.Abstract,Articles.Year
FROM
	Articles
ORDER BY Articles.Year ASC
END_SQL
$sth = $dbh->prepare($sql) or die "Can't prepare the query $query: $sth->errstr";
$sth->execute() or die "Can't execute the query $query: $sth->errstr";

my ( $string, %tf, %rare, %list, %toplist );
# fetchrow from sql results into array
while( my @row = $sth->fetchrow_array() ) {
	my ($Abstract, $year) = @row;
	push @{ $Abstracts{$year} }, $Abstract;
	push @{ $Abstracts{all} }, $Abstract;
	$first = $year if ( $first > $year );
	$last  = $year if ( $last < $year);
	}
    
my $tag = Lingua::EN::Tagger->new(
	longest_noun_phrase => 1,
	weight_noun_phrases => 0,
	relax => 0,
	stem => 0,
); 
$dbh->disconnect;

my $term;
open ($in, "<", "term.txt") || die "Cannot open file term.txt\n";
while (my $read = <$in>) {
	chomp $read;
	$read =~ tr/[A-Z]/[a-z]/;
	$term = $read;
}
# sort the abstracts by year
foreach my $y ( sort keys %Abstracts ) {                                                                          
	$string = join(' ', @{ $Abstracts{$y} });
	# key is the word, value is the count
	%list = $tag->get_words($string);
	# remove anything that is not a word   
	foreach my $key (keys %list) { 
		if ($key =~ /[^a-z]/ or length($key) <3 or ($key eq $term)) { 
			delete $list{$key};  
		}else {
		$tf{$y}{$key} = $list{$key};
		}       
	} 

	# copy tf hash to $%are, which willl store rare words found in abstracts
	%rare = %tf;
			   
	foreach my $word (@{ $Abstracts{$y} }) {
		foreach my $key (keys %{ $rare{$y} } ) {
			# save value in different variable to later change it
			my $val = $rare{$y}{$key};
			if ($word =~ /\b$key\b/g) {
				 # penalize every word for appearing in this abstract
				 $rare{$y}{$key} = $val/2;
			}
		}
	}

}

# sort hashes by values to find words with top scores
my @sorted_rare = sort { ${$rare{all}}{$b} <=> ${rare{all}}{$a} or  "\L$a" cmp "\L$b"} keys %{ $rare{all} };

open (my $out, ">", "TopicTrends.csv")|| die "Cannot open output file.\n";
print $out "key,value,date\n";
foreach  my $y ($first..$last) {
	foreach my $j ( @sorted_rare[ 0 .. 29 ] ) {
		if ( !defined  $rare{$y}{$j} ) {
			$toplist{$y}{$j} = 0;
		}else {
			$toplist{$y}{$j} = $rare{$y}{$j};
		}
		print $out "$j,$toplist{$y}{$j},$y\n";
	}
}
	
print "\nAnalysis is done!\n"; 
  
__END__
