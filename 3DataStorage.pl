#!/usr/bin/env perl

# ----------------------------------------------------------------------------------------
# BIOL595 Final Project: Literature Analysis (Part III)
# The function of this script is to connect to MySQL localhost, create a database, create 
# tables of Articles, Authors, Author_Article_Relationship, and Keywords. Then, extract
# data from xml file previously obtained by DataFetch.pl, and import the data to the
# database.
#
# Alexandr Pak, Krittikan Chanpaisaeng, & Xin Wen, April 28 2016
# ----------------------------------------------------------------------------------------

use warnings;
use DBI;
use XML::LibXML;
use Time::localtime;

my $dbh;
my $sth;
# set the parameters of database connection
my $host ="127.0.0.1";
print "\nPlease enter the username to localhost MySQL server:\n";
my $user = <>; 
chomp $user;
print "\nPlease enter the password to localhost:\n";
my $pass = <>;
chomp $pass;
print "\nPlease enter the port of localhost:\n";
my $port = <>;
chomp $port;
print "\nPlease name the database to create:\n";
$database = <>;
chomp $database;

# save the database information for future access
open (my $out, ">", "dbinfo.txt")|| die "Cannot open output file.\n";
print $out "$host $user $pass $port $database\n";
close ($out);

# connect to localhost and create a database
print "\nCreating database $database...\n";
create_database( $host, $user, $pass, $port, $database );
print "\nConnecting to database $database...\n";
connect_to_database( $host, $user, $pass, $port, $database );
print "\nCreating tables...\n";
create_tables();
print "\nParsing and importing data...\n";
xml_parsing();

$dbh->disconnect;

# ----------------------------------------------------------------------------------------
# create_database: 
# Use DBI:mysql to connect to mysql localhost and create a database.
# No return from the subroutine.
# Usage:
#	 create_database ( $host, $user, $pass, $port, $database );
# ----------------------------------------------------------------------------------------
sub create_database {
	# mysql user database name
	my ($host, $user, $pass, $port, $db) = @_;

	# connect to mysql localhost
	my $query = "connect to mysql localhost";
	$dbh = DBI->connect("DBI:mysql:host=$host;port=$port", $user, $pass,) 
	or die "Can't execute the query $query: $dbh->errstr\n";
	# create database
	$dbh->do("create database $db") or die "Cannot execute the query $query: $dbh->errstr\n";
}

# ----------------------------------------------------------------------------------------
# connect_to_database: 
# Connect to localhost mysql database
# No return from the subroutine.
# Usage:
#	 connect_to_database ( $host, $user, $pass, $port, $database );
# ----------------------------------------------------------------------------------------
sub connect_to_database {
	# mysql user database name
	my ($host, $user, $pass, $port, $db) = @_;

	# connect to mysql database
	my $query = "connect to mysql database";
	$dbh = DBI->connect("DBI:mysql:$db:$host:$port", $user, $pass,{
		PrintError => 0, RaiseError => 1, AutoCommit => 1,
	} ) or die "Can't execute the query $query: $dbh->errstr\n";
		
}

# ----------------------------------------------------------------------------------------
# create_tables: 
# Create tables Articles, Authors, Article_Author_Relationship, and Keywords
# No return from the subroutine.
# Usage:
#	 create_tables();
# ----------------------------------------------------------------------------------------
sub create_tables {

	# create tables Articles
	my $query = "create table Articles";
	my $sql = <<'END_SQL';
	CREATE TABLE Articles (
	  Id int(11) NOT NULL,
	  Year int(11) NOT NULL,
	  Title tinytext NOT NULL,
	  Abstract text NOT NULL,
	  Journal tinytext NOT NULL
	) 
END_SQL
	$sth = $dbh->do($sql) or die "Can't execute the query $query: $sth->errstr";

	# create tables Author_Article_Relationship
	$query = "create table Author_Article_Relationship";
	$sql = <<'END_SQL';
	CREATE TABLE Author_Article_Relationship (
	  AuthorId int(11) NOT NULL,
	  ArticleId int(11) NOT NULL
	) 
END_SQL
	$sth = $dbh->do($sql) or die "Can't execute the query $query: $sth->errstr";

	# create tables Keywords
	$query = "create table Keywords";
	$sql = <<'END_SQL';
	CREATE TABLE Keywords (
	  ArticleId int(11) NOT NULL,
	  Keyword varchar(50) NOT NULL
	) 
END_SQL
	$sth = $dbh->do($sql) or die "Can't execute the query $query: $sth->errstr";

	# create tables Authors
	$query = "create table Authors";
	$sql = <<'END_SQL';
	CREATE TABLE Authors (
	  NameId decimal(10,0) NOT NULL,
	  Name varchar(30) NOT NULL,
	  Affiliation tinytext
	) 
END_SQL
	$sth = $dbh->do($sql) or die "Can't execute the query $query: $sth->errstr";

	# set primary keys
	$query = "Set primary keys";
	$sql = <<'END_SQL';
	ALTER TABLE Articles
	  ADD PRIMARY KEY (Id)
END_SQL
	$sth = $dbh->prepare($sql) or die "Can't prepare the query $query: $sth->errstr";
	$sth->execute() or die "Can't execute the query $query: $sth->errstr";
	$sql = <<'END_SQL';
	ALTER TABLE Authors
	  ADD PRIMARY KEY (NameId)
END_SQL
	$sth = $dbh->prepare($sql) or die "Can't prepare the query $query: $sth->errstr";
	$sth->execute() or die "Can't execute the query $query: $sth->errstr";
}

# ----------------------------------------------------------------------------------------
# xml_parsing: 
# Use XML::LibXML module to parse the xml file, store information of articles and authors 
# to the tables Authors, Articles, Author_Article_Relationship, and Keywords in the 
# database.
# No return from the subroutine.
# Usage:
#	 xml_parsing ();
# ----------------------------------------------------------------------------------------
sub xml_parsing {
	my $file = "xmloutput.xml";
	open (my $in, "<", $file) || die "Cannot open file '$file'\n";

	# parse the xml file and import data into database
	my $parser = XML::LibXML->new;
	my $doc    = $parser->parse_fh($in);
	my $AuthorNumber = 0;
	my %Authors;

	foreach my $item ( $doc->findnodes('//PubmedArticle') ) {
		# save the PMID, Year, Title, Abstract, Journal information
		my ($PMID) = $item->findnodes('.//PMID')->string_value;
		# the newest article may not have the PubDate information
		my ($Year) = $item->findnodes('.//PubMedPubDate[attribute::PubStatus="pubmed"]/Year')->string_value;
		$Year = (localtime->year + 1900) unless ( $item->findnodes('.//PubMedPubDate[attribute::PubStatus="pubmed"]/Year')->size > 0 ); 
		my ($ArticleTitle) = $item->findnodes('.//ArticleTitle')->string_value;
		my ($AbstractText) = $item->findnodes('.//AbstractText')->to_literal;
		my ($Journal) = $item->findnodes('.//Journal/Title')->string_value;
		# save the keyword information
		my (@KeywordList) = $item->findnodes('.//KeywordList/Keyword')->to_literal_list;
		my (@MeshHeadingList) = $item->findnodes('.//DescriptorName')->to_literal_list;
		push (@KeywordList, @MeshHeadingList);
		# put the keywords into database, table of Keywords
		foreach my $keyword ( @KeywordList ) {
			$sth = $dbh->prepare ("INSERT INTO Keywords (ArticleId, Keyword) VALUES (?,?)");
			$sth->execute ($PMID, $keyword ) or die "Can't execute the insertion: $sth->errstr";
			$sth->finish();
		}
		# save the author information
		my (@AuthorInfo) = $item->findnodes('.//Article/AuthorList/Author');
		foreach my $author ( @AuthorInfo ) {
			my ($ForeName) = $author->findnodes('.//ForeName')->string_value;
			# filter junk author information
			if ($ForeName) {
				my ($LastName) = $author->findnodes('.//LastName')->string_value;
				my $FullName = join ' ',$ForeName, $LastName;
				my ($Affiliation) = $author->findnodes('.//AffiliationInfo/Affiliation')->to_literal;
				if (exists $Authors{$FullName} ) {
					# put the author and article id into database, table of Author_Article_Relationship
					$sth = $dbh->prepare ("INSERT INTO Author_Article_Relationship (AuthorId, ArticleId) VALUES (?,?)");
					$sth->execute ($Authors{$FullName}, $PMID)or die "Can't execute the insertion: $sth->errstr";
					$sth->finish();
				} else {
					$Authors{$FullName} = ++$AuthorNumber; 
					# put the new author information into database, table of Authors
					$sth = $dbh->prepare ("INSERT INTO Authors (NameId, Name, Affiliation) VALUES (?,?,?)");
					$sth->execute ($AuthorNumber, $FullName, $Affiliation)or die "Can't execute the insertion: $sth->errstr";
					$sth->finish();
					# put the author and article id into database, table of Author_Article_Relationship
					$sth = $dbh->prepare ("INSERT INTO Author_Article_Relationship (AuthorId, ArticleId) VALUES (?,?)");
					$sth->execute ($AuthorNumber, $PMID)or die "Can't execute the insertion: $sth->errstr";
					$sth->finish();
				}
			}
		}	
		# put the article information information into database, table of Articles
		$query = "INSERT INTO Articles (Id, Year, Title, Abstract, Journal) VALUES ( ?,?,?,?,?) ";
		$sth = $dbh->prepare($query) or die "Can't prepare data insertion: $dbh->errstr\n";
		$sth->execute( $PMID, $Year, $ArticleTitle, $AbstractText, $Journal) 
		or die "Can't execute the insertion: $sth->errstr";
		$sth->finish();
	}
	close($in);
	print "\nData Import Success!!! \n";
}




__END__

