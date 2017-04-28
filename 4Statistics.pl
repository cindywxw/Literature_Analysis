#!/usr/bin/env perl 

# ----------------------------------------------------------------------------------------
# BIOL595 Final Project: Literature Analysis (Part IV)
# The function of script is to connect to MySQL (Xampp) database created previously, 
# execute SQL query to count publications of each author, and export the top 10 authors
# and the number of their publications to a png file; count publications each year, and
# export the article numbers to a png file. 
#
# Alexandr Pak, Krittikan Chanpaisaeng, & Xin Wen, May 4 2016
# ----------------------------------------------------------------------------------------

# use module
use warnings;
use DBI;
use Data::Dumper;
use GD::Graph::bars;

# database information
my ($host, $user, $pass, $port, $db);
open (my $in, "<", "dbinfo.txt") || die "Cannot open file dbinfo.txt\n";
while (my $line = <$in>) {
	chomp $line;
	($host, $user, $pass, $port, $db) = split " ", $line;
}
my $dbh;
my $sth;
my @author;
my $count = 0;
open (my $out, ">", "Statistics.txt")|| die "Cannot open output file.\n";
# connect to the database
$dbh = DBI->connect("DBI:mysql:$db:$host:$port", $user, $pass,{
	PrintError       => 0,
	RaiseError       => 1,
	AutoCommit       => 1,
} ) or die "Can't connect to $db: $dbh->errstr\n";

stat_of_author ();
stat_of_pub ();

# ----------------------------------------------------------------------------------------
# stat_of_author: 
# Use SQL query to count the publications of each author, and fetchrow_array to store the
# data into an array.
# Usage:
#	 stat_of_author ();
# ----------------------------------------------------------------------------------------
sub stat_of_author {	
	# sql query to count author publication
	$query = "Count Author Publication";
	$sql = <<'END_SQL';
	SELECT
		Authors.Name,
		COUNT(*) AS 'count'
	FROM
		Authors
		INNER JOIN Author_Article_Relationship ON Authors.NameId=Author_Article_Relationship.AuthorId
		INNER JOIN Articles ON Author_Article_Relationship.ArticleId=Articles.Id
	GROUP BY
		Authors.NameId
	ORDER BY `count`  DESC
END_SQL
	$sth = $dbh->prepare($sql) or die "Can't prepare the query $query: $sth->errstr";
	$sth->execute() or die "Can't execute the query $query: $sth->errstr";

	# fetchrow from sql results into array
	while( my @row = $sth->fetchrow_array() ) {
		($author[$count][0], $author[$count][1]) = @row;
		$count++;
	}
	my @sorted_arr = sort {$b->[1] <=> $a->[1]} @author;		
	my @TopAuthors;
	my @AuthorName;
	my @PubNumber;
	# retrieve the top 10 productive authors and the numbers of their publications
	foreach my $i (0..9) {
		$AuthorName[$i]=$sorted_arr[$i][0];
		$PubNumber[$i]=$sorted_arr[$i][1];
		$TopAuthors[$i][0]=$sorted_arr[$i][0];
		$TopAuthors[$i][1]=$sorted_arr[$i][1];
	}
	
	# give a list
	print "\nWould you like to print out a list of the top 10 productive authors? [Y/N]\n";
	my $choice = <>;
	chomp $choice;
	if ($choice eq "Y" || $choice eq "y") {
		print $out "Top 10 Productive Authors\nRank 	Name		Number of Publications\n";
		foreach my $m (1..10) {
			printf $out "%4d %-26s %3d\n", $m, $AuthorName[$m-1], $PubNumber[$m-1];
		}
	}
	# create the bar graph
	print "\nWould you like to print out a graph of the author ranking? [Y/N]\n";
	$choice = <>;
	chomp $choice;
	if ($choice eq "Y" || $choice eq "y" ) { 
		authorrankgraph(\@AuthorName, \@PubNumber);
	}
}

# ----------------------------------------------------------------------------------------
# authorrankgraph: 
# Use GD::Graph module to create a bar chart for the most productive authors and the
# number of their publications.
# Usage:
#	 authorrankgraph (\@AuthorName, \@PubNumber);
# ----------------------------------------------------------------------------------------
sub authorrankgraph {

	my ( $x_ref, $y_ref )= @_;
	my @xLabels = @{ $x_ref};
	my @yLabels = @{ $y_ref};
	my @data = ( \@xLabels, \@yLabels ); 
	my $graph = GD::Graph::bars->new( 800, 600 ); 
	$graph->set(
		transparent   => '0',
		bgclr         => 'white',
		boxclr        => 'white',
		dclrs         => ['blue'],
		bar_width     => 40,
		show_values   => 1,
		x_labels_vertical => 1,
		title 	      => "Top 10 Productive Authors and Their Publcation Counts", 
		y_label 	  => "No. of Publication"
		); 
	my $image = $graph->plot( \@data ) or die( "Cannot create image" ); 
	open OUT, ">AuthorCount.png"; 
	binmode OUT; 
	print OUT $image->png(); 
	close OUT; 

}

# ----------------------------------------------------------------------------------------
# stat_of_pub: 
# Use SQL query to count the number of publications each year, and fetchrow_array to store
# the data into an array.
# Usage:
#	 stat_of_pub ();
# ----------------------------------------------------------------------------------------
sub stat_of_pub {
	my @publication;
	my @year;
	$count = 0;

	# sql query to count number of publications each year
	$query = "SELECT COUNT(id) AS Count, Year FROM Articles GROUP BY Year";
	$sth = $dbh->prepare($query) or die "Can't prepare the query $query: $sth->errstr";
	$sth->execute() or die "Can't execute the query $query: $sth->errstr";

	# fetchrow from sql results into array
	while( my @row = $sth->fetchrow_array() ) {
		($publication[$count], $year[$count]) = @row;
		($PubYear[$count][1],$PubYear[$count][0]) = @row;
		$count++;
	}
	$dbh->disconnect;

	# give a list
	print "\nWould you like to print out a list of the publications in each year? [Y/N]\n";
	$choice = <>;
	chomp $choice;
	if ($choice eq "Y" || $choice eq "y" ) {
		print $out "\n\nNumber of Publications Each Year\nYear,Publications\n";
		foreach my $i ( 1..$count) {
			print $out "$year[$i-1],	$publication[$i-1]\n";
		}
	}
	# create the bar graph
	print "\nWould you like to print out a graph of the publications in each year? [Y/N]\n";
	$choice = <>;
	chomp $choice;
	if ($choice eq "Y" || $choice eq "y" ) {
		pubyeargraph(\@year,\@publication);
	}
}

# ----------------------------------------------------------------------------------------
# pubyeargraph: 
# Use GD::Graph module to create a bar chart to show the change of publication numbers in
# each year.
# Usage:
#	 pubyeargraph(\@year,\@publication);
# ----------------------------------------------------------------------------------------
sub pubyeargraph {

	my ( $x_ref, $y_ref )= @_;
	my @xLabels = @{ $x_ref };
	my @yLabels = @{ $y_ref }; 
	my @data = ( \@xLabels, \@yLabels ); 
	my $graph = GD::Graph::bars->new( 1000, 600 ); 
	$graph->set( 
		transparent   => '0',
		bgclr         => 'white',
		boxclr        => 'white',
		dclrs         => ['dgreen'],
		bar_width     => 40,
		show_values   => 1,
		title         => "Publications in Each Year", 
		y_label       => "No. of Publication"
		); 
	my $image = $graph->plot( \@data ) or die( "Cannot create image" ); 
	open OUT, ">PublicationCount.png"; 
	binmode OUT; 
	print OUT $image->png(); 
	close OUT; 

}

exit;


__END__
