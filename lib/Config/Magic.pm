package Config::Magic;

#use 5.008002;
use strict;
use warnings;
use Parse::RecDescent;
require Exporter;

our @ISA = qw(Exporter);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

# This allows declaration	use Config::Magic ':all';
# If you do not need this, moving things directly into @EXPORT or @EXPORT_OK
# will save memory.
our %EXPORT_TAGS = ( 'all' => [ qw(parse new get_result) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw();

our $VERSION = '0.72';

# Preloaded methods go here.

sub parse
{
my $self=shift;
my ($FILE,$text);
return $self->{'parser'}->sections(shift) if(scalar(@_));
open(FILE,"<".$self->{'filename'}) || die "Unable to open file " . $self->{'filename'} . " in Config::Magic\n";
my @lines=<FILE>;
close(FILE);
for my $line (@lines) {$text .= $line; };
$self->{'result'}=$self->{'parser'}->sections($text);
return $self->{'result'};
}

sub get_result
{my $self=shift;
return $self->{'result'} if(exists($self->{'result'})); }

sub new {
  my %dat;
  bless(\%dat);

my $poop = q{
{
sub array2hash
 {
 my $hashref=shift;
 my %hashed;
 my @unhashed=@{$hashref};
  for my $elem (@unhashed)
  {
   if($$elem[0])
   {
   if(scalar(@{$elem})==2)
   {
    if(exists($hashed{$$elem[0]})) 
    {
       if(ref($hashed{$$elem[0]})=~/ARRAY/) {
        my @temparry=@{$hashed{$$elem[0]}};
        if(!($temparry[$#temparry]=~/loQuaTistop/)) { push(@{$hashed{$$elem[0]}},$$elem[1]); }
	else { 
	      delete($temparry[$#temparry]); 
	      $hashed{$$elem[0]}=[\@temparry,$$elem[1]];
	     }
       }
       else { $hashed{$$elem[0]} = [$hashed{$$elem[0]},$$elem[1]]; }
    } 
    else { $hashed{$$elem[0]}=$$elem[1]; 
         if(ref($hashed{$$elem[0]})=~/ARRAY/) {
	     push @{$hashed{$$elem[0]}},'loQuaTistop'; }
	   #Add this as a marker to show that nothing has yet been added to the array.
         } 
   } 
   else { $hashed{$$elem[0]}={} if(!exists($hashed{$$elem[0]})); };
  };
  };
   for my $key (%hashed) {
    if(ref($hashed{$key})=~/ARRAY/)
    { delete($hashed{$key}[scalar@{$hashed{$key}}-1]) if($hashed{$key}[scalar(@{$hashed{$key}})-1]=~/loQuaTistop/); }
   };
  return \%hashed;
 };

sub section_checker 
 { return [shift,array2hash(shift)]; };
}

#Ini files are the only kind of section that can't contain more ini files.
#That's why they're in their own spot. 
#No other type may contain inis, or there would be ambiguity
sections: section(s)  {array2hash($item[1]);}
#I'm going backwards - section refers to sections.  This has the potential to 
#generate infinite recursion, but in this case it will not.
section:  comment 
       | '<' qvar <commit> xml_1[$item[3]]  {[$item[2],$item[4]]}
       | '<' <commit> svar xml_1[$item[3]]  {[$item[3],$item[4]]}
       | ini_name <commit> strict_assign(s?) {section_checker($item[1],$item[3])}
       | varname bracket_section {section_checker($item[1],$item[2]); }
       | assign 

bracket_section: '(' section(s?) ')' {$item[2]}
               | '{' section(s?) '}' {$item[2]}
	       | <skip: "[ \t\r]*"> '[' <skip: "\s*"> section(s?) ']' {$item[2]}
xml_1 : xml_single 
      | xml_full section(s?) "</" "$arg[0]" ">" 
          {
	   push (@{$item[2]},@{$item[1]}); 
	   #else {unshift(@{$item[2]},[$item[1]]);}
	   array2hash($item[2]);
	  }
#I know it seems redundant, but it's because there's a flaw in the parser: 
# if it succeeds in a production, but it succeeds in the wrong path, it won't try again down a different one.
#  This is a workaround.
xml_single: varlist "/>" {$item[1]} | xml_assigns "/>" {$item[1]} | "/>" {[]}
#This thing requires arrays.
xml_full: varlist ">" {
	 if(ref($item[1])=~/ARRAY/) {
          my @return;
	  for my $it (@{$item[1]})
	   { push(@return,[$it]); };
	   \@return;
	  }
	 else {[[$item[1]]]; };
	} 
        | xml_assigns ">"  {$item[1]} 
	| ">"  {[]}

comment: /#.*?\n/ {[0]}
#C++ style comment
       | "\\\\" /.*?\n/ {[0]}
       | /;.*?\n/ {[0]}

assigns: assign(s?) {array2hash($item[1])}

xml_assigns: xml_assign(s?) {array2hash($item[1])}

ini_name: /\[([^\n#]*)\]/  {$1}

#The difference between normal and xml is that xml only has single variables on the right side, and 
#there's no space separated
xml_assign: left <skip: '[ \t\r]*'> svar


#The tokens are sacred unless quotes are used.
#If the first match failed, it means that we failed to find any assignment operator.  
#  If this is the case, we will assume it is without the operator.
#  Note that it the right is allowed to return an empty array/singleton by design.
assign: comment | 
      left <skip: '[ \t\r]*'> right {[$item[1],$item[3]]}
      | <skip:'[ \t\r]*'>svar {[$item[2]]}

csvlist: csv(s) <skip:'[ \t\r]*'> /([^\n#]*?)\n/
          { [@{$item[1]},$1]; }
csv: qvar ',' {$item[1]} 
   | /([^\n#;]*?),/ {$1;}
tsv: /([^\n#]*?)\t/ {$1;}
#There should be only one variable on the left.  If more than one are quoted, then it means that there are more than one on the left.
left:  qvar /(=>|:=|:|=)/ {$item[1]}
    |  /([^\{\}<>\(\)\[\]\n#]+?)(=>|:=|:|=|==)/ {$1;}
    |  csv 
    |  svar 

right: csvlist  {$item[1]} | varlist  {$item[1]}

#This is for ini files.  Each variable list must end at the end of a line.  This is to keep them
#From being confused with other types of files.
strict_assign: comment  
      | left <skip: '[ \t\r]*'> strict_right {[$item[1],$item[3]]}
      | <skip:'[ \t\r]*'>svar "\n" {[$item[2]]}
strict_right: csvlist "\n" {$item[1]} | varlist "\n" {$item[1]}

#This is supposed to be a flat list.  If it isn't, you're doing something wrong.  Stop it.
varlist: qvar varlist(?) 
{
if(scalar(@{$item[2]->[0]})) { unshift(@{$item[2]->[0]},$item[1]);  $item[2]->[0];}
else {$item[1];};
}
       | varname 
         {
	  my @return=split(/\s+/,$item[1]);
          if($#return==0) { $return[0]; } else {\@return; };
         }
#Variable names must be followed by newline or end tokens.
#Lookahead assertion takes care of this I hope.
#They must also NOT start with certain things.
varname: /.*?(?=[\n\{\}\[\]\(\)=:<>]|\/>|<\/)/ {
     #Eliminate trailing spaces
     $item[1]=~s/([^\s])\s*$/$1/;
     undef;
     $item[1] if(length($item[1])>0);
     }
svar: single  
    | qvar

qvar: /\'(.*?)\'/ {$1;}
    | /\"(.*?)\"/ {$1;}

single: /\s*(.*?)(?=[\n\{\}\[\]\(\)=:<>\s]|\/>|<\/|$)/  
{ $1 if(length($1)>0); }
};
$::RD_AUTOACTION =  q{ ($#item>1)?[@item[1..$#item]]:$item[1]};
  $dat{'filename'} = $_[1] if(scalar(@_)==2);
  $dat{'parser'}=new Parse::RecDescent($poop);
  return \%dat;
}
1;
__END__
=head1 NAME

Config::Magic - Perl extension for reading all kinds of configuration files

=head1 SYNOPSIS

 use Config::Magic; 
 use Data::Dumper;

 $input=q{
 Section 1 {
 [Section 4]
 #Comment style #1
 //Comment style #2
 ;Comment style #3
 Monkey:1
 Monkey=>2
 Monkey:=3
 <Section 2>
 Foo = Bar
 Baz { Bip:1
 Pants==5 }
 </Section>
 <Tasty Cheese="3" />
 <Section 5>
 Foo=Bippity,boppity,boo
 </Section>
 }
 }
 #Fastest way:
 print Dumper(Config::Magic::parse($input));

 #OO interface:

 $config = new Config::Magic("input.conf");
 print Dumper($config->parse);
 $result = $config->get_result;
 print Dumper($result);

=head2 OUTPUT (from first example)



 $VAR1 = {
          'Section 1' => {
                           'Tasty' => {
                                        'Cheese' => '3'
                                      },
                           'Section' => [
                                          {
                                            'Foo ' => 'Bar',
                                            'Baz' => {
                                                       'Bip' => '1',
                                                       'Pants' => '5'
                                                     },
                                            '2' => {}
                                          },
                                          {
                                            'Foo' => [
                                                       'Bippity',
                                                       'boppity',
                                                       'boo'
                                                     ],
                                            '5' => {}
                                          }
                                        ],
                           'Section 4' => {
                                            'Monkey' => [
                                                          '1',
                                                          '2',
                                                          '3'
                                                        ]
                                          }
                         }
        };

=head1 DESCRIPTION

This module uses Parse::RecDescent to generate a parse tree for nearly any kind of configuration file.  You can even combine files/configuration types.  It understands XML, Apache-style, ini files, csv files, and pretty much everything else I could find.  Just give it a file, and get a hash tree out.  If it doesn't understand the file, or it isn't well formed (such as if a bracket is missing, etc), then you will get a partial result, or no result at all.

There are no configuration options for this module.  It's just supposed to work.  The only ways it can be used are the ones shown in the synopsis, though it should recognize almost every kind of configuration file.

=head1 ABOUT THE GRAMMAR

Basically, config files as I know them can be broken down into three kinds of things:  comments, sections, and assignments.  This section covers how these are determined.  If you want a more precise description, see the code.  What follows is an attempt to put that into words.

=head2 Comments

Right now, the system recognizes three types of comments:  Those beginning with ;, those beginning with //, and those beginning with #.  Obviously you can interrupt any other type of token with a comment EXCEPT quotes.

=head2 Sections

Almost all kinds of sections can hold other sections, allowing nesting.  Each section will be represented in the hash tree as a hash, and each element will be a tuple in the hash.  

Kinds of sections:  

=head3 INI section 

exactly like a Windows INI file.  Because of the structure, these do not contain other sections - only assignments.
Example:

 [Section 1]
 a = b
 c : d

=head3 XML section

There are two flavors of this: an XML singleton, and an XML block statement

 Singleton:
 <Just one=two />
 Block:
 <Just one:two >Heres==more</Just>

The key thing to remember about XML statements is that within the block, only the first word is considered the name of the section.  Beyond that are either assignments, or an array which acts as a variable list.  Unlike most assignments, xml assignments are only to single variables - never to arrays.

=head3 Bracket Section

There are three kinds of these.  The easiest way to see them is to see examples:

 Section 1 {Statements}
 Section 2 (Statements)
 Section 3 [Statements]

Note that the third kind of statement might be confused for an INI if it contains only a singleton.  For this reason, the ONLY way to specify this kind of statement is if the block element "[" is on the same line as the section name declaration.  Otherwise, any amount of white space can separate the section name from it's declaration.

=head2 Assignments

There are a lot of ways of doing this.  First of all, any of these things are identifiable as assignment operators:
:,=,:=,==,=>

If you use any of these, whatever is on the left is considered the left side of the assignment, and whatever is on the right is considered the right side.

Note that each word (anything that doesn't contain spaces) on the right is considered a single operand, so this assignment:
 Left side=Right side

 Will produce this:
'Left side' => [
                'Right',
		'Side'
		]

If you do not use any operators, the first word (anything not spaces again) will be considered the variable, and everything else will be it's values.
Example:

 Left Right Right Right

 Will produce:
  'Left' => [
             'Right',
	     'Right',
	     'Right'
	    ]

If there is no right side, the value will be passed along as a singleton.  HOWEVER, in order to allow both singletons and lists together, it will become a key in a hash with the value equal to a reference to an empty hash.  This behaviour may change in the future depending on user input.

 Example assignments:
 Value=1
 5

 Output:
 {
  Value=>'1',
  5    =>{}
 }

=head2 Quotes and Quote Effects

Quotes may encapsulate anything that goes into the tree.  You may use single or double quotes, and the result is that everything within the quotes is considered a single element.

Quotes may also be multiline.  For this reason, neglecting to end a quote may have drastic consequences on the interpretation of your data.

If you wish to use a quote within one of your elements, quote it with the other kind of quote.  

Example input assignment:

'"Fire bad"'

Output:

 {
  '"Fire bad"'=>{}
 }

Note that the double quotes remain.  There is currently no way to escape a quote, simply because I don't know how to recognize and ignore that while also recognizing quotes within a regular expression.  If anyone knows, I'd be glad to hear it.

=head2 EXPORT

None by default.  

=head1 SEE ALSO

Parse::RecDescent

The global options used by Parse::RecDescent will affect this module as well, if you wish to affect this module's internals. Do not change the AutoAction, or this module will most likely cease to function.

Tie::IxHash

The output from Config::Magic is a hash, and normally there is no guarantee of ordering for a hash.  This module causes the elements to remain in insertion order - i.e. the things that are higher up in the file end up first.
This slows down hashing somewhat.

=head1 KNOWN LIMITATIONS

Because it uses Parse::RecDescent and the grammar created is very large, this module is slow and may take up enormous amounts of memory.  On my slowest test machine, a PIII-500, it took approximately two minutes to parse my /etc/apache/commonapache.conf, and used 320MB of RAM at it's peak.  This is a very complex configuration file, and is not what you can usually expect from the module; it is closer to the limits you'll reach.  I feel that this is okay because it only needs to parse configuration files, which are often small, and only need to be used at the beginning of the program.  After you get the hash tree, there's no real need for speed or memory.

It is unlikely to parse tab-separated value files with empty fields correctly.  The reason for this is that there is no way to tell the difference between space separated assignments and TSV assignments.  Since there are more of the latter, this was included in the grammer, while TSV files were left out.

There are also some things that happen when using ini files that make it difficult to use with other formats.  For example, consider this:

=head2 EXAMPLE:

 [Section 1]
 Singleton1
 Singleton2
 Singleton3
 Section2
 {Section stuff
 }

In this example, section 2 is an abiguity.  Is "Section2" a singleton from an ini section, or as the beginning title of a section?  If you combine INI files with other kinds, you must use beginning section markers on their own lines.  Note that this could change if there are improvements made to Parse::RecDescent.

=head2 FIXED EXAMPLE:

 [Section 1]
 Singleton1
 Singleton2
 Singleton3
 Section2 {
 Section stuff
 }

Finally, it is quite likely that there are many bugs remaining of which the author is unaware.

=head1 TODO

Make it possible to add and remove conflicting configurations from the list, if this is needed, possibly.  
I'm open to suggestions.


=head1 AUTHOR

Rusty Phillips <rustyp@freeshell.org>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2004 by Rusty Phillips

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.6 or,
at your option, any later version of Perl 5 you may have available.



=cut
