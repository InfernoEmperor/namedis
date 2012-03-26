# require "csmathling.txt" generated by catree.pl
use feature qw(switch say);

use strict;
use warnings 'all';

use IO::Handle;
use lib '/media/tough/namedis';
#use lib 'c:/lsh/namedis';

use NLPUtil;

use lib '.';
use ConceptNet;

use Getopt::Std;

#use constant{
#	OPTIONS => 'A:',
#};

#my $ANCESTORS_SAVE_FILENAME;
#my $processedOptionCount = 0;
#
#my %opt;
#getopts(OPTIONS, \%opt);
#
#if(exists $opt{'A'}){
#	$ANCESTORS_SAVE_FILENAME = $opt{'A'};
#	print "Will save ancestor lists into file '$ANCESTORS_SAVE_FILENAME'\n";
#	$processedOptionCount++;
#}

open_or_die(CATS, "< csmathling.txt");

my $line;
my ($term, $cat2, $cat1, $catlist);
my %pickedCats;
my @cats;
my %pickedTerms;

openLogfile();

NLPUtil::initialize( lemmaCacheLoadFile => "lemma-cache.txt" );

ConceptNet::iniLists();

setDebug( ConceptNet::DBG_ADD_EDGE
					|
		 ConceptNet::DBG_BUILD_INDEX 
		);

#setNewTermMode(ConceptNet::NEWTERM_COMPLEX);

my $progresser = makeProgresser(vars => [ \$. ]);

while($line = <CATS>){
	&$progresser();
	
	trim($line);
	next if !$line;
	
	($cat2, $cat1) = split /\t/, $line;

	addEdge(\@conceptNet, $cat2, $cat1, 0);
}
progress_end("$. lines read from 'csmathling.txt'");
close(CATS);

my @isFileExtended = (0, 1);
my @catfiles = ('cat.txt', 'extended.txt');

#my @isFileExtended = (1);
#my @catfiles = ('extended2.txt');

excludeX(@excludedX);

my $catfile;

my $oldEdgeCount = 0;
my $oldNodeCount = 0;

my $tag;

my $conceptNetSize = \$ConceptNet::sizeof{\@conceptNet};

$progresser = makeProgresser( vars => [ \$., $conceptNetSize ] );

my $i;
my $isExt;
my $redir;

#my $excludedTermsFilename = getAvailName("excluded-terms.txt");
#open_or_die($EXCLUDE, "> $excludedTermsFilename");

for($i = 0; $i < @catfiles; $i++){
	$catfile = $catfiles[$i];
	$isExt = $isFileExtended[$i];
	
	print STDERR "Reading edges from '$catfile':\n";
	$tag = $catfile;
	$tag =~ s/\..+$//i;
	
	close(EDGES);
	open_or_die(EDGES, "< $catfile");
	
	while($line = <EDGES>){
		&$progresser();

		next if $line =~ /^#/;
		
		trim($line);
		next if !$line;
		
		($term, $catlist, $redir) = split /\t/, $line;
		
		if(!$catlist){
			print $tee "Weird $.: $line\n";
			next;
		}
			
		next if $isExt && !$redir && ( isExcluded($catlist) || isExcludedX($catlist) );
		
		@cats = split /\|/, $catlist;
		for $cat1(@cats){
			if(getTermID($cat1) == -1){
				next;
			}
			if($isExt){
				# discard all extended single-word terms, other than abbreviations (all-capital). 
				# too noisy :(
				# if it's extended, @cats only contain one term. so it's not low efficient to check the space count here
				my $spaceCount = $term =~ tr/ / /;
				if( $spaceCount == 0 && $term =~ /[^A-Z]/ ){
					if($redir){
						print $LOG "Exclude redir: $line\n";
					}
					next;
				}
									# like Example 13, Theorem 4, etc.
				if(! $redir && $spaceCount == 1 && $term =~ / \d{1,2}$/){
					print $LOG "Exclude ext: $line\n";
					next;
				}
				
#				if( length($term) > length($cat1) + 2 && 
#						substr( $term, 0, length($cat1) + 2 ) eq "$cat1 (" ){
#					print $LOG "Exclude term contained in parent: $line\n";
#					next;
#				}
					
				if(! $redir){
					addEdge(\@conceptNet, $term, $cat1, 1);
				}
				else{
					addEdge(\@conceptNet, $term, $cat1, 0);
				}
			}
			else{
				addEdge(\@conceptNet, $term, $cat1, 0);
			}
		}
	}
	
	progress_end("$. lines read from '$catfile'");
	say STDERR $$conceptNetSize - $oldEdgeCount, " new edges, ", 
				$termGID - $oldNodeCount, " new nodes";
				
	$oldEdgeCount = $$conceptNetSize;
	$oldNodeCount = $termGID;
}

if(@catfiles > 1){
	say STDERR "$$conceptNetSize edges in total, $termGID nodes";
}
	
my @treeRoots = ("computer science", "computer engineering", "Electromagnetism", "Mathematics", "Linguistics");

exclude(@excluded);
exclude4whitelist(\%whitelist);

dumpChildren( rootterms => \@treeRoots, dumpFilename => "csmathling-full.txt" );

cmdline( rootterms => \@treeRoots, dumpFilename => "csmathling-full.txt");

#if($ANCESTORS_SAVE_FILENAME){
#	saveAncestors(\@ancestorTree, $ANCESTORS_SAVE_FILENAME);
#}